"""
engine.py - Logic of the Database Acquisition Tool.

All the control lives here, in Python: grid plan, gantry and MTRS motion, synchronized
oscilloscope acquisition, pause/resume/stop and saving. The web interface
(server.py + web/) only sends commands and displays the state.

Route of the plan:
  - Z levels outermost; within each level a serpentine XY grid (rows along X, Y direction
    alternating) and the XY route is reversed on every Z level.
  - At every position K MTRS angles are measured: theta_k = (offset + 360 k / K) mod 360.
    With alternating angle order one position is measured in increasing angle and the next
    one in decreasing angle: no return turns and the PD cable never winds up.
  - With n_passes > 1 the whole route is repeated (odd passes reversed).
  - The MTRS tilt is ALWAYS kept at the config value (0 deg). pd_tilt_deg is the mechanical
    tilt of the 3D-printed mount: it is only recorded.

Acquisition: every sample is ONE continuous oscilloscope record (no gaps). With
record_ms > 0 the record (length and sample rate) is set when the session starts and the
user's oscilloscope settings are restored at the end. With scope_fft = False the FFT is
computed in Python over the whole record (the oscilloscope FFT takes ~1.4 s and uses at most
64K points).

Files of every session (output_root/session_<date>[_label]/):
  session.json   plan configuration + devices + record + final status
  plan.csv       every planned measurement
  points.csv     one row per measurement: commanded/measured pose, tilts and RSS per LED frequency
  trajectory.csv 10 Hz telemetry (gantry + MTRS) during the session
  fft/mNNNNN.csv FFT of every acquisition (reduced to <= FFT_SAVE_MAX_BINS bins, peaks kept)
  wave/mNNNNN.npz raw waveform (uint16 ADC codes, lossless) if save_waveforms
  README.txt     description of the columns and files
"""

import csv
import json
import math
import os
import queue
import threading
import time
from datetime import datetime

import numpy as np

from hardware.scope import clipped_fraction, decimate_spectrum, frequency_features
from hardware.testbed import Stopped
from hardware.utils import RateTimer

# --- time model, calibrated with real measurements ---
#   MTRS (2026-10-07): 72 deg in 49.1 s = trapezoid 1.5 deg/s, 1.5 deg/s2 (config)
#   gantry (3 sessions, 2026-10-09/12, 220 moves): MOVING phase (including arrival detection)
#           = 3.70 / 4.67 / 6.75 / 7.70 / 8.73 s for 150 / 200 / 300 / 350 / 400 mm at 50 mm/s
#           -> d/v + v/a + arrival with a ~160 mm/s2 (the firmware uses its own acceleration, 40 %)
#   oscilloscope (2026-10-12): the slow part is NOT the transfer but the oscilloscope computing
#           its own FFT (~1.4 s per acquisition with 50 kpts). With :SINGle and without that FFT:
#           ~0.2-0.3 s capture + transfer (50 kpts 0.17 s, 1 Mpts 0.64 s).
#           With the real oscilloscope one acquisition is MEASURED at Preview; the model below
#           is only used with the simulated oscilloscope.
ACQ_BASE_S = 0.30             # :SINGle + waiting for the end of the capture
ACQ_PER_POINT_S = 0.65e-6     # USB transfer per point (WORD format)
SCOPE_FFT_S = 1.4             # oscilloscope FFT computation (only if scope_fft)
SAVE_BASE_S = 0.15            # writing the CSV/NPZ files of one measurement
SAVE_PER_POINT_S = 0.5e-6     # Python FFT + waveform compression, per point
GANTRY_ACCEL_EST = 160.0      # effective acceleration of the real gantry [mm/s2]
ARRIVAL_OVERHEAD_S = 0.1      # arrival polling, added to motion.arrival_hold_s
LONG_PLAN_WARN_S = 24 * 3600  # warn if the plan lasts longer than this
MAX_MEASUREMENTS = 5_000_000  # technical (memory) limit; ~140 days at 2.4 s per measurement

MAX_RETRIES = 2               # acquisition retries before pausing with an error
FFT_SAVE_MAX_BINS = 4000      # fft/mNNNNN.csv: spectrum reduced (max per group) to <= N bins
FFT_BYTES_PER_ROW = 14        # bytes per value in the FFT CSV
WAVE_BYTES_PER_POINT = 1.6    # wave/*.npz: compressed uint16 codes (measured ~1.3-1.7)
MAX_RECORD_POINTS = 4_000_000 # acquisition memory of the MSO-X 4154A (datasheet)
# With the oscilloscope Math FFT active the 4154A reduces the channel record to ~62,500 points
# (measured 2026-10-12: 50 ms -> 62,500 pts at 1.25 MSa/s instead of 500,000 at 10 MSa/s),
# which aliases everything above fs/2. scope_fft is only allowed up to this record size.
SCOPE_FFT_MAX_POINTS = 62_500

DEFAULT_CONFIG = {
    "x": [100.0, 1300.0, 300.0],          # start, end, step [mm]
    "y": [100.0, 1300.0, 300.0],
    "z": [-300.0, -300.0, 100.0],
    "k_angles": 4,
    "angle_offset_deg": 65.0,
    "pd_tilt_deg": 15.0,
    "n_samples": 1,
    "n_passes": 1,                        # times the WHOLE route is repeated (variance per point)
    "freqs_khz": [300.0, 500.0, 700.0, 900.0],
    "settle_s": 1.0,
    "record_ms": 100.0,                   # continuous record per sample [ms]; 0 = oscilloscope settings
    "record_fs_msa": 10.0,                # sample rate of the record [MSa/s]
    "scope_fft": False,                   # also read the oscilloscope FFT (+~1.4 s per sample)
    "serpentine_xy": True,
    "serpentine_angles": True,
    "save_waveforms": True,
    "time_points": 8000000,               # waveform points requested (8e6 = the whole record)
    "label": "",
}


def freq_label(f_hz):
    return f"{f_hz / 1e3:g}kHz"


def axis_values(name, start, stop, step):
    """Values of an axis (start included; end included if it falls on a multiple of the step)."""
    start, stop, step = float(start), float(stop), abs(float(step))
    if abs(stop - start) < 1e-9:
        return [start], []
    if step <= 0:
        raise ValueError(f"{name}: step must be > 0 when start != stop")
    n = int(math.floor(abs(stop - start) / step + 1e-9)) + 1
    sign = 1.0 if stop > start else -1.0
    vals = [round(start + sign * i * step, 6) for i in range(n)]
    warn = [] if abs(vals[-1] - stop) < 1e-6 else [
        f"{name}: {stop:g} is not reached with step {step:g}; last value is {vals[-1]:g}"]
    return vals, warn


def _clean(obj):
    """Makes an object valid for standard JSON (NaN/inf -> None, numpy -> python)."""
    if isinstance(obj, dict):
        return {k: _clean(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_clean(v) for v in obj]
    if isinstance(obj, (np.floating, float)):
        v = float(obj)
        return v if math.isfinite(v) else None
    if isinstance(obj, np.integer):
        return int(obj)
    return obj


# ============================================================
# PLAN
# ============================================================

def normalize_config(cfg):
    c = {**DEFAULT_CONFIG, **(cfg or {})}
    for ax in ("x", "y", "z"):
        c[ax] = [float(v) for v in c[ax]]
    c["k_angles"] = int(c["k_angles"])
    c["angle_offset_deg"] = float(c["angle_offset_deg"])
    c["n_samples"] = int(c["n_samples"])
    c["n_passes"] = int(c["n_passes"])
    c["pd_tilt_deg"] = float(c["pd_tilt_deg"])
    c["settle_s"] = float(c["settle_s"])
    c["record_ms"] = float(c["record_ms"])
    c["record_fs_msa"] = float(c["record_fs_msa"])
    c["scope_fft"] = bool(c["scope_fft"])
    c["freqs_khz"] = [float(f) for f in c["freqs_khz"]]
    c["serpentine_xy"] = bool(c["serpentine_xy"])
    c["serpentine_angles"] = bool(c["serpentine_angles"])
    c["save_waveforms"] = bool(c["save_waveforms"])
    c["time_points"] = c["time_points"] if c["time_points"] == "MAX" else int(c["time_points"])
    c["label"] = str(c.get("label", ""))
    return c


def build_plan(cfg, tb, start_pose=None):
    """Full plan + validation + duration and disk-space estimate."""
    errors, warnings = [], []
    try:
        c = normalize_config(cfg)
    except (TypeError, ValueError) as e:
        return {"ok": False, "errors": [f"Invalid value: {e}"], "warnings": []}

    axes = {}
    for ax in ("x", "y", "z"):
        try:
            axes[ax], w = axis_values(ax.upper(), *c[ax])
            warnings += w
        except ValueError as e:
            errors.append(str(e))
    if not 1 <= c["k_angles"] <= 360:
        errors.append("K (number of angles) must be between 1 and 360")
    if not 1 <= c["n_samples"] <= 100:
        errors.append("Samples per orientation must be between 1 and 100")
    if not c["freqs_khz"] or any(f <= 0 for f in c["freqs_khz"]):
        errors.append("Every LED needs a positive frequency (kHz)")
    elif len({freq_label(f * 1e3) for f in c["freqs_khz"]}) != len(c["freqs_khz"]):
        errors.append("Two LEDs have the same frequency (their columns in points.csv would collide)")
    if c["settle_s"] < 0:
        errors.append("Settle time must be >= 0")
    if len(axes) < 3:
        return {"ok": False, "errors": errors, "warnings": warnings, "config": c}

    for ax, i in (("x", 0), ("y", 1), ("z", 2)):
        lo, hi = tb.gantry.workspace_min[i], tb.gantry.workspace_max[i]
        bad = [v for v in axes[ax] if not lo <= v <= hi]
        if bad:
            errors.append(f"{ax.upper()} values outside the workspace [{lo:g}, {hi:g}]: {bad[:5]}")
    k_eff = min(max(c["k_angles"], 1), 360)
    angles = [round((c["angle_offset_deg"] + 360.0 * k / k_eff) % 360.0, 6) % 360.0 for k in range(k_eff)]
    if any(not tb.mtrs.valid_angle(a) for a in angles):
        errors.append("Some angles are not valid for the MTRS rotation mode")

    scope = tb.scope.info
    fs, center, span = scope.get("sample_rate_Sa_s"), scope.get("fft_center_Hz"), scope.get("fft_span_Hz")
    if c["record_ms"] < 0 or c["record_fs_msa"] <= 0:
        errors.append("Record length must be >= 0 ms (0 = oscilloscope settings) and the sample rate > 0")
    elif c["record_ms"] == 0 and c["scope_fft"] and record_points(c, scope) > SCOPE_FFT_MAX_POINTS:
        errors.append(f"The record configured on the oscilloscope has {record_points(c, scope):,} points; with "
                      f"its FFT active the oscilloscope reduces it to ~{SCOPE_FFT_MAX_POINTS:,} (aliasing). "
                      f"Disable 'Also read the oscilloscope FFT'.")
    elif c["record_ms"] > 0:
        fs = c["record_fs_msa"] * 1e6
        n_rec = record_points(c, scope)
        if n_rec > MAX_RECORD_POINTS:
            errors.append(f"A {c['record_ms']:g} ms record at {c['record_fs_msa']:g} MSa/s needs {n_rec:,} points; "
                          f"the oscilloscope memory allows {MAX_RECORD_POINTS:,}. Reduce the length or the rate.")
        f_max = max(c["freqs_khz"]) * 1e3 if c["freqs_khz"] else 0
        if c["scope_fft"] and n_rec > SCOPE_FFT_MAX_POINTS:
            errors.append(f"'Also read the oscilloscope FFT' cannot be used with a {n_rec:,}-point record: with its "
                          f"FFT active the oscilloscope reduces the record to ~{SCOPE_FFT_MAX_POINTS:,} points "
                          f"(sample rate {SCOPE_FFT_MAX_POINTS / (c['record_ms'] * 1e-3) / 1e6:.3g} MSa/s), so "
                          f"frequencies above {SCOPE_FFT_MAX_POINTS / (c['record_ms'] * 1e-3) / 2e3:.0f} kHz "
                          f"alias. Disable the option (FFT computed in Python) or use a record of at most "
                          f"{SCOPE_FFT_MAX_POINTS / fs * 1e3:.2f} ms at {c['record_fs_msa']:g} MSa/s.")
        if f_max and fs < 4 * f_max:
            warnings.append(f"{c['record_fs_msa']:g} MSa/s is less than 4x the highest frequency "
                            f"({f_max / 1e3:g} kHz); use High Resolution acquisition to limit aliasing.")
    for f in c["freqs_khz"]:
        f_hz = f * 1e3
        if fs and f_hz >= fs / 2:
            errors.append(f"{f:g} kHz is above the Nyquist frequency ({fs / 2e3:g} kHz)")
        elif center is not None and span is not None and abs(f_hz - center) > span / 2:
            warnings.append(f"{f:g} kHz is outside the scope FFT span "
                            f"({(center - span / 2) / 1e3:g}-{(center + span / 2) / 1e3:g} kHz): "
                            f"its FFT columns will be empty (waveform RSS is still computed)")
    if not 1 <= c["n_passes"] <= 1000:
        errors.append("Passes must be between 1 and 1000")
    n_meas = len(axes["x"]) * len(axes["y"]) * len(axes["z"]) * c["k_angles"] * c["n_passes"]
    if n_meas > MAX_MEASUREMENTS:
        errors.append(f"The plan has {n_meas:,} measurements; the program can handle at most "
                      f"{MAX_MEASUREMENTS:,} (memory limit). Use a coarser grid, fewer angles or passes.")
    if errors:
        return {"ok": False, "errors": errors, "warnings": warnings, "config": c}

    sites, rev = [], False
    for iz, z in enumerate(axes["z"]):
        level = []
        for ix, x in enumerate(axes["x"]):
            ys = list(enumerate(axes["y"]))
            if c["serpentine_xy"] and ix % 2 == 1:
                ys.reverse()
            level += [(ix, iy, iz, x, y, z) for iy, y in ys]
        if c["serpentine_xy"] and rev:
            level.reverse()
        rev = not rev
        sites += level

    # measuring order: increasing MTRS angle (never crosses 0/360 -> the cable never winds up)
    asc = sorted(range(len(angles)), key=lambda k: angles[k])
    plan = {"ok": True, "errors": [], "warnings": warnings, "base_warnings": list(warnings),
            "config": c, "axes": axes, "angles": angles, "order_asc": asc, "order_desc": asc[::-1],
            "sites": sites, "K": c["k_angles"], "n_sites": len(sites), "passes": c["n_passes"],
            "n_visits": len(sites) * c["n_passes"],
            "n_meas": len(sites) * c["k_angles"] * c["n_passes"]}
    n_rec = record_points(c, tb.scope.info)
    plan["record_points"] = n_rec
    fft_bytes = FFT_SAVE_MAX_BINS * FFT_BYTES_PER_ROW * (1 + c["n_samples"])
    plan["est_bytes"] = plan["n_meas"] * (fft_bytes + (WAVE_BYTES_PER_POINT * n_rec * c["n_samples"]
                                                       if c["save_waveforms"] else 0))
    apply_estimate(plan, tb, start_pose)
    return plan


def record_points(c, scope_info):
    """Points per acquisition: those of the requested record or, with record_ms = 0, the screen ones."""
    if c["record_ms"] > 0:
        return int(round(c["record_ms"] * 1e-3 * c["record_fs_msa"] * 1e6))
    tb_s, fs = scope_info.get("timebase_s_div"), scope_info.get("sample_rate_Sa_s")
    return int(round(10 * tb_s * fs)) if tb_s and fs else 10200


def apply_estimate(plan, tb, start_pose=None, acq_s=None, acq_source="default (simulated scope)"):
    """Computes (or recomputes) the estimated duration of the plan."""
    est, breakdown = estimate_times(plan, tb, start_pose, acq_s, acq_source)
    plan["est"] = est
    plan["est_cum"] = np.cumsum(est)
    plan["est_total_s"] = round(float(est.sum()), 1)
    plan["est_breakdown"] = breakdown
    plan["warnings"] = list(plan["base_warnings"])
    if plan["est_total_s"] > LONG_PLAN_WARN_S:
        plan["warnings"].append(f"Estimated duration {fmt_duration(plan['est_total_s'])} "
                                f"({plan['n_meas']:,} measurements). Consider a coarser grid or fewer angles.")


def angle_order(plan, visit):
    """Angle indices k in the order they are measured during visit number `visit`."""
    rev = plan["config"]["serpentine_angles"] and visit % 2 == 1
    return plan["order_desc"] if rev else plan["order_asc"]


def visit_site(plan, visit):
    """(pass, position index) of visit number `visit` (0-based).

    Every pass covers the whole grid; with serpentine_xy the odd passes run it backwards, so the
    gantry continues from where it ended instead of returning to the start.
    """
    p, j = divmod(visit, plan["n_sites"])
    rev = plan["config"]["serpentine_xy"] and p % 2 == 1
    return p, (plan["n_sites"] - 1 - j if rev else j)


def plan_measurement(plan, i):
    """Measurement i (0-based) of the plan, computed from the index (no huge lists in memory)."""
    v, j = divmod(i, plan["K"])
    p, s = visit_site(plan, v)
    k = angle_order(plan, v)[j]
    ix, iy, iz, x, y, z = plan["sites"][s]
    return {"meas_id": i + 1, "pass": p + 1, "site_id": s + 1, "ix": ix, "iy": iy, "iz": iz, "k": k,
            "x": x, "y": y, "z": z, "angle": plan["angles"][k], "est_s": float(plan["est"][i])}


def _trapezoid(d, v, a):
    d = np.abs(d)
    return np.where(d >= v * v / a, d / v + v / a, 2.0 * np.sqrt(d / a))


def estimate_times(plan, tb, start_pose=None, acq_s=None, acq_source="default (simulated scope)"):
    """Estimated duration of every measurement [s] and total breakdown.

    Uses the NOMINAL speeds of config/testbed.toml (those of the real hardware), even when the
    devices are simulated (simulated devices run sim_speedup times faster).
    Per measurement: max(gantry, MTRS) + arrival detection (if there was motion)
                     + settling + n_samples * acquisition + saving.
    acq_s: duration of one acquisition measured on the real oscilloscope (None -> model).
    """
    n_rec = plan["record_points"]
    acq = (ACQ_BASE_S + ACQ_PER_POINT_S * n_rec + (SCOPE_FFT_S if plan["config"]["scope_fft"] else 0.0)
           if acq_s is None else acq_s)
    save_s = SAVE_BASE_S + SAVE_PER_POINT_S * n_rec * plan["config"]["n_samples"]
    c, K = plan["config"], plan["K"]
    g_cfg, m_cfg = tb.cfg["gantry"], tb.cfg["mtrs"]
    v_g = max(g_cfg["velocity_mm_s"] * g_cfg.get("override_pct", 100.0) / 100.0, 1e-6)
    v_m, a_m = m_cfg["velocity_deg_s"], m_cfg["acceleration_deg_s2"]
    hold = tb.motion.get("arrival_hold_s", 0.3) + ARRIVAL_OVERHEAD_S

    S, n_visits = plan["n_sites"], plan["n_visits"]
    vis = np.arange(n_visits)
    p, j = vis // S, vis % S
    site_idx = np.where(c["serpentine_xy"] & (p % 2 == 1), S - 1 - j, j)
    xyz = np.array([s[3:6] for s in plan["sites"]], dtype=float)[site_idx]
    start_pos = np.asarray((start_pose or {}).get("pos") or xyz[0], dtype=float)
    d_visit = np.linalg.norm(xyz - np.vstack([start_pos, xyz[:-1]]), axis=1)

    angles = np.asarray(plan["angles"], dtype=float)
    fwd, rev = angles[plan["order_asc"]], angles[plan["order_desc"]]
    if c["serpentine_angles"]:
        seq = np.tile(np.concatenate([fwd, rev]), (n_visits + 1) // 2)[: n_visits * K]
    else:
        seq = np.tile(fwd, n_visits)
    a0 = (start_pose or {}).get("angle")
    da = np.abs(np.diff(seq, prepend=seq[0] if a0 is None else a0))
    dg = np.zeros(n_visits * K)
    dg[::K] = d_visit

    t_g = _trapezoid(dg, v_g, GANTRY_ACCEL_EST)
    t_m = _trapezoid(da, v_m, a_m)
    moved = (dg > 0.01) | (da > 1e-3)
    t_motion = np.maximum(t_g, t_m) + moved * hold
    t_fixed = c["settle_s"] + c["n_samples"] * acq + save_s
    est = t_motion + t_fixed
    mtrs_limited = t_m >= t_g
    breakdown = {
        "mtrs_rotation_s": float(np.sum(np.where(mtrs_limited, t_m, 0.0))),
        "gantry_motion_s": float(np.sum(np.where(mtrs_limited, 0.0, t_g))),
        "arrival_s": float(np.sum(moved * hold)),
        "settle_s": c["settle_s"] * len(est),
        "acquisition_s": (c["n_samples"] * acq + save_s) * len(est),
        "model": {"gantry_mm_s": v_g, "gantry_accel_mm_s2": GANTRY_ACCEL_EST,
                  "mtrs_deg_s": v_m, "mtrs_accel_deg_s2": a_m, "acquisition_s": round(acq, 3),
                  "acquisition_source": acq_source, "save_s": round(save_s, 3), "arrival_s": hold,
                  "record_points": n_rec},
    }
    return est, breakdown


def fmt_duration(s):
    s = int(round(s))
    if s < 3600:
        return f"{s // 60} min {s % 60} s"
    if s < 86400:
        return f"{s // 3600} h {s % 3600 // 60} min"
    return f"{s / 86400:.1f} days"


# ============================================================
# ACQUISITION ENGINE
# ============================================================

class Engine:
    """State + threads (telemetry, oscilloscope, runner). Thread-safe methods."""

    def __init__(self, tb, output_root, defaults=None):
        self.tb = tb
        self.output_root = output_root
        self.defaults = normalize_config(defaults or DEFAULT_CONFIG)
        self.lock = threading.RLock()
        self.state = "IDLE"            # IDLE | RUNNING | PAUSED | STOPPING | FINISHED | STOPPED
        self.phase = ""                # MOVING | SETTLING | MEASURING (while RUNNING)
        self.message = "Configure the grid and press Preview."
        self.error = None
        self.plan = None
        self.plan_version = 0
        self.config = dict(self.defaults)
        self.session_dir = None
        self.done = []
        self.next_index = 0
        self.tel = None
        self.fft = None
        self.fft_seq = 0
        self.fft_rate = 0.0
        self.log = []
        self._log_base = 0             # log entries already discarded (absolute cursor)
        self.target = None
        self.current = None
        self.t_session = None
        self.t_paused = 0.0
        self.actual_s = 0.0
        self.est_done_s = 0.0
        self._pause = threading.Event()
        self._stop = threading.Event()
        self._shutdown = threading.Event()
        self._scope_q = queue.Queue()
        self._live_scope_fft = True    # False: the oscilloscope FFT is not read (hidden in a session)
        self._fft_was_shown = None     # oscilloscope FFT display state before hiding it
        self._traj = None
        self._runner = None
        self._threads = []
        self._points_fields = None

    # ---------------------------------------------------------------
    # helpers
    # ---------------------------------------------------------------
    def _set(self, **kw):
        with self.lock:
            for k, v in kw.items():
                setattr(self, k, v)

    def add_log(self, text, level="info"):
        with self.lock:
            self.log.append({"t": time.time(), "level": level, "text": text})
            if len(self.log) > 2000:
                del self.log[:500]
                self._log_base += 500
        print(f"[acq] {level.upper()}: {text}" if level != "info" else f"[acq] {text}")

    def start_threads(self):
        self._threads = [threading.Thread(target=self._telemetry_loop, daemon=True),
                         threading.Thread(target=self._scope_loop, daemon=True)]
        for t in self._threads:
            t.start()
        while self.tel is None and not self._shutdown.is_set():
            time.sleep(0.05)

    def shutdown(self):
        self.stop()
        if self._runner is not None:
            self._runner.join(timeout=30)
        self._shutdown.set()
        for t in self._threads:
            t.join(timeout=10)

    # ---------------------------------------------------------------
    # telemetry and oscilloscope threads
    # ---------------------------------------------------------------
    TRAJ_FIELDS = ["unix_time_s", "state", "phase", "meas_id", "x_mm", "y_mm", "z_mm",
                   "speed_mm_s", "gantry_ok", "angle_deg", "mtrs_tilt_deg", "mtrs_moving",
                   "x_target_mm", "y_target_mm", "z_target_mm", "angle_target_deg"]

    def _telemetry_loop(self):
        timer = RateTimer(10.0)
        failing = False
        while not self._shutdown.is_set():
            try:
                p = self.tb.pose()
                failing = False
            except Exception as e:
                if not failing:
                    self.add_log(f"Telemetry error: {e}", "error")
                failing = True
                timer.wait()
                continue
            with self.lock:
                self.tel = p
                traj, state, phase, cur, tgt = self._traj, self.state, self.phase, self.current, self.target
            if traj is not None:
                t = tgt or {}
                traj[1].writerow([f"{p['unix']:.3f}", state, phase, (cur or {}).get("meas_id", ""),
                                  *(f"{v:.3f}" for v in p["pos"]), f"{p['speed']:.2f}",
                                  int(p["gantry_ok"]), f"{p['angle']:.4f}", f"{p['tilt']:.4f}",
                                  int(p["mtrs_moving"]), t.get("x", ""), t.get("y", ""),
                                  t.get("z", ""), t.get("angle", "")])
                traj[2] += 1
                if traj[2] % 10 == 0:
                    traj[0].flush()
            timer.wait()

    def _scope_loop(self):
        t_last, failing = time.perf_counter(), False
        while not self._shutdown.is_set():
            try:
                req = self._scope_q.get_nowait()
            except queue.Empty:
                req = None
            if req is not None:
                try:
                    req["result"] = req["fn"]()
                except Exception as e:
                    req["error"] = e
                    self.tb.scope.recover()
                finally:
                    req["done"].set()
                continue
            if not self._live_scope_fft:          # oscilloscope FFT hidden during the session
                time.sleep(0.05)
                continue
            try:
                fft = self.tb.scope.read_fft()
                now = time.perf_counter()
                with self.lock:
                    self.fft = fft
                    self.fft_seq += 1
                    self.fft_rate = 1.0 / max(now - t_last, 1e-6)
                t_last, failing = now, False
            except Exception as e:
                if self._shutdown.is_set():
                    break
                if not failing:
                    self.add_log(f"Error reading the live FFT ({e}); communication resynchronised.",
                                 "warning")
                failing = True
                self.tb.scope.recover()
                time.sleep(0.5)
            time.sleep(0.02)

    def scope_call(self, fn, timeout=120.0):
        """Runs fn in the oscilloscope thread (pyvisa is used from a single thread)."""
        req = {"fn": fn, "done": threading.Event()}
        self._scope_q.put(req)
        if not req["done"].wait(timeout):
            raise TimeoutError("The oscilloscope did not respond.")
        if "error" in req:
            raise req["error"]
        return req["result"]

    # ---------------------------------------------------------------
    # commands (called from the web server)
    # ---------------------------------------------------------------
    def busy(self):
        return self.state in ("RUNNING", "PAUSED", "STOPPING")

    def make_plan(self, cfg):
        if self.busy():
            return {"ok": False, "errors": ["An acquisition is in progress."], "warnings": []}
        plan = build_plan(cfg, self.tb, self.tel)
        if plan["ok"] and self.tb.modes.get("scope") == "real":
            acq_s = self._measure_acquisition_time(plan["config"])
            if acq_s is not None:
                apply_estimate(plan, self.tb, self.tel, acq_s,
                               "measured at preview with the current scope settings")
        with self.lock:
            self.config = plan.get("config", self.config)
            if plan["ok"]:
                self.plan = plan
                self.plan_version += 1
                self.done, self.next_index = [], 0
                if self.state in ("FINISHED", "STOPPED"):
                    self.state = "IDLE"
                self.message = (f"Plan ready: {plan['n_meas']} measurements at {plan['n_sites']} "
                                f"positions. Review it and press Start.")
                self.error = None
        return plan

    def _configure_record(self, c):
        """Applies the requested record (record_ms > 0) on the oscilloscope; undone by _restore_record.

        With scope_fft = False it also hides the oscilloscope FFT: otherwise the oscilloscope keeps
        recomputing it between measurements (~2 s with 1 Mpts) and delays every capture.
        """
        scope = self.tb.scope
        if not c["scope_fft"] and self._fft_was_shown is None:
            self._live_scope_fft = False
            self._fft_was_shown = self.scope_call(scope.fft_displayed, timeout=30)
            if self._fft_was_shown:
                self.scope_call(lambda: scope.set_fft_display(False), timeout=30)
        if c["record_ms"] > 0:
            scope = self.tb.scope
            self.scope_call(lambda: scope.configure_record(c["record_ms"] * 1e-3, c["record_fs_msa"] * 1e6),
                            timeout=30)
        else:
            self.scope_call(self.tb.scope.refresh_info, timeout=30)

    def _restore_record(self):
        scope = self.tb.scope
        try:
            self.scope_call(scope.restore_record, timeout=30)
            if self._fft_was_shown:
                self.scope_call(lambda: scope.set_fft_display(True), timeout=30)
        except Exception as e:
            self.add_log(f"Could not restore the oscilloscope settings: {e}", "error")
        finally:
            self._fft_was_shown = None
            self._live_scope_fft = True

    def _measure_acquisition_time(self, c):
        """Actual duration of one acquisition with the requested record (nothing moves)."""
        scope = self.tb.scope
        try:
            self._configure_record(c)
            t0 = time.perf_counter()
            acqs = self.scope_call(lambda: scope.record(1, c["time_points"], c["scope_fft"]), timeout=120)
            dt = time.perf_counter() - t0
            self.add_log(f"Acquisition time measured: {dt:.2f} s per sample "
                         f"({acqs[0]['v'].size:,} waveform points, "
                         f"{acqs[0]['v'].size / acqs[0]['fs'] * 1e3:g} ms).")
            return dt
        except Exception as e:
            self.add_log(f"Could not measure the acquisition time ({e}); using the model.", "warning")
            return None
        finally:
            self._restore_record()

    def refresh_scope(self):
        if self.busy():
            raise RuntimeError("Not allowed during an acquisition.")
        info = self.scope_call(self.tb.scope.refresh_info, timeout=30)
        self.add_log("Oscilloscope settings re-read.")
        return info

    def start(self):
        with self.lock:
            if self.busy():
                raise RuntimeError("An acquisition is already in progress.")
            if self.plan is None:
                raise RuntimeError("Preview a plan first.")
        c = self.plan["config"]
        try:
            self._configure_record(c)
        except Exception as e:
            self._restore_record()
            raise RuntimeError(f"Could not configure the oscilloscope record: {e}")
        if c["record_ms"] > 0:
            self.add_log(f"Oscilloscope record set to {c['record_ms']:g} ms at {c['record_fs_msa']:g} MSa/s "
                         f"(restored at the end of the session).")
        self._open_session()
        self._pause.clear()
        self._stop.clear()
        with self.lock:
            self.state, self.phase, self.error = "RUNNING", "", None
            self.done, self.next_index = [], 0
            self.t_session, self.t_paused, self.actual_s, self.est_done_s = time.time(), 0.0, 0.0, 0.0
        self.add_log(f"Acquisition started: {self.plan['n_meas']} measurements -> {self.session_dir}")
        self._runner = threading.Thread(target=self._run, daemon=True)
        self._runner.start()

    def pause(self):
        if self.state == "RUNNING":
            self._pause.set()
            self._set(message="Pausing after the current measurement...")
            self.add_log("Pause requested (takes effect after the current measurement).")

    def resume(self):
        if self.state == "PAUSED":
            self._pause.clear()
            self._set(error=None, message="Resuming...")
            self.add_log("Resumed.")

    def stop(self):
        if self.busy():
            self._stop.set()
            self._pause.clear()
            self._set(state="STOPPING", message="Stopping: halting gantry and MTRS...")
            self.add_log("STOP requested.", "warning")
            threading.Thread(target=self.tb.stop, daemon=True).start()

    # ---------------------------------------------------------------
    # execution
    # ---------------------------------------------------------------
    def _sleep_checked(self, seconds):
        t_end = time.perf_counter() + seconds
        while time.perf_counter() < t_end:
            if self._stop.is_set():
                raise Stopped
            time.sleep(0.05)

    def _run(self):
        n_total = self.plan["n_meas"]
        final = "FINISHED"
        try:
            while self.next_index < n_total:
                if self._stop.is_set():
                    final = "STOPPED"
                    break
                if self._pause.is_set():
                    t0 = time.perf_counter()
                    self._set(state="PAUSED", phase="",
                              message=self.error and f"Paused after an error: {self.error}"
                              or "Paused. Press Resume to continue or Stop to end the session.")
                    while self._pause.is_set() and not self._stop.is_set():
                        time.sleep(0.1)
                    self._set(t_paused=self.t_paused + time.perf_counter() - t0)
                    continue
                m = plan_measurement(self.plan, self.next_index)
                self._set(state="RUNNING")
                t0 = time.perf_counter()
                try:
                    summary = self._measure(m)
                except Stopped:
                    final = "STOPPED"
                    break
                except Exception as e:
                    self.tb.stop()
                    self._set(error=str(e))
                    self.add_log(f"Measurement {m['meas_id']} failed: {e}. Acquisition paused.", "error")
                    self._pause.set()
                    continue
                with self.lock:
                    self.done.append(summary)
                    self.next_index += 1
                    self.actual_s += time.perf_counter() - t0
                    self.est_done_s += m["est_s"]
            else:
                final = "FINISHED"
        except Exception as e:
            final = "STOPPED"
            self.add_log(f"Unexpected error: {e}", "error")
            self._set(error=str(e))
        finally:
            self._close_session(final)
            n = len(self.done)
            self._set(state=final, phase="", target=None, current=None,
                      message=(f"Finished: {n} measurements saved." if final == "FINISHED" else
                               f"Stopped: {n} of {n_total} measurements saved.") +
                              f"  Folder: {self.session_dir}")
            self.add_log(f"Session {final.lower()}: {n}/{n_total} measurements.")

    def _measure(self, m):
        c, tb = self.plan["config"], self.tb
        n_total = self.plan["n_meas"]
        xyz, ang = (m["x"], m["y"], m["z"]), m["angle"]
        target = {"x": m["x"], "y": m["y"], "z": m["z"], "angle": ang}
        current = {k: m[k] for k in ("meas_id", "pass", "site_id", "k", "angle")}
        self._set(current=current, target=target, phase="MOVING",
                  message=f"Measurement {m['meas_id']}/{n_total}: moving to X={m['x']:g} "
                          f"Y={m['y']:g} Z={m['z']:g} mm, {ang:g} deg")
        tel = self.tel
        xyz_cmd = None if tb.gantry.arrived(xyz, {"pos": tel["pos"], "speed": tel["speed"]}) else xyz
        ang_cmd = None if tb.mtrs.arrived(ang, tel["angle"], tel["mtrs_moving"]) else ang
        t_move0 = time.perf_counter()
        if xyz_cmd is not None or ang_cmd is not None:
            tb.move_to_pose(xyz_cmd, ang_cmd)
            tb.wait_pose(xyz_cmd, ang_cmd, stop_event=self._stop)
        t_move = time.perf_counter() - t_move0

        self._set(phase="SETTLING", message=f"Measurement {m['meas_id']}/{n_total}: settling "
                                            f"{c['settle_s']:g} s")
        self._sleep_checked(c["settle_s"])

        self._set(phase="MEASURING", message=f"Measurement {m['meas_id']}/{n_total}: acquiring "
                                             f"{c['n_samples']} sample(s)")
        tel_before = self.tel
        scope = tb.scope
        for attempt in range(MAX_RETRIES + 1):
            try:
                acqs = self.scope_call(lambda: scope.record(c["n_samples"], c["time_points"], c["scope_fft"]),
                                       timeout=60 + 30 * c["n_samples"])
                break
            except Exception as e:
                if attempt == MAX_RETRIES:
                    raise RuntimeError(f"acquisition failed after {MAX_RETRIES + 1} attempts: {e}")
                self.add_log(f"Acquisition error ({e}); retrying ({attempt + 1}/{MAX_RETRIES})", "warning")
                time.sleep(1.0)
        if self._stop.is_set():
            raise Stopped
        self._check_record(acqs)
        return self._save_measurement(m, acqs, tel_before, self.tel, t_move)

    def _check_record(self, acqs):
        """Checks that the oscilloscope returned the requested record without aliasing; else nothing is saved."""
        c = self.plan["config"]
        expected, f_max = self.plan["record_points"], max(self.freqs_hz)
        for a in acqs:
            n, fs = a["v"].size, a["fs"]
            short = c["record_ms"] > 0 and abs(n - expected) > 0.01 * expected
            if short or fs < 2.2 * f_max:
                raise RuntimeError(
                    f"the oscilloscope returned {n:,} points at {fs / 1e6:.4g} MSa/s"
                    + (f" instead of {expected:,} at {c['record_fs_msa']:g} MSa/s" if c["record_ms"] > 0 else "")
                    + f"; frequencies above {fs / 2e3:.0f} kHz alias (highest studied: {f_max / 1e3:g} kHz). "
                      f"Measurement not saved. Check the oscilloscope (Math FFT on? record settings changed?)")

    # ---------------------------------------------------------------
    # saving
    # ---------------------------------------------------------------
    def _open_session(self):
        p = self.plan
        c = p["config"]
        name = f"session_{datetime.now():%Y%m%d_%H%M%S}" + (f"_{c['label']}" if c["label"] else "")
        sdir = os.path.join(self.output_root, "".join(ch if ch.isalnum() or ch in "-_" else "_"
                                                      for ch in name))
        os.makedirs(os.path.join(sdir, "fft"), exist_ok=True)
        if c["save_waveforms"]:
            os.makedirs(os.path.join(sdir, "wave"), exist_ok=True)
        self.freqs_hz = [f * 1e3 for f in c["freqs_khz"]]
        units = self._fft_units()

        fields = ["meas_id", "pass", "site_id", "ix", "iy", "iz", "k", "iso_time", "unix_time_s",
                  "x_cmd_mm", "y_cmd_mm", "z_cmd_mm", "angle_cmd_deg",
                  "x_mm", "y_mm", "z_mm", "angle_deg", "mtrs_tilt_deg", "pd_tilt_deg"]
        for f in self.freqs_hz:
            lb = freq_label(f)
            fields += [f"{lb}_fft_{units}", f"{lb}_wave_Vrms"]
            if c["n_samples"] > 1:
                fields += [f"{lb}_fft_{units}_std", f"{lb}_wave_Vrms_std"]
        fields += ["pos_err_mm", "angle_err_deg", "n_acq", "clip_frac", "wave_ac_rms_V",
                   "fft_file", "wave_file"]
        self._points_fields = fields
        with open(os.path.join(sdir, "points.csv"), "w", newline="") as f:
            csv.writer(f).writerow(fields)

        with open(os.path.join(sdir, "plan.csv"), "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["meas_id", "pass", "site_id", "ix", "iy", "iz", "k", "x_mm", "y_mm", "z_mm",
                        "angle_deg", "est_s"])
            for i in range(p["n_meas"]):
                m = plan_measurement(p, i)
                w.writerow([m["meas_id"], m["pass"], m["site_id"], m["ix"], m["iy"], m["iz"], m["k"],
                            m["x"], m["y"], m["z"], m["angle"], f"{m['est_s']:.2f}"])

        traj_f = open(os.path.join(sdir, "trajectory.csv"), "w", newline="")
        traj_w = csv.writer(traj_f)
        traj_w.writerow(self.TRAJ_FIELDS)
        self._write_readme(sdir, units)
        with self.lock:
            self.session_dir = sdir
            self._traj = [traj_f, traj_w, 0]
        self._write_session_json(status="RUNNING")

    def _write_session_json(self, status):
        p = self.plan
        info = self.tb.info()
        data = {
            "tool": "database_acquisition", "status": status,
            "start": datetime.fromtimestamp(self.t_session or time.time()).isoformat(),
            "end": datetime.now().isoformat() if status != "RUNNING" else None,
            "plan_config": p["config"],
            "notes": {"pd_tilt_deg": "mechanical tilt of the 3D-printed PD mount (recorded only; "
                                     "the MTRS tilt stays at the config value)",
                      "angles": "theta_k = (angle_offset_deg + 360*k/K) mod 360, k = 0..K-1 (MTRS "
                                "rotation); measured in increasing MTRS angle so 0/360 is never crossed"},
            "axes_mm": p["axes"], "angles_deg": p["angles"],
            "n_sites": p["n_sites"], "n_meas": p["n_meas"], "n_done": len(self.done),
            "frequencies_Hz": [f * 1e3 for f in p["config"]["freqs_khz"]],
            "estimated_total_s": p["est_total_s"],
            "estimate_breakdown": p["est_breakdown"],
            "record": {"record_ms": p["config"]["record_ms"] or "oscilloscope settings",
                       "sample_rate_Sa_s": self.tb.scope.info.get("sample_rate_Sa_s"),
                       "points_per_sample": p["record_points"],
                       "fft_source": "oscilloscope Math FFT" if p["config"]["scope_fft"] else
                                     "Python, Hanning window over the full record (scope FFT band)"},
            "testbed": info,
        }
        with open(os.path.join(self.session_dir, "session.json"), "w") as f:
            json.dump(_clean(data), f, indent=2, default=str)

    def _write_readme(self, sdir, units):
        c = self.plan["config"]
        fft_src = "oscilloscope Math FFT" if c["scope_fft"] else "Python FFT, Hanning, whole record"
        rec = (f"{c['record_ms']:g} ms at {c['record_fs_msa']:g} MSa/s, {self.plan['record_points']:,} points"
               if c["record_ms"] > 0 else "length set on the oscilloscope")
        max_bins = FFT_SAVE_MAX_BINS
        text = f"""Database Acquisition Tool - session data
=========================================
points.csv      one row per measurement (position x orientation), compact summary:
  meas_id/site_id     measurement / grid position id (see plan.csv); ix,iy,iz grid indices
  pass                repetition of the whole route (1..n_passes); same site_id + k in different passes =
                      same pose measured again -> group by (site_id, k) to get the variance per point
  k                   angle index: angle_cmd_deg = (angle_offset_deg + 360*k/K) mod 360 (session.json)
  *_cmd_*             commanded pose; x_mm,y_mm,z_mm,angle_deg measured pose (gantry/MTRS feedback)
  mtrs_tilt_deg       measured MTRS tilt (kept at the config value, normally 0)
  pd_tilt_deg         mechanical tilt of the PD mount (3D-printed part) - recorded only
  <f>kHz_fft_{units:<5} FFT peak near f, full resolution ({fft_src})
  <f>kHz_wave_Vrms    RMS amplitude of the f sinusoid over the whole continuous record (lock-in projection at f)
  *_std               std over the samples (only when n_samples > 1)
  clip_frac           fraction of waveform samples at the screen edge (> 0 means saturation)
  wave_ac_rms_V       total RMS of the waveform (signal + noise)
Each sample is ONE continuous record ({rec}); see session.json "record".
fft/mNNNNN.csv  FFT of every sample: frequency_Hz, acq_1..acq_n. Reduced to <= {max_bins} bins by taking
                the maximum of each group of bins (peaks preserved); the full-resolution spectrum can be
                recomputed from the waveform (hardware.scope.spectrum_vrms).
wave/mNNNNN.npz raw waveform, lossless ADC codes:
                  z = np.load(path); v = (z["codes"] - z["y_reference"][:, None]) * z["y_increment"][:, None]
                                         + z["y_origin"][:, None]          # volts, shape (n, samples)
                  t = np.arange(v.shape[1]) / z["fs"]; z["unix"] = start time of each sample
                (simulated scope: z["v"] holds the volts directly)
plan.csv        all planned measurements; trajectory.csv: gantry + MTRS telemetry at 10 Hz
session.json    plan configuration, devices and scope settings, final status
"""
        with open(os.path.join(sdir, "README.txt"), "w") as f:
            f.write(text)

    def _save_measurement(self, m, acqs, tel_before, tel_after, t_move):
        c, scope = self.plan["config"], self.tb.scope
        sdir, mid = self.session_dir, m["meas_id"]
        units = self._fft_units()
        tag = f"m{mid:05d}"
        pos = [float(v) for v in np.mean([tel_before["pos"], tel_after["pos"]], axis=0)]
        ang = 0.5 * (tel_before["angle"] + tel_after["angle"])
        tilt = 0.5 * (tel_before["tilt"] + tel_after["tilt"])
        feats = frequency_features(acqs, self.freqs_hz, scope.led_band)
        low, high = scope.channel_limits()
        clip = max(clipped_fraction(a["v"], low, high) for a in acqs)
        v_all = np.concatenate([a["v"] for a in acqs])

        header = [f"meas_id: {mid}", f"site_id: {m['site_id']}", f"x_mm: {pos[0]:.3f}",
                  f"y_mm: {pos[1]:.3f}", f"z_mm: {pos[2]:.3f}", f"angle_deg: {ang:.4f}",
                  f"pd_tilt_deg: {c['pd_tilt_deg']}", f"fft_units: {units}"]
        header += [f"acq_{i + 1}_unix_time_s: {a['unix']:.6f}" for i, a in enumerate(acqs)]
        f0 = acqs[0]["f"]
        bin_hz = float(f0[1] - f0[0]) if f0.size > 1 else math.nan
        spectra = [decimate_spectrum(a["f"], a["fft"], FFT_SAVE_MAX_BINS) for a in acqs]
        n_f = min(s[1].size for s in spectra)
        if not c["scope_fft"]:          # the interface shows the (Python) FFT of the last measurement
            with self.lock:
                self.fft = {"unix": acqs[-1]["unix"], "f": spectra[-1][0], "y": spectra[-1][1],
                            "ylim": (None, None), "units": "Vrms", "source": "python"}
                self.fft_seq += 1
                self.fft_rate = 0.0
        header += [f"fft_source: {acqs[0].get('fft_source', 'scope')}", f"fft_bin_full_Hz: {bin_hz:.6g}",
                   f"fft_saved_bins: {n_f} (maximum of each group of {max(1, f0.size // max(n_f, 1))} bins)",
                   f"record_points: {acqs[0]['v'].size}", f"fs_Sa_s: {acqs[0]['fs']:.6g}"]
        cols = np.column_stack([spectra[0][0][:n_f]] + [s[1][:n_f] for s in spectra])
        names = ",".join(["frequency_Hz"] + [f"acq_{i + 1}" for i in range(len(acqs))])
        fft_file = f"fft/{tag}.csv"
        np.savetxt(os.path.join(sdir, fft_file), cols, delimiter=",", fmt="%.6e",
                   header="\n".join(header + [names]), comments="# ")

        wave_file = ""
        if c["save_waveforms"]:
            n_t = min(a["v"].size for a in acqs)
            wave_file = f"wave/{tag}.npz"
            common = {"fs": acqs[0]["fs"], "unix": np.array([a["unix"] for a in acqs])}
            if all("codes" in a for a in acqs):          # raw ADC codes: lossless, 2 bytes/point
                sc = np.array([a["scale"] for a in acqs])
                np.savez_compressed(os.path.join(sdir, wave_file),
                                    codes=np.array([a["codes"][:n_t] for a in acqs], dtype=np.uint16),
                                    y_increment=sc[:, 0], y_origin=sc[:, 1], y_reference=sc[:, 2], **common)
            else:
                np.savez_compressed(os.path.join(sdir, wave_file),
                                    v=np.array([a["v"][:n_t] for a in acqs], dtype=np.float32), **common)

        row = {
            "meas_id": mid, "pass": m["pass"], "site_id": m["site_id"], "ix": m["ix"], "iy": m["iy"], "iz": m["iz"],
            "k": m["k"], "iso_time": datetime.now().isoformat(timespec="seconds"),
            "unix_time_s": f"{acqs[0]['unix']:.3f}",
            "x_cmd_mm": m["x"], "y_cmd_mm": m["y"], "z_cmd_mm": m["z"], "angle_cmd_deg": m["angle"],
            "x_mm": round(pos[0], 3), "y_mm": round(pos[1], 3), "z_mm": round(pos[2], 3),
            "angle_deg": round(ang, 4), "mtrs_tilt_deg": round(tilt, 4), "pd_tilt_deg": c["pd_tilt_deg"],
            "pos_err_mm": round(math.dist(pos, (m["x"], m["y"], m["z"])), 3),
            "angle_err_deg": round(ang - m["angle"], 4), "n_acq": len(acqs),
            "clip_frac": f"{clip:.4g}", "wave_ac_rms_V": f"{float(np.std(v_all)):.6g}",
            "fft_file": fft_file, "wave_file": wave_file,
        }
        rss, fft_vals = {}, {}
        for ft in feats:
            lb = freq_label(ft["freq_Hz"])
            row[f"{lb}_fft_{units}"] = "" if math.isnan(ft["fft_mean"]) else f"{ft['fft_mean']:.6g}"
            row[f"{lb}_wave_Vrms"] = f"{ft['vrms_mean']:.6g}"
            if c["n_samples"] > 1:
                row[f"{lb}_fft_{units}_std"] = "" if math.isnan(ft["fft_std"]) else f"{ft['fft_std']:.3g}"
                row[f"{lb}_wave_Vrms_std"] = f"{ft['vrms_std']:.3g}"
            rss[lb], fft_vals[lb] = ft["vrms_mean"], ft["fft_mean"]
        with open(os.path.join(sdir, "points.csv"), "a", newline="") as f:
            csv.DictWriter(f, fieldnames=self._points_fields).writerow(row)
        if clip and clip > 0.001:
            self.add_log(f"Measurement {mid}: {clip:.1%} of the samples are clipped (saturation).",
                         "warning")
        return {"meas_id": mid, "pass": m["pass"], "site_id": m["site_id"], "k": m["k"], "x": pos[0], "y": pos[1],
                "z": pos[2], "angle": ang, "rss": rss, "fft": fft_vals, "clip": clip,
                "t_move": round(t_move, 2), "t": time.time()}

    def _fft_units(self):
        return "Vrms" if not self.plan["config"]["scope_fft"] else (self.tb.scope.fft_units or "fft")

    def _close_session(self, status):
        with self.lock:
            traj, self._traj = self._traj, None
        if traj is not None:
            traj[0].close()
        c = self.plan["config"]
        if c["record_ms"] > 0 or not c["scope_fft"]:
            self._restore_record()
            self.add_log("Oscilloscope settings restored (timebase / sample rate / memory / FFT display).")
        if self.session_dir:
            try:
                self._write_session_json(status)
            except Exception as e:
                self.add_log(f"Could not update session.json: {e}", "error")

    # ---------------------------------------------------------------
    # state for the interface
    # ---------------------------------------------------------------
    def _progress(self):
        total = self.plan["n_meas"] if self.plan else 0
        n = len(self.done)
        elapsed = (time.time() - self.t_session - self.t_paused) if self.t_session and self.busy() else None
        eta = None
        if self.plan and n < total:
            cum = self.plan["est_cum"]
            remaining = float(cum[-1] - (cum[self.next_index - 1] if self.next_index > 0 else 0.0))
            ratio = self.actual_s / self.est_done_s if self.est_done_s > 0 else 1.0
            eta = remaining * ratio
        return {"done": n, "total": total, "elapsed_s": elapsed, "eta_s": eta,
                "current": self.current}

    def _fft_payload(self):
        fft = self.fft
        if fft is None or not len(fft["f"]):
            return None
        f, y = fft["f"], fft["y"]
        step = max(1, int(math.ceil(len(y) / 1400)))
        if step > 1:                                  # max decimation (keeps the peaks)
            n = len(y) // step * step
            y = y[:n].reshape(-1, step).max(axis=1)
            f = f[:n:step]
        return {"seq": self.fft_seq, "f0": float(f[0]), "df": float(f[1] - f[0]) if len(f) > 1 else 0,
                "y": [float(f"{v:.4g}") for v in y], "ylim": list(fft.get("ylim", (None, None))),
                "units": fft.get("units", self.tb.scope.fft_units), "rate": round(self.fft_rate, 1),
                "source": fft.get("source", "scope")}

    def _tel_payload(self):
        p = self.tel
        if p is None:
            return None
        return {"x": p["pos"][0], "y": p["pos"][1], "z": p["pos"][2], "v": p["speed"],
                "ok": p["gantry_ok"], "kin": p["kin"], "angle": p["angle"], "tilt": p["tilt"],
                "moving": p["mtrs_moving"]}

    def _plan_public(self):
        """Plan for the interface: positions as a flat list [x, y, z, iz, ...] (compact)."""
        p = self.plan
        if p is None:
            return None
        if p.get("_public_version") != self.plan_version:
            pub = {k: p[k] for k in ("config", "axes", "angles", "n_sites", "n_meas", "passes",
                                     "est_total_s", "est_breakdown", "est_bytes", "warnings")}
            pub["sites_flat"] = [v for s in p["sites"] for v in (s[3], s[4], s[5], s[2])]
            p["_public"], p["_public_version"] = _clean(pub), self.plan_version
        return p["_public"]

    def full_state(self):
        tb = self.tb
        g_cfg, m_cfg = tb.cfg["gantry"], tb.cfg["mtrs"]
        with self.lock:
            plan = self._plan_public()
            data = {
                "type": "full", "state": self.state, "phase": self.phase, "message": self.message,
                "error": self.error, "plan_version": self.plan_version, "plan": plan,
                "config": self.config, "defaults": self.defaults,
                "done": list(self.done), "log": self.log[-300:],
                "session_dir": self.session_dir, "progress": self._progress(),
                "tel": self._tel_payload(), "target": self.target, "fft": self._fft_payload(),
                "workspace": {"min": list(tb.gantry.workspace_min), "max": list(tb.gantry.workspace_max)},
                "view": tb.view, "modes": tb.modes,
                "scope": {k: tb.scope.info.get(k) for k in (
                    "idn", "fft_units", "fft_window", "fft_center_Hz", "fft_span_Hz",
                    "timebase_s_div", "sample_rate_Sa_s", "acquire_type", "ch_scale_V_div",
                    "ch_offset_V", "ch_coupling", "wgen_frequency_Hz", "acq_digitizer",
                    "acq_points", "acq_srate_max_Sa_s")},
                "gantry": {"velocity_mm_s": g_cfg["velocity_mm_s"],
                           "override_pct": g_cfg.get("override_pct", 100.0)},
                "mtrs": {"velocity_deg_s": m_cfg["velocity_deg_s"],
                         "tilt_target_deg": m_cfg.get("tilt_target_deg", 0.0)},
                "cursor": self._cursor(),
            }
        return _clean(data)

    def _cursor(self):
        return {"done": len(self.done), "log": self._log_base + len(self.log), "fft": self.fft_seq,
                "plan": self.plan_version}

    def update(self, cursor):
        """Changes since `cursor` (for the live stream). (None, None) = ask for the full state."""
        with self.lock:
            if cursor["done"] > len(self.done) or cursor["plan"] != self.plan_version:
                return None, None
            log_start = max(cursor["log"] - self._log_base, 0)
            data = {"type": "update", "state": self.state, "phase": self.phase,
                    "message": self.message, "error": self.error, "plan_version": self.plan_version,
                    "progress": self._progress(), "tel": self._tel_payload(), "target": self.target,
                    "session_dir": self.session_dir,
                    "new_done": self.done[cursor["done"]:], "log": self.log[log_start:]}
            if self.fft_seq != cursor["fft"]:
                data["fft"] = self._fft_payload()
            new_cursor = self._cursor()
        return _clean(data), new_cursor
