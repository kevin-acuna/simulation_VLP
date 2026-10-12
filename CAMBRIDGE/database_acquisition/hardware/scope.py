"""
scope.py - Keysight/Agilent InfiniiVision oscilloscope (MSO-X 4154A) through pyvisa.

  read_fft()  FFT computed by the oscilloscope (Math function) while running (live screen).
  record()    acquisitions: :SINGle -> channel waveform and FFT of the SAME acquisition
              (oscilloscope FFT, or computed in Python with scope_fft=False). Ends in RUN.
  configure_record() / restore_record()
              continuous record of a given duration and sample rate (Digitizer mode +
              timebase), and back to the user's previous settings.
  led_peak()  FFT peak around the LED frequency.

Timing measured on the MSO-X 4154A (2026-10-12, 50 kpts record):
  :DIGitize + *OPC? ~2.8 s  |  :SINGle ~0.2 s + oscilloscope FFT computation ~1.4 s
  without the oscilloscope FFT: :SINGle ~0.2 s + transfer (50 kpts ~0.17 s, 1 Mpts ~0.64 s).
  :WAVeform:DATA? only returns on-screen data: record length = 10 x timebase.

*RST and :AUToscale are never sent: the internal generator (WGEN) may be driving an LED.
Use the object from a single thread.
Parameters: [scope] section of config/testbed.toml (same names as the constructor).
"""

import math
import time

import numpy as np


def fft_peak(f, y, f0=None, band_hz=None, f_min=1.0, fallback_global=True):
    """FFT peak.

    With f0, searches within f0 +/- band, where the band is at least 1.5 bins (the
    oscilloscope FFT resolution can be coarser than band_hz). If there are no bins in the
    band: global maximum (> f_min) or, with fallback_global=False, (nan, nan).
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


def spectrum_vrms(v, fs, f_lo=0.0, f_hi=None):
    """Spectrum in Vrms (Hanning window, like the oscilloscope FFT) between f_lo and f_hi."""
    w = np.hanning(v.size)
    y = np.abs(np.fft.rfft((v - v.mean()) * w)) * (2.0 / w.sum() / math.sqrt(2.0))
    f = np.fft.rfftfreq(v.size, 1.0 / fs)
    sel = (f >= f_lo) & (f <= (f_hi if f_hi is not None else f[-1]))
    return f[sel], y[sel]


def decimate_spectrum(f, y, max_bins):
    """Reduces a spectrum to <= max_bins points keeping the maximum of each group (peaks kept)."""
    step = int(math.ceil(len(y) / max_bins)) if max_bins else 1
    if step <= 1:
        return f, y
    n = len(y) // step * step
    return f[:n:step], y[:n].reshape(-1, step).max(axis=1)


def tone_amplitude(t, v, f0):
    """Peak amplitude of the f0 sinusoid in the waveform (lock-in style projection)."""
    x = v - v.mean()
    return float(2.0 * abs(np.mean(x * np.exp(-2j * np.pi * f0 * t))))


def clipped_fraction(v, low, high, margin=0.005):
    """Fraction of samples stuck at the screen edge (saturated signal). NaN if no range."""
    if low is None or high is None:
        return math.nan
    m = margin * (high - low)
    return float(np.mean((v >= high - m) | (v <= low + m)))


def frequency_features(acqs, freqs_hz, band_hz=50.0):
    """Per-frequency summary of a set of acquisitions (output of Scope.record).

    For each f0 returns a dict with:
      freq_Hz        requested frequency
      fft_freq_Hz    frequency of the FFT peak near f0 (mean)
      fft_mean/std   value of that peak (FFT units: Vrms or dB)
      vrms_mean/std  RMS amplitude of the f0 sinusoid in the raw waveform [Vrms] (lock-in at f0)
    If f0 is outside the FFT range, the fft_* fields are NaN.
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
    """Logic shared by the real and the simulated oscilloscope."""

    def __init__(self, led_freq_hz="wgen", led_freq_band_hz=50.0, fft_peak_min_hz=1.0):
        self.led_freq_setting = led_freq_hz
        self.led_band = led_freq_band_hz
        self.peak_min = fft_peak_min_hz
        self.info = {}

    def led_frequency(self):
        """LED frequency [Hz] according to the config (or None = global peak)."""
        if self.led_freq_setting == "wgen":
            return self.info.get("wgen_frequency_Hz")
        return float(self.led_freq_setting) if self.led_freq_setting not in ("", None) else None

    def led_peak(self, f, y):
        """(frequency, value) of the FFT peak in the LED band."""
        return fft_peak(f, y, self.led_frequency(), self.led_band, self.peak_min)

    @property
    def fft_units(self):
        return self.info.get("fft_units", "")

    def refresh_info(self):
        return self.info

    def fft_displayed(self):
        return True

    def set_fft_display(self, on):
        pass

    def recover(self):
        pass

    def channel_limits(self):
        """Visible vertical range of the channel (8 divisions) from the last settings read."""
        scale, offset = self.info.get("ch_scale_V_div"), self.info.get("ch_offset_V", 0.0)
        return (None, None) if scale is None else (offset - 4 * scale, offset + 4 * scale)

    def fft_band(self):
        """Band (f_lo, f_hi) of the oscilloscope FFT, used for the spectrum computed in Python."""
        c, s = self.info.get("fft_center_Hz"), self.info.get("fft_span_Hz")
        return (0.0, None) if c is None or s is None else (max(c - s / 2, 0.0), c + s / 2)


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
        self._record_saved = None      # user settings before configure_record()
        self._fft_hidden = False       # oscilloscope FFT temporarily hidden by record()

    # ---------------------------------------------------------------
    def connect(self):
        import pyvisa
        self.rm = pyvisa.ResourceManager()
        # VISA may list the serial number with a different case (MY... / my...)
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
        try:
            i.clear()       # drops pending replies of a previously interrupted session (VI_ERROR_IO)
        except Exception:
            pass
        idn = i.query("*IDN?").strip()
        i.write("*CLS")
        self._saved = {":TRIGger:SWEep": i.query(":TRIGger:SWEep?").strip()}
        i.write(":TRIGger:SWEep AUTO")          # acquisitions never hang without a trigger
        self.m = self.m or self._find_fft()
        self.refresh_info(idn)
        print(f"[Scope] {idn}\n[Scope] FFT = FUNCtion{self.m} ({self.info['fft_source']}, "
              f"{self.fft_units}); LED = {self.led_frequency()} Hz")

    def refresh_info(self, idn=None):
        """Re-reads the current settings (channel, timebase, FFT, WGEN) of the oscilloscope."""
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
        # Digitizer mode and acquisition memory (read only; firmware >= 7.x)
        old_timeout, i.timeout = i.timeout, 3000
        try:
            self.info.update(acq_digitizer=q(":ACQuire:DIGitizer?"),
                             acq_points=int(float(q(":ACQuire:POINts?"))),
                             acq_srate_max_Sa_s=float(q(":ACQuire:SRATe? MAXimum")))
        except Exception:
            pass
        finally:
            i.timeout = old_timeout
        self._errors()
        return self.info

    def recover(self):
        """Resynchronizes the communication after a VISA error/timeout.

        If a query times out, its reply can arrive late and misalign the next ones
        (seen 2026-10-12: '-420 Query UNTERMINATED', '-221 Settings conflict'). The device
        clear drops anything pending and the error queue is emptied.
        """
        try:
            self.inst.clear()
        except Exception:
            pass
        self._source = None
        try:
            self._errors()
        except Exception:
            pass

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

    def _read(self, with_raw=False):
        p = [float(x) for x in self.inst.query(":WAVeform:PREamble?").split(",")]
        pre = dict(zip(["format", "type", "points", "count", "xincrement", "xorigin",
                        "xreference", "yincrement", "yorigin", "yreference"], p))
        raw = self.inst.query_binary_values(":WAVeform:DATA?", datatype="H",
                                            is_big_endian=False, container=np.array)
        x = (np.arange(raw.size) - pre["xreference"]) * pre["xincrement"] + pre["xorigin"]
        y = (raw.astype(float) - pre["yreference"]) * pre["yincrement"] + pre["yorigin"]
        return (x, y, pre, raw.astype(np.uint16)) if with_raw else (x, y, pre)

    def _fft(self):
        self._select(f"FUNCtion{self.m}", "NORMal", self.fft_points)
        f, y, _ = self._read()
        return f, y

    def fft_screen_limits(self):
        scale = float(self.inst.query(f":FUNCtion{self.m}:SCALe?"))
        offset = float(self.inst.query(f":FUNCtion{self.m}:OFFSet?"))
        return offset - 4 * scale, offset + 4 * scale

    def read_fft(self):
        """FFT currently on screen (oscilloscope running): dict unix, f, y, ylim."""
        f, y = self._fft()
        return {"unix": time.time(), "f": f, "y": y, "ylim": self.fft_screen_limits()}

    def _single(self):
        """One acquisition (:SINGle), waiting until it finishes (Run bit of the operation register)."""
        i = self.inst
        running = lambda: bool(int(float(i.query(":OPERegister:CONDition?"))) & 8)
        i.write(":STOP")
        i.write(":SINGle")
        t0 = time.monotonic()
        while not running() and time.monotonic() - t0 < 0.1:     # make sure the new capture started
            time.sleep(0.002)
        t_end = t0 + self.timeout_ms / 1000.0
        while running():
            if time.monotonic() > t_end:
                raise TimeoutError("[Scope] The acquisition did not complete (check the trigger).")
            time.sleep(0.005)

    def _show_fft(self, on):
        self.inst.write(f":FUNCtion{self.m}:DISPlay {1 if on else 0}")
        self._fft_hidden = not on

    def fft_displayed(self):
        return self.inst.query(f":FUNCtion{self.m}:DISPlay?").strip() in ("1", "ON")

    def set_fft_display(self, on):
        """Shows or hides the oscilloscope FFT. While hidden the oscilloscope does not compute it
        and every acquisition is ~1.4 s (50 kpts) or ~2 s (1 Mpts) faster. close() shows it again."""
        self._show_fft(on)

    def record(self, n_acq, time_points, scope_fft=True):
        """n_acq acquisitions: list of dicts unix, t, v, fs, codes, scale, f, fft, fft_source.

        scope_fft=True : f/fft = oscilloscope FFT (Math function) of the same acquisition.
        scope_fft=False: the oscilloscope FFT is switched off while acquiring (saves ~1.4 s per
                         acquisition) and f/fft are computed in Python with the same window
                         (Hanning) over the whole record, in the band of the oscilloscope FFT.
        codes/scale: raw ADC codes (uint16) and (yincrement, yorigin, yreference):
                     v = (codes - yreference) * yincrement + yorigin (lossless).
        """
        out = []
        restore_fft = False
        try:
            if not scope_fft and self.inst.query(f":FUNCtion{self.m}:DISPlay?").strip() in ("1", "ON"):
                self._show_fft(False)
                restore_fft = True
            for _ in range(n_acq):
                t0 = time.time()
                self._single()
                self._select(f"CHANnel{self.channel}", "RAW", time_points)
                t, v, pre, codes = self._read(with_raw=True)
                fs = 1.0 / pre["xincrement"]
                acq = {"unix": t0, "t": t - t[0], "v": v, "fs": fs, "codes": codes,
                       "scale": (pre["yincrement"], pre["yorigin"], pre["yreference"])}
                if scope_fft:
                    acq["f"], acq["fft"] = self._fft()
                    acq["fft_source"] = "scope"
                else:
                    acq["f"], acq["fft"] = spectrum_vrms(v, fs, *self.fft_band())
                    acq["fft_source"] = "python"
                out.append(acq)
        finally:
            if restore_fft:
                self._show_fft(True)
            self.inst.write(":RUN")
        return out

    # ---------------------------------------------------------------
    MAX_ACQ_POINTS = 4_000_000

    def configure_record(self, record_s, fs):
        """Continuous record of record_s seconds at fs samples/s (Digitizer mode).

        Only the on-screen data (10 divisions) can be downloaded, so the timebase is set to
        record_s/10 and memory for 2x is requested (while running the oscilloscope uses half;
        :SINGle uses all of it). The previous settings are saved for restore_record().
        """
        i = self.inst
        q = lambda c: i.query(c).strip()
        n = int(round(record_s * fs))
        self._errors()                  # drop old errors: only those of this configuration count
        if n > self.MAX_ACQ_POINTS:
            raise ValueError(f"[Scope] {record_s * 1e3:g} ms at {fs / 1e6:g} MSa/s needs {n:,} points "
                             f"(max {self.MAX_ACQ_POINTS:,}).")
        if self._record_saved is None:
            # :ACQuire:POINts? describes the LAST acquisition (not the request), so it cannot be
            # used to save the user's memory setting. On restore, 2 x the on-screen points are
            # requested (the oscilloscope uses half while running): the screen is filled as
            # before (100 kpts for 5 ms at 10 MSa/s, the 2026-10-12 setup).
            scale, srate = float(q(":TIMebase:SCALe?")), float(q(":ACQuire:SRATe?"))
            self._record_saved = {"digitizer": q(":ACQuire:DIGitizer?") in ("1", "ON"),
                                  "srate": srate, "scale": scale,
                                  "points": min(int(round(2 * 10 * scale * srate)), self.MAX_ACQ_POINTS)}
        # order matters: in Digitizer mode the timebase cannot exceed memory / sample rate
        # ("-222 Data out of range"), so memory first, then sample rate, then timebase
        i.write(f":ACQuire:POINts {min(2 * n, self.MAX_ACQ_POINTS)}")
        i.write(f":ACQuire:SRATe {fs:.6E}")
        q("*OPC?")
        for _ in range(5):          # the new memory may take a moment to apply: retry the timebase
            i.write(f":TIMebase:SCALe {record_s / 10:.6E}")
            q("*OPC?")
            if abs(float(q(":TIMebase:SCALe?")) * 10 - record_s) <= 1e-6 * record_s:
                break
            time.sleep(0.3)
        # the 4154A may answer "-222 Data out of range" to the timebase even though it applies it
        # (seen with 10 ms/div): the actual values are checked instead of trusting the error
        errs = self._errors()
        self.refresh_info()
        got_fs, got_tb = self.info["sample_rate_Sa_s"], self.info["timebase_s_div"]
        if abs(got_fs - fs) > 1e-6 * fs or abs(got_tb * 10 - record_s) > 1e-6 * record_s:
            self.restore_record()
            raise RuntimeError(f"[Scope] Could not set a {record_s * 1e3:g} ms record at {fs / 1e6:g} MSa/s "
                               f"(got {got_tb * 10e3:g} ms, {got_fs / 1e6:g} MSa/s; errors: {errs}).")
        print(f"[Scope] Record: {record_s * 1e3:g} ms continuous at {fs / 1e6:g} MSa/s ({n:,} points)"
              + (f"; scope messages: {errs}" if errs else "."))
        return self.info

    def restore_record(self):
        """Restores the previous timebase / sample rate / memory."""
        s, self._record_saved = self._record_saved, None
        if s is None:
            return
        i = self.inst
        i.write(f":TIMebase:SCALe {s['scale']:.6E}")                     # reverse order of configure
        if s["digitizer"]:
            i.write(f":ACQuire:SRATe {s['srate']:.6E}")
            i.write(f":ACQuire:POINts {s['points']}")
        else:
            i.write(":ACQuire:DIGitizer 0")
        i.query("*OPC?")
        if abs(float(i.query(":TIMebase:SCALe?")) - s["scale"]) > 1e-6 * s["scale"]:
            i.write(f":TIMebase:SCALe {s['scale']:.6E}")                 # in case the memory clipped it
        self._errors()
        self.refresh_info()
        print("[Scope] Previous timebase / sample rate / memory restored.")

    def close(self):
        if self.inst is None:
            return
        try:
            if self._fft_hidden:
                self._show_fft(True)
            self.restore_record()
            for cmd, value in self._saved.items():
                self.inst.write(f"{cmd} {value}")
            self.inst.write(":RUN")
            self.inst.close()
        finally:
            self.rm.close()
        print("[Scope] Connection closed.")
