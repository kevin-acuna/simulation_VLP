"""Figures of one processed capture (no instrument access): received record, its spectrum and the OFDM
constellation.

    show_capture(state)                 interactive figure (pyplot)
    save_capture_figure(state, path)    PNG without pyplot (safe from a worker thread)
"""

import numpy as np

TONE_OK, TONE_BAD, OFDM = "tab:green", "tab:red", "tab:blue"
SPECTRUM_MAX_HZ = 5e6        # upper limit of the spectrum panel (the record goes up to fs / 2)


def envelope(y, fs, max_points=3000):
    """(t_ms, min, max) of the record in blocks (keeps the peaks when drawing millions of samples)."""
    y = np.asarray(y)
    step = max(1, y.size // max_points)
    n = y.size // step * step
    blocks = y[:n].reshape(-1, step)
    return np.arange(blocks.shape[0]) * step / fs * 1e3, blocks.min(axis=1), blocks.max(axis=1)


def spectrum(y, fs, f_max=SPECTRUM_MAX_HZ, max_points=3000):
    """(f, Vrms, bin_Hz) of the whole record: Hann window, RMS amplitude per bin (as the oscilloscope FFT),
    reduced to <= max_points by keeping the maximum of each group of bins (peaks kept)."""
    y = np.asarray(y, dtype=float)
    w = np.hanning(y.size)
    a = np.abs(np.fft.rfft((y - y.mean()) * w)) * (2.0 / w.sum() / np.sqrt(2.0))
    f = np.fft.rfftfreq(y.size, 1.0 / fs)
    keep = f <= min(f_max, fs / 2)
    f, a = f[keep], a[keep]
    step = max(1, a.size // max_points)
    n = a.size // step * step
    return f[:n:step], a[:n].reshape(-1, step).max(axis=1), fs / y.size


def draw_capture(ax, state):
    """PD record (mV, mean removed) with the pilot windows (green valid / red rejected) and OFDM slots (blue)."""
    cap = state["capture"]
    y = np.asarray(cap["YData"])
    t, lo, hi = envelope(y - y.mean(), cap["FsCapture"])
    ax.clear()
    ax.fill_between(t, lo * 1e3, hi * 1e3, color="0.35", lw=0)
    r = state.get("result", {})
    for s in r.get("slotResults", []):
        if np.isfinite(s["communicationStart_s"]):
            ax.axvspan(s["communicationStart_s"] * 1e3, s["communicationEnd_s"] * 1e3, color=OFDM, alpha=0.12, lw=0)
    for w in state["windows"]:
        a = w["windowStart_s"] * 1e3
        ax.axvspan(a, a + w["windowDuration_s"] * 1e3, color=TONE_OK if w.get("validLogical") else TONE_BAD,
                   alpha=0.18, lw=0)
    ax.set_xlim(0, t[-1] if t.size else 1)
    ax.set_xlabel("Time [ms]   (green: pilot windows, blue: OFDM slots)")
    ax.set_ylabel("PD output - mean [mV]")
    ax.grid(True, alpha=0.3)


def draw_spectrum(ax, state, f_max=SPECTRUM_MAX_HZ):
    """Spectrum of the whole record (pilot + OFDM slots) with the OFDM band shaded and the pilot marked.

    The pilot is on only during its slots (12 of 22.4 ms by default), so its peak here is about
    pilot RMS x 12 / 22.4: the pilot RMS of the tables is measured inside the pilot windows."""
    cap = state["capture"]
    f, a, bin_hz = spectrum(cap["YData"], cap["FsCapture"], f_max)
    band = state["packet"]["activeFrequencyHz"]
    ax.clear()
    ax.axvspan(band[0] / 1e3, band[-1] / 1e3, color=OFDM, alpha=0.12, lw=0)
    ax.axvline(state["cfg"]["toneFrequencyHz"] / 1e3, color=TONE_OK, ls=":", lw=1)
    ax.semilogy(f / 1e3, np.maximum(a, 1e-9) * 1e3, color="0.25", lw=0.6)
    ax.set_xlim(0, f[-1] / 1e3 if f.size else 1)
    ax.set_xlabel(f"Frequency [kHz]   (blue: OFDM band, green: pilot; Hann, {bin_hz:g} Hz bins, peak of each group)")
    ax.set_ylabel("Amplitude [mVrms]")
    ax.grid(True, which="both", alpha=0.3)


def draw_constellation(ax, state):
    """Equalized payload of the first accepted OFDM frame over the ideal QAM points."""
    ax.clear()
    ideal = np.asarray(state["packet"]["payloadSymbols"]).ravel()
    ax.plot(ideal.real, ideal.imag, "+", color="0.7", ms=6)
    z = np.asarray(state.get("result", {}).get("equalizedPayload", [])).ravel()
    if z.size:
        ax.plot(z.real, z.imag, ".", color=OFDM, ms=3)
    lim = 1.25 * np.max(np.abs(ideal.real))
    ax.set_xlim(-lim, lim)
    ax.set_ylim(-lim, lim)
    ax.set_aspect("equal", adjustable="box")
    ax.set_xticks([])
    ax.set_yticks([])
    ax.set_title(f"{state['packet']['payloadQAM']}-QAM payload (1st frame)", fontsize=9)


def _fill(fig, state, title):
    ax_w = fig.add_axes([0.06, 0.58, 0.60, 0.34])
    ax_s = fig.add_axes([0.06, 0.09, 0.60, 0.36])
    ax_c = fig.add_axes([0.70, 0.20, 0.28, 0.62])
    draw_capture(ax_w, state)
    draw_spectrum(ax_s, state)
    draw_constellation(ax_c, state)
    s = state["summary"]
    ax_w.set_title(f"Pilot {s['ToneRMS_mV']:.4g} mVrms | BER {s['OriginalBER']:.3g} (averaged {s['AveragedBER']:.3g}) | "
                   f"frames {s['AcceptedFrames']} accepted, {s['RejectedFrames']} rejected", fontsize=10)
    if title:
        fig.suptitle(title, fontsize=9, x=0.01, ha="left")
    return fig


def show_capture(state, title=""):
    import matplotlib.pyplot as plt

    return _fill(plt.figure(title or "ISAC capture", figsize=(13, 7.5)), state, title)


def save_capture_figure(state, path, title="", dpi=90):
    """Saves the capture figure as PNG. Uses the object-oriented API only (no pyplot state)."""
    from matplotlib.figure import Figure

    fig = _fill(Figure(figsize=(13, 7.5)), state, title)
    fig.savefig(path, dpi=dpi)
    return path
