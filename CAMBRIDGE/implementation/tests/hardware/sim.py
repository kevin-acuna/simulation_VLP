"""
sim.py - Dispositivos simulados con la misma interfaz que Gantry / MTRS / Scope.

Aceptan los mismos parametros de config/testbed.toml (ignoran los que no usan) y
heredan la logica comun (llegada, limites, pico del LED). SimScope genera una senal
fisicamente plausible: LED lambertiano fijo y PD inclinado PD_TILT_DEG con
azimut = angulo del MTRS.
"""

import math
import threading
import time

import numpy as np

from .gantry import GantryBase
from .mtrs import MTRSBase
from .scope import ScopeBase


class _Mover:
    """Movimiento a velocidad constante en un hilo (vector de coordenadas)."""

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
                 start=(100.0, 100.0, -20.0), **_):
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
                 tolerance_deg=0.05, tilt_target_deg=0.0, speedup=1.0, **_):
        super().__init__(velocity_deg_s * speedup, acceleration_deg_s2 * speedup ** 2,
                         rotation_mode, tolerance_deg)
        self.tilt_target = tilt_target_deg
        self.mover = _Mover([0.0], self.velocity)
        self.info = {"simulated": True, "velocity_deg_s": self.velocity, "rotation_mode": rotation_mode}

    def connect(self):
        print("[SimMTRS] Ready. Rotation = 0 deg, tilt = 0 deg")

    def angle_deg(self):
        return self.mover.get()[0][0]

    def tilt_deg(self):
        return self.tilt_target

    def moving(self):
        return self.mover.get()[1] > 0

    def move_to(self, angle):
        if not self.valid_angle(angle):
            raise ValueError(f"Angle {angle} outside [0, 360] (LinearRange).")
        if abs(self.angle_error(angle)) > self.tolerance:
            self.mover.go([float(angle)])

    def stop(self):
        self.mover.halt()

    def close(self):
        self.mover.halt()
        print("[SimMTRS] Closed.")


class SimScope(ScopeBase):
    """FFT en dB de una senal LED senoidal recibida por un PD inclinado."""

    LED_POS_MM = (700.0, 700.0, 300.0)
    PD_TILT_DEG = 15.0
    LAMBERT_ORDER = 1.0
    F_LED_HZ = 1000.0
    FS = 100e3
    N = 10000

    def __init__(self, pose_fn=None, channel=1, led_freq_hz="wgen", led_freq_band_hz=50.0,
                 fft_peak_min_hz=1.0, **_):
        super().__init__(led_freq_hz, led_freq_band_hz, fft_peak_min_hz)
        self.pose_fn = pose_fn or (lambda: ((700.0, 700.0, -300.0), 0.0))
        self.channel = channel
        self.info = {"simulated": True, "idn": "SimScope", "fft_units": "dB",
                     "wgen_frequency_Hz": self.F_LED_HZ, "fft_function": 1, "fft_source": "CHAN1"}

    def connect(self):
        print(f"[SimScope] Ready. Simulated LED at {self.F_LED_HZ} Hz")

    def _amplitude(self):
        (x, y, z), angle = self.pose_fn()
        lx, ly, lz = self.LED_POS_MM
        d_vec = np.array([lx - x, ly - y, lz - z])
        d = np.linalg.norm(d_vec)
        u = d_vec / d
        t, a = math.radians(self.PD_TILT_DEG), math.radians(angle)
        n = np.array([math.sin(t) * math.cos(a), math.sin(t) * math.sin(a), math.cos(t)])
        cos_phi, cos_psi = max(u[2], 0.0), max(float(u @ n), 0.0)
        return 0.5 * cos_phi ** self.LAMBERT_ORDER * cos_psi * (500.0 / d) ** 2

    def _signal(self):
        t = np.arange(self.N) / self.FS
        v = 1.0 + self._amplitude() * np.sin(2 * np.pi * self.F_LED_HZ * t) + 2e-3 * np.random.randn(self.N)
        return t, v

    def _fft_of(self, v):
        w = np.hanning(v.size)
        spec = np.abs(np.fft.rfft((v - v.mean()) * w)) * 2 / w.sum() / math.sqrt(2)
        f = np.fft.rfftfreq(v.size, 1 / self.FS)
        sel = f <= 5000
        return f[sel], 20 * np.log10(np.maximum(spec[sel], 1e-9))

    def read_fft(self):
        time.sleep(0.05)
        f, y = self._fft_of(self._signal()[1])
        return {"unix": time.time(), "f": f, "y": y, "ylim": (-120.0, 0.0)}

    def record(self, n_acq, time_points):
        out = []
        for _ in range(n_acq):
            t0 = time.time()
            t, v = self._signal()
            f, y = self._fft_of(v)
            out.append({"unix": t0, "f": f, "fft": y, "t": t, "v": v, "fs": self.FS})
            time.sleep(0.2)
        return out

    def close(self):
        print("[SimScope] Closed.")
