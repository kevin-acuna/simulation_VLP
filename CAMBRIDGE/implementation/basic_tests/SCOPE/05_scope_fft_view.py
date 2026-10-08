"""
05_scope_fft_view.py

Lee y muestra en vivo la FFT CALCULADA POR EL OSCILOSCOPIO (funcion Math FFT),
sin procesar en Python la senal de voltaje del canal.

  :FUNCtion<m>:OPERation FFT     -> la FFT es una funcion Math (m = 1..4)
  :WAVeform:SOURce FUNCtion<m>   -> se descarga la traza de esa funcion
  preamble: XORigin = frecuencia inicial [Hz], XINCrement = ancho de bin [Hz]
            Y en dB (VTYPe = DEC) o en V rms (VTYPe = VRMS), igual que en pantalla

Antes de ejecutar: activa en el osciloscopio Math -> FFT sobre el canal del PD
(o pon CONFIGURE_FFT = True). Tecla 's' en la ventana: guarda la traza actual en CSV.
Cerrar la ventana (o Ctrl+C) para terminar.
"""

import os
import time
from datetime import datetime

import matplotlib.pyplot as plt
import numpy as np

from scope_common import (
    connect, read_errors, read_waveform, restore_settings, save_settings,
)


# ============================================================
# HIPERPARAMETROS
# ============================================================

VISA_ADDRESS = "USB0::0x0957::0x17BC::MY64080105::0::INSTR"   # MSO-X 4154A del laboratorio
MATH_FUNCTION = None             # None -> la primera funcion Math con FFT activa; o 1..4

# Modo de lectura:
#   "running"  -> lee la FFT mientras el osciloscopio sigue en RUN (la pantalla sigue viva)
#   "digitize" -> cada cuadro hace una adquisicion completa (:DIGitize) y lee la FFT de
#                 esa adquisicion exacta (sincronizado; la pantalla se congela entre cuadros)
READ_MODE = "running"
POINTS = "MAX"                   # puntos de la traza FFT a descargar ("MAX" o entero)
REFRESH_PAUSE_S = 0.05           # pausa entre lecturas
Y_LIMITS = "scope"               # "scope": misma escala vertical que la pantalla ; "auto"
PEAK_MIN_HZ = 1.0                # ignorar bins por debajo (DC) al buscar el pico

# False -> usa la FFT tal como esta configurada en el panel frontal.
# True  -> configura la funcion MATH_FUNCTION (o 1) con estos valores:
CONFIGURE_FFT = False
SOURCE_CHANNEL = 1               # canal de entrada de la FFT (PDA100A2)
FFT_SPAN_HZ = 10e3               # ancho del eje de frecuencia mostrado
FFT_CENTER_HZ = 5e3              # frecuencia central
FFT_WINDOW = "HANNing"           # RECTangular | HANNing | FLATtop | BHARris | BARTlett
FFT_VTYPE = "DECibel"            # DECibel (dB) | VRMS (lineal)

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")


# ============================================================
# UTILIDADES
# ============================================================

def find_fft_function(scope):
    for m in range(1, 5):
        try:
            op = scope.query(f":FUNCtion{m}:OPERation?").strip().upper()
            shown = scope.query(f":FUNCtion{m}:DISPlay?").strip() in ("1", "ON")
        except Exception:
            break
        if op == "FFT" and shown:
            return m
    read_errors(scope)
    raise RuntimeError(
        "No hay ninguna funcion Math con FFT visible. Activala en el osciloscopio "
        "(Math -> Operator: FFT) o usa CONFIGURE_FFT = True."
    )


def fft_settings(scope, m):
    f = f":FUNCtion{m}"
    q = lambda cmd: scope.query(f"{f}{cmd}").strip()
    s = {
        "function": m,
        "operation": q(":OPERation?"),
        "source": q(":SOURce1?"),
        "vtype": q(":FFT:VTYPe?"),
        "window": q(":FFT:WINDow?"),
        "center_Hz": float(q(":FFT:CENTer?")),
        "span_Hz": float(q(":FFT:SPAN?")),
        "scale_per_div": float(q(":SCALe?")),
        "offset": float(q(":OFFSet?")),
    }
    timeout, scope.timeout = scope.timeout, 2000     # consultas opcionales (segun firmware)
    for key, cmd in (("rbw_Hz", ":FFT:RBWidth?"), ("bin_Hz", ":FFT:BSIZe?"),
                     ("fft_srate_Sa_s", ":FFT:SRATe?")):
        try:
            s[key] = float(q(cmd))
        except Exception:
            s[key] = float("nan")
    scope.timeout = timeout
    read_errors(scope)
    s["units"] = "dB" if s["vtype"].upper().startswith("DEC") else "V rms"
    return s


# ============================================================
# PROGRAMA
# ============================================================

rm, scope, idn = connect(VISA_ADDRESS)
saved = save_settings(scope, [":TRIGger:SWEep"])

try:
    if CONFIGURE_FFT:
        m = MATH_FUNCTION or 1
        f = f":FUNCtion{m}"
        scope.write(f"{f}:OPERation FFT")
        scope.write(f"{f}:SOURce1 CHANnel{SOURCE_CHANNEL}")
        scope.write(f"{f}:FFT:WINDow {FFT_WINDOW}")
        scope.write(f"{f}:FFT:VTYPe {FFT_VTYPE}")
        scope.write(f"{f}:FFT:SPAN {FFT_SPAN_HZ}")
        scope.write(f"{f}:FFT:CENTer {FFT_CENTER_HZ}")
        scope.write(f"{f}:DISPlay 1")
        time.sleep(0.5)
    else:
        m = MATH_FUNCTION or find_fft_function(scope)

    if READ_MODE == "digitize":
        scope.write(":TRIGger:SWEep AUTO")

    scope.write(f":WAVeform:SOURce FUNCtion{m}")
    scope.write(":WAVeform:FORMat WORD")
    scope.write(":WAVeform:BYTeorder LSBFirst")
    scope.write(":WAVeform:UNSigned 1")
    scope.write(":WAVeform:POINts:MODE NORMal")
    scope.write(f":WAVeform:POINts {POINTS}")
    errors = read_errors(scope)
    if errors:
        print(f"Errores de configuracion: {errors}")

    cfg = fft_settings(scope, m)
    print(f"\nFFT del osciloscopio: FUNCtion{m}")
    for k, v in cfg.items():
        print(f"  {k:<15} {v}")

    plt.ion()
    fig, ax = plt.subplots(figsize=(11, 5.5), num="MSO-X 4154A - FFT del osciloscopio")
    line, = ax.plot([], [], lw=1)
    peak_marker, = ax.plot([], [], "v", color="red", ms=9)
    ax.set_xlabel("Frecuencia [Hz]")
    ax.set_ylabel(f"FFT [{cfg['units']}]")
    ax.grid(True, alpha=0.4)
    ax.set_title(" ", fontsize=10)
    fig.tight_layout()

    current = {}

    def on_key(event):
        if event.key != "s" or not current:
            return
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        path = os.path.join(OUTPUT_DIR, f"scope_fft_F{m}_{datetime.now():%Y%m%d_%H%M%S}.csv")
        header = "\n".join(
            [f"instrument: {idn}", f"unix_time_s: {current['unix']:.6f}", f"read_mode: {READ_MODE}"]
            + [f"{k}: {v}" for k, v in cfg.items()]
            + [f"preamble_{k}: {v:.9g}" for k, v in current["pre"].items()]
            + [f"frequency_Hz,fft_{cfg['units'].replace(' ', '_')}"]
        )
        np.savetxt(path, np.column_stack([current["f"], current["y"]]), delimiter=",",
                   fmt=["%.6f", "%.6e"], header=header, comments="# ")
        print(f"\nGuardado: {path}")

    fig.canvas.mpl_connect("key_press_event", on_key)

    t_last = time.perf_counter()
    first = True
    while plt.fignum_exists(fig.number):
        if READ_MODE == "digitize":
            scope.write(":DIGitize")
            scope.query("*OPC?")
        freq, y, pre = read_waveform(scope)
        current.update(f=freq, y=y, pre=pre, unix=time.time())

        if first:
            print(f"\nPrimera traza: {y.size} puntos, {freq[0]:.3f} .. {freq[-1]:.3f} Hz, "
                  f"bin = {pre['xincrement']:.4g} Hz")
            first = False

        valid = freq >= PEAK_MIN_HZ
        k = int(np.argmax(np.where(valid, y, -np.inf)))
        now = time.perf_counter()
        fps, t_last = 1.0 / (now - t_last), now

        line.set_data(freq, y)
        peak_marker.set_data([freq[k]], [y[k]])
        ax.set_xlim(freq[0], freq[-1])
        if Y_LIMITS == "scope":
            scale = float(scope.query(f":FUNCtion{m}:SCALe?"))
            offset = float(scope.query(f":FUNCtion{m}:OFFSet?"))
            ax.set_ylim(offset - 4 * scale, offset + 4 * scale)
        else:
            ax.relim()
            ax.autoscale_view(scalex=False)
        ax.set_title(
            f"FUNC{m} ({cfg['source']}, ventana {cfg['window']})   "
            f"pico = {y[k]:.2f} {cfg['units']} @ {freq[k]:.2f} Hz   "
            f"bin = {pre['xincrement']:.3g} Hz   {fps:.1f} fps   ('s' = guardar CSV)",
            fontsize=10,
        )
        fig.canvas.draw_idle()
        plt.pause(REFRESH_PAUSE_S)

except KeyboardInterrupt:
    print("\nInterrumpido por el usuario.")

finally:
    restore_settings(scope, saved)
    if READ_MODE == "digitize":
        scope.write(":RUN")
    scope.close()
    rm.close()
    print("Conexion cerrada.")
