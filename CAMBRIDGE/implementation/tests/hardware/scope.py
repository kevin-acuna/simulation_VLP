"""
scope.py - Osciloscopio Keysight/Agilent InfiniiVision (MSO-X 4154A) via pyvisa.

  read_fft()  FFT calculada por el osciloscopio (funcion Math), en RUN (pantalla viva).
  record()    adquisiciones sincronizadas: :DIGitize -> FFT del osciloscopio + forma de
              onda del canal de la MISMA adquisicion. Al final vuelve a RUN.
  led_peak()  pico de una FFT alrededor de la frecuencia del LED.

Nunca se envia *RST ni :AUToscale: el generador interno (WGEN) alimenta el LED.
Usar el objeto desde un solo hilo.
Parametros: seccion [scope] de config/testbed.toml (mismos nombres que el constructor).
"""

import math
import time

import numpy as np


def fft_peak(f, y, f0=None, band_hz=None, f_min=1.0, fallback_global=True):
    """Pico de la FFT.

    Con f0 busca dentro de f0 +/- banda, donde la banda es al menos 1.5 bins (la
    resolucion de la FFT del osciloscopio puede ser mayor que band_hz). Si no hay bins
    en la banda: maximo global (> f_min) o, con fallback_global=False, (nan, nan).
    """
    mask = f >= f_min
    if f0 is not None:
        bin_hz = float(np.median(np.diff(f))) if f.size > 1 else 0.0
        near = mask & (np.abs(f - f0) <= max(band_hz or 0.0, 1.5 * bin_hz))
        if near.any():
            mask = near
        elif not fallback_global:
            return math.nan, math.nan
    if not mask.any():
        return math.nan, math.nan
    k = int(np.flatnonzero(mask)[np.argmax(y[mask])])
    return float(f[k]), float(y[k])


def tone_amplitude(t, v, f0):
    """Amplitud (pico) de la senoide de frecuencia f0 en la forma de onda (proyeccion tipo lock-in)."""
    x = v - v.mean()
    return float(2.0 * abs(np.mean(x * np.exp(-2j * np.pi * f0 * t))))


def clipped_fraction(v, low, high, margin=0.005):
    """Fraccion de muestras pegadas al borde de pantalla (senal saturada). NaN si no hay rango."""
    if low is None or high is None:
        return math.nan
    m = margin * (high - low)
    return float(np.mean((v >= high - m) | (v <= low + m)))


def frequency_features(acqs, freqs_hz, band_hz=50.0):
    """Resumen por frecuencia de un conjunto de adquisiciones (salida de Scope.record).

    Para cada f0 devuelve un dict con:
      freq_Hz        frecuencia pedida
      fft_freq_Hz    frecuencia del pico de la FFT del osciloscopio cerca de f0 (media)
      fft_mean/std   valor de ese pico (unidades de la FFT: Vrms o dB)
      vrms_mean/std  amplitud RMS de la senoide f0 en la forma de onda cruda [Vrms]
    Si f0 esta fuera del rango de la FFT, los campos fft_* son NaN.
    """
    out = []
    for f0 in freqs_hz:
        peaks = np.array([fft_peak(a["f"], a["fft"], f0, band_hz, fallback_global=False)
                          for a in acqs])
        vrms = np.array([tone_amplitude(a["t"], a["v"], f0) / math.sqrt(2) for a in acqs])
        out.append({"freq_Hz": float(f0), "fft_freq_Hz": float(np.mean(peaks[:, 0])),
                    "fft_mean": float(np.mean(peaks[:, 1])), "fft_std": float(np.std(peaks[:, 1])),
                    "vrms_mean": float(vrms.mean()), "vrms_std": float(vrms.std())})
    return out


class ScopeBase:
    """Logica comun al osciloscopio real y al simulado."""

    def __init__(self, led_freq_hz="wgen", led_freq_band_hz=50.0, fft_peak_min_hz=1.0):
        self.led_freq_setting = led_freq_hz
        self.led_band = led_freq_band_hz
        self.peak_min = fft_peak_min_hz
        self.info = {}

    def led_frequency(self):
        """Frecuencia del LED [Hz] segun la configuracion (o None = pico global)."""
        if self.led_freq_setting == "wgen":
            return self.info.get("wgen_frequency_Hz")
        return float(self.led_freq_setting) if self.led_freq_setting not in ("", None) else None

    def led_peak(self, f, y):
        """(frecuencia, valor) del pico de la FFT en la banda del LED."""
        return fft_peak(f, y, self.led_frequency(), self.led_band, self.peak_min)

    @property
    def fft_units(self):
        return self.info.get("fft_units", "")

    def refresh_info(self):
        return self.info

    def channel_limits(self):
        """Rango vertical visible del canal (8 divisiones) segun la ultima info leida."""
        scale, offset = self.info.get("ch_scale_V_div"), self.info.get("ch_offset_V", 0.0)
        return (None, None) if scale is None else (offset - 4 * scale, offset + 4 * scale)


class Scope(ScopeBase):
    def __init__(self, address, channel=1, fft_function=None, fft_points="MAX", timeout_ms=20000,
                 led_freq_hz="wgen", led_freq_band_hz=50.0, fft_peak_min_hz=1.0):
        super().__init__(led_freq_hz, led_freq_band_hz, fft_peak_min_hz)
        self.address, self.channel = address, channel
        self.m = fft_function or None
        self.fft_points = fft_points
        self.timeout_ms = timeout_ms
        self.rm = self.inst = None
        self._source = None
        self._saved = {}

    # ---------------------------------------------------------------
    def connect(self):
        import pyvisa
        self.rm = pyvisa.ResourceManager()
        # VISA puede listar el serial en otra capitalizacion (MY... / my...)
        listed = {r.upper(): r for r in self.rm.list_resources("?*::INSTR")}
        self.address = listed.get(self.address.upper(), self.address)
        try:
            self.inst = self.rm.open_resource(self.address)
        except pyvisa.VisaIOError as e:
            hint = ("another program is holding the oscilloscope (another script, Keysight "
                    "Interactive IO / BenchVue): close it" if "NCIC" in str(e) else
                    f"available resources: {list(listed.values())}")
            raise RuntimeError(f"[Scope] Could not open {self.address}: {e}. {hint}.") from e
        i = self.inst
        i.timeout = self.timeout_ms
        i.read_termination = i.write_termination = "\n"
        i.chunk_size = 4 * 1024 * 1024
        idn = i.query("*IDN?").strip()
        i.write("*CLS")
        self._saved = {":TRIGger:SWEep": i.query(":TRIGger:SWEep?").strip()}
        i.write(":TRIGger:SWEep AUTO")          # :DIGitize no se cuelga sin senal
        self.m = self.m or self._find_fft()
        self.refresh_info(idn)
        print(f"[Scope] {idn}\n[Scope] FFT = FUNCtion{self.m} ({self.info['fft_source']}, "
              f"{self.fft_units}); LED = {self.led_frequency()} Hz")

    def refresh_info(self, idn=None):
        """Relee la configuracion actual (canal, base de tiempo, FFT, WGEN) del osciloscopio."""
        i = self.inst
        q = lambda c: i.query(c).strip()
        f = f":FUNCtion{self.m}"
        idn = idn or self.info.get("idn") or q("*IDN?")
        self.info = {
            "idn": idn, "address": self.address, "channel": self.channel,
            "fft_function": self.m, "fft_source": q(f"{f}:SOURce1?"),
            "fft_vtype": q(f"{f}:FFT:VTYPe?"), "fft_window": q(f"{f}:FFT:WINDow?"),
            "fft_center_Hz": float(q(f"{f}:FFT:CENTer?")), "fft_span_Hz": float(q(f"{f}:FFT:SPAN?")),
            "timebase_s_div": float(q(":TIMebase:SCALe?")),
            "sample_rate_Sa_s": float(q(":ACQuire:SRATe?")),
            "acquire_type": q(":ACQuire:TYPE?"),
            "ch_scale_V_div": float(q(f":CHANnel{self.channel}:SCALe?")),
            "ch_offset_V": float(q(f":CHANnel{self.channel}:OFFSet?")),
            "ch_coupling": q(f":CHANnel{self.channel}:COUPling?"),
            "ch_impedance": q(f":CHANnel{self.channel}:IMPedance?"),
        }
        self.info["fft_units"] = "dB" if self.info["fft_vtype"].upper().startswith("DEC") else "Vrms"
        try:
            self.info.update(
                wgen_output=q(":WGEN:OUTPut?"), wgen_function=q(":WGEN:FUNCtion?"),
                wgen_frequency_Hz=float(q(":WGEN:FREQuency?")),
                wgen_vpp_V=float(q(":WGEN:VOLTage?")),
                wgen_offset_V=float(q(":WGEN:VOLTage:OFFSet?")))
        except Exception:
            pass
        self._errors()
        return self.info

    def _errors(self):
        errs = []
        for _ in range(50):
            e = self.inst.query(":SYSTem:ERRor?").strip()
            if e.startswith(("+0", "0")):
                return errs
            errs.append(e)
        return errs

    def _find_fft(self):
        import pyvisa
        for m in range(1, 5):
            try:
                op = self.inst.query(f":FUNCtion{m}:OPERation?").strip().upper()
                shown = self.inst.query(f":FUNCtion{m}:DISPlay?").strip() in ("1", "ON")
            except pyvisa.VisaIOError:
                break
            if op == "FFT" and shown:
                return m
        raise RuntimeError("[Scope] No Math function with a visible FFT (set Math -> FFT on the PD channel).")

    # ---------------------------------------------------------------
    def _select(self, source, mode, points):
        if self._source != (source, mode, points):
            i = self.inst
            i.write(f":WAVeform:SOURce {source}")
            i.write(":WAVeform:FORMat WORD")
            i.write(":WAVeform:BYTeorder LSBFirst")
            i.write(":WAVeform:UNSigned 1")
            i.write(f":WAVeform:POINts:MODE {mode}")
            i.write(f":WAVeform:POINts {points}")
            self._source = (source, mode, points)

    def _read(self):
        p = [float(x) for x in self.inst.query(":WAVeform:PREamble?").split(",")]
        pre = dict(zip(["format", "type", "points", "count", "xincrement", "xorigin",
                        "xreference", "yincrement", "yorigin", "yreference"], p))
        raw = self.inst.query_binary_values(":WAVeform:DATA?", datatype="H",
                                            is_big_endian=False, container=np.array)
        x = (np.arange(raw.size) - pre["xreference"]) * pre["xincrement"] + pre["xorigin"]
        y = (raw.astype(float) - pre["yreference"]) * pre["yincrement"] + pre["yorigin"]
        return x, y, pre

    def _fft(self):
        self._select(f"FUNCtion{self.m}", "NORMal", self.fft_points)
        f, y, _ = self._read()
        return f, y

    def fft_screen_limits(self):
        scale = float(self.inst.query(f":FUNCtion{self.m}:SCALe?"))
        offset = float(self.inst.query(f":FUNCtion{self.m}:OFFSet?"))
        return offset - 4 * scale, offset + 4 * scale

    def read_fft(self):
        """FFT actual en pantalla (osciloscopio en RUN): dict unix, f, y, ylim."""
        f, y = self._fft()
        return {"unix": time.time(), "f": f, "y": y, "ylim": self.fft_screen_limits()}

    def record(self, n_acq, time_points):
        """n_acq adquisiciones sincronizadas: lista de dict unix, f, fft, t, v, fs."""
        out = []
        try:
            for _ in range(n_acq):
                t0 = time.time()
                self.inst.write(":DIGitize")
                self.inst.query("*OPC?")
                f, y = self._fft()
                self._select(f"CHANnel{self.channel}", "RAW", time_points)
                t, v, pre = self._read()
                out.append({"unix": t0, "f": f, "fft": y, "t": t - t[0], "v": v,
                            "fs": 1.0 / pre["xincrement"]})
        finally:
            self.inst.write(":RUN")
        return out

    def close(self):
        if self.inst is None:
            return
        try:
            for cmd, value in self._saved.items():
                self.inst.write(f"{cmd} {value}")
            self.inst.write(":RUN")
            self.inst.close()
        finally:
            self.rm.close()
        print("[Scope] Connection closed.")
