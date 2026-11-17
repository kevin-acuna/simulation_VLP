"""Figures of one processed capture (no instrument access): received record and OFDM constellation."""

import numpy as np

TONE_OK, TONE_BAD, OFDM = "tab:green", "tab:red", "tab:blue"


def envelope(y, fs, max_points=3000):
    """(t_ms, min, max) of the record in blocks (keeps the peaks when drawing millions of samples)."""
    y = np.asarray(y)
    step = max(1, y.size // max_points)
    n = y.size // step * step
    blocks = y[:n].reshape(-1, step)
    return np.arange(blocks.shape[0]) * step / fs * 1e3, blocks.min(axis=1), blocks.max(axis=1)


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


def show_capture(state, title=""):
    import matplotlib.pyplot as plt

    fig = plt.figure(title or "ISAC capture", figsize=(12, 4.5))
    ax_w = fig.add_axes([0.06, 0.14, 0.62, 0.76])
    ax_c = fig.add_axes([0.72, 0.14, 0.26, 0.76])
    draw_capture(ax_w, state)
    draw_constellation(ax_c, state)
    s = state["summary"]
    ax_w.set_title(f"Pilot {s['ToneRMS_mV']:.4g} mVrms | BER {s['OriginalBER']:.3g} (averaged {s['AveragedBER']:.3g}) | "
                   f"frames {s['AcceptedFrames']} accepted, {s['RejectedFrames']} rejected", fontsize=10)
    return fig
