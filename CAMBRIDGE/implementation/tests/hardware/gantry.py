"""
gantry.py - igus DLE-RG-0012-BLDC via CRI (cri_lib).

Convencion iRC de este gantry: Z cartesiana = -A3 -> Z = 0 arriba, negativa hacia abajo.
El robot ejecuta cada Move Cart completo aunque se pierda la conexion: usar el E-stop
o el Stop de iRC como respaldo.

Parametros: seccion [gantry] de config/testbed.toml (mismos nombres que el constructor).
"""

import math
import re
import time

AXES = ("X", "Y", "Z")


def version_tuple(version):
    """'V980-14-003-3' -> (14, 3, 3)."""
    m = re.match(r"V\d+-(\d+)-(\d+)-(\d+)", version)
    return tuple(int(x) for x in m.groups()) if m else (0, 0, 0)


class GantryBase:
    """Logica comun al gantry real y al simulado."""

    def __init__(self, workspace_min_mm, workspace_max_mm, velocity_mm_s, override_pct=100.0,
                 tolerance_mm=1.0, still_speed_mm_s=0.5):
        self.workspace_min = tuple(workspace_min_mm)
        self.workspace_max = tuple(workspace_max_mm)
        self.velocity = velocity_mm_s
        self.override = override_pct
        self.tolerance = tolerance_mm
        self.still_speed = still_speed_mm_s
        self.info = {}

    def outside_workspace(self, xyz):
        """Lista de problemas (vacia si xyz esta dentro de la caja permitida)."""
        return [
            f"{a}={v:.1f} outside [{lo:.0f}, {hi:.0f}]"
            for a, v, lo, hi in zip(AXES, xyz, self.workspace_min, self.workspace_max)
            if not lo <= v <= hi
        ]

    def estimated_time(self, xyz):
        dist = math.dist(self.state()["pos"], xyz)
        return dist / max(self.velocity * self.override / 100.0, 1e-6)

    def arrived(self, xyz, state=None):
        """True si esta en xyz (dentro de tolerancia) y quieto."""
        s = state or self.state()
        return math.dist(s["pos"], xyz) <= self.tolerance and abs(s["speed"]) < self.still_speed

    def is_moving(self, state=None):
        s = state or self.state()
        return abs(s["speed"]) >= self.still_speed


class Gantry(GantryBase):
    def __init__(self, ip, port, workspace_min_mm, workspace_max_mm, velocity_mm_s,
                 override_pct=100.0, acceleration_pct=None, tolerance_mm=1.0,
                 still_speed_mm_s=0.5, expected_robot="DLE-RG-0012-BLDC",
                 expected_versions=("V980-14-003-3", "V980-14-004-4"),
                 connect_attempts=5, disable_on_exit=False):
        super().__init__(workspace_min_mm, workspace_max_mm, velocity_mm_s, override_pct,
                         tolerance_mm, still_speed_mm_s)
        self.ip, self.port = ip, port
        self.acceleration = acceleration_pct
        self.expected_robot = expected_robot
        self.expected_versions = tuple(expected_versions)
        self.connect_attempts = connect_attempts
        self.disable_on_exit = disable_on_exit
        self.robot = None

    # ---------------------------------------------------------------
    def connect(self, confirm=input):
        """Conecta, verifica y deja el robot listo. `confirm(msg)` pide confirmacion."""
        from cri_lib.cri_controller import CRIController
        from cri_lib.cri_errors import CRIConnectionError
        from cri_lib.robot_state import ReferencingAxisState

        for attempt in range(1, self.connect_attempts + 1):
            print(f"[Gantry] Connecting to {self.ip}:{self.port} (attempt {attempt})...")
            robot = CRIController()
            try:
                robot.connect(self.ip, self.port, application_name="OWP-Experiment",
                              application_version="1-0-0")
                self.robot = robot
                break
            except CRIConnectionError as e:
                print(f"  failed: {e.__cause__ or e}")
                time.sleep(1.0)
        else:
            raise RuntimeError(f"[Gantry] Could not connect to {self.ip}:{self.port}.")

        r = self.robot
        r.wait_for_status_update(timeout=5)
        time.sleep(0.5)
        try:
            r.get_referencing_info()
        except Exception as e:
            print(f"[Gantry] WARNING: could not read the referencing state ({e}).")

        st = r.robot_state
        version = st.robot_control_version
        print(f"[Gantry] {st.robot_type}  {version}")
        if self.expected_robot not in st.robot_type:
            raise RuntimeError(f"[Gantry] The connected robot is not {self.expected_robot}.")
        if version not in self.expected_versions:
            if confirm(f"[Gantry] Unexpected version {version}. Continue? [y/N]: ").lower() != "y":
                raise RuntimeError("[Gantry] Cancelled by the user.")
        if version_tuple(version) < (14, 4, 1):
            self.acceleration = None          # Move Cart con aceleracion requiere >= V14-004-1
        simulated = self.ip in ("127.0.0.1", "localhost")
        if not st.emergency_stop_ok and not simulated:
            raise RuntimeError("[Gantry] The E-stop circuit is not OK.")

        if not r.set_active_control(True):
            raise RuntimeError("[Gantry] Could not acquire active control.")
        if not self.state()["ok"]:
            confirm("[Gantry] Motors not ready. Press ENTER for Reset + Enable (Ctrl+C cancels)...")
            if not r.reset() or not r.enable() or not r.wait_for_kinematics_ready(timeout=10):
                s = self.state()
                raise RuntimeError(f"[Gantry] Robot not ready: {s['kin']} / {s['axes_error']}")
        ref = r.robot_state.referencing_state
        if ref.mandatory and ref.global_state != ReferencingAxisState.REFERENCED:
            raise RuntimeError("[Gantry] Robot not referenced. Reference it in iRC.")
        if not r.set_override(self.override):
            raise RuntimeError("[Gantry] Could not set the override.")

        self.info = {
            "robot_type": st.robot_type, "robot_control_version": version,
            "ip": self.ip, "port": self.port, "simulated_irc": simulated,
            "velocity_mm_s": self.velocity, "override_pct": self.override,
            "acceleration_pct": self.acceleration,
            "workspace_min_mm": self.workspace_min, "workspace_max_mm": self.workspace_max,
        }
        print(f"[Gantry] Ready. Position: {self.state()['pos']}")

    # ---------------------------------------------------------------
    def state(self):
        from cri_lib.robot_state import KinematicsState

        r = self.robot
        with r.robot_state_lock:
            s = r.robot_state
            p, j = s.position_robot, s.joints_set_point
            kin, err = s.kinematics_state, s.combined_axes_error
            out = {
                "pos": (p.X, p.Y, p.Z), "abc": (p.A, p.B, p.C), "ext": (j.E1, j.E2, j.E3),
                "speed": s.cart_speed_mm_per_s, "kin": kin.name, "axes_error": err,
            }
        out["connected"] = r.connected
        out["ok"] = r.connected and kin == KinematicsState.NO_ERROR and err == "NoError"
        return out

    def move_to(self, xyz):
        """Envia un Move Cart absoluto (no espera a que termine)."""
        problems = self.outside_workspace(xyz)
        if problems:
            raise ValueError("; ".join(problems))
        s = self.state()
        if not s["ok"]:
            raise RuntimeError(f"Gantry not ready: {s['kin']} / {s['axes_error']}")
        ok = self.robot.move_cartesian(*xyz, *s["abc"], *s["ext"], velocity=self.velocity,
                                       wait_move_finished=False, acceleration=self.acceleration)
        if not ok:
            raise RuntimeError("The controller rejected the move (check iRC).")

    def stop(self):
        if self.robot is not None and self.robot.connected:
            self.robot.stop_move()

    def close(self):
        r = self.robot
        if r is None:
            return
        if r.connected:
            try:
                if self.is_moving():
                    r.stop_move()
                if self.disable_on_exit:
                    r.disable()
                r.set_active_control(False)
            except Exception as e:
                print(f"[Gantry] Warning while closing: {e}")
        r.close()
        print("[Gantry] Connection closed.")
