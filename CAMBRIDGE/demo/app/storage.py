"""
storage.py - Files of a demo session (output_root/demo_<date>_<region>_K.._pd.._tilt.._<record>[_label]/,
same folder-name format as database_acquisition: hardware/utils.py).

  points.csv     one row per orientation, same columns as database_acquisition (the MATLAB analysis
                 reads it unchanged); site_id = point number
  estimates.csv  one row per point: true and estimated PD position, errors, status
  wave/mNNNNN.npz raw waveforms (optional, lossless ADC codes as in database_acquisition)
  session.json   interface configuration, positioning hyperparameters, devices, final status
"""

import csv
import json
import math
import os
from datetime import datetime

import numpy as np

from hardware.utils import folder_name, name_span, name_tail, name_xy, unique_dir

POINT_FIELDS_HEAD = ["meas_id", "pass", "site_id", "ix", "iy", "iz", "k", "iso_time", "unix_time_s",
                     "x_cmd_mm", "y_cmd_mm", "z_cmd_mm", "angle_cmd_deg", "mtrs_tilt_cmd_deg",
                     "x_mm", "y_mm", "z_mm", "angle_deg", "mtrs_tilt_deg", "pd_tilt_deg"]
POINT_FIELDS_TAIL = ["pos_err_mm", "angle_err_deg", "n_acq", "clip_frac", "wave_ac_rms_V", "fft_file", "wave_file"]
ESTIMATE_FIELDS = ["point_id", "iso_time", "K", "status", "estimator", "pd_response",
                   "x_cmd_mm", "y_cmd_mm", "z_cmd_mm", "true_X_m", "true_Y_m", "true_Z_m",
                   "est_X_m", "est_Y_m", "est_Z_m", "est_gantry_z_mm", "err_X_cm", "err_Y_cm", "err_Z_cm",
                   "err_3d_cm", "err_h_cm", "err_dir_deg", "err_range_cm", "distance_m", "amplitude_V",
                   "fit_rms_pct", "angles_deg", "rss_V", "mtrs_tilt_cmd_deg", "mtrs_tilts_deg"]


def freq_label(f_hz):
    return f"{f_hz / 1e3:g}kHz"


def _clean(obj):
    if isinstance(obj, dict):
        return {k: _clean(v) for k, v in obj.items() if not k.startswith("_")}
    if isinstance(obj, (list, tuple)):
        return [_clean(v) for v in obj]
    if isinstance(obj, float) and not math.isfinite(obj):
        return None
    if isinstance(obj, np.generic):
        return obj.item()
    return obj


def demo_name(config, nominal_offset, pd_tilt, when=None):
    """Folder name in the format of the acquisition tools (hardware/utils.py), e.g.
    demo_20261016-113422_random-xy100to1300-z0to360_K5-off65_pd15_tilt0_100ms"""
    c = config
    where = "manual" if c.get("mode") == "manual" else (
        f"random-{name_xy(c['region_x'], c['region_y'])}-z{name_span(*c['region_z'])}")
    tail = name_tail(c["k_angles"], nominal_offset, pd_tilt, c.get("mtrs_tilt_mode", "fixed"), c.get("mtrs_tilt_deg", 0.0),
                     c.get("mtrs_tilt_min_deg", 0.0), c.get("mtrs_tilt_max_deg", 0.0), c.get("record_ms", 0.0),
                     c.get("n_samples", 1), 1, c.get("label", ""))
    return folder_name("demo", when, where, tail)


class Session:
    def __init__(self, output_root, config, freqs_hz, meta):
        name = demo_name(config, meta.get("nominal_offset_deg", 0.0), meta.get("positioning", {}).get("pd_tilt_deg", 0.0))
        self.dir = unique_dir(output_root, name)
        os.makedirs(self.dir, exist_ok=True)
        if config["save_waveforms"]:
            os.makedirs(os.path.join(self.dir, "wave"), exist_ok=True)
        self.config, self.freqs_hz, self.meta = config, freqs_hz, meta
        self.start = datetime.now().isoformat()
        self.point_fields = POINT_FIELDS_HEAD + [c for f in freqs_hz for c in
                                                 (f"{freq_label(f)}_fft_Vrms", f"{freq_label(f)}_wave_Vrms")] \
            + POINT_FIELDS_TAIL
        self._header("points.csv", self.point_fields)
        self._header("estimates.csv", ESTIMATE_FIELDS)
        self.n_meas = self.n_points = 0
        self.write_json("RUNNING")

    def _header(self, name, fields):
        with open(os.path.join(self.dir, name), "w", newline="") as f:
            csv.writer(f).writerow(fields)

    def _append(self, name, fields, row):
        with open(os.path.join(self.dir, name), "a", newline="") as f:
            csv.DictWriter(f, fieldnames=fields).writerow(row)

    def write_measurement(self, row, acqs=None):
        """row: dict with the points.csv fields (missing ones left empty). Returns the measurement id."""
        self.n_meas += 1
        row = {**row, "meas_id": self.n_meas, "pass": 1, "ix": 0, "iy": 0, "iz": 0, "fft_file": "",
               "iso_time": datetime.now().isoformat(timespec="seconds")}
        if acqs is not None and self.config["save_waveforms"]:
            row["wave_file"] = self._save_wave(f"m{self.n_meas:05d}", acqs)
        self._append("points.csv", self.point_fields, row)
        return self.n_meas

    def _save_wave(self, tag, acqs):
        path = f"wave/{tag}.npz"
        n_t = min(a["v"].size for a in acqs)
        common = {"fs": acqs[0]["fs"], "unix": np.array([a["unix"] for a in acqs])}
        if all("codes" in a for a in acqs):
            sc = np.array([a["scale"] for a in acqs])
            np.savez_compressed(os.path.join(self.dir, path), codes=np.array([a["codes"][:n_t] for a in acqs]),
                                y_increment=sc[:, 0], y_origin=sc[:, 1], y_reference=sc[:, 2], **common)
        else:
            np.savez_compressed(os.path.join(self.dir, path),
                                v=np.array([a["v"][:n_t] for a in acqs], dtype=np.float32), **common)
        return path

    def write_estimate(self, point, res, meta):
        self.n_points += 1
        f = lambda v, k=1.0, nd=6: "" if v is None or not math.isfinite(v) else f"{v * k:.{nd}g}"   # noqa: E731
        est = res.get("est_m") or [None] * 3
        err = res.get("err_m") or [None] * 3
        row = {"point_id": point["id"], "iso_time": datetime.now().isoformat(timespec="seconds"), "K": res["K"],
               "status": res["status"], "estimator": meta["estimator"], "pd_response": meta["pd_response"],
               "x_cmd_mm": point["target"][0], "y_cmd_mm": point["target"][1], "z_cmd_mm": point["target"][2],
               **{f"true_{a}_m": f(v) for a, v in zip("XYZ", res["true_m"])},
               **{f"est_{a}_m": f(v) for a, v in zip("XYZ", est)},
               **{f"err_{a}_cm": f(v, 100) for a, v in zip("XYZ", err)},
               "est_gantry_z_mm": f(res.get("est_gantry_z_mm")), "err_3d_cm": f(res.get("err_3d_m"), 100),
               "err_h_cm": f(res.get("err_h_m"), 100), "err_dir_deg": f(res.get("err_dir_deg")),
               "err_range_cm": f(res.get("err_range_m"), 100), "distance_m": f(res.get("distance_m")),
               "amplitude_V": f(res.get("amplitude_V")), "fit_rms_pct": f(res.get("fit_rms_pct")),
               "angles_deg": " ".join(f"{a:.4f}" for a in point["meas_angles"]),
               "rss_V": " ".join(f"{v:.6g}" for v in point["rss_V"]),
               "mtrs_tilt_cmd_deg": point.get("tilt_cmd", 0.0),
               "mtrs_tilts_deg": " ".join(f"{v:.4f}" for v in point.get("meas_tilts", []) if v is not None)}
        self._append("estimates.csv", ESTIMATE_FIELDS, row)

    def write_json(self, status, extra=None):
        data = {"tool": "vlp_demo", "status": status, "start": self.start,
                "end": datetime.now().isoformat() if status != "RUNNING" else None,
                "n_measurements": self.n_meas, "n_points": self.n_points,
                "frequencies_Hz": self.freqs_hz, "config": self.config, **self.meta, **(extra or {})}
        with open(os.path.join(self.dir, "session.json"), "w") as f:
            json.dump(_clean(data), f, indent=2, default=str)
