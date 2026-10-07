"""
scope_common.py

Funciones comunes para el osciloscopio Keysight/Agilent InfiniiVision
(en el laboratorio: MSO-X 4154A; mismo juego de comandos que el MSOX6004A) via pyvisa.

IMPORTANTE: nunca se envia *RST ni :AUToscale, porque el generador interno
(WGEN) del mismo osciloscopio alimenta el LED y se perderia su configuracion.
"""

import numpy as np
import pyvisa

# Modelos aceptados (texto en *IDN?). En el laboratorio: MSO-X 4154A.
MODEL_HINTS = ("4154A", "6004A")


def is_known_model(idn):
    return any(hint in idn for hint in MODEL_HINTS)


# ============================================================
# CONEXION
# ============================================================

def find_scope(rm):
    """Busca el osciloscopio entre los recursos VISA (USB/LAN/GPIB, no COM)."""
    for resource in rm.list_resources("?*::INSTR"):
        if resource.startswith("ASRL"):
            continue
        try:
            with rm.open_resource(resource) as inst:
                inst.timeout = 2000
                idn = inst.query("*IDN?")
            if is_known_model(idn):
                return resource
        except pyvisa.VisaIOError:
            pass
    raise RuntimeError(
        f"No se encontro ningun osciloscopio {MODEL_HINTS}. Revisa el cable, "
        f"Keysight Connection Expert, o define VISA_ADDRESS manualmente."
    )


def connect(address=None, timeout_ms=10000):
    """Abre el osciloscopio. Devuelve (rm, inst, idn)."""
    rm = pyvisa.ResourceManager()
    address = address or find_scope(rm)
    inst = rm.open_resource(address)
    inst.timeout = timeout_ms
    inst.read_termination = "\n"
    inst.write_termination = "\n"
    inst.chunk_size = 4 * 1024 * 1024
    idn = inst.query("*IDN?").strip()
    if not is_known_model(idn):
        print(f"AVISO: modelo no reconocido {MODEL_HINTS}: {idn}")
    inst.write("*CLS")
    print(f"Conectado a {address}\n  {idn}")
    return rm, inst, idn


def read_errors(inst):
    """Vacia la cola de errores SCPI y la devuelve como lista."""
    errors = []
    for _ in range(50):
        err = inst.query(":SYSTem:ERRor?").strip()
        if err.startswith(("+0", "0")):
            break
        errors.append(err)
    return errors


def save_settings(inst, commands):
    """Guarda el valor actual de cada comando SCPI (p.ej. ':TRIGger:SWEep')."""
    return {cmd: inst.query(f"{cmd}?").strip() for cmd in commands}


def restore_settings(inst, saved):
    for cmd, value in saved.items():
        inst.write(f"{cmd} {value}")


# ============================================================
# CONFIGURACION
# ============================================================

def configure_channel(inst, ch, scale_v, offset_v, coupling, impedance, bw_limit):
    c = f":CHANnel{ch}"
    inst.write(f"{c}:DISPlay ON")
    inst.write(f"{c}:IMPedance {impedance}")
    inst.write(f"{c}:COUPling {coupling}")
    inst.write(f"{c}:SCALe {scale_v}")
    inst.write(f"{c}:OFFSet {offset_v}")
    inst.write(f"{c}:BWLimit {1 if bw_limit else 0}")


def channel_settings(inst, ch):
    c = f":CHANnel{ch}"
    return {
        "display": inst.query(f"{c}:DISPlay?").strip(),
        "scale_V_div": float(inst.query(f"{c}:SCALe?")),
        "offset_V": float(inst.query(f"{c}:OFFSet?")),
        "coupling": inst.query(f"{c}:COUPling?").strip(),
        "impedance": inst.query(f"{c}:IMPedance?").strip(),
        "bw_limit": inst.query(f"{c}:BWLimit?").strip(),
        "probe": inst.query(f"{c}:PROBe?").strip(),
    }


def screen_limits(inst, ch):
    """Rango vertical visible en pantalla (8 divisiones)."""
    scale = float(inst.query(f":CHANnel{ch}:SCALe?"))
    offset = float(inst.query(f":CHANnel{ch}:OFFSet?"))
    return offset - 4 * scale, offset + 4 * scale


def setup_waveform(inst, ch, points, points_mode="NORMal"):
    """Configura la transferencia: WORD de 16 bits, sin signo, little-endian."""
    inst.write(f":WAVeform:SOURce CHANnel{ch}")
    inst.write(":WAVeform:FORMat WORD")
    inst.write(":WAVeform:BYTeorder LSBFirst")
    inst.write(":WAVeform:UNSigned 1")
    inst.write(f":WAVeform:POINts:MODE {points_mode}")
    inst.write(f":WAVeform:POINts {points}")


# ============================================================
# ADQUISICION
# ============================================================

def acquire(inst, ch):
    """Una adquisicion completa (el osciloscopio queda en STOP)."""
    inst.write(f":DIGitize CHANnel{ch}")
    inst.query("*OPC?")


def read_waveform(inst):
    """Descarga la forma de onda. Devuelve (t [s], v [V], preamble dict)."""
    p = [float(x) for x in inst.query(":WAVeform:PREamble?").split(",")]
    pre = dict(zip(
        ["format", "type", "points", "count", "xincrement", "xorigin",
         "xreference", "yincrement", "yorigin", "yreference"], p))
    raw = inst.query_binary_values(
        ":WAVeform:DATA?", datatype="H", is_big_endian=False, container=np.array
    )
    t = (np.arange(raw.size) - pre["xreference"]) * pre["xincrement"] + pre["xorigin"]
    v = (raw.astype(float) - pre["yreference"]) * pre["yincrement"] + pre["yorigin"]
    return t, v, pre


# ============================================================
# METRICAS DE LA SENAL
# ============================================================

def signal_metrics(t, v):
    """Media (DC), Vpp y componente espectral dominante (sin DC)."""
    x = v - v.mean()
    w = np.hanning(x.size)
    spectrum = np.abs(np.fft.rfft(x * w)) * 2.0 / w.sum()
    freqs = np.fft.rfftfreq(x.size, t[1] - t[0])
    spectrum[0] = 0.0
    k = int(np.argmax(spectrum))
    return {
        "mean_V": float(v.mean()),
        "vpp_V": float(np.ptp(v)),
        "f_peak_Hz": float(freqs[k]),
        "amp_peak_V": float(spectrum[k]),
    }


def clipped_fraction(v, low, high):
    """Fraccion de muestras pegadas al borde de la pantalla (posible saturacion)."""
    margin = 0.005 * (high - low)
    return float(np.mean((v >= high - margin) | (v <= low + margin)))
