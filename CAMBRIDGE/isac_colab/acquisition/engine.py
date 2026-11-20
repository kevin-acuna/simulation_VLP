"""
engine.py - Control of the ISAC acquisition: threads, motion, capture, receiver and saving.

The GUI only calls the public methods and reads snapshot() / last / history. All the instrument I/O of the
measurements (VISA, Kinesis, CRI) runs in the worker thread; the telemetry thread only reads the pose.

One measurement:
  move gantry + MTRS together (the MTRS tilt is commanded again at every new site) -> wait for arrival ->
  settle -> capture (AWG playback checked, :DIGitize) -> receiver (pilot RMS, BER, EVM, frames) ->
  raw record + CSV rows + results.xlsx (+ figures/cNNNNN.png).
Errors of the instruments or of the motion PAUSE the plan: Resume retries the same measurement, Skip records
it as failed (row with the error) and goes on, STOP ends the plan (it can be continued later).
Communication failures (no sync, rejected frames, high BER, rejected pilot windows) are results, not errors.
"""

import math
import queue
import threading
import time
import traceback

import numpy as np

import isac
from hardware.testbed import Stopped
from hardware.utils import RateTimer, wrap180
from isac.plotting import save_capture_figure
from isac.storage import isac_tables


class Engine:
    def __init__(self, tb, rig, experiment, session, plan, settle_s=1.0, n_captures=1, manual_tilt_deg=0.0,
                 backup_dir=None, save_figures=True, telemetry_hz=10.0):
        self.tb, self.rig, self.experiment, self.session, self.plan = tb, rig, experiment, session, plan
        self.settle_s, self.n_captures, self.manual_tilt = settle_s, int(n_captures), manual_tilt_deg
        self.backup_dir = backup_dir
        self.save_figures = save_figures
        self.telemetry_hz = telemetry_hz
        self.lock = threading.Lock()
        self.mode = "IDLE"            # IDLE | PLAN | PAUSED | MANUAL
        self.phase = ""               # MOVING | SETTLING | CAPTURING | PROCESSING
        self.status = "Ready."
        self.tel = None               # last pose (Testbed.pose)
        self.target = None            # (x, y, z, angle) of the current move
        self.next_index = 0           # next measurement of the plan
        self.last = None              # {"state": processed capture, "row": captures row}
        self.history = []             # short rows of every capture (GUI plots)
        self.events = queue.Queue()   # "capture" | "mode": the GUI redraws everything
        self._jobs = queue.Queue()
        self._decision = queue.Queue()
        self._stop = threading.Event()
        self._pause = threading.Event()
        self._shutdown = threading.Event()
        self._force_tilt = True       # command the MTRS tilt at the next move even inside a site
        self._threads = []

    # ---------------------------------------------------------------
    # State
    # ---------------------------------------------------------------
    def _set(self, **kw):
        with self.lock:
            for k, v in kw.items():
                setattr(self, k, v)

    def snapshot(self):
        with self.lock:
            return dict(mode=self.mode, phase=self.phase, status=self.status, tel=self.tel, target=self.target,
                        next_index=self.next_index, n_plan=len(self.plan), n_captures=len(self.history))

    def _mode(self, mode, status=None):
        self._set(mode=mode, phase="", **({"status": status} if status is not None else {}))
        self.events.put("mode")

    # ---------------------------------------------------------------
    # Commands (GUI thread)
    # ---------------------------------------------------------------
    def start(self):
        self._threads = [threading.Thread(target=self._telemetry_loop, daemon=True),
                         threading.Thread(target=self._worker_loop, daemon=True)]
        for t in self._threads:
            t.start()
        t0 = time.perf_counter()
        while self.snapshot()["tel"] is None and time.perf_counter() - t0 < 10:
            time.sleep(0.05)

    def start_plan(self):
        if self.mode != "IDLE":
            return self._set(status="Busy: wait for the current measurement (or press STOP).")
        if self.next_index >= len(self.plan):
            return self._set(status="The plan is complete.")
        self._stop.clear()
        self._pause.clear()
        self._force_tilt = True
        self._mode("PLAN", f"Plan started at measurement {self.next_index + 1}/{len(self.plan)}.")
        self._jobs.put(("plan", None))

    def pause(self):
        if self.mode == "PLAN":
            self._pause.set()
            self._set(status="Pausing after the current measurement...")

    def resume(self):
        if self.mode == "PAUSED":
            self._decision.put("resume")

    def skip(self):
        if self.mode == "PAUSED":
            self._decision.put("skip")

    def stop(self):
        self._stop.set()
        threading.Thread(target=self.tb.stop, daemon=True).start()
        if self.mode == "PAUSED":
            self._decision.put("stop")
        self._set(status="STOP sent.")

    def go_and_measure(self, xyz, angle):
        if self.mode != "IDLE":
            return self._set(status="Busy: wait for the current measurement (or press STOP).")
        problems = self.tb.check_pose(xyz, angle, self.manual_tilt)
        if problems:
            return self._set(status="Invalid pose: " + "; ".join(problems))
        self._stop.clear()
        self._force_tilt = True
        self._mode("MANUAL")
        self._jobs.put(("manual", dict(xyz=tuple(xyz), angle=float(angle), tilt=self.manual_tilt)))

    def measure_here(self):
        if self.mode != "IDLE":
            return self._set(status="Busy: wait for the current measurement (or press STOP).")
        self._stop.clear()
        self._mode("MANUAL")
        self._jobs.put(("here", dict(xyz=None, angle=None, tilt=None)))

    def shutdown(self, timeout=60.0):
        self._shutdown.set()
        self._stop.set()
        self._decision.put("stop")
        self.tb.stop()
        for t in self._threads:
            t.join(timeout)

    # ---------------------------------------------------------------
    # Threads
    # ---------------------------------------------------------------
    def _telemetry_loop(self):
        timer = RateTimer(self.telemetry_hz)
        while not self._shutdown.is_set():
            try:
                self._set(tel=self.tb.pose())
            except Exception as e:
                self._set(status=f"Telemetry error: {e}")
                time.sleep(0.5)
            timer.wait()

    def _worker_loop(self):
        while not self._shutdown.is_set():
            try:
                kind, arg = self._jobs.get(timeout=0.2)
            except queue.Empty:
                continue
            status = None
            try:
                if kind == "plan":
                    self._run_plan()
                    status = (f"Plan complete: {len(self.plan)} measurements." if self.next_index >= len(self.plan)
                              else None)
                else:
                    self._run_manual(kind, arg)
            except Stopped:
                status = f"STOP: stopped by the user ({self.next_index}/{len(self.plan)} plan measurements done)."
            except Exception as e:
                self._report_error(e)
                status = f"ERROR: {e}"
            self._mode("IDLE", status)

    # ---------------------------------------------------------------
    # Plan / manual measurements
    # ---------------------------------------------------------------
    def _run_plan(self):
        while self.next_index < len(self.plan):
            if self._shutdown.is_set() or self._stop.is_set():
                raise Stopped
            m = self.plan[self.next_index]
            if self._pause.is_set():
                self._pause.clear()
                if self._decide(f"PAUSED before measurement {self.next_index + 1}/{len(self.plan)}. "
                                f"Resume / Skip / STOP.", m, "skipped by the user"):
                    continue
            try:
                self._measure(m, "plan")
            except Stopped:
                raise
            except Exception as e:
                self._report_error(e)
                self._decide(f"ERROR at measurement {self.next_index + 1}/{len(self.plan)}: {e}  ->  Resume "
                             f"(retry) / Skip (record as failed) / STOP.", m, f"skipped after error: {e}")
                continue
            self._set(next_index=self.next_index + 1)

    def _decide(self, message, m, skip_reason):
        """Waits for Resume / Skip / STOP while paused. Returns True if the measurement was skipped."""
        while not self._decision.empty():
            self._decision.get_nowait()
        self._mode("PAUSED", message)
        decision = "stop"
        while not self._shutdown.is_set():
            try:
                decision = self._decision.get(timeout=0.2)
                break
            except queue.Empty:
                pass
        if decision == "stop" or self._shutdown.is_set():
            raise Stopped
        self._stop.clear()
        self._force_tilt = True
        self._mode("PLAN", "Resumed." if decision == "resume" else "Skipped.")
        if decision == "skip":
            self._record_failure(m, "plan", skip_reason)
            self._set(next_index=self.next_index + 1)
            return True
        return False

    def _run_manual(self, kind, target):
        for rep in range(self.n_captures):
            self._measure(dict(target, site_id=None, k=None, rep=rep, new_site=rep == 0,
                               new_pose=rep == 0 and kind == "manual"), kind)

    def _measure(self, m, mode):
        t_move = 0.0
        if m["new_pose"]:
            xyz, angle = m["xyz"], m["angle"]
            self._set(phase="MOVING", target=(*xyz, angle),
                      status=f"Moving to X={xyz[0]:.1f} Y={xyz[1]:.1f} Z={xyz[2]:.1f} mm, {angle:.2f} deg "
                             f"(~{self.tb.estimated_time(xyz, angle, m['tilt']):.0f} s)")
            self.tb.move_to_pose(xyz, angle, m["tilt"], force_tilt=m["new_site"] or self._force_tilt)
            self._force_tilt = False
            t_move = self.tb.wait_pose(xyz, angle, stop_event=self._stop, tilt=m["tilt"])
            self._set(phase="SETTLING", status=f"In position. Settling {self.settle_s:g} s...")
            self._sleep(self.settle_s)
        if self.rig.last_transmission is None:          # e.g. the AWG settings changed and were restored
            self._set(status="Restarting the AWG playback...")
            self.rig.transmit(self.experiment, self.session.dir, backup_dir=self.backup_dir)
        self._set(phase="CAPTURING", status="Capturing...")
        before = self.tb.pose()
        capture = self.rig.capture(self.experiment)
        after = self.tb.pose()
        unix = time.time()
        self._set(phase="PROCESSING", status="Processing...")
        state = isac.process(capture, self.experiment)
        row, windows, slots = isac_tables(state)
        row.update(self._pose_columns(m, mode, before, after, t_move, unix))
        row["capture_id"] = self.session.add(row, capture, windows, slots)
        self.session.write_excel()
        if self.save_figures:
            try:
                save_capture_figure(state, self.session.figure_path(row["capture_id"]),
                                    f"{self.session.dir.name}  capture {row['capture_id']} ({mode})")
            except Exception as e:                          # a figure never stops the acquisition
                print(f"[ISAC] Figure of capture {row['capture_id']} not saved: {e}")
        self._add_history(row)
        with self.lock:
            self.last = {"state": state, "row": row}
        self.events.put("capture")
        mv = lambda v: "n/a" if v is None else f"{v * 1e3:.4g} mVrms"
        ber = lambda v: "n/a" if v is None else f"{v:.3g}"
        self._set(status=f"Capture #{row['capture_id']} saved: pilot {mv(row['tone_Vrms'])}, "
                         f"{ber(row['goodput_Mbps'])} Mb/s, BER {ber(row['ber'])} "
                         f"(averaged {ber(row['ber_avg'])}), {row['frames_accepted']} frames ok / "
                         f"{row['frames_rejected']} rejected" + ("" if row["isac_ok"] else "  [criteria NOT met]"))
        print(f"[ISAC] #{row['capture_id']} {mode} site={m.get('site_id')} k={m.get('k')} rep={m.get('rep')} "
              f"pos=({row['x_mm']}, {row['y_mm']}, {row['z_mm']}) rot={row['angle_deg']}: pilot {mv(row['tone_Vrms'])}, "
              f"BER {ber(row['ber'])} / avg {ber(row['ber_avg'])}, EVM {ber(row['evm_pct'])} %, "
              f"goodput {ber(row['goodput_Mbps'])} of {ber(row['rate_nominal_Mbps'])} Mb/s")

    def _sleep(self, seconds):
        t_end = time.perf_counter() + seconds
        while time.perf_counter() < t_end:
            if self._stop.is_set() or self._shutdown.is_set():
                raise Stopped
            time.sleep(0.05)

    def _pose_columns(self, m, mode, before, after, t_move, unix):
        pos = [float(v) for v in np.mean([before["pos"], after["pos"]], axis=0)]
        angle = before["angle"] + wrap180(after["angle"] - before["angle"]) / 2
        cmd = m.get("xyz")
        return dict(
            mode=mode, unix_time_s=round(unix, 3), site_id=m.get("site_id"), k=m.get("k"), rep=m.get("rep"),
            x_cmd_mm=cmd[0] if cmd else None, y_cmd_mm=cmd[1] if cmd else None, z_cmd_mm=cmd[2] if cmd else None,
            angle_cmd_deg=m.get("angle"), tilt_cmd_deg=m.get("tilt"),
            x_mm=round(pos[0], 3), y_mm=round(pos[1], 3), z_mm=round(pos[2], 3), angle_deg=round(angle, 4),
            tilt_deg=round((before["tilt"] + after["tilt"]) / 2, 4),
            pos_err_mm=round(math.dist(pos, cmd), 3) if cmd else None,
            angle_err_deg=round(wrap180(angle - m["angle"]), 4) if m.get("angle") is not None else None,
            pos_drift_mm=round(math.dist(before["pos"], after["pos"]), 3), move_time_s=round(t_move, 2))

    def _record_failure(self, m, mode, reason):
        p = self.tb.pose()
        row = {**self._pose_columns(m, mode, p, p, 0.0, time.time()), "error": reason}
        row["capture_id"] = self.session.add(row)
        self.session.write_excel()
        self._add_history(row)
        self.events.put("capture")

    def _add_history(self, row):
        keys = ("capture_id", "mode", "site_id", "x_mm", "y_mm", "tone_Vrms", "ber", "ber_avg", "isac_ok", "error")
        with self.lock:
            self.history.append({k: row.get(k) for k in keys})

    def _report_error(self, e):
        traceback.print_exc()
        self.tb.stop()
        try:
            self.rig.recover()
        except Exception:
            pass
        self._set(status=f"ERROR: {e}")
