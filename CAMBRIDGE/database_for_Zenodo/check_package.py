"""Checks upload/ before it is uploaded to Zenodo, reading only upload/: file list and Zenodo limits, checksums,
integrity of the archives, counts of every dataset, references between tables and raw waveforms, published
metadata (no local path or removed key), RSS tables against points.csv, RSS recomputed from raw waveforms,
columns documented in README.md, and the placeholders that remain to be completed.
Usage: python check_package.py [--quick]      (--quick skips the CRC test of the archives, about 10 GB)
"""
import argparse
import csv
import hashlib
import io
import json
import math
import random
import re
import zipfile
from collections import defaultdict
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent / "upload"
# dataset: (positions, rows of points.csv, single 100-ms records, sessions)
EXPECTED = {"D1_calibration_scan": (19881, 19881, 19881, 1), "D2_grid": (125, 1250, 1250, 2),
            "D3_blind_test": (131, 655, 655, 2), "R_repeated_records": (47, 47, 230, 3)}
FILES = ({"README.md", "LICENSE.txt", "checksums.md5", "example_load_data.py", "example_load_data.m", "read_npz.m",
          "D1_calibration_scan_RSS.csv", "D2_grid_RSS.csv", "D3_blind_test_RSS.csv", "D1_calibration_scan_tables.zip",
          "D2_grid.zip", "D3_blind_test.zip", "R_repeated_records.zip"}
         | {f"D1_calibration_scan_waveforms_part{i}of4.zip" for i in range(1, 5)})
REMOVED_KEYS = {"former_name", "z_conversion", "scope_user_settings", "estimated_total_s", "estimate_breakdown",
                "settings_file", "config_file", "kinesis_path", "ip", "address", "workspace_min_mm", "workspace_max_mm"}
LOCAL = re.compile(r"lisvuser|[A-Za-z]:\\\\|192\.168\.")
Z_OFFSET_M, STAGE_ZERO_DEG, FREQS_KHZ = 0.858 + 0.09696, 66.5, (300, 500, 700, 900)
failures, warnings = [], []


def check(ok, message):
    print(("  ok    " if ok else "  FAIL  ") + message)
    if not ok:
        failures.append(message)


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 22), b""):
            h.update(chunk)
    return h.hexdigest()


def table(data):
    reader = csv.DictReader(io.StringIO(data.decode("utf-8")))
    return list(reader.fieldnames), list(reader)


def keys(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield k
            yield from keys(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from keys(v)


def lockin(v, fs, f):
    n = np.arange(v.shape[1])
    x = v - v.mean(axis=1, keepdims=True)
    return np.sqrt(2) * np.abs(x @ np.exp(-2j * np.pi * f * n / fs)) / v.shape[1]


def main():
    parser = argparse.ArgumentParser(description="Checks the Zenodo upload folder (upload/).")
    parser.add_argument("--quick", action="store_true", help="skip the CRC test of the archives")
    args = parser.parse_args()

    print("Files")
    paths = sorted(OUT.iterdir())
    names = {p.name for p in paths}
    check(names == FILES, f"exactly the {len(FILES)} expected files"
          + ("" if names == FILES else f" (missing {sorted(FILES - names)}, extra {sorted(names - FILES)})"))
    check(all(p.is_file() for p in paths), "no sub-folders (Zenodo records are flat)")
    total = sum(p.stat().st_size for p in paths)
    check(len(paths) <= 100 and total <= 50e9, f"{len(paths)} files <= 100 and {total / 1e9:.2f} GB <= 50 GB")
    listed = {}
    for line in (OUT / "checksums.md5").read_text(encoding="utf-8").splitlines():
        digest, name = line.split("  ", 1)
        listed[name] = digest
    check(set(listed) == names - {"checksums.md5"}, "checksums.md5 lists every other file")
    bad = [n for n, d in listed.items() if (OUT / n).exists() and md5(OUT / n) != d]
    check(not bad, "MD5 checksums match" + (f" (differ: {bad})" if bad else ""))

    print("Archives")
    index, zips, duplicates = {}, {}, 0
    for p in paths:
        if p.suffix == ".zip":
            zf = zipfile.ZipFile(p)
            zips[p.name] = zf
            for name in zf.namelist():
                duplicates += name in index
                index[name] = zf
            if not args.quick:
                check(zf.testzip() is None, f"{p.name}: CRC of every member")
    members = list(index)
    check(not duplicates, "no file in two archives")
    check(all(not m.startswith(("/", "\\")) and ".." not in m and "\\" not in m for m in members),
          f"{len(members)} members with relative forward-slash paths")
    check(not [m for m in members if re.search(r"__MACOSX|\.DS_Store|Thumbs\.db|desktop\.ini", m)], "no hidden files")
    check({m.split("/")[0] for m in members} == set(EXPECTED), "top folders = the four datasets")

    print("Datasets")
    points = {}
    for dataset, (n_pos, n_rows, n_rec, n_sess) in EXPECTED.items():
        sessions = sorted({m.split("/")[1] for m in members if m.startswith(dataset + "/")})
        pos = rows = rec = 0
        waves_ref, waves_all = set(), {m for m in members if m.startswith(dataset + "/") and m.endswith(".npz")}
        for s in sessions:
            base = f"{dataset}/{s}/"
            info = json.loads(index[base + "session.json"].read(base + "session.json"))
            fields, pts = table(index[base + "points.csv"].read(base + "points.csv"))
            points[(dataset, s)] = {r["meas_id"]: r for r in pts}
            K = (info.get("plan_config") or info["config"])["k_angles"]
            ks = defaultdict(set)
            for r in pts:
                ks[r["site_id"]].add(r["k"])
            check(all(len(v) == K for v in ks.values()), f"{s[:24]}: every position has its K = {K} orientations")
            check("fft_file" not in fields, f"{s[:24]}: no fft_file column")
            text = json.dumps(info)
            found = sorted(REMOVED_KEYS & set(keys(info)))
            check(not found and not LOCAL.search(text), f"{s[:24]}: session.json without local paths or removed keys"
                  + (f" (found {found})" if found else ""))
            for name in ("plan.csv", "trajectory.csv") if dataset != "D3_blind_test" else ("estimates.csv",):
                check(base + name in index, f"{s[:24]}: {name} present")
            for name in (n for n in index if n.startswith(base) and n.endswith(".csv")):
                check(not LOCAL.search(index[name].read(name).decode("utf-8")), f"{name[len(dataset) + 1:][:24]}.../"
                      f"{name.rsplit('/', 1)[1]}: no local path")
            if dataset == "D3_blind_test":
                check("summary" not in info and "end" not in info and info["n_points"] == len(ks)
                      and info["n_measurements"] == len(pts), f"{s[:24]}: session counts = published positions")
                _, est = table(index[base + "estimates.csv"].read(base + "estimates.csv"))
                check({e["point_id"] for e in est} == set(ks), f"{s[:24]}: one estimate per position")
                points[(dataset, s, "estimates")] = est
            pos += len(ks)
            rows += len(pts)
            rec += sum(int(r["n_acq"]) for r in pts)
            waves_ref |= {base + r["wave_file"] for r in pts}
        check((pos, rows, rec, len(sessions)) == (n_pos, n_rows, n_rec, n_sess),
              f"{dataset}: {pos} positions, {rows} rows, {rec} records, {len(sessions)} sessions")
        check(waves_ref == waves_all, f"{dataset}: every waveform referenced by points.csv is present, none extra")
    est = [e for key, v in points.items() if len(key) == 3 for e in v]
    mean = sum(float(e["err_3d_cm"]) for e in est) / len(est)
    check(f"{mean:.2f}" == "4.10", f"D3: mean live error {mean:.4f} cm over {len(est)} positions (article: 4.10 cm)")

    print("RSS tables")
    for dataset, freqs in (("D1_calibration_scan", FREQS_KHZ), ("D2_grid", FREQS_KHZ), ("D3_blind_test", (500,))):
        fields, rows = table((OUT / f"{dataset}_RSS.csv").read_bytes())
        cols = (["session", "site_id", "k", "meas_id", "X_m", "Y_m", "Z_m", "alpha_deg", "nx", "ny", "nz"]
                + [f"rss_{f}kHz_V" for f in freqs] + ["unix_time_s"])
        check(fields == cols, f"{dataset}_RSS.csv: columns")
        n_pts = sum(len(v) for key, v in points.items() if key[0] == dataset and len(key) == 2)
        worst = 0.0
        mismatch = 0
        for r in rows:
            p = points[(dataset, r["session"])][r["meas_id"]]
            t, a = math.radians(float(p["pd_tilt_deg"])), math.radians(float(p["angle_deg"]) - STAGE_ZERO_DEG)
            n = (math.sin(t) * math.sin(a), math.sin(t) * math.cos(a), math.cos(t))
            xyz = (float(p["x_cmd_mm"]) / 1e3, float(p["y_cmd_mm"]) / 1e3, Z_OFFSET_M + float(p["z_cmd_mm"]) / 1e3)
            worst = max([worst] + [abs(float(r[c]) - v) for c, v in zip(("X_m", "Y_m", "Z_m", "nx", "ny", "nz"),
                                                                         xyz + n)])
            mismatch += any(r[f"rss_{f}kHz_V"] != p[f"{f}kHz_wave_Vrms"] for f in freqs) or \
                r["alpha_deg"] != p["angle_deg"] or r["site_id"] != p["site_id"] or r["k"] != p["k"] or \
                r["unix_time_s"] != p["unix_time_s"]
        check(len(rows) == n_pts and mismatch == 0 and worst < 1e-6,
              f"{dataset}_RSS.csv: {len(rows)} rows = points.csv (values identical, geometry within {worst:.1e})")

    print("RSS recomputed from raw waveforms (4 random records per dataset)")
    rng = random.Random(0)
    for dataset in EXPECTED:
        keys_ = [k for k in points if k[0] == dataset and len(k) == 2]
        worst = worst_std = 0.0
        shapes = True
        for _ in range(4):
            key = rng.choice(keys_)
            p = points[key][rng.choice(sorted(points[key]))]
            name = f"{dataset}/{key[1]}/{p['wave_file']}"
            z = np.load(io.BytesIO(index[name].read(name)))
            v = (z["codes"] - z["y_reference"][:, None]) * z["y_increment"][:, None] + z["y_origin"][:, None]
            shapes &= v.shape == (int(p["n_acq"]), 1000000) and float(z["fs"]) == 1e7
            for f in FREQS_KHZ:
                y = lockin(v, float(z["fs"]), f * 1e3)
                worst = max(worst, abs(y.mean() / float(p[f"{f}kHz_wave_Vrms"]) - 1))
                if v.shape[0] > 1:
                    worst_std = max(worst_std, abs(y.std() / float(p[f"{f}kHz_wave_Vrms_std"]) - 1))
            worst = max(worst, abs(v.std() / float(p["wave_ac_rms_V"]) - 1))
        check(shapes and worst < 2e-5 and worst_std < 6e-3,
              f"{dataset}: n_acq x 10^6 samples at 10 MSa/s; largest relative difference {worst:.1e} "
              f"(6 digits written)" + (f", std {worst_std:.1e} (3 digits)" if worst_std else ""))

    print("README.md")
    readme = (OUT / "README.md").read_text(encoding="utf-8")
    cols = set()
    for key, v in points.items():
        rows = v if len(key) == 3 else list(v.values())
        cols |= {re.sub(r"^\d+kHz_", "<f>kHz_", c) for c in rows[0]}
    for dataset in ("D1_calibration_scan", "D2_grid", "D3_blind_test"):
        cols |= {re.sub(r"^rss_\d+kHz_V$", "rss_<f>kHz_V", c) for c in table((OUT / f"{dataset}_RSS.csv")
                                                                             .read_bytes())[0]}
    undocumented = sorted(c for c in cols if f"`{c}`" not in readme)
    check(not undocumented, "every column of the tables is documented" + (f" (missing {undocumented})"
                                                                            if undocumented else ""))
    for i, line in enumerate(readme.splitlines(), 1):
        if "TODO" in line:
            warnings.append(f"README.md line {i}: {line.strip()[:110]}".encode("ascii", "replace").decode("ascii"))

    print()
    for w in warnings:
        print("  TO COMPLETE  " + w)
    print(f"\n{len(failures)} failure(s), {len(warnings)} placeholder(s) to complete.")
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
