"""
testbed.py - Punto de entrada unico a los equipos del testbed.

Lee config/testbed.toml, crea cada equipo (real o simulado), los conecta y ofrece los
metodos comunes que usan los experimentos:

    from hardware.testbed import Testbed

    with Testbed() as tb:                            # lee la config y conecta todo
        tb.go_to_pose((700, 700, -300), 144)         # gantry + MTRS a la vez, espera llegada
        acqs = tb.scope.record(3, 100000)            # adquisiciones sincronizadas
        f, peak = tb.scope.led_peak(acqs[0]["f"], acqs[0]["fft"])

    Testbed(devices=("scope",))                      # solo algunos equipos
    Testbed(modes={"gantry": "sim"})                 # sobrescribir el modo de la config

Cada equipo sigue disponible por separado: tb.gantry, tb.mtrs, tb.scope.
"""

import math
import os
import time
import tomllib

from .gantry import GantryBase

IMPL_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(IMPL_ROOT, "config", "testbed.toml")
DEVICES = ("gantry", "mtrs", "scope")


class Stopped(Exception):
    """Movimiento detenido por una solicitud de STOP."""


def load_config(path=None):
    with open(path or CONFIG_PATH, "rb") as f:
        return tomllib.load(f)


class Testbed:
    def __init__(self, devices=DEVICES, modes=None, config_path=None):
        self.config_path = os.path.abspath(config_path or CONFIG_PATH)
        self.cfg = load_config(self.config_path)
        self.modes = {**self.cfg["modes"], **(modes or {})}
        self.motion = self.cfg.get("motion", {})
        self.view = self.cfg.get("view", {})
        self.gantry = self._make("gantry") if "gantry" in devices else None
        self.mtrs = self._make("mtrs") if "mtrs" in devices else None
        self.scope = self._make("scope") if "scope" in devices else None
        self._connected = []

    # ---------------------------------------------------------------
    # Creacion / conexion
    # ---------------------------------------------------------------
    def _make(self, name):
        cfg = dict(self.cfg[name])
        real = self.modes.get(name, "real") == "real"
        speedup = self.modes.get("sim_speedup", 1.0)
        if name == "gantry":
            from .gantry import Gantry
            from .sim import SimGantry
            return Gantry(**cfg) if real else SimGantry(speedup=speedup, **cfg)
        if name == "mtrs":
            from .mtrs import MTRS
            from .sim import SimMTRS
            return MTRS(**cfg) if real else SimMTRS(speedup=speedup, **cfg)
        from .scope import Scope
        from .sim import SimScope
        return Scope(**cfg) if real else SimScope(pose_fn=self._sim_pose, **cfg)

    def _sim_pose(self):
        pos = self.gantry.state()["pos"] if self.gantry else (700.0, 700.0, -300.0)
        return pos, (self.mtrs.angle_deg() if self.mtrs else 0.0)

    @property
    def devices(self):
        """Equipos creados, en orden de conexion."""
        return [d for d in (self.scope, self.mtrs, self.gantry) if d is not None]

    def connect(self, confirm=input):
        for dev in self.devices:
            dev.connect(confirm) if isinstance(dev, GantryBase) else dev.connect()
            self._connected.append(dev)
        return self

    def close(self):
        for dev in reversed(self._connected):
            try:
                dev.close()
            except Exception as e:
                print(f"[Testbed] Error closing {type(dev).__name__}: {e}")
        self._connected = []

    def __enter__(self):
        try:
            return self.connect()
        except BaseException:
            self.close()
            raise

    def __exit__(self, *exc):
        self.close()

    def info(self):
        """Configuracion + informacion de los equipos (para guardar con cada sesion)."""
        return {"config_file": self.config_path, "modes": self.modes, "config": self.cfg,
                **{name: getattr(self, name).info for name in DEVICES if getattr(self, name)}}

    # ---------------------------------------------------------------
    # Pose conjunta gantry + MTRS
    # ---------------------------------------------------------------
    def pose(self):
        """Estado actual: posicion/velocidad del gantry y angulo/tilt del MTRS."""
        p = {"unix": time.time()}
        if self.gantry:
            g = self.gantry.state()
            p.update(pos=g["pos"], speed=g["speed"], gantry_ok=g["ok"], kin=g["kin"],
                     axes_error=g["axes_error"])
        if self.mtrs:
            p.update(angle=self.mtrs.angle_deg(), tilt=self.mtrs.tilt_deg(),
                     mtrs_moving=self.mtrs.moving())
        return p

    def check_pose(self, xyz=None, angle=None):
        """Lista de problemas del destino (vacia si es valido)."""
        problems = self.gantry.outside_workspace(xyz) if xyz is not None else []
        if angle is not None and not self.mtrs.valid_angle(angle):
            problems.append(f"angle {angle} outside [0, 360]")
        return problems

    def estimated_time(self, xyz=None, angle=None):
        t = [self.gantry.estimated_time(xyz)] if xyz is not None else []
        t += [self.mtrs.estimated_time(angle)] if angle is not None else []
        return max(t, default=0.0)

    def move_to_pose(self, xyz=None, angle=None):
        """Inicia el movimiento del gantry y del MTRS a la vez (no espera)."""
        problems = self.check_pose(xyz, angle)
        if problems:
            raise ValueError("; ".join(problems))
        if angle is not None:
            self.mtrs.move_to(angle)
        if xyz is not None:
            try:
                self.gantry.move_to(xyz)
            except Exception:
                self.stop()
                raise

    def arrived(self, xyz=None, angle=None, pose=None):
        """(llego, error_gantry_mm, error_mtrs_deg) usando las tolerancias de la config."""
        p = pose or self.pose()
        g_err = math.dist(p["pos"], xyz) if xyz is not None else 0.0
        m_err = abs(self.mtrs.angle_error(angle, p["angle"])) if angle is not None else 0.0
        g_ok = xyz is None or self.gantry.arrived(xyz, {"pos": p["pos"], "speed": p["speed"]})
        m_ok = angle is None or self.mtrs.arrived(angle, p["angle"], p["mtrs_moving"])
        return g_ok and m_ok, g_err, m_err

    def wait_pose(self, xyz=None, angle=None, timeout=None, stop_event=None, on_sample=None):
        """Espera a que gantry y MTRS lleguen. Devuelve el tiempo [s].

        Lanza Stopped (stop_event activado), TimeoutError, o RuntimeError (error del
        gantry o ambos detenidos sin llegar). En esos casos detiene los equipos.
        """
        m = self.motion
        hold_s, stall_s = m.get("arrival_hold_s", 0.3), m.get("stall_time_s", 5.0)
        poll_s = m.get("poll_s", 0.05)
        if timeout is None:
            timeout = 1.5 * self.estimated_time(xyz, angle) + m.get("timeout_margin_s", 30.0)
        t0 = time.perf_counter()
        hold = still_since = None
        try:
            while True:
                if stop_event is not None and stop_event.is_set():
                    raise Stopped
                time.sleep(poll_s)
                now = time.perf_counter() - t0
                p = self.pose()
                if on_sample is not None:
                    on_sample(p)
                if self.gantry and not p["gantry_ok"]:
                    raise RuntimeError(f"Gantry error: {p['kin']} / {p['axes_error']}")
                ok, g_err, m_err = self.arrived(xyz, angle, p)
                if ok:
                    hold = hold or now
                    if now - hold >= hold_s:
                        return now
                else:
                    hold = None
                moving = ((self.gantry is not None and self.gantry.is_moving(p))
                          or p.get("mtrs_moving", False))
                if moving or ok or now < 2.0:
                    still_since = None
                else:
                    still_since = still_since or now
                    if now - still_since > stall_s:
                        raise RuntimeError(f"Stopped before reaching the target: gantry "
                                           f"{g_err:.1f} mm, MTRS {m_err:.2f} deg")
                if now > timeout:
                    raise TimeoutError(f"Timeout ({timeout:.0f} s): gantry {g_err:.1f} mm, "
                                       f"MTRS {m_err:.2f} deg")
        except BaseException:
            self.stop()
            raise

    def go_to_pose(self, xyz=None, angle=None, **wait_kw):
        """move_to_pose + wait_pose."""
        self.move_to_pose(xyz, angle)
        return self.wait_pose(xyz, angle, **wait_kw)

    def stop(self):
        """Detiene gantry y MTRS (ignora errores de cada uno)."""
        for dev in (self.gantry, self.mtrs):
            if dev is not None:
                try:
                    dev.stop()
                except Exception as e:
                    print(f"[Testbed] Error stopping {type(dev).__name__}: {e}")
