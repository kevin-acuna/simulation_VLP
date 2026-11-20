"""Session folder of an ISAC acquisition: raw records, tables (CSV) and results.xlsx.

    <root>/isac_<YYYYmmdd-HHMMSS>[_<label>]/
      session.json        hyperparameters, devices, prepared waveform, instruments, final status
      experiment.npz      prepared experiment (OFDM packet + plan): needed to re-process the raw records
      transmission.npz    AWG load / reuse metadata
      captures.csv        one row per capture: pose + pilot tone (Vrms) + communication (BER, EVM, frames)
      tone_windows.csv    one row per pilot window of every capture
      ofdm_slots.csv      one row per OFDM slot (one per complete cycle) of every capture
      results.xlsx        the three tables (sheets captures / tone_windows / ofdm_slots) + a "session" sheet
      wave/cNNNNN.npz     raw oscilloscope record of capture NNNNN (WORD codes + scale, lossless)
      figures/cNNNNN.png  record, spectrum and constellation of capture NNNNN (when figures are saved)

The CSV files are written row by row (they survive a crash); results.xlsx is rebuilt from them. If it is open
in Excel it cannot be replaced: the program warns and updates it when it is closed again.
"""

import csv
import json
import math
import os
from datetime import datetime
from pathlib import Path

import numpy as np

from .common import load_record, now_iso, save_record, signature

ID_COLUMNS = ["capture_id", "iso_time", "unix_time_s", "mode"]
POSE_COLUMNS = ["site_id", "k", "rep", "x_cmd_mm", "y_cmd_mm", "z_cmd_mm", "angle_cmd_deg", "tilt_cmd_deg",
                "x_mm", "y_mm", "z_mm", "angle_deg", "tilt_deg", "pos_err_mm", "angle_err_deg", "pos_drift_mm",
                "move_time_s"]
TONE_COLUMNS = ["tone_freq_Hz", "tone_Vrms", "tone_Vrms_mean", "tone_Vrms_std", "snr_pilot_dB", "tone_windows_valid",
                "tone_windows", "tone_purity_min", "tone_dc_V"]
RATE_COLUMNS = ["goodput_Mbps", "goodput_frames_Mbps", "goodput_avg_Mbps", "goodput_cycle_Mbps", "rate_nominal_Mbps",
                "rate_nominal_cycle_Mbps", "shannon_est_Mbps"]
COMM_COLUMNS = ["ber", "bit_errors", "ber_avg", "bit_errors_avg", "n_bits", "evm_pct", "snr_comm_dB",
                "frames_accepted", "frames_rejected", "frames_expected", "cycles_complete", "cycles_timing_ok",
                "timing_ok", "ofdm_target_met", "isac_ok", "reason"]
RECORD_COLUMNS = ["fs_Sa_s", "n_points", "duration_ms", "wave_mean_V", "wave_min_V", "wave_max_V", "wave_file",
                  "error"]
CAPTURE_COLUMNS = ID_COLUMNS + POSE_COLUMNS + TONE_COLUMNS + RATE_COLUMNS + COMM_COLUMNS + RECORD_COLUMNS
WINDOW_COLUMNS = ["capture_id", "window", "cycle", "start_ms", "duration_ms", "n_samples", "tone_Vrms", "dc_V",
                  "purity", "peak_freq_Hz", "accepted", "valid", "status"]
SLOT_COLUMNS = ["capture_id", "cycle", "tone_start_ms", "tone_ms", "ofdm_ms", "cycle_ms", "timing_ok",
                "frames_expected", "frames_located", "frames_accepted", "frames_rejected", "n_bits", "bit_errors",
                "ber", "bit_errors_avg", "ber_avg", "evm_pct", "goodput_Mbps", "goodput_frames_Mbps", "reason"]
TABLES = {"captures": CAPTURE_COLUMNS, "tone_windows": WINDOW_COLUMNS, "ofdm_slots": SLOT_COLUMNS}


def _finite(v):
    return v is not None and not (isinstance(v, float) and not math.isfinite(v))


def _num(v, scale=1.0):
    """Float (scaled) or None for missing / non-finite values."""
    try:
        v = float(v) * scale
    except (TypeError, ValueError):
        return None
    return v if math.isfinite(v) else None


def pilot_snr_db(state):
    """20 log10(pilot RMS / predicted std of its estimate) of the first valid pilot window (see rates)."""
    pos = state["positionInput"]
    if pos is None:
        return None
    cap = state["capture"]
    fs, n = float(cap["FsCapture"]), int(pos["nSamples"])
    first = int(round(pos["windowStart_s"] * fs))
    seg = np.asarray(cap["YData"][first:first + n], dtype=float)
    w = np.hanning(seg.size)
    psd = np.abs(np.fft.rfft((seg - seg.mean()) * w)) ** 2 * 2 / (fs * np.sum(w**2))
    df = np.abs(np.fft.rfftfreq(seg.size, 1 / fs) - state["cfg"]["toneFrequencyHz"])
    n0 = np.median(psd[(df > 3e3) & (df < 100e3)]) / math.log(2)        # mean of chi2(2) bins = median / ln 2
    return float(20 * math.log10(pos["rms_V"] / math.sqrt(n0 / (2 * seg.size / fs))))


def rates(state):
    """Pilot / communication SNR and bit rates of a processed capture [dB, Mb/s].

    snr_pilot_dB       20 log10(pilot RMS / sigma) of the first valid pilot window, sigma = sqrt(N0 / 2T) = std of a
                       least-squares amplitude over the window T in white noise of one-sided density N0 (N0 = median
                       level within +/-100 kHz of the pilot, +/-3 kHz excluded). Same definition as RSS / sigma; the
                       measured spread over the 3-4 windows of one capture is tone_Vrms_std
    snr_comm_dB        -20 log10(EVM): effective SNR of the demodulated payload symbols (noise, interference,
                       quantization and channel-estimation error included)
    rate_nominal_Mbps  payload bits / frame duration = rate while the OFDM slot is on (ICS NominalOFDMslotPayload)
    rate_nominal_cycle_Mbps   the same averaged over the whole cycle (ICS NominalCyclePayload)
    goodput_Mbps       correctly decoded payload bits (original decisions) / duration of all the expected frames:
                       rejected frames count as 0 bits; goodput_cycle_Mbps = averaged over the cycle;
                       goodput_avg_Mbps = the same with the training-averaged decisions
    goodput_frames_Mbps  frame (packet) goodput: payload of the accepted frames WITHOUT any bit error / duration of
                       all the expected frames (no FEC: a frame with one wrong bit is lost)
    shannon_est_Mbps   ESTIMATE, not measured: same frame structure with log2(1 + SNR) bits per carrier
    """
    r, p, packet = state.get("result", {}), state["plan"], state["packet"]
    evm = _num(r.get("EVM"))
    snr = 1.0 / evm**2 if evm else None
    duty = p["communicationDuration_s"] / p["cycleDuration_s"]
    nominal = p["nominalPayloadRate_bps"] / 1e6
    expected = r.get("expectedFrames", 0)
    good = good_avg = good_frames = None
    if expected:
        ok = sum(1 for f in r.get("frameResults", []) if f.get("accepted") and f.get("bitErrors") == 0)
        good_frames = ok * packet["payloadBitCount"] / (expected * p["ofdmFrameDuration_s"]) / 1e6
        errors = _num(r.get("bitErrors")) or 0.0
        good = (r.get("nBits", 0) - errors) / (expected * p["ofdmFrameDuration_s"]) / 1e6
        a = state["receiverAverage"]
        if a.get("available"):
            good_avg = (a["nBits"] - a["bitErrors"]) / (expected * p["ofdmFrameDuration_s"]) / 1e6
    elif state["analysisOK"]:
        good = good_frames = 0.0
    return dict(
        snr_pilot_dB=pilot_snr_db(state),
        snr_comm_dB=10 * math.log10(snr) if snr else None,
        rate_nominal_Mbps=nominal, rate_nominal_cycle_Mbps=p["nominalCyclePayloadRate_bps"] / 1e6,
        goodput_Mbps=good, goodput_frames_Mbps=good_frames, goodput_avg_Mbps=good_avg, goodput_cycle_Mbps=None if good is None else good * duty,
        shannon_est_Mbps=nominal * math.log2(1 + snr) / packet["bitsPerCarrier"] if snr else None)


def isac_tables(state):
    """(capture columns, tone window rows, OFDM slot rows) of a processed capture (see experiment.process)."""
    r, a, cap = state.get("result", {}), state["receiverAverage"], state["capture"]
    pos = state["positionInput"]
    valid = [w["rms_V"] for w in state["windows"] if w.get("validLogical")]
    purity = [w["bandPurity"] for w in r.get("toneResults", []) if _finite(w.get("bandPurity"))]
    y = np.asarray(cap["YData"])
    row = dict(
        tone_freq_Hz=state["cfg"]["toneFrequencyHz"], tone_Vrms=pos["rms_V"] if pos else None,
        tone_Vrms_mean=float(np.mean(valid)) if valid else None,
        tone_Vrms_std=float(np.std(valid)) if len(valid) > 1 else None,
        tone_windows_valid=len(valid), tone_windows=len(r.get("toneResults", [])),
        tone_purity_min=min(purity) if purity else None,
        tone_dc_V=state["windows"][pos["selectedRow"] - 1]["dc_V"] if pos else None,
        ber=_num(r.get("BER")), bit_errors=_num(r.get("bitErrors")),
        ber_avg=_num(a.get("BER")) if a.get("available") else None,
        bit_errors_avg=_num(a.get("bitErrors")) if a.get("available") else None,
        n_bits=r.get("nBits", 0), evm_pct=_num(r.get("EVM"), 100), frames_accepted=r.get("acceptedFrames", 0),
        frames_rejected=r.get("rejectedFrames", 0), frames_expected=r.get("expectedFrames", 0),
        cycles_complete=r.get("completeCycles", 0), cycles_timing_ok=r.get("validTimingCycles", 0),
        timing_ok=bool(r.get("timingAccepted", False)), ofdm_target_met=bool(state["ofdmTargetMet"]),
        isac_ok=bool(state["combinedCriteriaMet"]),
        reason=state["analysisError"] or r.get("reason", ""),
        fs_Sa_s=cap["FsCapture"], n_points=y.size, duration_ms=1e3 * cap["durationSeconds"],
        wave_mean_V=float(y.mean()), wave_min_V=float(y.min()), wave_max_V=float(y.max()), **rates(state))
    windows = [dict(window=i + 1, cycle=w["cycleIndex"], start_ms=_num(w["windowStart_s"], 1e3),
                    duration_ms=_num(w["windowDuration_s"], 1e3), n_samples=w["nSamples"],
                    tone_Vrms=_num(w["rms_V"]), dc_V=_num(w["dc_V"]), purity=_num(w["bandPurity"]),
                    peak_freq_Hz=_num(w["peakFrequencyHz"]), accepted=bool(w["accepted"]),
                    valid=bool(w.get("validLogical", False)), status=w.get("validationStatus", w["reason"]))
               for i, w in enumerate(state["windows"] or r.get("toneResults", []))]
    averaged = {}
    for f in a.get("frameResults", []) if a.get("available") else []:
        e, n = averaged.get(f["Cycle"], (0, 0))
        averaged[f["Cycle"]] = (e + f["AveragedErrors"], n + f["Bits"])
    slots = []
    slot_s = state["plan"]["communicationFrames"] * state["plan"]["ofdmFrameDuration_s"]
    for s in r.get("slotResults", []):
        e_avg, n_avg = averaged.get(s["cycleIndex"], (None, 0))
        slots.append(dict(
            cycle=s["cycleIndex"], tone_start_ms=_num(s["toneStart_s"], 1e3),
            tone_ms=_num(s["toneDurationMeasured_s"], 1e3), ofdm_ms=_num(s["communicationDurationMeasured_s"], 1e3),
            cycle_ms=_num(s["cycleDurationMeasured_s"], 1e3), timing_ok=bool(s["timingAccepted"]),
            frames_expected=s["expectedFrames"], frames_located=s["framesLocated"],
            frames_accepted=s["acceptedFrames"], frames_rejected=s["rejectedFrames"], n_bits=s["nBits"],
            bit_errors=_num(s["bitErrors"]), ber=_num(s["BER"]), bit_errors_avg=e_avg,
            ber_avg=e_avg / n_avg if n_avg else None, evm_pct=_num(s["EVM"], 100),
            goodput_Mbps=(s["nBits"] - (s["bitErrors"] if s["nBits"] else 0)) / slot_s / 1e6,
            goodput_frames_Mbps=sum(1 for f in r.get("frameResults", []) if f["cycleIndex"] == s["cycleIndex"]
                                    and f.get("accepted") and f.get("bitErrors") == 0)
            * state["packet"]["payloadBitCount"] / slot_s / 1e6, reason=s["reason"]))
    return row, windows, slots


def save_wave(path, capture):
    """Raw oscilloscope record: WORD codes + scale (V = (codes - y_reference) * y_increment + y_origin)."""
    p = capture["preamble"]
    np.savez_compressed(path, codes=np.asarray(capture["codes"], dtype=np.uint16), fs=capture["FsCapture"],
                        x_increment=p["XIncrement"], x_origin=p["XOrigin"], x_reference=p["XReference"],
                        y_increment=p["YIncrement"], y_origin=p["YOrigin"], y_reference=p["YReference"],
                        preamble=capture["preambleText"], captured_at=capture["capturedAt"])


def load_experiment(session_dir):
    exp = load_record(Path(session_dir) / "experiment.npz")["experiment"]
    exp["signature"] = signature(exp)
    return exp


def load_capture(session_dir, capture_id, experiment=None):
    """Capture dictionary of a saved raw record, ready for isac.process(capture, experiment)."""
    experiment = experiment or load_experiment(session_dir)
    with np.load(Path(session_dir) / "wave" / f"c{int(capture_id):05d}.npz") as z:
        codes, fs = z["codes"], float(z["fs"])
        y = (codes.astype(float) - float(z["y_reference"])) * float(z["y_increment"]) + float(z["y_origin"])
        t = (np.arange(codes.size) - float(z["x_reference"])) * float(z["x_increment"]) + float(z["x_origin"])
        captured = str(z["captured_at"])
    return dict(YData=y, XData=t, codes=codes, FsCapture=fs, durationSeconds=(codes.size - 1) / fs,
                capturedAt=captured, experimentSignature=experiment["signature"], validForProcessing=True)


def _cell(v):
    if isinstance(v, (np.generic,)):
        v = v.item()
    return None if isinstance(v, float) and not math.isfinite(v) else v


def _csv_text(v):
    v = _cell(v)
    if v is None:
        return ""
    return f"{v:.10g}" if isinstance(v, float) else str(v)


class Session:
    def __init__(self, root, label, meta):
        name = f"isac_{datetime.now():%Y%m%d-%H%M%S}" + (f"_{label}" if label else "")
        name = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in name)
        path, i = Path(root) / name, 2
        while path.exists():
            path, i = Path(root) / f"{name}_{i}", i + 1
        self.dir = path
        (self.dir / "wave").mkdir(parents=True)
        self.meta = {"name": self.dir.name, "started": now_iso(), **meta, "n_captures": 0, "status": "running"}
        self.rows = {name: [] for name in TABLES}
        self.next_id = 1
        self.excel_warned = False
        self.write_meta()

    @property
    def excel_path(self):
        return self.dir / "results.xlsx"

    def write_meta(self, **updates):
        self.meta.update(updates)
        tmp = self.dir / "session.json.tmp"
        tmp.write_text(json.dumps(self.meta, indent=2, default=str), encoding="utf-8")
        os.replace(tmp, self.dir / "session.json")

    def figure_path(self, capture_id):
        (self.dir / "figures").mkdir(exist_ok=True)
        return self.dir / "figures" / f"c{int(capture_id):05d}.png"

    def save_experiment(self, experiment):
        save_record(self.dir / "experiment.npz", {"experiment": experiment})

    def add(self, row, capture=None, windows=(), slots=()):
        """Stores one capture: raw record (if any) + one row in captures and its windows / slots. Returns the id."""
        cid = self.next_id
        self.next_id += 1
        row = {**row, "capture_id": cid, "iso_time": row.get("iso_time") or now_iso()}
        if capture is not None:
            row["wave_file"] = f"wave/c{cid:05d}.npz"
            save_wave(self.dir / row["wave_file"], capture)
        self._append("captures", [row])
        self._append("tone_windows", [{"capture_id": cid, **w} for w in windows])
        self._append("ofdm_slots", [{"capture_id": cid, **s} for s in slots])
        self.write_meta(n_captures=len(self.rows["captures"]))
        return cid

    def _append(self, table, rows):
        if not rows:
            return
        columns = TABLES[table]
        path = self.dir / f"{table}.csv"
        new = not path.exists()
        with path.open("a", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            if new:
                w.writerow(columns)
            w.writerows([[_csv_text(r.get(c)) for c in columns] for r in rows])
        self.rows[table] += [{c: _cell(r.get(c)) for c in columns} for r in rows]

    def write_excel(self):
        """Rebuilds results.xlsx. Returns False if the file is open in another program."""
        from openpyxl import Workbook

        wb = Workbook(write_only=True)
        for table, columns in TABLES.items():
            ws = wb.create_sheet(table)
            ws.freeze_panes = "B2"
            ws.append(columns)
            for r in self.rows[table]:
                ws.append([r[c] for c in columns])
        ws = wb.create_sheet("session")
        ws.append(["key", "value"])
        for k, v in _flatten(self.meta):
            ws.append([k, v])
        tmp = self.dir / "results.xlsx.tmp"
        wb.save(tmp)
        try:
            os.replace(tmp, self.excel_path)
        except PermissionError:
            if not self.excel_warned:
                print(f"[Session] {self.excel_path.name} is open in another program: it will be updated after it "
                      f"is closed (the CSV files are always up to date).")
                self.excel_warned = True
            return False
        self.excel_warned = False
        return True

    def close(self, status):
        self.write_meta(status=status, finished=now_iso())
        self.write_excel()


def _flatten(d, prefix=""):
    for k, v in d.items():
        key = f"{prefix}{k}"
        if isinstance(v, dict):
            yield from _flatten(v, key + ".")
        elif isinstance(v, (list, tuple)):
            yield key, json.dumps(v, default=str)
        else:
            yield key, _cell(v) if isinstance(v, (int, float, bool, np.generic)) or v is None else str(v)
