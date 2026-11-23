"""Minimal example: read an RSS table, read the raw waveform of one record and recompute its RSS.

Run it from the folder that holds the downloaded files, with the archives extracted in the same folder:
    python example_load_data.py
Requires Python 3.8 or later and NumPy.
"""
import csv
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent          # folder with the *_RSS.csv files and the extracted archives
FREQS_KHZ = (300, 500, 700, 900)                # nominal modulation frequencies of the four LEDs


def read_table(name):
    with open(ROOT / name, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def read_waveform(path):
    """Records of a wave/*.npz file in volts (one row per record) and the sample rate in Sa/s."""
    z = np.load(path)
    v = (z["codes"] - z["y_reference"][:, None]) * z["y_increment"][:, None] + z["y_origin"][:, None]
    return v, float(z["fs"])


def rss(v, fs, f):
    """RSS (V rms) of the tone at f in each record: digital lock-in over the whole record."""
    n = np.arange(v.shape[1])
    x = v - v.mean(axis=1, keepdims=True)
    return np.sqrt(2) * np.abs(x @ np.exp(-2j * np.pi * f * n / fs)) / v.shape[1]


rows = read_table("D2_grid_RSS.csv")
print(f"D2: {len(rows)} records at {len({(r['session'], r['site_id']) for r in rows})} positions")
r = rows[0]
print(f"First record: X = {r['X_m']} m, Y = {r['Y_m']} m, Z = {r['Z_m']} m, stage angle {r['alpha_deg']} deg, "
      f"PD normal ({r['nx']}, {r['ny']}, {r['nz']})")

wave = ROOT / "D2_grid" / r["session"] / "wave" / f"m{int(r['meas_id']):05d}.npz"
if not wave.exists():
    raise SystemExit(f"{wave} not found: extract D2_grid.zip into {ROOT} to read the raw waveforms.")
v, fs = read_waveform(wave)
print(f"Raw waveform: {v.shape[1]} samples at {fs / 1e6:g} MSa/s")
for f in FREQS_KHZ:
    print(f"  {f} kHz LED: RSS recomputed {rss(v, fs, f * 1e3)[0]:.6g} V, in the table {r[f'rss_{f}kHz_V']} V")
