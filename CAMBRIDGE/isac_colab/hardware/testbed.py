"""
testbed.py - Gantry + MTRS of the ISAC testbed (the AWG and oscilloscope are in isac/).

Reads config/devices.toml, builds the gantry and the MTRS (real or simulated), connects them and provides
the joint pose methods:

    from hardware.testbed import Testbed

    with Testbed() as tb:                            # reads the config and connects both devices
        tb.go_to_pose((700, 700, 300), 144, tilt=0)  # gantry + MTRS together, waits for arrival
        print(tb.pose())

    Testbed(modes={"gantry": "sim", "mtrs": "sim"})  # override the modes of the config
"""

import math
import os
import time
import tomllib

from .gantry import GantryBase

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(REPO_ROOT, "config", "devices.toml")


class Stopped(Exception):
    """Motion interrupted by a STOP request."""


def load_config(path=None):
    with open(path or CONFIG_PATH, "rb") as f:
        return tomllib.load(f)


class Testbed:
    def __init__(self, modes=None, config_path=None):
        self.config_path = os.path.abspath(config_path or CONFIG_PATH)
        self.cfg = load_config(self.config_path)
        self.modes = {**self.cfg["modes"], **(modes or {})}
        self.motion = self.cfg.get("motion", {})
        self.view = self.cfg.get("view", {})
        speedup = self.modes.get("sim_speedup", 1.0)
        if self.modes.get("gantry", "real") == "real":
            from .gantry import Gantry
            self.gantry = Gantry(**self.cfg["gantry"])
        else:
            from .sim import SimGantry
            self.gantry = SimGantry(speedup=speedup, **self.cfg["gantry"])
        if self.modes.get("mtrs", "real") == "real":
            from .mtrs import MTRS
            self.mtrs = MTRS(**self.cfg["mtrs"])
        else:
            from .sim import SimMTRS
            self.mtrs = SimMTRS(speedup=speedup, **self.cfg["mtrs"])
        self._connected = []

    # ---------------------------------------------------------------
    # Connection
    # ---------------------------------------------------------------
    def connect(self, confirm=input):
        for dev in (self.mtrs, self.gantry):
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
        """Configuration + device information (stored with every session)."""
        return {"config_file": self.config_path, "modes": self.modes,
                "gantry": self.gantry.info, "mtrs": self.mtrs.info}

    # ---------------------------------------------------------------
    # Joint gantry + MTRS pose
    # ---------------------------------------------------------------
    def pose(self):
        """Current state: gantry position/speed and MTRS angle/tilt."""
        p = {"unix": time.time()}
        g = self.gantry.state()
        p.update(pos=g["pos"], speed=g["speed"], gantry_ok=g["ok"], kin=g["kin"], axes_error=g["axes_error"])
        p.update(angle=self.mtrs.angle_deg(), tilt=self.mtrs.tilt_deg(),
                 mtrs_moving=self.mtrs.moving(), tilt_moving=self.mtrs.tilt_moving())
        return p

    def check_pose(self, xyz=None, angle=None, tilt=None):
        """List of problems with a target pose (empty if it is valid)."""
        problems = self.gantry.outside_workspace(xyz) if xyz is not None else []
        if angle is not None and not self.mtrs.valid_angle(angle):
            problems.append(f"angle {angle} outside [0, 360]")
        if tilt is not None and not self.mtrs.valid_tilt(tilt):
            problems.append(f"MTRS tilt {tilt} outside +/-{self.mtrs.tilt_limit} deg")
        return problems

    def estimated_time(self, xyz=None, angle=None, tilt=None):
        t = [self.gantry.estimated_time(xyz)] if xyz is not None else []
        t += [self.mtrs.estimated_time(angle)] if angle is not None else []
        t += [self.mtrs.tilt_estimated_time(tilt)] if tilt is not None else []
        return max(t, default=0.0)

    def move_to_pose(self, xyz=None, angle=None, tilt=None, force_tilt=False):
        """Starts the gantry, MTRS rotation and MTRS tilt motion at the same time (does not wait).

        force_tilt: send the tilt command even if the reading is already there."""
        problems = self.check_pose(xyz, angle, tilt)
        if problems:
            raise ValueError("; ".join(problems))
        try:
            if angle is not None:
                self.mtrs.move_to(angle)
            if tilt is not None:
                self.mtrs.move_tilt(tilt, force=force_tilt)
            if xyz is not None:
                self.gantry.move_to(xyz)
        except Exception:
            self.stop()
            raise

    def arrived(self, xyz=None, angle=None, pose=None, tilt=None):
        """(arrived, gantry_error_mm, mtrs_error_deg) using the tolerances of the config.

        mtrs_error_deg is the largest of the rotation and tilt errors."""
        p = pose or self.pose()
        g_err = math.dist(p["pos"], xyz) if xyz is not None else 0.0
        m_err = abs(self.mtrs.angle_error(angle, p["angle"])) if angle is not None else 0.0
        t_err = abs(p["tilt"] - tilt) if tilt is not None else 0.0
        g_ok = xyz is None or self.gantry.arrived(xyz, {"pos": p["pos"], "speed": p["speed"]})
        m_ok = angle is None or self.mtrs.arrived(angle, p["angle"], p["mtrs_moving"])
        t_ok = tilt is None or self.mtrs.tilt_arrived(tilt, p["tilt"], p["tilt_moving"])
        return g_ok and m_ok and t_ok, g_err, max(m_err, t_err)

    def wait_pose(self, xyz=None, angle=None, timeout=None, stop_event=None, on_sample=None, tilt=None):
        """Waits until the gantry and the MTRS (rotation and tilt) arrive. Returns the elapsed time [s].

        Raises Stopped (stop_event set), TimeoutError, or RuntimeError (gantry error, or both
        devices standing still without arriving). In those cases the devices are stopped.
        """
        m = self.motion
        hold_s, stall_s = m.get("arrival_hold_s", 0.3), m.get("stall_time_s", 5.0)
        poll_s = m.get("poll_s", 0.05)
        if timeout is None:
            timeout = 1.5 * self.estimated_time(xyz, angle, tilt) + m.get("timeout_margin_s", 30.0)
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
                if not p["gantry_ok"]:
                    raise RuntimeError(f"Gantry error: {p['kin']} / {p['axes_error']}")
                ok, g_err, m_err = self.arrived(xyz, angle, p, tilt)
                if ok:
                    hold = hold or now
                    if now - hold >= hold_s:
                        return now
                else:
                    hold = None
                moving = (self.gantry.is_moving(p)
                          or p.get("mtrs_moving", False) or p.get("tilt_moving", False))
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

    def go_to_pose(self, xyz=None, angle=None, tilt=None, **wait_kw):
        """move_to_pose + wait_pose."""
        self.move_to_pose(xyz, angle, tilt)
        return self.wait_pose(xyz, angle, tilt=tilt, **wait_kw)

    def stop(self):
        """Stops the gantry and the MTRS (errors of each device are ignored)."""
        for dev in (self.gantry, self.mtrs):
            try:
                dev.stop()
            except Exception as e:
                print(f"[Testbed] Error stopping {type(dev).__name__}: {e}")
