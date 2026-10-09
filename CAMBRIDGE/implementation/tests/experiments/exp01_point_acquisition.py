"""
exp01_point_acquisition.py - Experimento 01: adquisicion punto a punto (manual).

El usuario escribe X, Y, Z [mm] (coordenadas del gantry) y el angulo de rotacion del
MTRS [deg] (tilt siempre 0) y pulsa "Go & measure":
  1. El gantry y el MTRS se mueven a la vez.
  2. Cada 100 ms se actualizan: posicion XY (+ Z), angulo del MTRS y la FFT del
     osciloscopio (la que calcula el propio osciloscopio, funcion Math FFT).
  3. Al llegar (y tras SETTLE_TIME_S) se hacen N_ACQUISITIONS adquisiciones
     sincronizadas (:DIGitize -> FFT del osciloscopio + forma de onda del canal) y
     se guardan en CSV junto con la pose medida.

Los parametros de los EQUIPOS estan en config/testbed.toml (se configuran una vez).
Aqui solo van los parametros propios de este experimento.

Archivos de cada sesion (OUTPUT_ROOT/exp01_<fecha>/):
  session.json        parametros del experimento + configuracion e info de los equipos
  points.csv          una fila por punto: pose comandada/medida y, para cada frecuencia de
                      FREQUENCIES_KHZ, el pico de la FFT del osciloscopio y la amplitud
                      RMS de esa senoide en la forma de onda cruda
  trajectory.csv      telemetria a 10 Hz de toda la sesion (gantry + MTRS)
  pNNNN_fft.csv       FFT del osciloscopio de cada adquisicion del punto NNNN
  pNNNN_wave.csv      forma de onda del canal de cada adquisicion (si SAVE_WAVEFORMS)

Botones: "Go & measure", "Measure here" (sin mover), "STOP" (detiene gantry y MTRS).
Antes de ejecutar: gantry referenciado (iRC), MTRS con home (Kinesis cerrado),
osciloscopio con Math -> FFT sobre el canal del PD y sin otros programas conectados.
"""

import csv
import json
import math
import os
import queue
import sys
import threading
import time
from datetime import datetime

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.widgets import Button, TextBox

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from hardware.scope import fft_peak, frequency_features   # noqa: E402
from hardware.testbed import Stopped, Testbed             # noqa: E402
from hardware.utils import RateTimer, wrap180             # noqa: E402


# ============================================================
# HIPERPARAMETROS DEL EXPERIMENTO
# (los de los equipos estan en config/testbed.toml)
# ============================================================

DEVICE_MODE_OVERRIDE = {}            # p.ej. {"gantry": "sim"}; vacio = modos de la config

# Frecuencias a estudiar y registrar en points.csv, en kHz. El numero de frecuencias es
# la longitud de la lista: [700.0] -> 1 frecuencia (700 kHz); [700.0, 850.0] -> 2.
# Lista vacia [] -> se usa la frecuencia del LED de la config (generador del osciloscopio).
FREQUENCIES_KHZ = [700.0]

SETTLE_TIME_S = 1.0                  # espera tras llegar, antes de medir (vibraciones)
N_ACQUISITIONS = 3                   # adquisiciones sincronizadas por punto
TIME_POINTS = 100000                 # puntos de la forma de onda por adquisicion (o "MAX")
SAVE_WAVEFORMS = True                # guardar la forma de onda cruda (pNNNN_wave.csv)
GUI_REFRESH_MS = 100                 # refresco de la interfaz
TELEMETRY_RATE_HZ = 10.0             # muestreo de gantry + MTRS (trajectory.csv)
OUTPUT_ROOT = os.path.join(ROOT, "data", "exp01")


# ============================================================
# ESTADO COMPARTIDO ENTRE HILOS
# ============================================================

class Shared:
    def __init__(self):
        self.lock = threading.Lock()
        self.tel = None                  # ultima pose (Testbed.pose)
        self.fft = None                  # ultima FFT leida del osciloscopio
        self.fft_fps = 0.0
        self.state = "STARTING"          # IDLE | MOVING | SETTLING | MEASURING
        self.status = ""
        self.target = None               # (x, y, z, angulo)
        self.point_id = 0
        self.last_summary = None
        self.gui_events = queue.Queue()

    def set(self, **kw):
        with self.lock:
            for k, v in kw.items():
                setattr(self, k, v)

    def get(self, *names):
        with self.lock:
            return tuple(getattr(self, n) for n in names)


S = Shared()
shutdown = threading.Event()
stop_event = threading.Event()
jobs = queue.Queue()
record_requests = queue.Queue()


def get_tel():
    tel, = S.get("tel")
    return tel


def freq_label(f_hz):
    """700000 -> '700kHz' (nombre de columna legible)."""
    return f"{f_hz / 1e3:g}kHz"


# ============================================================
# HILOS
# ============================================================

TRAJ_FIELDS = ["unix_time_s", "state", "point_id", "x_mm", "y_mm", "z_mm", "speed_mm_s",
               "gantry_ok", "angle_deg", "tilt_deg", "mtrs_moving",
               "x_target_mm", "y_target_mm", "z_target_mm", "angle_target_deg"]


def telemetry_loop(tb, path):
    timer = RateTimer(TELEMETRY_RATE_HZ)
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(TRAJ_FIELDS)
        n = 0
        while not shutdown.is_set():
            try:
                tel = tb.pose()
            except Exception as e:
                S.set(status=f"Telemetry error: {e}")
                timer.wait()
                continue
            S.set(tel=tel)
            state, pid, target = S.get("state", "point_id", "target")
            w.writerow([f"{tel['unix']:.3f}", state, pid, *(f"{v:.3f}" for v in tel["pos"]),
                        f"{tel['speed']:.2f}", int(tel["gantry_ok"]), f"{tel['angle']:.4f}",
                        f"{tel['tilt']:.4f}", int(tel["mtrs_moving"]),
                        *(target or (math.nan,) * 4)])
            n += 1
            if n % 10 == 0:
                f.flush()
            timer.wait()


def scope_loop(scope):
    t_last = time.perf_counter()
    while not shutdown.is_set():
        try:
            req = record_requests.get_nowait()
        except queue.Empty:
            req = None
        try:
            if req is not None:
                req["result"] = scope.record(N_ACQUISITIONS, TIME_POINTS)
            else:
                fft = scope.read_fft()
                now = time.perf_counter()
                S.set(fft=fft, fft_fps=1.0 / max(now - t_last, 1e-6))
                t_last = now
        except Exception as e:
            if req is not None:
                req["error"] = e
            else:
                S.set(status=f"Error reading the FFT: {e}")
                time.sleep(0.5)
        finally:
            if req is not None:
                req["done"].set()
        time.sleep(0.01)


def worker_loop(tb, session_dir, freqs_hz):
    while not shutdown.is_set():
        try:
            job = jobs.get(timeout=0.2)
        except queue.Empty:
            continue
        stop_event.clear()
        try:
            run_job(tb, session_dir, freqs_hz, **job)
        except Stopped:
            S.set(state="IDLE", status="STOP: motion stopped by the user.")
        except Exception as e:
            tb.stop()
            S.set(state="IDLE", status=f"ERROR: {e}")
            print(f"[exp01] ERROR: {e}")


# ============================================================
# MOVIMIENTO + MEDIDA
# ============================================================

def sleep_checked(seconds):
    t_end = time.perf_counter() + seconds
    while time.perf_counter() < t_end:
        if stop_event.is_set() or shutdown.is_set():
            raise Stopped
        time.sleep(0.05)


def run_job(tb, session_dir, freqs_hz, target=None, angle=None):
    if target is None:                           # "Measure here": pose actual
        tel = get_tel()
        target, angle, t_move = tel["pos"], tel["angle"], 0.0
        S.set(target=(*target, angle))
    else:
        problems = tb.check_pose(target, angle)
        if problems:
            raise ValueError("; ".join(problems))
        S.set(state="MOVING", target=(*target, angle),
              status=f"Moving to X={target[0]:.1f} Y={target[1]:.1f} Z={target[2]:.1f} mm, "
                     f"{angle:.2f} deg (~{tb.estimated_time(target, angle):.0f} s)")
        tb.move_to_pose(target, angle)
        t_move = tb.wait_pose(target, angle, stop_event=stop_event)

    S.set(state="SETTLING", status=f"In position. Settling for {SETTLE_TIME_S} s...")
    sleep_checked(SETTLE_TIME_S)

    S.set(state="MEASURING", status=f"Measuring {N_ACQUISITIONS} acquisitions...")
    tel_before = get_tel()
    req = {"done": threading.Event()}
    record_requests.put(req)
    t_end = time.perf_counter() + 60.0 + 20.0 * N_ACQUISITIONS
    while not req["done"].wait(0.2):
        if shutdown.is_set():
            raise Stopped
        if time.perf_counter() > t_end:
            raise TimeoutError("The oscilloscope did not respond to the acquisition.")
    if "error" in req:
        raise RuntimeError(f"Acquisition failed: {req['error']}")
    tel_after = get_tel()

    pid, = S.get("point_id")
    pid += 1
    row, feats = save_point(tb.scope, session_dir, freqs_hz, pid, target, angle,
                            tel_before, tel_after, t_move, req["result"])
    units = tb.scope.fft_units
    values = "  ".join(f"{freq_label(ft['freq_Hz'])}: FFT {ft['fft_mean']:.4g} {units}, "
                       f"wave {ft['vrms_mean'] * 1e3:.3f} mVrms" for ft in feats)
    S.set(point_id=pid, last_summary={"point_id": pid, "features": feats}, state="IDLE",
          status=f"Point #{pid} saved.  " + (values if len(feats) == 1 else
                                              "Values per frequency in 'Last point'."))
    S.gui_events.put(("point", row))
    print(f"[exp01] Point #{pid}: X={row['x_mm']} Y={row['y_mm']} Z={row['z_mm']} mm, "
          f"rot={row['angle_deg']} deg | {values}")


# ============================================================
# GUARDADO
# ============================================================

def point_fields(freqs_hz, units):
    """Columnas de points.csv (las de cada frecuencia van justo despues de la pose)."""
    per_freq = []
    for f0 in freqs_hz:
        lb = freq_label(f0)
        per_freq += [f"{lb}_fft_freq_Hz", f"{lb}_fft_{units}", f"{lb}_fft_{units}_std",
                     f"{lb}_wave_Vrms", f"{lb}_wave_Vrms_std"]
    return (["point_id", "iso_time", "unix_time_s",
             "x_cmd_mm", "y_cmd_mm", "z_cmd_mm", "angle_cmd_deg",
             "x_mm", "y_mm", "z_mm", "angle_deg", "tilt_deg"]
            + per_freq
            + ["pos_err_mm", "angle_err_deg", "pos_drift_mm", "move_time_s", "n_acq",
               "led_freq_Hz", "fft_units", "wave_fs_Sa_s", "wave_points", "wave_mean_V",
               "wave_vpp_V", "wave_ac_rms_V", "fft_file", "wave_file"])


def save_point(scope, session_dir, freqs_hz, pid, target, angle, tel_before, tel_after,
               t_move, acqs):
    pos = [float(v) for v in np.mean([tel_before["pos"], tel_after["pos"]], axis=0)]
    ang = 0.5 * (tel_before["angle"] + tel_after["angle"])
    units = scope.fft_units
    feats = frequency_features(acqs, freqs_hz, scope.led_band)
    v_all = np.concatenate([a["v"] for a in acqs])
    tag = f"p{pid:04d}"

    header = [f"point_id: {pid}", f"x_mm: {pos[0]:.3f}", f"y_mm: {pos[1]:.3f}",
              f"z_mm: {pos[2]:.3f}", f"angle_deg: {ang:.4f}", f"fft_units: {units}"]
    header += [f"acq_{i + 1}_unix_time_s: {a['unix']:.6f}" for i, a in enumerate(acqs)]
    n_f = min(a["fft"].size for a in acqs)
    cols = np.column_stack([acqs[0]["f"][:n_f]] + [a["fft"][:n_f] for a in acqs])
    names = ",".join(["frequency_Hz"] + [f"acq_{i + 1}" for i in range(len(acqs))])
    fft_file = f"{tag}_fft.csv"
    np.savetxt(os.path.join(session_dir, fft_file), cols, delimiter=",", fmt="%.6e",
               header="\n".join(header + [names]), comments="# ")

    wave_file = ""
    if SAVE_WAVEFORMS:
        n_t = min(a["v"].size for a in acqs)
        cols = np.column_stack([acqs[0]["t"][:n_t]] + [a["v"][:n_t] for a in acqs])
        names = ",".join(["time_s"] + [f"acq_{i + 1}_V" for i in range(len(acqs))])
        wave_file = f"{tag}_wave.csv"
        np.savetxt(os.path.join(session_dir, wave_file), cols, delimiter=",", fmt="%.6e",
                   header="\n".join(header + [f"fs_Sa_s: {acqs[0]['fs']:.9g}", names]),
                   comments="# ")

    row = {
        "point_id": pid, "iso_time": datetime.now().isoformat(timespec="seconds"),
        "unix_time_s": f"{acqs[0]['unix']:.3f}",
        "x_cmd_mm": round(target[0], 3), "y_cmd_mm": round(target[1], 3),
        "z_cmd_mm": round(target[2], 3), "angle_cmd_deg": round(angle, 4),
        "x_mm": round(pos[0], 3), "y_mm": round(pos[1], 3), "z_mm": round(pos[2], 3),
        "angle_deg": round(ang, 4), "tilt_deg": round(tel_after["tilt"], 4),
        "pos_err_mm": round(math.dist(pos, target), 3),
        "angle_err_deg": round(wrap180(ang - angle), 4),
        "pos_drift_mm": round(math.dist(tel_before["pos"], tel_after["pos"]), 3),
        "move_time_s": round(t_move, 2), "n_acq": len(acqs),
        "led_freq_Hz": scope.led_frequency(), "fft_units": units,
        "wave_fs_Sa_s": f"{acqs[0]['fs']:.6g}", "wave_points": acqs[0]["v"].size,
        "wave_mean_V": round(float(v_all.mean()), 6), "wave_vpp_V": round(float(np.ptp(v_all)), 6),
        "wave_ac_rms_V": round(float(np.std(v_all)), 6),
        "fft_file": fft_file, "wave_file": wave_file,
    }
    for ft in feats:
        lb = freq_label(ft["freq_Hz"])
        row.update({f"{lb}_fft_freq_Hz": round(ft["fft_freq_Hz"], 3),
                    f"{lb}_fft_{units}": f"{ft['fft_mean']:.6g}",
                    f"{lb}_fft_{units}_std": f"{ft['fft_std']:.3g}",
                    f"{lb}_wave_Vrms": f"{ft['vrms_mean']:.6g}",
                    f"{lb}_wave_Vrms_std": f"{ft['vrms_std']:.3g}"})

    path = os.path.join(session_dir, "points.csv")
    new = not os.path.exists(path)
    with open(path, "a", newline="") as f:
        w = csv.DictWriter(f, fieldnames=point_fields(freqs_hz, units))
        if new:
            w.writeheader()
        w.writerow(row)
    return row, feats


# ============================================================
# INTERFAZ
# ============================================================

class GUI:
    def __init__(self, tb, freqs_hz):
        self.tb = tb
        self.freqs = freqs_hz
        self.units = tb.scope.fft_units
        self.trail = []
        self.fft_limits = None
        self.background = None

        self.fig = fig = plt.figure("Experiment 01 - point-by-point acquisition", figsize=(15, 9))
        wmin, wmax = tb.gantry.workspace_min, tb.gantry.workspace_max

        # --- XY: origen abajo-derecha; X hacia arriba, Y hacia la izquierda ---
        ax = self.ax_xy = fig.add_axes([0.04, 0.43, 0.36, 0.52])
        ax.set_xlim(wmax[1], wmin[1])                 # Y crece hacia la izquierda
        ax.set_ylim(wmin[0], wmax[0])                 # X crece hacia arriba
        ax.set_aspect("equal", adjustable="box")
        ax.yaxis.tick_right()
        ax.yaxis.set_label_position("right")
        ax.set_xlabel("Y [mm]  (increases to the left)")
        ax.set_ylabel("X [mm]  (increases upwards)")
        ax.set_title("Gantry - top view")
        ax.grid(True, alpha=0.3)
        ax.annotate("", xy=(wmin[1], 0.18 * wmax[0]), xytext=(wmin[1], 0),
                    arrowprops=dict(arrowstyle="->", color="tab:red", lw=2))
        ax.annotate("", xy=(0.18 * wmax[1], wmin[0]), xytext=(wmin[1], wmin[0]),
                    arrowprops=dict(arrowstyle="->", color="tab:green", lw=2))
        ax.text(wmin[1] + 0.03 * wmax[1], 0.2 * wmax[0], "X", color="tab:red", fontweight="bold")
        ax.text(0.2 * wmax[1], wmin[0] + 0.03 * wmax[0], "Y", color="tab:green", fontweight="bold")
        self.points_sc = ax.scatter([], [], s=40, c="tab:purple", zorder=3)
        self.trail_ln, = ax.plot([], [], color="tab:blue", alpha=0.4, lw=1)
        self.target_mk, = ax.plot([], [], "x", color="tab:orange", ms=12, mew=2)
        self.pos_mk, = ax.plot([], [], "o", color="tab:blue", ms=10)

        # --- Z ---
        az = self.ax_z = fig.add_axes([0.48, 0.43, 0.025, 0.52])
        az.set_ylim(wmin[2], wmax[2])
        az.set_xlim(0, 1)
        az.set_xticks([])
        az.yaxis.tick_right()
        az.set_title("Z [mm]", fontsize=9)
        az.grid(True, axis="y", alpha=0.3)
        self.z_target_ln, = az.plot([0, 1], [np.nan, np.nan], "--", color="tab:orange", lw=2)
        self.z_ln, = az.plot([0, 1], [np.nan, np.nan], color="tab:blue", lw=4)

        # --- MTRS (polar) ---
        ap = self.ax_rot = fig.add_axes([0.565, 0.47, 0.21, 0.46], projection="polar")
        ap.set_theta_zero_location(tb.view.get("mtrs_zero_location", "N"))
        ap.set_theta_direction(-1 if tb.view.get("mtrs_clockwise", False) else 1)
        ap.set_ylim(0, 1.1)
        ap.set_yticklabels([])
        ap.set_title("MTRS - rotation (top view)", fontsize=10)
        self.rot_target_ln, = ap.plot([0, 0], [0, 1], "--", color="tab:orange", lw=1.5)
        self.needle, = ap.plot([0, 0], [0, 0.95], color="tab:blue", lw=5, solid_capstyle="round")

        # --- Panel de informacion ---
        self.info_txt = fig.text(0.795, 0.93, "", family="monospace", fontsize=9, va="top")

        # --- FFT ---
        af = self.ax_fft = fig.add_axes([0.05, 0.145, 0.9, 0.225])
        af.set_xlabel("Frequency [Hz]")
        af.set_ylabel(f"Scope FFT [{self.units}]")
        af.grid(True, alpha=0.3)
        for f0 in self.freqs:
            af.axvline(f0, color="tab:red", ls=":", lw=1)
        if self.freqs:
            af.plot([], [], color="tab:red", ls=":", label="studied frequencies")
            af.legend(loc="upper right", fontsize=8)
        self.fft_ln, = af.plot([], [], lw=1)
        self.peak_mk, = af.plot([], [], "v", color="tab:red", ms=8)

        # --- Controles ---
        tel = get_tel()
        init = [*(f"{v:.1f}" for v in tel["pos"]), f"{tel['angle']:.2f}"]
        self.boxes = []
        for i, (label, val) in enumerate(zip(("X [mm]", "Y [mm]", "Z [mm]", "Rot [deg]"), init)):
            box = TextBox(fig.add_axes([0.08 + 0.13 * i, 0.025, 0.07, 0.045]), label, initial=val)
            self.boxes.append(box)
        self.btn_go = Button(fig.add_axes([0.61, 0.02, 0.11, 0.055]), "Go & measure", color="#cde8cd")
        self.btn_here = Button(fig.add_axes([0.73, 0.02, 0.10, 0.055]), "Measure here")
        self.btn_stop = Button(fig.add_axes([0.85, 0.02, 0.10, 0.055]), "STOP",
                               color="#f4a0a0", hovercolor="#ff6060")
        self.btn_go.on_clicked(self.on_go)
        self.btn_here.on_clicked(self.on_here)
        self.btn_stop.on_clicked(self.on_stop)
        self.status_txt = fig.text(0.05, 0.08, "", fontsize=10, color="tab:blue")

        self.animated = [self.trail_ln, self.target_mk, self.pos_mk, self.z_target_ln, self.z_ln,
                         self.rot_target_ln, self.needle, self.info_txt, self.fft_ln,
                         self.peak_mk, self.status_txt]
        for a in self.animated:
            a.set_animated(True)
        fig.canvas.mpl_connect("draw_event", self.on_draw)
        fig.canvas.mpl_connect("close_event", lambda _e: shutdown.set())
        self.timer = fig.canvas.new_timer(interval=GUI_REFRESH_MS)
        self.timer.add_callback(self.update)
        self.timer.start()

    # ---------------------------------------------------------------
    def busy(self):
        state, = S.get("state")
        return state != "IDLE"

    def on_go(self, _event):
        if self.busy():
            S.set(status="Busy: wait for the current point to finish (or press STOP).")
            return
        try:
            x, y, z, ang = (float(b.text.replace(",", ".")) for b in self.boxes)
        except ValueError:
            S.set(status="Invalid values: enter numbers for X, Y, Z and rotation.")
            return
        self.trail = []
        S.set(state="MOVING")
        jobs.put({"target": (x, y, z), "angle": ang})

    def on_here(self, _event):
        if self.busy():
            S.set(status="Busy.")
            return
        S.set(state="SETTLING")
        jobs.put({})

    def on_stop(self, _event):
        stop_event.set()
        threading.Thread(target=self.tb.stop, daemon=True).start()
        S.set(status="STOP sent.")

    # ---------------------------------------------------------------
    def on_draw(self, _event):
        self.background = self.fig.canvas.copy_from_bbox(self.fig.bbox)
        for a in self.animated:
            self.fig.draw_artist(a)

    def update(self):
        if shutdown.is_set():
            return
        tel, fft, fps, state, status, target, pid, last = S.get(
            "tel", "fft", "fft_fps", "state", "status", "target", "point_id", "last_summary")
        full_redraw = False

        while not S.gui_events.empty():
            kind, data = S.gui_events.get()
            if kind == "point":
                offs = self.points_sc.get_offsets().tolist() + [[data["y_mm"], data["x_mm"]]]
                self.points_sc.set_offsets(offs)
                self.ax_xy.annotate(str(data["point_id"]), (data["y_mm"], data["x_mm"]),
                                    xytext=(4, 4), textcoords="offset points", fontsize=8)
                full_redraw = True

        if tel is not None:
            x, y, z = tel["pos"]
            if state == "MOVING":
                self.trail.append((y, x))
            self.pos_mk.set_data([y], [x])
            if self.trail:
                ty, tx = zip(*self.trail)
                self.trail_ln.set_data(ty, tx)
            self.z_ln.set_ydata([z, z])
            a = math.radians(tel["angle"])
            self.needle.set_data([a, a], [0, 0.95])
        if target is not None:
            self.target_mk.set_data([target[1]], [target[0]])
            self.z_target_ln.set_ydata([target[2], target[2]])
            ta = math.radians(target[3])
            self.rot_target_ln.set_data([ta, ta], [0, 1.0])

        live = []
        if fft is not None and fft["f"].size:
            f, yv = fft["f"], fft["y"]
            limits = (float(f[0]), float(f[-1]), *fft["ylim"])
            if limits != self.fft_limits:
                self.fft_limits = limits
                self.ax_fft.set_xlim(limits[0], limits[1])
                self.ax_fft.set_ylim(limits[2], limits[3])
                full_redraw = True
            self.fft_ln.set_data(f, yv)
            peaks = [fft_peak(f, yv, f0, self.tb.scope.led_band, fallback_global=False)
                     for f0 in self.freqs]
            self.peak_mk.set_data([p[0] for p in peaks], [p[1] for p in peaks])
            live = [f"  {freq_label(f0):>9}: {p[1]:.4g} {self.units}" if not math.isnan(p[1])
                    else f"  {freq_label(f0):>9}: outside span"
                    for f0, p in zip(self.freqs, peaks)]
            live.append(f"  ({fps:4.1f} FFT/s)")

        lines = [f"State  : {state}", f"Points : {pid}", ""]
        if tel is not None:
            lines += [
                "Gantry",
                f"  X = {tel['pos'][0]:8.2f} mm", f"  Y = {tel['pos'][1]:8.2f} mm",
                f"  Z = {tel['pos'][2]:8.2f} mm", f"  v = {tel['speed']:8.2f} mm/s",
                f"  {tel['kin']} / {tel['axes_error']}", "",
                "MTRS",
                f"  rot  = {tel['angle']:8.3f} deg", f"  tilt = {tel['tilt']:8.3f} deg",
                f"  {'MOVING' if tel['mtrs_moving'] else 'still'}", "",
            ]
        if target is not None:
            lines += ["Target", f"  X={target[0]:.1f} Y={target[1]:.1f} Z={target[2]:.1f}",
                      f"  rot={target[3]:.2f} deg", ""]
        lines += ["Scope FFT (live)"] + (live or ["  -"])
        if last is not None:
            lines += ["", f"Last point #{last['point_id']} (FFT | wave)"]
            for ft in last["features"]:
                fft_txt = "n/a" if math.isnan(ft["fft_mean"]) else f"{ft['fft_mean']:.4g} {self.units}"
                lines.append(f"  {freq_label(ft['freq_Hz']):>9}: {fft_txt} | "
                             f"{ft['vrms_mean'] * 1e3:.3f} mVrms")
        self.info_txt.set_text("\n".join(lines))
        self.status_txt.set_text(status)
        self.status_txt.set_color("tab:red" if status.startswith(("ERROR", "STOP")) else "tab:blue")

        canvas = self.fig.canvas
        if full_redraw or self.background is None:
            canvas.draw()
        else:
            canvas.restore_region(self.background)
            for a in self.animated:
                self.fig.draw_artist(a)
            canvas.blit(self.fig.bbox)
        canvas.flush_events()


# ============================================================
# PROGRAMA PRINCIPAL
# ============================================================

def experiment_params():
    return {k: v for k, v in globals().items()
            if k.isupper() and isinstance(v, (int, float, str, tuple, list, dict))
            and k != "TRAJ_FIELDS"}


def main():
    tb = Testbed(modes=DEVICE_MODE_OVERRIDE)
    threads = []
    try:
        tb.connect()
        freqs_hz = [f * 1e3 for f in FREQUENCIES_KHZ] or [tb.scope.led_frequency()]
        if None in freqs_hz:
            raise ValueError("FREQUENCIES_KHZ is empty and the config has no LED frequency.")
        center, span = tb.scope.info.get("fft_center_Hz"), tb.scope.info.get("fft_span_Hz")
        if center is not None and span is not None:
            for f0 in freqs_hz:
                if abs(f0 - center) > span / 2:
                    print(f"[exp01] WARNING: {freq_label(f0)} is outside the scope FFT span "
                          f"({(center - span / 2) / 1e3:g}-{(center + span / 2) / 1e3:g} kHz); "
                          f"its FFT columns will be NaN.")
        print(f"[exp01] Studied frequencies: {[freq_label(f) for f in freqs_hz]}")

        session_dir = os.path.join(OUTPUT_ROOT, f"exp01_{datetime.now():%Y%m%d_%H%M%S}")
        os.makedirs(session_dir, exist_ok=True)
        with open(os.path.join(session_dir, "session.json"), "w") as f:
            json.dump({"start": datetime.now().isoformat(), "experiment": experiment_params(),
                       "frequencies_Hz": freqs_hz, "led_freq_Hz": tb.scope.led_frequency(),
                       "testbed": tb.info()}, f, indent=2, default=str)
        print(f"[exp01] Session: {session_dir}")

        threads = [
            threading.Thread(target=telemetry_loop, daemon=True,
                             args=(tb, os.path.join(session_dir, "trajectory.csv"))),
            threading.Thread(target=scope_loop, args=(tb.scope,), daemon=True),
            threading.Thread(target=worker_loop, args=(tb, session_dir, freqs_hz), daemon=True),
        ]
        for t in threads:
            t.start()
        while get_tel() is None:
            time.sleep(0.05)
        S.set(state="IDLE", status="Ready. Enter X, Y, Z and rotation, then press 'Go & measure'.")

        gui = GUI(tb, freqs_hz)
        plt.show()
        gui.timer.stop()

    except KeyboardInterrupt:
        print("\n[exp01] Interrupted.")
    finally:
        shutdown.set()
        stop_event.set()
        for t in threads:
            t.join(timeout=10)
        tb.close()


if __name__ == "__main__":
    main()
