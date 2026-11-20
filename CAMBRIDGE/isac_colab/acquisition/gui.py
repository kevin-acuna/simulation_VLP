"""
gui.py - Matplotlib interface of the ISAC acquisition (same style as testbed exp01).

Panels: gantry top view (plan sites, measured sites, live position), Z bar, MTRS rotation, live state + last
capture, OFDM constellation, last PD record (pilot windows / OFDM slots), its spectrum and the history of pilot
RMS and BER.
Buttons: Go & measure (typed X, Y, Z, rotation), Measure here, Start / Continue plan, Pause / Resume, Skip,
STOP. The GUI only sends commands to the Engine; it never talks to the devices.
"""

import math

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.widgets import Button, TextBox

from isac.plotting import draw_capture, draw_constellation, draw_spectrum

SITE_COLORS = {"ok": "tab:green", "comm": "tab:orange", "error": "tab:red"}


def _fmt(v, spec, unit="", scale=1.0):
    return "n/a" if v is None or (isinstance(v, float) and not math.isfinite(v)) else f"{v * scale:{spec}}{unit}"


class GUI:
    def __init__(self, engine, refresh_ms=100, title="ISAC acquisition"):
        self.e = engine
        tb = engine.tb
        self.trail, self.background = [], None
        self.fig = fig = plt.figure(title, figsize=(16, 9))
        wmin, wmax = tb.gantry.workspace_min, tb.gantry.workspace_max

        # --- top view: origin at the bottom right, X upwards, Y to the left (as exp01) ---
        ax = self.ax_xy = fig.add_axes([0.035, 0.43, 0.25, 0.52])
        ax.set_xlim(wmax[1], wmin[1])
        ax.set_ylim(wmin[0], wmax[0])
        ax.set_aspect("equal", adjustable="box")
        ax.yaxis.tick_right()
        ax.yaxis.set_label_position("right")
        ax.set_xlabel("Y [mm]  (increases to the left)")
        ax.set_ylabel("X [mm]  (increases upwards)")
        ax.set_title("Gantry - top view", fontsize=10)
        ax.grid(True, alpha=0.3)
        sites = np.array(sorted({m["xyz"][:2] for m in engine.plan})) if engine.plan else np.zeros((0, 2))
        if sites.size:
            ax.scatter(sites[:, 1], sites[:, 0], s=60, facecolors="none", edgecolors="0.6", zorder=2)
        self.done_sc = ax.scatter([], [], s=36, zorder=3)
        self.trail_ln, = ax.plot([], [], color="tab:blue", alpha=0.4, lw=1)
        self.target_mk, = ax.plot([], [], "x", color="tab:orange", ms=12, mew=2)
        self.pos_mk, = ax.plot([], [], "o", color="tab:blue", ms=9)
        for label, color in (("criteria met", "ok"), ("comm. criteria not met", "comm"), ("error / skipped", "error")):
            ax.scatter([], [], s=30, color=SITE_COLORS[color], label=label)
        ax.legend(loc="upper left", fontsize=7, framealpha=0.8)

        # --- Z ---
        az = self.ax_z = fig.add_axes([0.335, 0.43, 0.012, 0.52])
        az.set_ylim(wmin[2], wmax[2])
        az.set_xlim(0, 1)
        az.set_xticks([])
        az.yaxis.tick_right()
        az.set_title("Z [mm]", fontsize=9)
        az.grid(True, axis="y", alpha=0.3)
        self.z_target_ln, = az.plot([0, 1], [np.nan, np.nan], "--", color="tab:orange", lw=2)
        self.z_ln, = az.plot([0, 1], [np.nan, np.nan], color="tab:blue", lw=4)

        # --- MTRS rotation ---
        ap = self.ax_rot = fig.add_axes([0.375, 0.53, 0.14, 0.38], projection="polar")
        ap.set_theta_zero_location(tb.view.get("mtrs_zero_location", "N"))
        ap.set_theta_direction(-1 if tb.view.get("mtrs_clockwise", False) else 1)
        ap.set_ylim(0, 1.1)
        ap.set_yticklabels([])
        ap.set_title("MTRS rotation", fontsize=10)
        for a in sorted({m["angle"] for m in engine.plan}):
            ap.plot([math.radians(a)] * 2, [0, 1.05], ":", color="0.6", lw=1)
        self.rot_target_ln, = ap.plot([0, 0], [0, 1], "--", color="tab:orange", lw=1.5)
        self.needle, = ap.plot([0, 0], [0, 0.95], color="tab:blue", lw=5, solid_capstyle="round")

        # --- text, constellation, record, history ---
        self.info_txt = fig.text(0.535, 0.95, "", family="monospace", fontsize=8.5, va="top")
        self.ax_const = fig.add_axes([0.79, 0.47, 0.19, 0.46])
        self.ax_const.set_xticks([])
        self.ax_const.set_yticks([])
        self.ax_const.set_title("OFDM constellation", fontsize=9)
        self.ax_wave = fig.add_axes([0.045, 0.175, 0.32, 0.19])
        self.ax_wave.set_title("Last PD record", fontsize=9)
        self.ax_spec = fig.add_axes([0.425, 0.175, 0.245, 0.19])
        self.ax_spec.set_title("Spectrum of the last record", fontsize=9)
        self.ax_hist = fig.add_axes([0.715, 0.175, 0.235, 0.19])
        self.ax_ber = self.ax_hist.twinx()

        # --- controls ---
        tel = engine.snapshot()["tel"]
        init = [*(f"{v:.1f}" for v in tel["pos"]), f"{tel['angle']:.2f}"]
        self.boxes = [TextBox(fig.add_axes([0.055 + 0.085 * i, 0.02, 0.045, 0.045]), label, initial=val)
                      for i, (label, val) in enumerate(zip(("X [mm]", "Y [mm]", "Z [mm]", "Rot [deg]"), init))]
        specs = [("Go & measure", 0.39, 0.09, "#cde8cd", self.on_go), ("Measure here", 0.49, 0.08, None, self.on_here),
                 ("Start plan", 0.58, 0.09, "#cfe0f5", self.on_plan), ("Pause", 0.68, 0.08, None, self.on_pause),
                 ("Skip", 0.77, 0.07, None, self.on_skip), ("STOP", 0.85, 0.09, "#f4a0a0", self.on_stop)]
        self.buttons = {}
        for label, x, w, color, cb in specs:
            b = Button(fig.add_axes([x, 0.015, w, 0.055]), label, **({"color": color} if color else {}))
            b.on_clicked(cb)
            self.buttons[label] = b
        self.status_txt = fig.text(0.05, 0.09, "", fontsize=10, color="tab:blue")

        self.animated = [self.trail_ln, self.target_mk, self.pos_mk, self.z_target_ln, self.z_ln,
                         self.rot_target_ln, self.needle, self.info_txt, self.status_txt]
        for a in self.animated:
            a.set_animated(True)
        fig.canvas.mpl_connect("draw_event", self.on_draw)
        self.closed = False
        fig.canvas.mpl_connect("close_event", self.on_close)
        self.redraw_static()
        self.timer = fig.canvas.new_timer(interval=refresh_ms)
        self.timer.add_callback(self.update)
        self.timer.start()

    # ---------------------------------------------------------------
    # Buttons
    # ---------------------------------------------------------------
    def on_go(self, _event):
        try:
            x, y, z, ang = (float(b.text.replace(",", ".")) for b in self.boxes)
        except ValueError:
            return self.e._set(status="Invalid values: enter numbers for X, Y, Z and rotation.")
        self.trail = []
        self.e.go_and_measure((x, y, z), ang)

    def on_here(self, _event):
        self.e.measure_here()

    def on_plan(self, _event):
        self.trail = []
        self.e.start_plan()

    def on_pause(self, _event):
        self.e.resume() if self.e.mode == "PAUSED" else self.e.pause()

    def on_skip(self, _event):
        self.e.skip()

    def on_stop(self, _event):
        self.e.stop()

    def on_close(self, _event=None):
        self.closed = True
        self.timer.stop()

    # ---------------------------------------------------------------
    # Drawing
    # ---------------------------------------------------------------
    def on_draw(self, _event):
        self.background = self.fig.canvas.copy_from_bbox(self.fig.bbox)
        for a in self.animated:
            self.fig.draw_artist(a)

    def redraw_static(self):
        """Panels that change only after a capture or a mode change."""
        snap = self.e.snapshot()
        n_plan, done = snap["n_plan"], snap["next_index"]
        self.buttons["Start plan"].label.set_text("Continue plan" if 0 < done < n_plan else "Start plan")
        self.buttons["Pause"].label.set_text("Resume" if snap["mode"] == "PAUSED" else "Pause")
        with self.e.lock:
            hist, last = list(self.e.history), self.e.last
        pts = [h for h in hist if h["x_mm"] is not None]
        if pts:
            self.done_sc.set_offsets([[h["y_mm"], h["x_mm"]] for h in pts])
            self.done_sc.set_color([SITE_COLORS["error" if h["error"] else "ok" if h["isac_ok"] else "comm"]
                                    for h in pts])
        if last is not None and "state" in last:
            draw_capture(self.ax_wave, last["state"])
            draw_spectrum(self.ax_spec, last["state"])
            draw_constellation(self.ax_const, last["state"])
            self.ax_wave.set_title(f"Last PD record (capture #{last['row']['capture_id']})", fontsize=9)
            self.ax_spec.set_title("Spectrum of the last record", fontsize=9)
            self.ax_wave.set_xlabel("Time [ms]  (green: pilot, blue: OFDM)", fontsize=8)
            self.ax_spec.set_xlabel("Frequency [kHz]  (blue: OFDM band)", fontsize=8)
        ah, ab = self.ax_hist, self.ax_ber
        ah.clear()
        ab.clear()
        ids = [h["capture_id"] for h in hist]
        tone = [np.nan if h["tone_Vrms"] is None else h["tone_Vrms"] * 1e3 for h in hist]
        ber = [np.nan if h["ber"] is None else max(h["ber"], 1e-7) for h in hist]
        ber_avg = [np.nan if h["ber_avg"] is None else max(h["ber_avg"], 1e-7) for h in hist]
        ah.plot(ids, tone, ".-", color="tab:green", ms=4, lw=0.8)
        ab.semilogy(ids, ber, "x", color="tab:red", ms=4)
        ab.semilogy(ids, ber_avg, ".", color="tab:purple", ms=4)
        ab.set_ylim(5e-8, 1)
        ab.yaxis.tick_right()
        ab.yaxis.set_label_position("right")
        ah.set_xlabel("Capture #  (BER 0 drawn at 1e-7)")
        ah.set_ylabel("Pilot [mVrms]", color="tab:green")
        ab.set_ylabel("BER  (x orig.  . avg.)", color="tab:purple")
        ah.grid(True, alpha=0.3)
        self.fig.canvas.draw()

    def update(self):
        # after the window is closed matplotlib replaces the canvas: the timer may still fire once
        if self.closed or not hasattr(self.fig.canvas, "restore_region"):
            return self.on_close()
        redraw = False
        while not self.e.events.empty():
            self.e.events.get_nowait()
            redraw = True
        if redraw:
            self.redraw_static()
        s = self.e.snapshot()
        tel, target = s["tel"], s["target"]
        if tel is not None:
            x, y, z = tel["pos"]
            if s["phase"] == "MOVING":
                self.trail.append((y, x))
            self.pos_mk.set_data([y], [x])
            if self.trail:
                self.trail_ln.set_data(*zip(*self.trail))
            self.z_ln.set_ydata([z, z])
            a = math.radians(tel["angle"])
            self.needle.set_data([a, a], [0, 0.95])
        if target is not None:
            self.target_mk.set_data([target[1]], [target[0]])
            self.z_target_ln.set_ydata([target[2]] * 2)
            self.rot_target_ln.set_data([math.radians(target[3])] * 2, [0, 1.0])
        self.info_txt.set_text("\n".join(self._info_lines(s)))
        self.status_txt.set_text(s["status"])
        self.status_txt.set_color("tab:red" if s["status"].startswith(("ERROR", "STOP", "PAUSED", "Invalid"))
                                  else "tab:blue")
        canvas = self.fig.canvas
        if self.background is None:
            canvas.draw()
        else:
            canvas.restore_region(self.background)
            for a in self.animated:
                self.fig.draw_artist(a)
            canvas.blit(self.fig.bbox)
        canvas.flush_events()

    def _info_lines(self, s):
        lines = [f"State    : {s['mode']}" + (f" - {s['phase']}" if s["phase"] else ""),
                 f"Plan     : {s['next_index']} / {s['n_plan']} done", f"Captures : {s['n_captures']}", ""]
        tel, target = s["tel"], s["target"]
        if tel is not None:
            lines += ["Gantry", f"  X = {tel['pos'][0]:8.2f} mm", f"  Y = {tel['pos'][1]:8.2f} mm",
                      f"  Z = {tel['pos'][2]:8.2f} mm", f"  v = {tel['speed']:8.2f} mm/s", "",
                      "MTRS", f"  rot  = {tel['angle']:8.3f} deg", f"  tilt = {tel['tilt']:8.3f} deg",
                      f"  {'MOVING' if tel['mtrs_moving'] or tel['tilt_moving'] else 'still'}", ""]
        if target is not None:
            lines += ["Target", f"  X={target[0]:.1f} Y={target[1]:.1f} Z={target[2]:.1f}",
                      f"  rot={target[3]:.2f} deg", ""]
        last = self.e.last
        if last is not None:
            r = last["row"]
            lines += [f"Last capture #{r['capture_id']} ({r['mode']}"
                      + (f", site {r['site_id']}, k {r['k']}" if r.get("site_id") else "") + ")",
                      f"  pilot  {_fmt(r['tone_Vrms'], '.4g', ' mVrms', 1e3)}"
                      f"  ({r['tone_windows_valid']}/{r['tone_windows']} windows)",
                      f"  rate   {_fmt(r.get('goodput_Mbps'), '.3f', ' Mb/s')} of {_fmt(r.get('rate_nominal_Mbps'), '.3f')}",
                      f"  BER    {_fmt(r['ber'], '.3g')} | avg {_fmt(r['ber_avg'], '.3g')}",
                      f"  EVM    {_fmt(r['evm_pct'], '.2f', ' %')}  (SNR {_fmt(r.get('snr_comm_dB'), '.1f', ' dB')})",
                      f"  frames {r['frames_accepted']} ok / {r['frames_rejected']} rejected",
                      f"  criteria {'MET' if r['isac_ok'] else 'NOT met'}"]
        return lines
