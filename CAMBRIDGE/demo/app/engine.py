"""
engine.py - Logic of the VLP Positioning Demo (all the control runs here; the web page only sends
commands and displays the state).

Loop, without end until Stop (or max_points):
  1. next position: the manual queue first; otherwise a random position in the region (random mode)
     or wait for one (manual mode)
  2. K orientations theta_k = (nominal_offset + 360 k / K) mod 360, nominal offset 65 deg as in the
     campaigns (sorted; measured in increasing order on one point and decreasing on the next, so the
     MTRS never makes a return turn): move, settle, record, RSS of every LED (lock-in on the raw
     waveform); the RSS panel fills up live. The estimator uses the real (calibrated) offset of
     [geometry] mtrs_offset_deg with the measured MTRS angles
  3. estimate the position from the K RSS of the positioning LED (positioner.py) and compare it with
     the true one (gantry feedback -> PD centre, geometry.py)
Pause takes effect after the current orientation (the point continues on Resume); Stop is immediate
(the point in progress is not estimated). Every orientation is saved as in database_acquisition.
"""

import math
import threading
import time
import traceback

import numpy as np

from hardware.scope import clipped_fraction, frequency_features
from hardware.testbed import Stopped
from hardware.utils import RateTimer
from storage import Session, freq_label

MAX_RETRIES = 2                  # acquisition retries before pausing with an error
MAX_RECORD_POINTS = 4_000_000    # memory of the MSO-X 4154A
TIME_POINTS = 8_000_000          # waveform points requested (= the whole record)
FIT_CURVE_STEP_DEG = 4.0         # resolution of the fitted RSS curve shown in the interface
DONE_KEEP = 5000                 # points kept in memory for the interface

DEFAULT_CONFIG = {
    "mode": "random",                       # "random" | "manual"
    "region_x": [100.0, 1300.0],            # random positions: gantry box [mm]
    "region_y": [100.0, 1300.0],
    "region_z": [0.0, 360.0],               # gantry z up (0 = lowest PD position): PD 0.955-1.315 m, the heights
                                            # where the positioning was validated (campaigns of 14-15/10)
    "k_angles": 5,                          # orientations per point
    "mtrs_tilt_mode": "fixed",              # MTRS tilt, commanded at every new position: "fixed" | "random"
    "mtrs_tilt_deg": 0.0,                   # fixed mode
    "mtrs_tilt_min_deg": -3.0,              # random mode: uniform in [min, max], one value per position
    "mtrs_tilt_max_deg": 3.0,
    "n_samples": 1,                         # records per orientation (averaged)
    "settle_s": 1.0,
    "record_ms": 100.0,                     # continuous record per sample [ms]; 0 = scope settings
    "record_fs_msa": 10.0,
    "freqs_khz": [300.0, 500.0, 700.0, 900.0],   # LEDs recorded (the positioning LED is always added)
    "save_waveforms": True,
    "max_points": 0,                        # 0 = run until Stop
    "seed": None,                           # random positions; None = new seed at every Start
    "label": "",
}


def normalize_config(cfg, defaults):
    c = {**defaults, **(cfg or {})}
    for k in ("region_x", "region_y", "region_z"):
        c[k] = sorted(float(v) for v in c[k])
    c["mode"] = "manual" if c["mode"] == "manual" else "random"
    for k in ("k_angles", "n_samples", "max_points"):
        c[k] = int(c[k])
    for k in ("settle_s", "record_ms", "record_fs_msa", "mtrs_tilt_deg", "mtrs_tilt_min_deg", "mtrs_tilt_max_deg"):
        c[k] = float(c[k])
    c["mtrs_tilt_mode"] = "random" if str(c["mtrs_tilt_mode"]).lower() == "random" else "fixed"
    c["freqs_khz"] = [float(f) for f in c["freqs_khz"]]
    c["save_waveforms"] = bool(c["save_waveforms"])
    c["seed"] = None if c.get("seed") in (None, "") else int(c["seed"])
    c["label"] = str(c.get("label") or "")
    return c


def plan_angles(K, first_deg):
    return sorted(round((first_deg + 360.0 * k / K) % 360.0, 6) for k in range(K))


class DemoEngine:
    def __init__(self, tb, positioner, settings, output_root, defaults=None):
        self.tb, self.pos, self.settings, self.output_root = tb, positioner, settings, output_root
        self.led_freq_khz = float(settings["positioning"]["led_frequency_khz"])
        self.nominal_offset = float(settings["plan"]["nominal_offset_deg"])
        self.show_led = bool(settings.get("display", {}).get("show_led", False))
        self.random_step = float(settings["plan"].get("random_step_mm", 1.0))
        self.defaults = normalize_config(defaults or {}, DEFAULT_CONFIG)
        self.config = dict(self.defaults)
        self.lock = threading.RLock()
        self.state, self.phase, self.message, self.error = "IDLE", "", "Configure and press Start.", None
        self.queue, self.done, self.current, self.cur_seq = [], [], None, 0
        self.log, self._log_base, self.tel = [], 0, None
        self.session, self.t_start, self._rng, self._pid = None, None, None, 0
        self._pause, self._stop, self._shutdown = threading.Event(), threading.Event(), threading.Event()
        self._runner, self._threads = None, []
        self._fft_was_shown = None
        self._tilt_rng, self._last_tilt_cmd = None, None

    # ---------------------------------------------------------------
    # helpers and threads
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
        print(f"[demo] {level.upper()}: {text}" if level != "info" else f"[demo] {text}")

    def start_threads(self):
        self._threads = [threading.Thread(target=self._telemetry_loop, daemon=True)]
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

    def _telemetry_loop(self):
        timer, failing = RateTimer(10.0), False
        while not self._shutdown.is_set():
            try:
                p = self.tb.pose()
                failing = False
                with self.lock:
                    self.tel = p
            except Exception as e:
                if not failing:
                    self.add_log(f"Telemetry error: {e}", "error")
                failing = True
            timer.wait()

    def busy(self):
        return self.state in ("RUNNING", "PAUSED", "STOPPING")

    # ---------------------------------------------------------------
    # validation
    # ---------------------------------------------------------------
    def check_config(self, cfg):
        c = normalize_config(cfg, self.defaults)
        errors, warnings = [], []
        g = self.tb.gantry
        for axis, i in (("x", 0), ("y", 1), ("z", 2)):
            lo, hi = c[f"region_{axis}"]
            if lo < g.workspace_min[i] or hi > g.workspace_max[i]:
                errors.append(f"Region {axis.upper()} [{lo:g}, {hi:g}] outside the workspace "
                              f"[{g.workspace_min[i]:g}, {g.workspace_max[i]:g}] mm.")
        if not 3 <= c["k_angles"] <= 72:
            errors.append("K must be between 3 and 72 (the 3D position needs at least 3 orientations).")
        mtrs, lim = self.tb.mtrs, self.tb.mtrs.tilt_limit
        tilts = ([c["mtrs_tilt_deg"]] if c["mtrs_tilt_mode"] == "fixed"
                 else [c["mtrs_tilt_min_deg"], c["mtrs_tilt_max_deg"]])
        if not all(mtrs.valid_tilt(t) for t in tilts):
            errors.append(f"MTRS tilt must be within +/-{lim:g} deg.")
        elif c["mtrs_tilt_mode"] == "random" and c["mtrs_tilt_min_deg"] > c["mtrs_tilt_max_deg"]:
            errors.append("MTRS tilt range: min must be <= max.")
        elif any(abs(t) > mtrs.tolerance for t in tilts):
            warnings.append("The estimator does not model the MTRS tilt yet (its PD normals assume tilt 0): with a "
                            "non-zero tilt the estimated positions will be biased. The tilt is still commanded "
                            "and recorded (points.csv, estimates.csv).")
        if c["n_samples"] < 1:
            errors.append("Samples per orientation must be >= 1.")
        if c["record_ms"] < 0 or c["record_fs_msa"] <= 0:
            errors.append("Invalid record length or sample rate.")
        n_rec = c["record_ms"] * 1e-3 * c["record_fs_msa"] * 1e6
        if n_rec > MAX_RECORD_POINTS:
            errors.append(f"Record of {n_rec:,.0f} points: the oscilloscope holds at most {MAX_RECORD_POINTS:,}.")
        if not any(abs(f - self.led_freq_khz) < 1e-6 for f in c["freqs_khz"]):
            c["freqs_khz"] = sorted(c["freqs_khz"] + [self.led_freq_khz])
            warnings.append(f"The positioning LED ({self.led_freq_khz:g} kHz) was added to the recorded LEDs.")
        if any(f <= 0 for f in c["freqs_khz"]) or len(set(c["freqs_khz"])) != len(c["freqs_khz"]):
            errors.append("LED frequencies must be positive and different.")
        if c["record_ms"] > 0 and c["record_fs_msa"] * 1e6 < 2.2 * max(c["freqs_khz"]) * 1e3:
            errors.append("The sample rate is too low for the highest LED frequency (aliasing).")
        return c, errors, warnings

    def check_target(self, xyz):
        xyz = [float(v) for v in xyz]
        problems = self.tb.gantry.outside_workspace(xyz)
        if problems:
            raise ValueError("; ".join(problems))
        return xyz

    # ---------------------------------------------------------------
    # commands (web server)
    # ---------------------------------------------------------------
    def start(self, cfg):
        if self.busy():
            raise RuntimeError("The demo is already running.")
        c, errors, warnings = self.check_config(cfg)
        if errors:
            raise ValueError(" ".join(errors))
        c["seed"] = c["seed"] if c["seed"] is not None else int(np.random.SeedSequence().entropy % 2 ** 31)
        self._rng = np.random.default_rng(c["seed"])
        self._tilt_rng = np.random.default_rng([c["seed"], 1])      # own stream: positions do not change
        self._last_tilt_cmd = None
        self._configure_scope(c)
        meta = {"positioning": self.pos.describe(), "settings_file": self.settings["_path"],
                "nominal_offset_deg": self.nominal_offset,
                "angles_deg": plan_angles(c["k_angles"], self.nominal_offset), "testbed": self.tb.info()}
        self.session = Session(self.output_root, c, [f * 1e3 for f in c["freqs_khz"]], meta)
        self._pause.clear()
        self._stop.clear()
        with self.lock:
            self.config, self.done, self.current, self.error, self._pid = c, [], None, None, 0
            self.state, self.phase, self.t_start = "RUNNING", "", time.time()
            self.cur_seq += 1
        for w in warnings:
            self.add_log(w, "warning")
        self.add_log(f"Demo started ({c['mode']} positions, K = {c['k_angles']}) -> {self.session.dir}")
        self._runner = threading.Thread(target=self._run, daemon=True)
        self._runner.start()

    def pause(self):
        if self.state == "RUNNING":
            self._pause.set()
            self._set(message="Pausing after the current orientation...")
            self.add_log("Pause requested (after the current orientation).")

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

    def set_mode(self, mode):
        with self.lock:
            self.config["mode"] = "manual" if mode == "manual" else "random"
        self.add_log(f"Mode: {self.config['mode']} positions.")

    def add_target(self, xyz):
        xyz = self.check_target(xyz)
        with self.lock:
            self.queue.append(xyz)
        self.add_log(f"Position queued: X {xyz[0]:g}, Y {xyz[1]:g}, Z {xyz[2]:g} mm.")

    def clear_queue(self):
        with self.lock:
            self.queue = []

    # ---------------------------------------------------------------
    # oscilloscope
    # ---------------------------------------------------------------
    def _configure_scope(self, c):
        scope = self.tb.scope
        self._fft_was_shown = scope.fft_displayed()
        if self._fft_was_shown:
            scope.set_fft_display(False)            # the scope FFT slows every capture down
        if c["record_ms"] > 0:
            scope.configure_record(c["record_ms"] * 1e-3, c["record_fs_msa"] * 1e6)
        else:
            scope.refresh_info()

    def _restore_scope(self):
        scope = self.tb.scope
        try:
            scope.restore_record()
            if self._fft_was_shown:
                scope.set_fft_display(True)
            self.add_log("Oscilloscope settings restored.")
        except Exception as e:
            self.add_log(f"Could not restore the oscilloscope settings: {e}", "error")

    def _record(self, c):
        scope = self.tb.scope
        for attempt in range(MAX_RETRIES + 1):
            try:
                acqs = scope.record(c["n_samples"], TIME_POINTS, scope_fft=False)
                fs, n = acqs[0]["fs"], acqs[0]["v"].size
                if fs < 2.2 * max(c["freqs_khz"]) * 1e3:
                    raise RuntimeError(f"record at {fs / 1e6:.3g} MSa/s aliases the LED frequencies")
                if c["record_ms"] > 0 and abs(n - c["record_ms"] * 1e-3 * c["record_fs_msa"] * 1e6) > 0.01 * n:
                    raise RuntimeError(f"the oscilloscope returned {n:,} points instead of the requested record")
                return acqs
            except Exception as e:
                scope.recover()
                if attempt == MAX_RETRIES or not scope.alive:
                    raise RuntimeError(f"acquisition failed after {attempt + 1} attempt(s): {e}. If the "
                                       f"oscilloscope is frozen, power-cycle it and press Resume")
                self.add_log(f"Acquisition error ({e}); retrying ({attempt + 1}/{MAX_RETRIES})", "warning")
                time.sleep(1.0)

    # ---------------------------------------------------------------
    # execution
    # ---------------------------------------------------------------
    def _check_stop(self):
        if self._stop.is_set():
            raise Stopped

    def _sleep(self, seconds):
        t_end = time.perf_counter() + seconds
        while time.perf_counter() < t_end:
            self._check_stop()
            time.sleep(0.05)

    def _wait_if_paused(self):
        if not self._pause.is_set():
            return
        self._set(state="PAUSED", phase="", message=f"Paused after an error: {self.error}" if self.error
                  else "Paused. Press Resume to continue or Stop to end.")
        while self._pause.is_set():
            self._check_stop()
            time.sleep(0.1)
        self._set(state="RUNNING")

    def _next_target(self):
        while True:
            self._check_stop()
            self._wait_if_paused()
            with self.lock:
                if self.queue:
                    return self.queue.pop(0), "manual"
                mode = self.config["mode"]
            if mode == "random":
                c, st = self.config, self.random_step
                xyz = [float(np.round(self._rng.uniform(*c[f"region_{a}"]) / st) * st) for a in "xyz"]
                return xyz, "random"
            self._set(phase="WAITING", message="Waiting for a position: click on the top view (or type X, Y, Z) "
                                               "and press Measure, or switch to random positions.")
            time.sleep(0.2)

    def _run(self):
        final = "STOPPED"
        try:
            while True:
                c = self.config
                if c["max_points"] and self.session.n_points >= c["max_points"]:
                    final = "FINISHED"
                    break
                target, origin = self._next_target()
                try:
                    self._measure_point(target, origin)
                except Stopped:
                    raise
                except Exception as e:
                    self.tb.stop()
                    traceback.print_exc()
                    self._set(error=str(e), current=None)
                    self.add_log(f"Point failed: {e}. Demo paused.", "error")
                    self._pause.set()
        except Stopped:
            final = "STOPPED"
        except Exception as e:
            traceback.print_exc()
            self.add_log(f"Unexpected error: {e}", "error")
            self._set(error=str(e))
        finally:
            self._restore_scope()
            n = self.session.n_points if self.session else 0
            if self.session:
                self.session.write_json(final, {"summary": self.stats()})
            self._set(state=final, phase="", message=f"{'Finished' if final == 'FINISHED' else 'Stopped'}: "
                      f"{n} points estimated. Folder: {self.session.dir if self.session else '-'}")
            self.add_log(f"Demo {final.lower()}: {n} points.")

    def _measure_point(self, target, origin):
        c, tb = self.config, self.tb
        K, freqs_hz = c["k_angles"], [f * 1e3 for f in c["freqs_khz"]]
        self._pid += 1                      # also counts points that failed: ids never repeat
        pid = self._pid
        angles = plan_angles(K, self.nominal_offset)
        order = list(range(K)) if pid % 2 else list(range(K))[::-1]
        truth_cmd = self.pos.geometry.pd_position(target)
        tilt = (c["mtrs_tilt_deg"] if c["mtrs_tilt_mode"] == "fixed" else
                round(float(self._tilt_rng.uniform(c["mtrs_tilt_min_deg"], c["mtrs_tilt_max_deg"])), 3))
        cur = {"id": pid, "origin": origin, "target": list(target), "true_cmd_mm": (1e3 * truth_cmd).tolist(),
               "angles": angles, "order": order, "rss_V": [None] * K, "meas_angles": [None] * K,
               "meas_pos": [None] * K, "rss_all": [None] * K, "active_k": None, "t0": time.time(), "result": None,
               "tilt_cmd": tilt, "meas_tilts": [None] * K}
        self._set(current=cur, cur_seq=self.cur_seq + 1)
        lb_pos = freq_label(self.led_freq_khz * 1e3)
        for j, k in enumerate(order):
            if j:
                self._wait_if_paused()
            self._check_stop()
            ang = angles[k]
            cur["active_k"] = k
            self._set(phase="MOVING", cur_seq=self.cur_seq + 1,
                      message=f"Point {pid}: {'moving to' if j == 0 else 'turning to'} X {target[0]:g} Y {target[1]:g} "
                              f"Z {target[2]:g} mm, {ang:.1f} deg, tilt {tilt:g} deg ({j + 1}/{K})")
            tel = self.tel
            xyz_cmd = None if (j or tb.gantry.arrived(target, {"pos": tel["pos"], "speed": tel["speed"]})) else target
            ang_cmd = None if tb.mtrs.arrived(ang, tel["angle"], tel["mtrs_moving"]) else ang
            # tilt: always commanded at a new position (j = 0), and again if it is found away from the command
            last = self._last_tilt_cmd
            if last is not None and not tel["tilt_moving"] and abs(tel["tilt"] - last) > tb.mtrs.tolerance:
                self.add_log(f"Point {pid}: MTRS tilt read {tel['tilt']:.3f} deg but {last:g} deg was commanded: "
                             f"it moved by itself; commanding {tilt:g} deg again.", "warning")
            tilt_off = not tb.mtrs.tilt_arrived(tilt, tel["tilt"], tel["tilt_moving"])
            tilt_cmd = tilt if j == 0 or tilt_off else None
            if xyz_cmd is not None or ang_cmd is not None or tilt_cmd is not None:
                tb.move_to_pose(xyz_cmd, ang_cmd, tilt_cmd, force_tilt=j == 0)
                tb.wait_pose(xyz_cmd, ang_cmd, stop_event=self._stop, tilt=tilt_cmd)
            self._last_tilt_cmd = tilt
            self._set(phase="SETTLING", message=f"Point {pid}: settling {c['settle_s']:g} s ({j + 1}/{K})")
            self._sleep(c["settle_s"])
            self._set(phase="MEASURING", message=f"Point {pid}: measuring orientation {j + 1}/{K} ({ang:.1f} deg)")
            before = self.tel
            acqs = self._record(c)
            after = self.tel
            self._check_stop()
            pos = [float(v) for v in np.mean([before["pos"], after["pos"]], axis=0)]
            ang_m = 0.5 * (before["angle"] + after["angle"])
            tilt_m = 0.5 * (before["tilt"] + after["tilt"])
            feats = frequency_features(acqs, freqs_hz, tb.scope.led_band)
            low, high = tb.scope.channel_limits()
            clip = max(clipped_fraction(a["v"], low, high) for a in acqs)
            v_all = np.concatenate([a["v"] for a in acqs])
            row = {"site_id": pid, "k": k, "unix_time_s": f"{acqs[0]['unix']:.3f}",
                   "x_cmd_mm": target[0], "y_cmd_mm": target[1], "z_cmd_mm": target[2], "angle_cmd_deg": ang,
                   "mtrs_tilt_cmd_deg": tilt, "x_mm": round(pos[0], 3), "y_mm": round(pos[1], 3),
                   "z_mm": round(pos[2], 3), "angle_deg": round(ang_m, 4), "mtrs_tilt_deg": round(tilt_m, 4),
                   "pd_tilt_deg": self.pos.geometry.pd_tilt_deg, "pos_err_mm": round(math.dist(pos, target), 3),
                   "angle_err_deg": round(ang_m - ang, 4), "n_acq": len(acqs), "clip_frac": f"{clip:.4g}",
                   "wave_ac_rms_V": f"{float(np.std(v_all)):.6g}"}
            rss_all = {}
            for ft in feats:
                lb = freq_label(ft["freq_Hz"])
                row[f"{lb}_fft_Vrms"] = "" if math.isnan(ft["fft_mean"]) else f"{ft['fft_mean']:.6g}"
                row[f"{lb}_wave_Vrms"] = f"{ft['vrms_mean']:.6g}"
                rss_all[lb] = ft["vrms_mean"]
            self.session.write_measurement(row, acqs)
            if clip and clip > 0.001:
                self.add_log(f"Point {pid}, {ang:.1f} deg: {clip:.1%} of the samples clipped (saturation).", "warning")
            with self.lock:
                cur["rss_V"][k], cur["meas_angles"][k], cur["meas_pos"][k] = rss_all[lb_pos], ang_m, pos
                cur["meas_tilts"][k] = tilt_m
                cur["rss_all"][k] = rss_all
                self.cur_seq += 1

        self._set(phase="ESTIMATING", message=f"Point {pid}: estimating the position")
        truth_gantry = np.mean(cur["meas_pos"], axis=0)
        res = self.pos.locate(cur["rss_V"], cur["meas_angles"], truth_gantry)
        est = res.pop("_estimate")
        curve_angles = np.arange(0.0, 360.0, FIT_CURVE_STEP_DEG)
        fit = self.pos.predicted_rss(est, curve_angles)
        meta = self.pos.describe()
        self.session.write_estimate(cur, res, meta)
        item = self._done_item(cur, res, truth_gantry)
        with self.lock:
            cur.update(active_k=None, result=item, duration_s=time.time() - cur["t0"],
                       fit={"angles": curve_angles.tolist(), "rss_mV": None if fit is None else (1e3 * fit).tolist()})
            self.done.append(item)
            del self.done[:-DONE_KEEP]
            self.cur_seq += 1
        if res["ok"]:
            self.add_log(f"Point {pid}: error {100 * res['err_3d_m']:.1f} cm (horizontal {100 * res['err_h_m']:.1f}, "
                         f"vertical {100 * res['err_v_m']:+.1f} cm), {item['duration_s']:.0f} s")
        else:
            self.add_log(f"Point {pid}: no estimate ({res['status']}).", "warning")
        if pid % 10 == 0:
            self.session.write_json("RUNNING", {"summary": self.stats()})

    def _done_item(self, cur, res, truth_gantry):
        mm = lambda v: None if v is None else [round(1e3 * x, 2) for x in v]   # noqa: E731
        return {"id": cur["id"], "t": time.time(), "K": res["K"], "ok": res["ok"], "status": res["status"],
                "origin": cur["origin"], "gantry": [round(v, 2) for v in truth_gantry], "true": mm(res["true_m"]),
                "est": mm(res.get("est_m")), "err": mm(res.get("err_m")),
                "err_3d_mm": None if not res["ok"] else round(1e3 * res["err_3d_m"], 2),
                "err_h_mm": None if not res["ok"] else round(1e3 * res["err_h_m"], 2),
                "err_dir_deg": res.get("err_dir_deg"), "err_range_mm": None if not res["ok"] else 1e3 * res["err_range_m"],
                "fit_rms_pct": res.get("fit_rms_pct"), "duration_s": round(time.time() - cur["t0"], 1)}

    # ---------------------------------------------------------------
    # state for the interface
    # ---------------------------------------------------------------
    def stats(self):
        ok = [d for d in self.done if d["ok"]]
        if not ok:
            return {"n": len(self.done), "n_ok": 0}
        e = np.array([d["err_3d_mm"] for d in ok])
        return {"n": len(self.done), "n_ok": len(ok), "mean_mm": float(e.mean()), "median_mm": float(np.median(e)),
                "rmse_mm": float(np.sqrt(np.mean(e ** 2))), "p90_mm": float(np.percentile(e, 90)),
                "max_mm": float(e.max()), "last_mm": float(e[-1]),
                "mean_h_mm": float(np.mean([d["err_h_mm"] for d in ok])),
                "bias_v_mm": float(np.mean([d["err"][2] for d in ok])),
                "mean_time_s": float(np.mean([d["duration_s"] for d in self.done]))}

    def _tel_payload(self):
        p = self.tel
        if p is None:
            return None
        r = self.pos.geometry.pd_position(p["pos"])
        return {"x": p["pos"][0], "y": p["pos"][1], "z": p["pos"][2], "v": p["speed"], "ok": p["gantry_ok"],
                "kin": p["kin"], "angle": p["angle"], "tilt": p["tilt"], "moving": p["mtrs_moving"],
                "phys": [1e3 * r[0], 1e3 * r[1], 1e3 * r[2]]}

    def _current_payload(self):
        cur = self.current
        if cur is None:
            return None
        out = {k: cur[k] for k in ("id", "origin", "target", "true_cmd_mm", "angles", "order", "meas_angles",
                                   "active_k", "result")}
        out["rss_mV"] = [None if v is None else 1e3 * v for v in cur["rss_V"]]
        out["fit"] = cur.get("fit")
        return out

    def _static(self):
        g, geo, m = self.tb.gantry, self.pos.geometry, self.pos.model
        z_lo, z_hi = g.workspace_min[2], g.workspace_max[2]
        h_lo, h_hi = 1e3 * geo.pd_height(z_lo), 1e3 * geo.pd_height(z_hi)     # PD height [mm] at both z limits
        return {"workspace": {"min": list(g.workspace_min), "max": list(g.workspace_max)},
                "phys_box": {"min": [g.workspace_min[0], g.workspace_min[1], min(h_lo, h_hi)],
                             "max": [g.workspace_max[0], g.workspace_max[1], max(h_lo, h_hi)]},
                "z_to_height": [z_lo, h_lo, z_hi, h_hi],           # linear map gantry z -> PD height (display)
                "led_mm": (1e3 * m.led_position).tolist() if self.show_led else None,
                "led_freq_khz": self.led_freq_khz, "nominal_offset_deg": self.nominal_offset,
                "view": self.tb.view, "modes": self.tb.modes}

    def full_state(self):
        with self.lock:
            return {"type": "full", "state": self.state, "phase": self.phase, "message": self.message,
                    "error": self.error, "config": self.config, "defaults": self.defaults, "queue": list(self.queue),
                    "done": list(self.done), "current": self._current_payload(), "stats": self.stats(),
                    "tel": self._tel_payload(), "log": self.log[-300:], "session_dir": self.session.dir if self.session else None,
                    "elapsed_s": time.time() - self.t_start if self.t_start and self.busy() else None,
                    **self._static(), "cursor": self._cursor()}

    def _cursor(self):
        return {"done": len(self.done), "log": self._log_base + len(self.log), "cur": self.cur_seq}

    def update(self, cursor):
        """Changes since `cursor` for the live stream; (None, None) = send the full state."""
        with self.lock:
            if cursor["done"] > len(self.done):
                return None, None
            log_start = max(cursor["log"] - self._log_base, 0)
            data = {"type": "update", "state": self.state, "phase": self.phase, "message": self.message,
                    "error": self.error, "queue": list(self.queue), "mode": self.config["mode"],
                    "tel": self._tel_payload(), "new_done": self.done[cursor["done"]:], "log": self.log[log_start:],
                    "session_dir": self.session.dir if self.session else None,
                    "elapsed_s": time.time() - self.t_start if self.t_start and self.busy() else None}
            if cursor["cur"] != self.cur_seq:
                data["current"] = self._current_payload()
                data["stats"] = self.stats()
            return data, self._cursor()
