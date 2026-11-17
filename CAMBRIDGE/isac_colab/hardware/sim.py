"""
sim.py - Simulated gantry and MTRS with the same interface as Gantry / MTRS.

They accept the same parameters of config/devices.toml (unused ones are ignored) and inherit the shared
logic (arrival, limits). The simulated AWG + oscilloscope is isac/sim.py.
"""

import math
import threading
import time

from .gantry import GantryBase
from .mtrs import MTRSBase


class _Mover:
    """Constant-speed motion of a coordinate vector, in a background thread."""

    def __init__(self, start, speed):
        self.pos = list(start)
        self.speed = speed
        self.v = 0.0
        self.lock = threading.Lock()
        self._stop = threading.Event()
        self._thread = None

    def go(self, target):
        self.halt()
        self._stop.clear()

        def run():
            dt = 0.01
            while not self._stop.is_set():
                with self.lock:
                    d = math.dist(self.pos, target)
                    if d < 1e-9:
                        break
                    step = min(self.speed * dt, d)
                    self.pos = [p + (t - p) * step / d for p, t in zip(self.pos, target)]
                    self.v = self.speed
                time.sleep(dt)
            with self.lock:
                self.v = 0.0

        self._thread = threading.Thread(target=run, daemon=True)
        self._thread.start()

    def halt(self):
        self._stop.set()
        if self._thread is not None:
            self._thread.join()

    def get(self):
        with self.lock:
            return tuple(self.pos), self.v


class SimGantry(GantryBase):
    def __init__(self, workspace_min_mm, workspace_max_mm, velocity_mm_s, override_pct=100.0,
                 tolerance_mm=1.0, still_speed_mm_s=0.5, speedup=1.0,
                 start=(100.0, 100.0, 20.0), **_):
        super().__init__(workspace_min_mm, workspace_max_mm, velocity_mm_s * speedup,
                         override_pct, tolerance_mm, still_speed_mm_s)
        self.mover = _Mover(start, self.velocity * override_pct / 100.0)
        self.info = {"simulated": True, "velocity_mm_s": self.velocity,
                     "workspace_min_mm": self.workspace_min, "workspace_max_mm": self.workspace_max}

    def connect(self, confirm=input):
        print(f"[SimGantry] Ready. Position: {self.state()['pos']}")

    def state(self):
        pos, v = self.mover.get()
        return {"pos": pos, "abc": (0.0, 0.0, 180.0), "ext": (0.0, 0.0, 0.0), "speed": v,
                "kin": "NO_ERROR", "axes_error": "NoError", "connected": True, "ok": True}

    def move_to(self, xyz):
        problems = self.outside_workspace(xyz)
        if problems:
            raise ValueError("; ".join(problems))
        self.mover.go(xyz)

    def stop(self):
        self.mover.halt()

    def close(self):
        self.mover.halt()
        print("[SimGantry] Closed.")


class SimMTRS(MTRSBase):
    def __init__(self, velocity_deg_s=1.5, acceleration_deg_s2=1.5, rotation_mode="LinearRange",
                 tolerance_deg=0.05, tilt_target_deg=0.0, tilt_limit_deg=3.0, tilt_velocity_deg_s=0.5,
                 tilt_acceleration_deg_s2=0.5, speedup=1.0, **_):
        super().__init__(velocity_deg_s * speedup, acceleration_deg_s2 * speedup ** 2,
                         rotation_mode, tolerance_deg, tilt_limit_deg, tilt_velocity_deg_s * speedup,
                         tilt_acceleration_deg_s2 * speedup ** 2)
        self.tilt_target = tilt_target_deg
        self.mover = _Mover([0.0], self.velocity)
        self.tilt_mover = _Mover([float(tilt_target_deg)], self.tilt_velocity)
        self.info = {"simulated": True, "velocity_deg_s": self.velocity, "rotation_mode": rotation_mode,
                     "tilt_limit_deg": tilt_limit_deg, "tilt_velocity_deg_s": self.tilt_velocity}

    def connect(self):
        print(f"[SimMTRS] Ready. Rotation = 0 deg, tilt = {self.tilt_target:g} deg")

    def angle_deg(self):
        return self.mover.get()[0][0]

    def tilt_deg(self):
        return self.tilt_mover.get()[0][0]

    def moving(self):
        return self.mover.get()[1] > 0

    def tilt_moving(self):
        return self.tilt_mover.get()[1] > 0

    def move_to(self, angle):
        if not self.valid_angle(angle):
            raise ValueError(f"Angle {angle} outside [0, 360] (LinearRange).")
        if abs(self.angle_error(angle)) > self.tolerance:
            self.mover.go([float(angle)])

    def move_tilt(self, tilt, force=False):
        if not self.valid_tilt(tilt):
            raise ValueError(f"Tilt {tilt} outside +/-{self.tilt_limit} deg.")
        if force or abs(self.tilt_deg() - tilt) > self.tolerance:
            self.tilt_mover.go([float(tilt)])

    def stop(self):
        self.mover.halt()
        self.tilt_mover.halt()

    def close(self):
        self.stop()
        print("[SimMTRS] Closed.")
