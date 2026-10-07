"""
03_MTRS_Rotation.py

Secuencia de orientaciones del MTRS (Thorlabs Motorized Tilt and Rotation Stage)
con telemetria de angulo a frecuencia fija (para el digital twin sincronizado).

    home -> [mover a K[i] -> settling -> dwell] para cada i -> (retorno a 0)

Con SERPENTINE, los ciclos alternan el orden (0 -> 288, luego 288 -> 0), de modo
que en LinearRange la plataforma nunca cruza 360 deg y el cable no se enrolla.

Durante TODAS las fases (homing, movimiento, settling, dwell) se reporta el
angulo a TELEMETRY_RATE_HZ: en consola (linea que se refresca), en una ventana
en vivo (vista superior + angulo vs tiempo) y en CSV con timestamp absoluto
(unix time) para sincronizarlo con el gantry y el osciloscopio.

Notas del hardware (ThorlabsDefaultSettings.xml, perfil "MTRS Rotate"):
  - El MTRS es DeviceType 117 -> Kinesis lo maneja con BenchtopDCServo
    (2 canales DC servo: "MTRS Rotate" y "MTRS Tilt").
  - Rotacion: MaxVel = 1.5 deg/s, MaxAccn = 3.0 deg/s^2, rango 0-360 deg.
  - Tilt: +/-3 deg. En este setup se mantiene a 0 deg (el tilt de 15 deg es
    mecanico, pieza impresa en 3D).
"""

import csv
import math
import os
import threading
import time
from datetime import datetime

import clr


# ============================================================
# CONFIGURACION
# ============================================================

KINESIS_PATH = r"C:\Program Files\Thorlabs\Kinesis"

# Seriales (texto, 8 digitos, prefijo 117). Se ven en Kinesis o con 01_mtrs_detect.py.
# Si rotacion y tilt tienen serial distinto, poner cada uno; si es el mismo
# controlador con 2 canales, poner el mismo serial en ambos.
# None -> autodetectar entre todos los MTRS conectados (por nombre de configuracion
#         "MTRS Rotate" / "MTRS Tilt").
ROT_SERIAL_NO = None             # p.ej. "117000001"
TILT_SERIAL_NO = None            # p.ej. "117000002"
ROT_CHANNEL = None               # None -> autodetectar; solo necesario si un serial
TILT_CHANNEL = None              #         tiene varios canales y no se identifican

# --- Secuencia de orientaciones (azimuth, deg) ---------------
K_DEG = [0.0, 72.0, 144.0, 216.0, 288.0]
DWELL_TIME_S = 1.0               # tiempo de permanencia en cada orientacion
N_CYCLES = 2                     # repeticiones de la secuencia (simula N puntos XY)
SERPENTINE = True                # ciclo par: 0 -> 288 ; ciclo impar: 288 -> 0
                                 # (sin movimiento de retorno y sin enrollar el cable)
RETURN_TO_ZERO_AT_END = True     # volver a 0 deg al terminar (en LinearRange va en reversa)

# --- Perfil de movimiento (rotacion) -------------------------
ROT_MAX_VELOCITY_DEG_S = 1.5     # maximo del MTRS
ROT_ACCELERATION_DEG_S2 = 1.5    # maximo del MTRS (perfil Kinesis)
ROT_BACKLASH_DEG = None          # None -> mantener el valor del dispositivo

# --- Wrapping / shortest-path --------------------------------
# ROTATION_MODE:
#   "LinearRange"         posicion absoluta en [0, 360], nunca cruza 360 -> 0.
#                         El camino es determinista y el cable del PD no se enrolla.
#   "RotationalRange"     posicion reportada con wrap en [0, 360); puede cruzar 360.
#   "RotationalUnlimited" posicion sin limite (sin wrap).
# ROTATION_DIRECTION (solo aplica a los modos rotacionales):
#   "Quickest" (camino mas corto) | "Forwards" | "Reverse"
ROTATION_MODE = "LinearRange"
ROTATION_DIRECTION = "Quickest"

# Proteccion del cable: detiene el motor si la rotacion acumulada (unwrapped,
# medida desde el home) sale de este rango.
CABLE_LIMIT_DEG = (-10.0, 370.0)

# --- Settling ------------------------------------------------
# La orientacion se considera asentada cuando |error| <= POSITION_TOLERANCE_DEG
# y el motor esta quieto de forma continua durante SETTLING_TIME_S.
POSITION_TOLERANCE_DEG = 0.05    # repetibilidad bidireccional del MTRS: +/-0.05 deg
SETTLING_TIME_S = 0.2
SETTLING_TIMEOUT_S = 5.0

# --- Homing --------------------------------------------------
# El homing se hace en Kinesis (GUI). Con HOME_* = False el script exige que el
# canal ya tenga home y se detiene si no lo tiene.
HOME_ROTATION = False
FORCE_HOME = False               # False -> solo hace home si el canal lo necesita
HOME_TIMEOUT_S = 300.0           # una vuelta completa a 1.5 deg/s ~ 240 s

# --- Tilt (se mantiene fijo) ---------------------------------
CONTROL_TILT = True              # False -> no se toca el canal de tilt
HOME_TILT = False
TILT_TARGET_DEG = 0.0

# --- Telemetria ----------------------------------------------
TELEMETRY_RATE_HZ = 10.0
KINESIS_POLLING_MS = 50          # debe ser <= 1000 / TELEMETRY_RATE_HZ
PRINT_TELEMETRY = True
PRINT_INLINE = True              # True -> una linea que se refresca; False -> una linea por muestra
SAVE_CSV = True
LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs")

# --- Vista en vivo (matplotlib) ------------------------------
LIVE_VIEW = True
# Ajustar para que coincida con el MTRS fisico visto desde arriba:
VIEW_ZERO_LOCATION = "N"         # donde se dibuja 0 deg: "N", "E", "S", "W"
VIEW_CLOCKWISE = False           # sentido en que crece el angulo visto desde arriba
VIEW_HISTORY_S = 120.0           # ventana de la grafica angulo vs tiempo


# ============================================================
# CARGAR KINESIS
# ============================================================

dll_dir = os.add_dll_directory(KINESIS_PATH)

for dll in (
    "Thorlabs.MotionControl.DeviceManagerCLI.dll",
    "Thorlabs.MotionControl.GenericMotorCLI.dll",
    "ThorLabs.MotionControl.Benchtop.DCServoCLI.dll",
):
    clr.AddReference(os.path.join(KINESIS_PATH, dll))

from System import Action, Decimal, UInt64
from Thorlabs.MotionControl.DeviceManagerCLI import DeviceManagerCLI
from Thorlabs.MotionControl.GenericMotorCLI.Settings import RotationSettings
from Thorlabs.MotionControl.Benchtop.DCServoCLI import BenchtopDCServo


# ============================================================
# UTILIDADES
# ============================================================

def to_float(value):
    return float(Decimal.ToDouble(value))


def wrap180(angle_deg):
    return (angle_deg + 180.0) % 360.0 - 180.0


def move_time_estimate(distance, vel, acc):
    """Duracion de un perfil trapezoidal (o triangular si no llega a vel)."""
    distance = abs(distance)
    if distance >= vel ** 2 / acc:
        return distance / vel + vel / acc
    return 2.0 * math.sqrt(distance / acc)


class RateTimer:
    """Temporizador de frecuencia fija sin deriva acumulada."""

    def __init__(self, rate_hz):
        self.period = 1.0 / rate_hz
        self.next = time.perf_counter()

    def wait(self):
        self.next += self.period
        delay = self.next - time.perf_counter()
        if delay > 0:
            time.sleep(delay)
        else:
            self.next = time.perf_counter()


class Telemetry:
    """Muestrea rotacion/tilt, imprime y guarda en CSV.

    `subscribers` es el punto de integracion futuro (digital twin, gantry,
    osciloscopio): cada funcion recibe el dict de la muestra.
    """

    FIELDS = [
        "unix_time_s", "t_s", "cycle", "k_index", "phase", "target_deg",
        "rot_deg", "rot_unwrapped_deg", "error_deg", "tilt_deg", "in_motion",
    ]

    def __init__(self, rot, tilt, csv_path=None, subscribers=()):
        self.rot = rot
        self.tilt = tilt
        self.timer = RateTimer(TELEMETRY_RATE_HZ)
        self.t0 = time.perf_counter()
        self.subscribers = list(subscribers)
        self.cycle = 0
        self.k_index = -1
        self.last_rot = to_float(rot.Position)
        self.unwrapped = self.last_rot
        self.last_key = None
        self.file = None
        if csv_path:
            self.file = open(csv_path, "w", newline="")
            self.writer = csv.DictWriter(self.file, fieldnames=self.FIELDS)
            self.writer.writeheader()

    def sample(self, phase, target=None):
        rot_deg = to_float(self.rot.Position)
        self.unwrapped += wrap180(rot_deg - self.last_rot)
        self.last_rot = rot_deg
        error = wrap180(rot_deg - target) if target is not None else float("nan")

        s = {
            "unix_time_s": time.time(),
            "t_s": time.perf_counter() - self.t0,
            "cycle": self.cycle,
            "k_index": self.k_index,
            "phase": phase,
            "target_deg": target if target is not None else float("nan"),
            "rot_deg": rot_deg,
            "rot_unwrapped_deg": self.unwrapped,
            "error_deg": error,
            "tilt_deg": to_float(self.tilt.Position) if self.tilt else float("nan"),
            "in_motion": bool(self.rot.Status.IsInMotion),
        }

        if PRINT_TELEMETRY:
            k_txt = f"k={s['k_index'] + 1}/{len(K_DEG)}" if s["k_index"] >= 0 else "k=-  "
            line = (
                f"[{s['t_s']:8.2f} s] {phase:<10} c={s['cycle']} {k_txt}  "
                f"target={s['target_deg']:8.3f}  rot={rot_deg:8.3f}  "
                f"err={error:+8.3f}  tilt={s['tilt_deg']:+6.3f}  "
                f"acum={self.unwrapped:8.2f}  {'MOV' if s['in_motion'] else '---'}"
            )
            if PRINT_INLINE:
                key = (phase, s["cycle"], s["k_index"])
                if self.last_key is not None and key != self.last_key:
                    print()
                self.last_key = key
                print("\r" + line, end="", flush=True)
            else:
                print(line)
        if self.file:
            self.writer.writerow(s)
            self.file.flush()
        for fn in self.subscribers:
            fn(s)

        lo, hi = CABLE_LIMIT_DEG
        if not phase.startswith("HOME") and not lo <= self.unwrapped <= hi:
            raise RuntimeError(
                f"Rotacion acumulada {self.unwrapped:.1f} deg fuera de "
                f"CABLE_LIMIT_DEG {CABLE_LIMIT_DEG}. Motor detenido."
            )
        return s

    def close(self):
        if self.file:
            self.file.close()


class LiveView:
    """Vista en vivo: MTRS visto desde arriba (polar) + angulo vs tiempo.

    Usa blitting: el fondo (ejes, rejilla, etiquetas) se dibuja una vez y en
    cada muestra solo se redibujan los elementos que cambian.
    """

    def __init__(self):
        import matplotlib.pyplot as plt

        self.plt = plt
        plt.ion()
        self.fig = plt.figure("MTRS - vista en vivo", figsize=(12, 5.5))
        self.ax_p = self.fig.add_subplot(1, 2, 1, projection="polar")
        self.ax_t = self.fig.add_subplot(1, 2, 2)

        ax = self.ax_p
        ax.set_theta_zero_location(VIEW_ZERO_LOCATION)
        ax.set_theta_direction(-1 if VIEW_CLOCKWISE else 1)
        ax.set_ylim(0, 1.2)
        ax.set_yticklabels([])
        ax.set_title("Vista superior")
        k_rad = [math.radians(a) for a in K_DEG]
        self.k_marks = ax.scatter(k_rad, [1.0] * len(K_DEG), s=160, zorder=3,
                                  c=["lightgrey"] * len(K_DEG), edgecolors="k")
        for k, a in enumerate(k_rad):
            ax.text(a, 1.13, f"k{k + 1}", ha="center", va="center", fontsize=9)
        self.target_line, = ax.plot([0, 0], [0, 1], "--", color="tab:orange", lw=1.5)
        self.needle, = ax.plot([0, 0], [0, 0.95], color="tab:blue", lw=5,
                               solid_capstyle="round")
        self.info = self.fig.text(0.02, 0.02, "", family="monospace", fontsize=9)

        ax = self.ax_t
        ax.set_xlabel("t [s]")
        ax.set_ylabel("Angulo de rotacion [deg]")
        ax.set_ylim(-10, 370)
        ax.set_yticks(K_DEG + [360.0])
        ax.grid(True, alpha=0.4)
        self.line_target, = ax.plot([], [], "--", color="tab:orange", lw=1.2, label="target")
        self.line_rot, = ax.plot([], [], color="tab:blue", lw=1.8, label="rot")
        ax.legend(loc="upper left")

        self.t, self.rot, self.target = [], [], []
        self.visited = set()
        self.cycle = None
        self.x0 = 0.0
        ax.set_xlim(self.x0, self.x0 + VIEW_HISTORY_S)

        self.animated = [self.k_marks, self.target_line, self.needle,
                         self.line_target, self.line_rot, self.info]
        for artist in self.animated:
            artist.set_animated(True)
        self.background = None
        self.fig.canvas.mpl_connect("draw_event", self._on_draw)

        self.fig.tight_layout(rect=(0, 0.06, 1, 1))
        plt.show(block=False)
        self.fig.canvas.draw()
        self.fig.canvas.flush_events()

    def _on_draw(self, _event):
        self.background = self.fig.canvas.copy_from_bbox(self.fig.bbox)
        for artist in self.animated:
            self.fig.draw_artist(artist)

    def __call__(self, s):
        if not self.plt.fignum_exists(self.fig.number):
            return
        if s["cycle"] != self.cycle:
            self.cycle = s["cycle"]
            self.visited.clear()
        if s["phase"] == "DWELL":
            self.visited.add(s["k_index"])

        colors = []
        for k in range(len(K_DEG)):
            if k == s["k_index"] and s["phase"] != "DWELL":
                colors.append("tab:orange")
            elif k in self.visited:
                colors.append("tab:green")
            else:
                colors.append("lightgrey")
        self.k_marks.set_facecolor(colors)

        rot = math.radians(s["rot_deg"])
        self.needle.set_data([rot, rot], [0, 0.95])
        has_target = not math.isnan(s["target_deg"])
        tgt = math.radians(s["target_deg"]) if has_target else rot
        self.target_line.set_data([tgt, tgt], [0, 1.0])
        self.target_line.set_visible(has_target)

        self.t.append(s["t_s"])
        self.rot.append(s["rot_deg"])
        self.target.append(s["target_deg"])
        self.line_rot.set_data(self.t, self.rot)
        self.line_target.set_data(self.t, self.target)

        self.info.set_text(
            f"{s['phase']:<10} ciclo={s['cycle']}  "
            f"k={s['k_index'] + 1 if s['k_index'] >= 0 else '-'}/{len(K_DEG)}   "
            f"rot={s['rot_deg']:8.3f} deg   target={s['target_deg']:8.3f} deg   "
            f"err={s['error_deg']:+7.3f} deg   tilt={s['tilt_deg']:+6.3f} deg   "
            f"acumulado={s['rot_unwrapped_deg']:7.2f} deg   "
            f"{'EN MOVIMIENTO' if s['in_motion'] else 'quieto'}"
        )

        canvas = self.fig.canvas
        if s["t_s"] > self.x0 + VIEW_HISTORY_S:
            # Desplazar la ventana de tiempo: requiere redibujar el fondo
            self.x0 = s["t_s"] - 0.25 * VIEW_HISTORY_S
            self.ax_t.set_xlim(self.x0, self.x0 + VIEW_HISTORY_S)
            canvas.draw()
        elif self.background is not None:
            canvas.restore_region(self.background)
            for artist in self.animated:
                self.fig.draw_artist(artist)
            canvas.blit(self.fig.bbox)
        canvas.flush_events()

    def keep_open(self):
        if self.plt.fignum_exists(self.fig.number):
            for artist in self.animated:
                artist.set_animated(False)
            self.fig.canvas.draw_idle()
            print("\nCierra la ventana de la vista en vivo para terminar.")
            self.plt.ioff()
            self.plt.show()


# ============================================================
# MOVIMIENTOS CON TELEMETRIA
# ============================================================

def run_tracked(tel, command, phase, target, timeout_s, is_done):
    """Lanza un comando asincrono de Kinesis y muestrea hasta que termine.

    command(callback) debe iniciar el movimiento (MoveTo / Home).
    is_done(sample) es un respaldo por si el callback no llega.
    """
    done = threading.Event()
    command(Action[UInt64](lambda _task_id: done.set()))
    t_start = time.perf_counter()

    while True:
        s = tel.sample(phase, target)
        elapsed = time.perf_counter() - t_start
        if elapsed > timeout_s:
            raise TimeoutError(f"{phase}: no termino en {timeout_s:.0f} s")
        tel.timer.wait()
        if done.is_set() or (elapsed > 1.0 and not s["in_motion"] and is_done(s)):
            return elapsed


def move_rotation(tel, rot, target):
    current = to_float(rot.Position)
    if ROTATION_MODE == "LinearRange":
        distance = target - current
    elif ROTATION_DIRECTION == "Quickest":
        distance = wrap180(target - current)
    else:
        distance = 360.0
    if abs(wrap180(target - current)) <= POSITION_TOLERANCE_DEG:
        return 0.0

    timeout = 1.5 * move_time_estimate(
        distance, ROT_MAX_VELOCITY_DEG_S, ROT_ACCELERATION_DEG_S2
    ) + 10.0
    return run_tracked(
        tel,
        lambda cb: rot.MoveTo(Decimal(target), cb),
        "MOVING", target, timeout,
        lambda s: abs(s["error_deg"]) <= POSITION_TOLERANCE_DEG,
    )


def settle(tel, target):
    t_start = time.perf_counter()
    t_ok = None
    while True:
        s = tel.sample("SETTLING", target)
        now = time.perf_counter()
        tel.timer.wait()
        if abs(s["error_deg"]) <= POSITION_TOLERANCE_DEG and not s["in_motion"]:
            t_ok = t_ok or now
            if now - t_ok >= SETTLING_TIME_S:
                return now - t_start, s
        else:
            t_ok = None
        if now - t_start > SETTLING_TIMEOUT_S:
            print(f"\n  ! Settling timeout: error = {s['error_deg']:+.3f} deg")
            return now - t_start, s


def dwell(tel, target):
    t_start = time.perf_counter()
    samples = []
    while time.perf_counter() - t_start < DWELL_TIME_S:
        samples.append(tel.sample("DWELL", target))
        tel.timer.wait()
    return samples


# ============================================================
# CONEXION
# ============================================================

def find_serials():
    """Seriales a conectar: los indicados o, si falta alguno, todos los MTRS."""
    DeviceManagerCLI.BuildDeviceList()
    serials = [str(s) for s in DeviceManagerCLI.GetDeviceList()]
    print(f"Dispositivos Thorlabs encontrados: {serials}")
    for wanted in (ROT_SERIAL_NO, TILT_SERIAL_NO):
        if wanted is not None and wanted not in serials:
            raise RuntimeError(f"No se encontro el dispositivo {wanted}.")
    if ROT_SERIAL_NO is not None and (TILT_SERIAL_NO is not None or not CONTROL_TILT):
        return list(dict.fromkeys(s for s in (ROT_SERIAL_NO, TILT_SERIAL_NO) if s))
    mtrs = [s for s in serials if s.startswith(str(BenchtopDCServo.DevicePrefix117))]
    if not mtrs:
        raise RuntimeError("No se encontro ningun MTRS (serial con prefijo 117).")
    return list(dict.fromkeys([s for s in (ROT_SERIAL_NO, TILT_SERIAL_NO) if s] + mtrs))


def pick_channel(entries, serial, channel, keyword, required):
    """Elige un canal de `entries` = [(serial, n, ch, name)]."""
    found = [e for e in entries
             if (serial is None or e[0] == serial) and (channel is None or e[1] == channel)]
    if len(found) > 1:
        found = [e for e in found if keyword in e[3].lower()]
    if len(found) == 1:
        print(f"  -> {keyword.upper()}: serial {found[0][0]}, canal {found[0][1]} ('{found[0][3]}')")
        return found[0][2]
    if not required and not found:
        print(f"  -> {keyword.upper()}: no encontrado (no se controlara)")
        return None
    raise RuntimeError(
        f"No se pudo identificar el canal '{keyword}' ({len(found)} candidatos). "
        f"Define ROT/TILT_SERIAL_NO y/o ROT/TILT_CHANNEL manualmente."
    )


def prepare_channel(device, number):
    ch = device.GetChannel(number)
    if not ch.IsSettingsInitialized():
        ch.WaitForSettingsInitialized(10000)
    if not ch.IsSettingsInitialized():
        raise RuntimeError(f"El canal {number} no pudo inicializarse.")
    ch.StartPolling(KINESIS_POLLING_MS)
    time.sleep(0.25)
    ch.EnableDevice()
    time.sleep(0.25)
    config = ch.LoadMotorConfiguration(ch.DeviceID)
    name = str(config.DeviceSettingsName)
    print(f"  Canal {number}: '{name}'  posicion = {to_float(ch.Position):.3f} deg")
    return ch, name


def configure_rotation(rot):
    limits = rot.AdvancedMotorLimits
    v_max, a_max = to_float(limits.VelocityMaximum), to_float(limits.AccelerationMaximum)
    vel = min(ROT_MAX_VELOCITY_DEG_S, v_max) if v_max > 0 else ROT_MAX_VELOCITY_DEG_S
    acc = min(ROT_ACCELERATION_DEG_S2, a_max) if a_max > 0 else ROT_ACCELERATION_DEG_S2
    rot.SetVelocityParams(Decimal(vel), Decimal(acc))

    rot.SetRotationModes(
        getattr(RotationSettings.RotationModes, ROTATION_MODE),
        getattr(RotationSettings.RotationDirections, ROTATION_DIRECTION),
    )
    if ROT_BACKLASH_DEG is not None:
        rot.SetBacklash(Decimal(ROT_BACKLASH_DEG))

    vp = rot.GetVelocityParams()
    print("\nConfiguracion de rotacion (leida del dispositivo):")
    print(f"  Limites del dispositivo: v_max = {v_max:.3f} deg/s, a_max = {a_max:.3f} deg/s^2")
    print(f"  Velocidad maxima:        {to_float(vp.MaxVelocity):.3f} deg/s")
    print(f"  Aceleracion:             {to_float(vp.Acceleration):.3f} deg/s^2")
    print(f"  Rotation mode:           {ROTATION_MODE} / {ROTATION_DIRECTION}")
    print(f"  Backlash:                {to_float(rot.GetBacklash()):.3f} deg")
    print(f"  Settling:                |err| <= {POSITION_TOLERANCE_DEG} deg durante {SETTLING_TIME_S} s")
    print(f"  Dwell:                   {DWELL_TIME_S} s   Telemetria: {TELEMETRY_RATE_HZ} Hz")
    print(f"  Tiempo estimado 72 deg:  {move_time_estimate(72.0, to_float(vp.MaxVelocity), to_float(vp.Acceleration)):.1f} s")


# ============================================================
# PROGRAMA PRINCIPAL
# ============================================================

def main():
    if KINESIS_POLLING_MS > 1000.0 / TELEMETRY_RATE_HZ:
        raise ValueError("KINESIS_POLLING_MS debe ser <= periodo de telemetria.")
    if ROTATION_MODE == "LinearRange" and not all(0.0 <= k <= 360.0 for k in K_DEG):
        raise ValueError("En LinearRange todos los K_DEG deben estar en [0, 360].")

    print("\n=== TEST MTRS 3: SECUENCIA DE ROTACION ===\n")
    serials = find_serials()

    devices = []
    channels = []
    tel = None
    rot = None
    view = None
    results = []

    try:
        entries = []
        for serial in serials:
            device = BenchtopDCServo.CreateBenchtopDCServo(serial)
            device.Connect(serial)
            devices.append(device)
            time.sleep(0.5)
            info = device.GetDeviceInfo()
            print(f"\nConectado {serial}: {info.Description}  ({info.NumChannels} canal(es))")
            for number in range(1, info.NumChannels + 1):
                ch, name = prepare_channel(device, number)
                channels.append(ch)
                entries.append((serial, number, ch, name))

        print()
        rot = pick_channel(entries, ROT_SERIAL_NO, ROT_CHANNEL, "rot", required=True)
        tilt = pick_channel(entries, TILT_SERIAL_NO, TILT_CHANNEL, "tilt",
                            required=TILT_SERIAL_NO is not None)
        if tilt is rot:
            raise RuntimeError("Rotacion y tilt apuntan al mismo canal; revisa la configuracion.")

        configure_rotation(rot)

        must_be_homed = [("rotacion", rot)] if not HOME_ROTATION else []
        if CONTROL_TILT and tilt is not None and not HOME_TILT:
            must_be_homed.append(("tilt", tilt))
        not_homed = [name for name, ch in must_be_homed if not ch.Status.IsHomed]
        if not_homed:
            raise RuntimeError(
                f"Canal(es) sin home: {', '.join(not_homed)}. Haz el homing en "
                f"Kinesis, cierra Kinesis y vuelve a ejecutar este script."
            )
        if must_be_homed:
            print("  Homing verificado (hecho previamente en Kinesis).")

        csv_path = None
        if SAVE_CSV:
            os.makedirs(LOG_DIR, exist_ok=True)
            csv_path = os.path.join(
                LOG_DIR, f"mtrs_rotation_{datetime.now():%Y%m%d_%H%M%S}.csv"
            )
        tel = Telemetry(rot, tilt, csv_path)

        input("\nPulsa ENTER para iniciar la secuencia...")
        if LIVE_VIEW:
            view = LiveView()
            tel.subscribers.append(view)
        tel.timer = RateTimer(TELEMETRY_RATE_HZ)

        # --- Tilt fijo ---------------------------------------
        if CONTROL_TILT and tilt is not None:
            if HOME_TILT and (FORCE_HOME or tilt.NeedsHoming):
                run_tracked(tel, lambda cb: tilt.Home(cb), "HOME_TILT", None,
                            HOME_TIMEOUT_S, lambda s: tilt.Status.IsHomed)
            if abs(to_float(tilt.Position) - TILT_TARGET_DEG) > POSITION_TOLERANCE_DEG:
                run_tracked(tel, lambda cb: tilt.MoveTo(Decimal(TILT_TARGET_DEG), cb),
                            "MOVE_TILT", None, 60.0,
                            lambda s: abs(s["tilt_deg"] - TILT_TARGET_DEG) <= POSITION_TOLERANCE_DEG)

        # --- Homing de rotacion ------------------------------
        if HOME_ROTATION and (FORCE_HOME or rot.NeedsHoming):
            run_tracked(tel, lambda cb: rot.Home(cb), "HOME_ROT", 0.0,
                        HOME_TIMEOUT_S, lambda s: rot.Status.IsHomed)
            tel.unwrapped = tel.last_rot = to_float(rot.Position)

        # --- Secuencia K -------------------------------------
        for cycle in range(N_CYCLES):
            tel.cycle = cycle
            order = list(range(len(K_DEG)))
            if SERPENTINE and cycle % 2 == 1:
                order.reverse()

            for k in order:
                target = K_DEG[k]
                tel.k_index = k
                t_move = move_rotation(tel, rot, target)
                t_settle, s_settled = settle(tel, target)
                dwell_samples = dwell(tel, target)
                errors = [d["error_deg"] for d in dwell_samples]
                results.append({
                    "cycle": cycle, "k": k, "target": target,
                    "t_move": t_move, "t_settle": t_settle,
                    "rot": s_settled["rot_deg"],
                    "err_mean": sum(errors) / len(errors) if errors else float("nan"),
                    "err_max": max(map(abs, errors)) if errors else float("nan"),
                })

        if RETURN_TO_ZERO_AT_END:
            tel.k_index = -1
            move_rotation(tel, rot, 0.0)
            settle(tel, 0.0)

        print("\n================ RESUMEN ================")
        print(" cyc  k  target   rot_final  err_mean  err_max  t_move  t_settle")
        for r in results:
            print(
                f" {r['cycle']:>3} {r['k'] + 1:>2} {r['target']:7.2f}  {r['rot']:9.3f}  "
                f"{r['err_mean']:+8.4f} {r['err_max']:8.4f} {r['t_move']:6.1f}s {r['t_settle']:7.2f}s"
            )
        print(f"Rotacion acumulada (unwrapped): {tel.unwrapped:.2f} deg")
        if csv_path:
            print(f"Telemetria guardada en: {csv_path}")
        print("\n=== TEST COMPLETADO ===")

    except BaseException as e:
        print(f"\n\n{'Interrumpido por el usuario' if isinstance(e, KeyboardInterrupt) else 'ERROR'}."
              " Deteniendo motor...")
        if rot is not None:
            rot.StopImmediate()
        if not isinstance(e, KeyboardInterrupt):
            raise

    finally:
        if tel is not None:
            tel.close()
        print("\nCerrando conexion...")
        for ch in channels:
            try:
                ch.StopPolling()
            except Exception:
                pass
        for device in devices:
            try:
                device.Disconnect()
            except Exception:
                pass
        print("Conexion cerrada.")
        if view is not None:
            view.keep_open()


if __name__ == "__main__":
    main()
