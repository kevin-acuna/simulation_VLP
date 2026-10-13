"""
exp03_frequency_response.py - Respuesta en frecuencia del enlace LED -> PD.

El PD se coloca en una posicion (x, y, z) escrita en consola y se deja encendido un solo LED,
alimentado por el generador interno (WGEN) del osciloscopio. Se barre su frecuencia y, para cada f,
se mide la amplitud del pico de la FFT en f [mVrms]. Al terminar se guarda el .csv (f vs amplitud)
y se dibuja la curva.

Ejecutar:
    python testbed_dev/experiments/exp03_FrecuencyResponse/exp03_frequency_response.py
    ... --sim                (todo simulado, para probar)   --pos 700 700 -300  (sin preguntar)
    ... --no-show            (guarda la grafica sin abrir la ventana)

Usa los drivers y config/testbed.toml de ../../database_acquisition (osciloscopio por LAN,
capturas con :DIGitize). Apagar los demas LEDs antes de empezar.
"""

import argparse
import csv
import json
import os
import sys
import time
from datetime import datetime

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))                         # CAMBRIDGE/testbed_dev
REPO = os.path.join(os.path.dirname(ROOT), "database_acquisition")    # drivers + config/testbed.toml
sys.path.insert(0, REPO)

from hardware.scope import clipped_fraction, fft_peak, spectrum_vrms   # noqa: E402
from hardware.sim import SimScope                                     # noqa: E402
from hardware.testbed import Testbed                                  # noqa: E402


# ============================================================
# HIPERPARAMETROS DEL EXPERIMENTO
# (los de los equipos estan en database_acquisition/config/testbed.toml)
# ============================================================

F_START_HZ = 5e3                 # primera frecuencia del barrido
F_STOP_HZ = 1e6                  # ultima frecuencia (incluida si cae en el paso)
F_STEP_HZ = 5e3                  # paso entre frecuencias

RECORD_MS = 20.0                 # registro continuo por muestra [ms] (resolucion FFT = 1/T = 50 Hz)
SAMPLE_RATE_MSA = 10.0           # frecuencia de muestreo [MSa/s] (>= 4 x F_STOP_HZ recomendado)
N_SAMPLES = 3                    # capturas por frecuencia (se promedia el pico)
SETTLE_S = 0.2                   # espera tras cambiar la frecuencia, antes de medir
FFT_BAND_HZ = 200.0              # el pico se busca en f +/- esta banda (minimo 1.5 bins)

# Generador que alimenta el LED: por defecto el WGEN del propio osciloscopio de medida.
WGEN_FREQ_CMD = ":WGEN:FREQuency {f:.6E}"
WGEN_FREQ_QUERY = ":WGEN:FREQuency?"

DEVICE_MODE_OVERRIDE = {}        # p.ej. {"gantry": "sim"}; vacio = modos de la config
SHOW_PLOT = True                 # abrir la grafica al terminar (siempre se guarda el .png)
OUTPUT_ROOT = os.path.join(ROOT, "data", "exp03")


# ============================================================

def ask_position(tb):
    """Pide X Y Z [mm] por consola. Enter = quedarse en la posicion actual."""
    cur = tb.gantry.state()["pos"]
    print(f"\nCurrent PD position: X={cur[0]:.1f}  Y={cur[1]:.1f}  Z={cur[2]:.1f} mm")
    while True:
        txt = input("Target position 'X Y Z' in mm (Enter = stay here): ").replace(",", " ").split()
        if not txt:
            return None
        try:
            xyz = tuple(float(v) for v in txt)
            if len(xyz) != 3:
                raise ValueError
        except ValueError:
            print("  Write three numbers, e.g. 700 700 -300")
            continue
        problems = tb.check_pose(xyz)
        if problems:
            print("  Not allowed:", "; ".join(problems))
            continue
        return xyz


def set_led_frequency(sc, f):
    """Pone el LED a f [Hz] y devuelve la frecuencia aplicada por el generador."""
    if isinstance(sc, SimScope):                       # simulado: un solo LED a f
        sc.LEDS = ((f, SimScope.LEDS[0][1]),)
        return f
    sc.inst.write(WGEN_FREQ_CMD.format(f=f))
    sc.inst.query("*OPC?")
    return float(sc.inst.query(WGEN_FREQ_QUERY))


def measure(sc, f):
    """Amplitud [Vrms] del pico de la FFT en f (media y std de N_SAMPLES) y fraccion saturada."""
    for attempt in range(3):
        try:
            acqs = sc.record(N_SAMPLES, 8_000_000, scope_fft=False)
            break
        except Exception as e:
            if attempt == 2:
                raise
            print(f"  WARNING: acquisition error ({e}); reconnecting and retrying...")
            if not sc.recover():
                raise RuntimeError(sc.DEAD_HINT) from e
            sc.configure_record(RECORD_MS * 1e-3, SAMPLE_RATE_MSA * 1e6)
            sc.set_fft_display(False)
    peaks = []
    for a in acqs:
        fr, y = spectrum_vrms(a["v"], a["fs"])                 # FFT Hanning del registro completo
        peaks.append(fft_peak(fr, y, f, FFT_BAND_HZ, fallback_global=False)[1])
    low, high = sc.channel_limits()
    clip = max(clipped_fraction(a["v"], low, high) for a in acqs)
    return float(np.mean(peaks)), float(np.std(peaks)), clip


def plot(freqs_hz, amps_mv, title, path, show):
    import matplotlib
    if not show:
        matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.plot(np.asarray(freqs_hz) / 1e3, amps_mv, ".-", lw=1, ms=4)
    ax.set_xlabel("Frequency [kHz]")
    ax.set_ylabel("FFT amplitude [mVrms]")
    ax.set_title(title, fontsize=10)
    ax.set_ylim(bottom=0)
    ax.grid(True, alpha=0.4)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    print(f"[exp03] Plot saved: {path}")
    if show:
        plt.show()


def main():
    ap = argparse.ArgumentParser(description="Frequency response of the LED -> PD link.")
    ap.add_argument("--sim", action="store_true", help="simulate every device")
    ap.add_argument("--pos", nargs=3, type=float, metavar=("X", "Y", "Z"), help="PD position [mm] (no prompt)")
    ap.add_argument("--no-show", action="store_true", help="save the plot without opening it")
    args = ap.parse_args()

    modes = dict(DEVICE_MODE_OVERRIDE)
    if args.sim:
        modes.update(gantry="sim", scope="sim")
    freqs = np.arange(F_START_HZ, F_STOP_HZ + F_STEP_HZ / 2, F_STEP_HZ)
    fs = SAMPLE_RATE_MSA * 1e6
    if freqs.max() >= fs / 2:
        sys.exit(f"[exp03] {freqs.max() / 1e3:g} kHz is above Nyquist ({fs / 2e3:g} kHz): raise SAMPLE_RATE_MSA.")
    if freqs.max() > fs / 4:
        print(f"[exp03] WARNING: {SAMPLE_RATE_MSA:g} MSa/s is less than 4x the highest frequency.")

    tb = Testbed(devices=("gantry", "scope"), modes=modes)
    sc = tb.scope
    f_orig = fft_shown = pos = None
    out_dir = None
    rows = []
    try:
        tb.connect()
        xyz = tuple(args.pos) if args.pos else ask_position(tb)
        if xyz is not None:
            print(f"[exp03] Moving the PD to X={xyz[0]:g} Y={xyz[1]:g} Z={xyz[2]:g} mm ...")
            tb.go_to_pose(xyz)
        pos = tb.gantry.state()["pos"]

        if not isinstance(sc, SimScope):
            f_orig = float(sc.inst.query(WGEN_FREQ_QUERY))
            if sc.inst.query(":WGEN:OUTPut?").strip() not in ("1", "ON"):
                print("[exp03] WARNING: the WGEN output is OFF: the LED will not be modulated.")
        print("[exp03] Make sure that ONLY the LED driven by the generator is on.")
        sc.configure_record(RECORD_MS * 1e-3, fs)
        fft_shown = sc.fft_displayed()
        sc.set_fft_display(False)

        out_dir = os.path.join(OUTPUT_ROOT, f"exp03_{datetime.now():%Y%m%d_%H%M%S}")
        os.makedirs(out_dir, exist_ok=True)
        csv_path = os.path.join(out_dir, "frequency_response.csv")
        print(f"[exp03] Sweep: {len(freqs)} frequencies, {F_START_HZ / 1e3:g}-{freqs.max() / 1e3:g} kHz, "
              f"step {F_STEP_HZ / 1e3:g} kHz, {N_SAMPLES} x {RECORD_MS:g} ms per frequency -> {out_dir}")

        t0 = time.perf_counter()
        with open(csv_path, "w", newline="") as fcsv:
            w = csv.writer(fcsv)
            w.writerow(["frequency_Hz", "amplitude_mVrms"])
            for n, f in enumerate(freqs, 1):
                f_set = set_led_frequency(sc, float(f))
                time.sleep(SETTLE_S)
                amp, std, clip = measure(sc, f_set)
                rows.append((f_set, amp * 1e3, std * 1e3))
                w.writerow([f"{f_set:.1f}", f"{amp * 1e3:.6g}"])
                fcsv.flush()
                eta = (time.perf_counter() - t0) / n * (len(freqs) - n)
                print(f"  [{n:4d}/{len(freqs)}] {f_set / 1e3:8.1f} kHz  {amp * 1e3:9.4f} mVrms"
                      f"  (std {std * 1e3:.4f})  ETA {eta / 60:4.1f} min"
                      + (f"  WARNING: {clip:.1%} clipped" if clip > 0.001 else ""))
        print(f"[exp03] Done in {(time.perf_counter() - t0) / 60:.1f} min. Data: {csv_path}")
    except KeyboardInterrupt:
        print("\n[exp03] Ctrl+C: stopping (the points measured so far are kept).")
        tb.stop()
    finally:
        try:
            if f_orig is not None and sc.alive:
                sc.inst.write(WGEN_FREQ_CMD.format(f=f_orig))
                print(f"[exp03] Generator frequency restored to {f_orig / 1e3:g} kHz.")
            if sc.alive:
                sc.restore_record()
                if fft_shown:
                    sc.set_fft_display(True)
        except Exception as e:
            print(f"[exp03] WARNING: could not restore the oscilloscope: {e}")
        if out_dir:
            with open(os.path.join(out_dir, "session.json"), "w") as fj:
                json.dump({"position_mm": pos,
                           "frequencies": {"start_Hz": F_START_HZ, "stop_Hz": F_STOP_HZ, "step_Hz": F_STEP_HZ},
                           "record_ms": RECORD_MS, "sample_rate_MSa_s": SAMPLE_RATE_MSA, "n_samples": N_SAMPLES,
                           "settle_s": SETTLE_S, "fft_band_Hz": FFT_BAND_HZ,
                           "amplitude": "peak of the Python FFT (Hanning, whole record) near f, mean of n_samples [mVrms]",
                           "generator_frequency_before_Hz": f_orig, "n_points": len(rows),
                           "std_mVrms": [r[2] for r in rows], "scope": sc.info,
                           "modes": tb.modes}, fj, indent=2, default=str)
        tb.close()

    if rows:
        f_hz, a_mv = [r[0] for r in rows], [r[1] for r in rows]
        plot(f_hz, a_mv, f"Frequency response - PD at X={pos[0]:.0f} Y={pos[1]:.0f} Z={pos[2]:.0f} mm, "
                         f"{N_SAMPLES} x {RECORD_MS:g} ms per point",
             os.path.join(out_dir, "frequency_response.png"), SHOW_PLOT and not args.no_show)


if __name__ == "__main__":
    main()
