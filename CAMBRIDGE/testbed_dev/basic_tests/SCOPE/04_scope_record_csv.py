"""
04_scope_record_csv.py

Registra DURATION_S segundos CONTINUOS de un canal del MSOX6004A en un .csv.

Se hace UNA sola adquisicion cuya ventana de tiempo es DURATION_S (la base de
tiempo se ajusta automaticamente), de modo que las muestras son contiguas y
equiespaciadas. La frecuencia de muestreo resultante la decide el
osciloscopio: Fs ~= puntos / DURATION_S (limitada por su memoria).

El .csv contiene una cabecera de metadatos (lineas con '#') y las columnas
time_s, voltage_V.
"""

import os
import time
from datetime import datetime

import numpy as np

from scope_common import (
    acquire, channel_settings, clipped_fraction, configure_channel, connect,
    read_errors, read_waveform, restore_settings, save_settings,
    screen_limits, setup_waveform, signal_metrics,
)


# ============================================================
# HIPERPARAMETROS
# ============================================================

VISA_ADDRESS = None              # None -> autodetectar por *IDN?
CHANNEL = 1                      # canal del osciloscopio conectado al PDA100A2
DURATION_S = 1.0                 # segundos de senal a registrar
POINTS = "MAX"                   # "MAX" o un entero (p.ej. 100000)
ACQ_TYPE = "HRESolution"         # "NORMal" | "HRESolution" (mas bits a Fs baja)

# False -> conserva la escala vertical del panel frontal.
CONFIGURE_VERTICAL = False
V_SCALE_V_DIV = 1.0              # escala vertical [V/div] (pantalla = 8 div)
V_OFFSET_V = 3.0                 # voltaje en el centro de la pantalla
COUPLING = "DC"                  # "DC" | "AC"
IMPEDANCE = "ONEMeg"             # "ONEMeg" (1 MOhm) | "FIFTy" (50 Ohm)
BW_LIMIT = False                 # filtro de 20 MHz

RESTORE_SETTINGS = True          # devolver base de tiempo/trigger/adquisicion al final
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
FILE_PREFIX = "scope"
NOTES = ""                       # texto libre que se guarda en la cabecera
PLOT_AFTER = True                # mostrar la senal registrada al terminar


# ============================================================
# PROGRAMA
# ============================================================

rm, scope, idn = connect(VISA_ADDRESS, timeout_ms=int((DURATION_S + 60) * 1000))
saved = save_settings(scope, [
    ":TIMebase:RANGe", ":TIMebase:REFerence", ":TIMebase:POSition",
    ":TRIGger:SWEep", ":ACQuire:TYPE",
])

try:
    if CONFIGURE_VERTICAL:
        configure_channel(scope, CHANNEL, V_SCALE_V_DIV, V_OFFSET_V,
                          COUPLING, IMPEDANCE, BW_LIMIT)
    scope.write(":TIMebase:MODE MAIN")
    scope.write(":TIMebase:REFerence LEFT")
    scope.write(":TIMebase:POSition 0")
    scope.write(f":TIMebase:RANGe {DURATION_S}")
    scope.write(":TRIGger:SWEep AUTO")
    scope.write(f":ACQuire:TYPE {ACQ_TYPE}")
    errors = read_errors(scope)
    if errors:
        print(f"Errores de configuracion: {errors}")

    print(f"\nRegistrando {DURATION_S} s de CH{CHANNEL}...")
    unix_start = time.time()
    acquire(scope, CHANNEL)
    unix_end = time.time()

    setup_waveform(scope, CHANNEL, POINTS, points_mode="RAW")
    print("Descargando datos...")
    t, v, pre = read_waveform(scope)
    fs = 1.0 / pre["xincrement"]
    low, high = screen_limits(scope, CHANNEL)
    clip = clipped_fraction(v, low, high)
    m = signal_metrics(t, v)
    ch = channel_settings(scope, CHANNEL)

    print(f"  {v.size} puntos   Fs = {fs:.6g} Sa/s   duracion = {t[-1] - t[0]:.6g} s")
    print(f"  media = {m['mean_V']:.4f} V   Vpp = {m['vpp_V']:.4f} V   "
          f"pico FFT = {m['amp_peak_V']:.4f} V @ {m['f_peak_Hz']:.2f} Hz")
    if clip > 0.001:
        print(f"  AVISO: {clip:.1%} de las muestras en el borde de pantalla (senal saturada).")

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    path = os.path.join(OUTPUT_DIR, f"{FILE_PREFIX}_CH{CHANNEL}_{datetime.now():%Y%m%d_%H%M%S}.csv")
    header = "\n".join([
        f"instrument: {idn}",
        f"channel: {CHANNEL}",
        f"unix_time_acq_start_s: {unix_start:.6f}",
        f"unix_time_acq_end_s: {unix_end:.6f}",
        f"duration_requested_s: {DURATION_S}",
        f"sample_rate_Sa_s: {fs:.9g}",
        f"points: {v.size}",
        f"acquire_type: {ACQ_TYPE}",
        *(f"channel_{k}: {val}" for k, val in ch.items()),
        *(f"preamble_{k}: {val:.9g}" for k, val in pre.items()),
        f"mean_V: {m['mean_V']:.6g}",
        f"vpp_V: {m['vpp_V']:.6g}",
        f"f_peak_Hz: {m['f_peak_Hz']:.6g}",
        f"amp_peak_V: {m['amp_peak_V']:.6g}",
        f"clipped_fraction: {clip:.6g}",
        f"notes: {NOTES}",
        "time_s,voltage_V",
    ])
    print(f"Guardando {path} ...")
    np.savetxt(path, np.column_stack([t - t[0], v]), delimiter=",",
               fmt=["%.10e", "%.6e"], header=header, comments="# ")
    print("Guardado.")

finally:
    if RESTORE_SETTINGS:
        restore_settings(scope, saved)
    scope.write(":RUN")
    scope.close()
    rm.close()
    print("Osciloscopio en RUN. Conexion cerrada.")

if PLOT_AFTER:
    import matplotlib.pyplot as plt

    step = max(1, v.size // 200000)      # diezmado solo para graficar
    fig, ax = plt.subplots(figsize=(10, 4), num="Registro MSOX6004A")
    ax.plot(t[::step] - t[0], v[::step], lw=0.6)
    ax.set_xlabel("t [s]")
    ax.set_ylabel(f"CH{CHANNEL} [V]")
    ax.set_title(f"{os.path.basename(path)}   Fs = {fs:.4g} Sa/s")
    ax.grid(True, alpha=0.4)
    fig.tight_layout()
    plt.show()
