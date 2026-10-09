"""
mtrs.py - Thorlabs MTRS (Motorized Tilt and Rotation Stage) via Kinesis .NET.

El MTRS es DeviceType 117 -> BenchtopDCServo, canales "MTRS Rotate" / "MTRS Tilt".
El homing se hace en Kinesis; aqui solo se verifica. Cerrar Kinesis antes de conectar.

Parametros: seccion [mtrs] de config/testbed.toml (mismos nombres que el constructor).
"""

import os
import threading
import time

from .utils import move_time_estimate, wrap180

KINESIS_PATH = r"C:\Program Files\Thorlabs\Kinesis"
_K = {}          # modulos .NET cargados de forma diferida


def _load_kinesis(path):
    if _K:
        return _K
    import clr
    _K["dll_dir"] = os.add_dll_directory(path)
    for dll in ("Thorlabs.MotionControl.DeviceManagerCLI.dll",
                "Thorlabs.MotionControl.GenericMotorCLI.dll",
                "ThorLabs.MotionControl.Benchtop.DCServoCLI.dll"):
        clr.AddReference(os.path.join(path, dll))
    from System import Action, Decimal, UInt64
    from Thorlabs.MotionControl.DeviceManagerCLI import DeviceManagerCLI
    from Thorlabs.MotionControl.GenericMotorCLI.Settings import RotationSettings
    from Thorlabs.MotionControl.Benchtop.DCServoCLI import BenchtopDCServo
    _K.update(Action=Action, Decimal=Decimal, UInt64=UInt64, DeviceManagerCLI=DeviceManagerCLI,
              RotationSettings=RotationSettings, BenchtopDCServo=BenchtopDCServo)
    return _K


class MTRSBase:
    """Logica comun al MTRS real y al simulado."""

    def __init__(self, velocity_deg_s=1.5, acceleration_deg_s2=1.5, rotation_mode="LinearRange",
                 tolerance_deg=0.05):
        self.velocity, self.acceleration = velocity_deg_s, acceleration_deg_s2
        self.rotation_mode = rotation_mode
        self.tolerance = tolerance_deg
        self.info = {}

    def valid_angle(self, angle):
        return self.rotation_mode != "LinearRange" or 0.0 <= angle <= 360.0

    def angle_error(self, angle, current=None):
        return wrap180((self.angle_deg() if current is None else current) - angle)

    def estimated_time(self, angle):
        return move_time_estimate(abs(angle - self.angle_deg()), self.velocity, self.acceleration)

    def arrived(self, angle, current=None, moving=None):
        """True si esta en `angle` (dentro de tolerancia) y quieto."""
        moving = self.moving() if moving is None else moving
        return abs(self.angle_error(angle, current)) <= self.tolerance and not moving


class MTRS(MTRSBase):
    def __init__(self, rot_serial=None, tilt_serial=None, velocity_deg_s=1.5,
                 acceleration_deg_s2=1.5, rotation_mode="LinearRange",
                 rotation_direction="Quickest", tilt_target_deg=0.0,
                 tolerance_deg=0.05, polling_ms=50, kinesis_path=KINESIS_PATH):
        super().__init__(velocity_deg_s, acceleration_deg_s2, rotation_mode, tolerance_deg)
        self.rot_serial, self.tilt_serial = rot_serial or None, tilt_serial or None
        self.rotation_direction = rotation_direction
        self.tilt_target = tilt_target_deg
        self.polling_ms = polling_ms
        self.kinesis_path = kinesis_path
        self.devices, self.channels = [], []
        self.rot = self.tilt = None
        self.done = threading.Event()
        self.done.set()

    # ---------------------------------------------------------------
    def connect(self):
        k = _load_kinesis(self.kinesis_path)
        k["DeviceManagerCLI"].BuildDeviceList()
        found = [str(s) for s in k["DeviceManagerCLI"].GetDeviceList()]
        prefix = str(k["BenchtopDCServo"].DevicePrefix117)
        wanted = [s for s in (self.rot_serial, self.tilt_serial) if s]
        missing = [s for s in wanted if s not in found]
        if missing:
            raise RuntimeError(f"[MTRS] Not found: {missing}. Found: {found}. "
                               f"Close Kinesis if it is open.")
        serials = list(dict.fromkeys(wanted + [s for s in found if s.startswith(prefix)]))
        if not serials:
            raise RuntimeError(f"[MTRS] No MTRS found (prefix 117). Found: {found}")

        entries = []
        for serial in serials:
            device = k["BenchtopDCServo"].CreateBenchtopDCServo(serial)
            device.Connect(serial)
            self.devices.append(device)
            time.sleep(0.5)
            for n in range(1, device.GetDeviceInfo().NumChannels + 1):
                ch = device.GetChannel(n)
                if not ch.IsSettingsInitialized():
                    ch.WaitForSettingsInitialized(10000)
                ch.StartPolling(self.polling_ms)
                time.sleep(0.25)
                ch.EnableDevice()
                time.sleep(0.25)
                name = str(ch.LoadMotorConfiguration(ch.DeviceID).DeviceSettingsName)
                self.channels.append(ch)
                entries.append((serial, n, ch, name))
                print(f"[MTRS] {serial} channel {n}: '{name}'")

        def pick(serial, keyword):
            c = [e for e in entries if (serial is None or e[0] == serial) and keyword in e[3].lower()]
            if len(c) != 1:
                raise RuntimeError(f"[MTRS] Could not identify the '{keyword}' channel ({len(c)} candidates).")
            return c[0]

        rot_e, tilt_e = pick(self.rot_serial, "rot"), pick(self.tilt_serial, "tilt")
        self.rot, self.tilt = rot_e[2], tilt_e[2]
        not_homed = [n for n, ch in (("rotation", self.rot), ("tilt", self.tilt))
                     if not ch.Status.IsHomed]
        if not_homed:
            raise RuntimeError(f"[MTRS] Not homed: {not_homed}. Home it in Kinesis, then close Kinesis.")

        D, RS = k["Decimal"], k["RotationSettings"]
        self.rot.SetVelocityParams(D(self.velocity), D(self.acceleration))
        self.rot.SetRotationModes(getattr(RS.RotationModes, self.rotation_mode),
                                  getattr(RS.RotationDirections, self.rotation_direction))
        vp = self.rot.GetVelocityParams()
        if abs(self.tilt_deg() - self.tilt_target) > self.tolerance:
            print(f"[MTRS] Moving tilt to {self.tilt_target} deg...")
            self.tilt.MoveTo(D(self.tilt_target), 60000)

        self.info = {
            "rot_serial": rot_e[0], "rot_channel": rot_e[1], "tilt_serial": tilt_e[0],
            "tilt_channel": tilt_e[1], "velocity_deg_s": float(D.ToDouble(vp.MaxVelocity)),
            "acceleration_deg_s2": float(D.ToDouble(vp.Acceleration)),
            "rotation_mode": self.rotation_mode, "rotation_direction": self.rotation_direction,
            "tilt_target_deg": self.tilt_target,
        }
        print(f"[MTRS] Ready. Rotation = {self.angle_deg():.3f} deg, tilt = {self.tilt_deg():.3f} deg")

    # ---------------------------------------------------------------
    def angle_deg(self):
        return float(_K["Decimal"].ToDouble(self.rot.Position))

    def tilt_deg(self):
        return float(_K["Decimal"].ToDouble(self.tilt.Position))

    def moving(self):
        return bool(self.rot.Status.IsInMotion) or not self.done.is_set()

    def move_to(self, angle):
        """Inicia el movimiento (no espera a que termine)."""
        if not self.valid_angle(angle):
            raise ValueError(f"Angle {angle} outside [0, 360] (LinearRange).")
        if abs(self.angle_error(angle)) <= self.tolerance:
            return
        self.done.clear()
        cb = _K["Action"][_K["UInt64"]](lambda _id: self.done.set())
        self.rot.MoveTo(_K["Decimal"](float(angle)), cb)

    def stop(self):
        if self.rot is not None:
            self.rot.StopImmediate()
            self.done.set()

    def close(self):
        if self.rot is not None and self.moving():
            self.stop()
        for ch in self.channels:
            try:
                ch.StopPolling()
            except Exception:
                pass
        for d in self.devices:
            try:
                d.Disconnect()
            except Exception:
                pass
        print("[MTRS] Connection closed.")
