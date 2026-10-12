"""
03_scope_live_view.py

Visor en tiempo real de un canal del MSOX6004A (PDA100A2).
  - Arriba: forma de onda actual.
  - Abajo: historia del nivel DC (media) y de la amplitud de la componente
    dominante (FFT). Al tapar el PD con la mano ambas deben caer.

Cerrar la ventana (o Ctrl+C) para terminar. El osciloscopio queda en RUN.
"""

import time

import matplotlib.pyplot as plt

from scope_common import (
    acquire, clipped_fraction, configure_channel, connect, read_errors,
    read_waveform, restore_settings, save_settings, screen_limits,
    setup_waveform, signal_metrics,
)


# ============================================================
# HIPERPARAMETROS
# ============================================================

VISA_ADDRESS = "USB0::0x0957::0x17BC::MY64080105::0::INSTR"         # EL OSCILOSCOPIO QUE TENEMOS
CHANNEL = 1                      # canal del osciloscopio conectado al PDA100A2
POINTS = 2000                    # puntos por captura (mas = mas lento)
HISTORY_S = 30.0                 # ventana de la grafica de historia

# False -> usa lo configurado en el panel frontal del osciloscopio.
# True  -> aplica los valores siguientes antes de empezar.
CONFIGURE_SCOPE = False
V_SCALE_V_DIV = 1.0              # escala vertical [V/div] (pantalla = 8 div)
V_OFFSET_V = 3.0                 # voltaje en el centro de la pantalla
COUPLING = "DC"                  # "DC": nivel + modulacion ; "AC": solo modulacion
IMPEDANCE = "ONEMeg"             # "ONEMeg" (1 MOhm) | "FIFTy" (50 Ohm)
BW_LIMIT = False                 # filtro de 20 MHz (reduce ruido)
TIMEBASE_S_DIV = 1e-3            # base de tiempo [s/div] (pantalla = 10 div)
ACQ_TYPE = "NORMal"              # "NORMal" | "HRESolution" | "AVERage"


# ============================================================
# PROGRAMA
# ============================================================

rm, scope, idn = connect(VISA_ADDRESS)
saved = save_settings(scope, [":TRIGger:SWEep"])

try:
    if CONFIGURE_SCOPE:
        configure_channel(scope, CHANNEL, V_SCALE_V_DIV, V_OFFSET_V,
                          COUPLING, IMPEDANCE, BW_LIMIT)
        scope.write(f":TIMebase:SCALe {TIMEBASE_S_DIV}")
        scope.write(f":ACQuire:TYPE {ACQ_TYPE}")
    scope.write(":TRIGger:SWEep AUTO")   # captura aunque no haya senal (mano encima)
    setup_waveform(scope, CHANNEL, POINTS)
    errors = read_errors(scope)
    if errors:
        print(f"Errores de configuracion: {errors}")

    plt.ion()
    fig, (ax_w, ax_h) = plt.subplots(2, 1, figsize=(10, 7), num="MSOX6004A - vista en vivo")
    line_w, = ax_w.plot([], [], lw=1)
    ax_w.set_xlabel("t [ms]")
    ax_w.set_ylabel(f"CH{CHANNEL} [V]")
    ax_w.grid(True, alpha=0.4)
    line_dc, = ax_h.plot([], [], label="media (DC)")
    line_ac, = ax_h.plot([], [], label="amplitud componente dominante")
    ax_h.set_xlabel("t [s]")
    ax_h.set_ylabel("[V]")
    ax_h.grid(True, alpha=0.4)
    ax_h.legend(loc="upper left")
    fig.tight_layout()

    hist_t, hist_dc, hist_ac = [], [], []
    t0 = time.perf_counter()
    t_last = t0

    while plt.fignum_exists(fig.number):
        acquire(scope, CHANNEL)
        t, v, pre = read_waveform(scope)
        low, high = screen_limits(scope, CHANNEL)
        m = signal_metrics(t, v)
        clip = clipped_fraction(v, low, high)

        now = time.perf_counter()
        fps, t_last = 1.0 / (now - t_last), now
        hist_t.append(now - t0)
        hist_dc.append(m["mean_V"])
        hist_ac.append(m["amp_peak_V"])
        while hist_t and hist_t[0] < hist_t[-1] - HISTORY_S:
            del hist_t[0], hist_dc[0], hist_ac[0]

        line_w.set_data(t * 1e3, v)
        ax_w.set_xlim(t[0] * 1e3, t[-1] * 1e3)
        ax_w.set_ylim(low, high)
        ax_w.set_title(
            f"media={m['mean_V']:.3f} V   Vpp={m['vpp_V']:.3f} V   "
            f"pico={m['amp_peak_V']:.3f} V @ {m['f_peak_Hz']:.1f} Hz   "
            f"Fs={1 / pre['xincrement']:.3g} Sa/s   {fps:.1f} fps"
            + ("   SATURADA" if clip > 0.001 else ""),
            color="red" if clip > 0.001 else "black", fontsize=10,
        )
        line_dc.set_data(hist_t, hist_dc)
        line_ac.set_data(hist_t, hist_ac)
        ax_h.set_xlim(max(0.0, hist_t[-1] - HISTORY_S), max(HISTORY_S, hist_t[-1]))
        ax_h.relim()
        ax_h.autoscale_view(scalex=False)

        fig.canvas.draw_idle()
        plt.pause(0.001)

except KeyboardInterrupt:
    print("\nInterrumpido por el usuario.")

finally:
    restore_settings(scope, saved)
    scope.write(":RUN")
    scope.close()
    rm.close()
    print("Osciloscopio en RUN. Conexion cerrada.")
