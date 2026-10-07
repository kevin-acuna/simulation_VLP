"""
02_test_scope.py

Verificacion de la comunicacion con el MSOX6004A:
  1. *IDN? y cola de errores
  2. Configuracion actual de canales, base de tiempo y trigger
  3. Estado del generador interno (WGEN) que alimenta el LED
  4. Una adquisicion de prueba del canal CHANNEL (transferencia binaria)

No modifica la configuracion del osciloscopio (el trigger pasa a AUTO solo
durante la prueba y se restaura); al final lo deja en RUN.
"""

from scope_common import (
    acquire, channel_settings, connect, read_errors, read_waveform,
    restore_settings, save_settings, setup_waveform, signal_metrics,
)

VISA_ADDRESS = None              # None -> autodetectar; o p.ej. "USB0::0x2A8D::...::INSTR"
CHANNEL = 1                      # canal para la adquisicion de prueba
TEST_POINTS = 1000

rm, scope, idn = connect(VISA_ADDRESS)

try:
    errors = read_errors(scope)
    print(f"\nErrores previos en la cola: {errors or 'ninguno'}")

    print("\nCanales:")
    for ch in range(1, 5):
        s = channel_settings(scope, ch)
        print(f"  CH{ch}: display={s['display']}  {s['scale_V_div']:g} V/div  "
              f"offset={s['offset_V']:g} V  {s['coupling']}  {s['impedance']}  "
              f"BWL={s['bw_limit']}  probe={s['probe']}")

    print("\nBase de tiempo / adquisicion / trigger:")
    print(f"  {float(scope.query(':TIMebase:SCALe?')):g} s/div   "
          f"Fs = {float(scope.query(':ACQuire:SRATe?')):g} Sa/s   "
          f"tipo = {scope.query(':ACQuire:TYPE?').strip()}   "
          f"sweep = {scope.query(':TRIGger:SWEep?').strip()}")

    print("\nGenerador interno (WGEN -> LED):")
    try:
        print(f"  salida={scope.query(':WGEN:OUTPut?').strip()}  "
              f"funcion={scope.query(':WGEN:FUNCtion?').strip()}  "
              f"f={float(scope.query(':WGEN:FREQuency?')):g} Hz  "
              f"Vpp={float(scope.query(':WGEN:VOLTage?')):g} V  "
              f"offset={float(scope.query(':WGEN:VOLTage:OFFSet?')):g} V  "
              f"carga={scope.query(':WGEN:OUTPut:LOAD?').strip()}")
    except Exception as e:
        print(f"  No disponible: {e}")

    print(f"\nAdquisicion de prueba CH{CHANNEL} ({TEST_POINTS} puntos)...")
    saved = save_settings(scope, [":TRIGger:SWEep"])
    scope.write(":TRIGger:SWEep AUTO")   # evita esperar un trigger que no llega
    setup_waveform(scope, CHANNEL, TEST_POINTS)
    acquire(scope, CHANNEL)
    t, v, pre = read_waveform(scope)
    restore_settings(scope, saved)
    m = signal_metrics(t, v)
    print(f"  {v.size} puntos, Fs = {1 / pre['xincrement']:g} Sa/s, ventana = {t[-1] - t[0]:g} s")
    print(f"  media = {m['mean_V']:.4f} V   Vpp = {m['vpp_V']:.4f} V   "
          f"pico FFT = {m['amp_peak_V']:.4f} V @ {m['f_peak_Hz']:g} Hz")

    errors = read_errors(scope)
    print(f"\nErrores tras la prueba: {errors or 'ninguno'}")
    print("\n=== COMUNICACION OK ===")

finally:
    scope.write(":RUN")
    scope.close()
    rm.close()
