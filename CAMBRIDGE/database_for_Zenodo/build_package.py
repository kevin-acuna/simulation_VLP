"""Builds upload/, the folder whose files are uploaded to Zenodo, from the original acquisition sessions.

The sessions are only read, never modified. upload/ receives:
  README.md, LICENSE.txt, example_load_data.py, example_load_data.m, read_npz.m   (from static/)
  D1_calibration_scan_RSS.csv, D2_grid_RSS.csv, D3_blind_test_RSS.csv            (one row per record)
  D1_calibration_scan_tables.zip, D1_calibration_scan_waveforms_part<i>of4.zip,
  D2_grid.zip, D3_blind_test.zip, R_repeated_records.zip                         (session folders)
  checksums.md5
The archives (about 10 GB) are kept when they already exist, unless --force; the text files, the RSS tables and
the checksums are always rewritten, so that a change in the block below only takes a minute.
Usage: python build_package.py [--force]
"""
import argparse
import csv
import hashlib
import io
import json
import math
import time
import zipfile
from collections import defaultdict
from datetime import date
from pathlib import Path

# ----------------------------------------------------------------------------- to complete before the upload
TITLE = "Single-LED 3-D Visible Light Positioning With a Reorientable Photodiode: Measured RSS and Raw Waveforms"
VERSION = "1.0"
DOI = ""                       # DOI reserved in the Zenodo draft, e.g. "10.5281/zenodo.1234567"
CREATORS = "Acuña-Condori, K., TODO: co-authors"        # authors of the dataset, as in the Zenodo record
ARTICLE = ('TODO: authors, "3-D Visible Light Positioning With a Single LED and a Single Reorientable '
           'Photodiode: Bounds, Calibration, and Experimental Validation," TODO: journal, year, DOI.')
ACKNOWLEDGEMENTS = "TODO: laboratory where the data were acquired, funding."
CONTACT = "TODO: name and e-mail address of the contact person."
# ----------------------------------------------------------------------------- package
D1_RECORDS_PER_PART = 5000     # raw waveforms of D1 per archive (about 2.3 GB each)
STAGE_ZERO_DEG = 66.5          # calibrated stage zero alpha_0 of the article (normals of the RSS tables)
Z_OFFSET_M = 0.858 + 0.09696   # PD height at gantry z = 0: carriage height (measured) + PD elevation (CAD)
# removed from the published session.json: renaming history, scope settings restored after the session, time
# estimate of the plan, local paths, raw copy of the private testbed configuration, IP addresses, software limits
DROP_KEYS = ("former_name", "z_conversion", "scope_user_settings", "estimated_total_s", "estimate_breakdown",
             "settings_file")
DROP_TESTBED_KEYS = ("config_file", "config")
DROP_DEVICE_KEYS = ("ip", "port", "address", "workspace_min_mm", "workspace_max_mm")
# -----------------------------------------------------------------------------

HERE = Path(__file__).resolve().parent
CAMBRIDGE = HERE.parent
ACQ = CAMBRIDGE / "database_acquisition" / "data"
DEMO = CAMBRIDGE / "demo" / "data"
STATIC = HERE / "static"
OUT = HERE / "upload"
FREQS_KHZ = (300, 500, 700, 900)

# dataset folder -> sessions (source folder, last position kept, None = all); only complete positions (all K
# orientations) are kept. D3 = the 131 positions of the article: 1-47 of the first session, all of the second.
DATASETS = {
    "D1_calibration_scan": [
        (ACQ / "campaign_20261013-182008_grid141x141x1-xy0to1400-s10-z180_K1-off65_pd0_tilt0_100ms", None)],
    "D2_grid": [
        (ACQ / "campaign_20261014-185628_grid5x5x2-xy100to1300-s300-z180to360_K10-off65_pd15_tilt0_100ms", None),
        (ACQ / "campaign_20261015-000723_grid5x5x3-xy100to1300-s300-z0to120_K10-off65_pd15_tilt0_100ms", None)],
    "D3_blind_test": [
        (DEMO / "demo_20261016-113422_random-xy100to1300-z0to360_K5-off65_pd15_tilt0_100ms", 47),
        (DEMO / "demo_20261016-174621_random-xy100to1300-z0to360_K5-off65_pd15_tilt0_100ms", None)],
    "R_repeated_records": [
        (ACQ / "campaign_20261013-101402_grid5x5x1-xy100to1300-s300-z180_K1-off65_pd0_tiltU-1to1_100msx2", None),
        (ACQ / "campaign_20261013-103703_grid5x5x1-xy100to1300-s300-z180_K1-off65_pd0_tiltU-2to2_100msx10", None),
        (ACQ / "campaign_20261013-113114_grid5x5x1-xy100to1300-s300-z180_K1-off65_pd0_tiltU-1to1_100msx5", None)],
}
RSS_TABLES = {"D1_calibration_scan": ("D1: position, orientation and RSS of the four LEDs, one row per record",
                                      FREQS_KHZ),
              "D2_grid": ("D2: position, orientation and RSS of the four LEDs, one row per record", FREQS_KHZ),
              "D3_blind_test": ("D3: position, orientation and RSS of the 500 kHz LED, one row per record", (500,))}
ARCHIVES = {"D2_grid": "D2, two sessions: tables and raw waveforms",
            "D3_blind_test": "D3, two sessions: tables (with the live estimates) and raw waveforms",
            "R_repeated_records": "R, three sessions: tables and raw waveforms"}
STATIC_FILES = {"LICENSE.txt": "License (CC BY 4.0)",
                "example_load_data.py": "Example in Python: read a table and a raw waveform, recompute the RSS",
                "example_load_data.m": "The same example in MATLAB",
                "read_npz.m": "Reader of the `.npz` waveforms for MATLAB"}


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return list(reader.fieldnames), list(reader)


def csv_bytes(fields, rows):
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=fields, lineterminator="\n", extrasaction="ignore")
    writer.writeheader()
    writer.writerows(rows)
    return buf.getvalue().encode("utf-8")


def clean_session(info, kept):
    """Published copy of session.json (DROP_* lists); for D3, the counts of the published positions."""
    info = {k: v for k, v in info.items() if k not in DROP_KEYS}
    if "testbed" in info:
        info["testbed"] = {k: ({kk: vv for kk, vv in v.items() if kk not in DROP_DEVICE_KEYS}
                               if isinstance(v, dict) else v)
                           for k, v in info["testbed"].items() if k not in DROP_TESTBED_KEYS}
    if info.get("tool") == "vlp_demo":          # the live summary and the end time referred to the whole session
        info.pop("summary", None)
        info.pop("end", None)
        info["n_measurements"] = len(kept)
        info["n_points"] = len({r["site_id"] for r in kept})
    return (json.dumps(info, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def load_session(src, last_site):
    """Published content of a session: {name: bytes} of its tables, kept rows of points.csv, waveform paths."""
    fields, rows = read_csv(src / "points.csv")
    info = json.loads((src / "session.json").read_text(encoding="utf-8"))
    K = (info.get("plan_config") or info["config"])["k_angles"]
    orientations = defaultdict(set)
    for r in rows:
        orientations[r["site_id"]].add(r["k"])
    kept = [r for r in rows
            if len(orientations[r["site_id"]]) == K and (last_site is None or int(r["site_id"]) <= last_site)]
    tables = {"points.csv": csv_bytes([f for f in fields if f != "fft_file"], kept)}
    for name in ("plan.csv", "trajectory.csv"):
        if (src / name).exists():
            tables[name] = (src / name).read_bytes()
    if (src / "estimates.csv").exists():
        efields, erows = read_csv(src / "estimates.csv")
        sites = {r["site_id"] for r in kept}
        tables["estimates.csv"] = csv_bytes(efields, [r for r in erows if r["point_id"] in sites])
    tables["session.json"] = clean_session(info, kept)
    return tables, kept, [src / r["wave_file"] for r in kept]


def rss_rows(session, kept, freqs):
    """Rows of an RSS table: position of the PD centre (m), stage angle, PD normal and RSS of each record."""
    out = []
    for r in kept:
        t, a = math.radians(float(r["pd_tilt_deg"])), math.radians(float(r["angle_deg"]) - STAGE_ZERO_DEG)
        n = (math.sin(t) * math.sin(a), math.sin(t) * math.cos(a), math.cos(t))
        out.append({"session": session, "site_id": r["site_id"], "k": r["k"], "meas_id": r["meas_id"],
                    "X_m": f"{float(r['x_cmd_mm']) / 1e3:.5f}", "Y_m": f"{float(r['y_cmd_mm']) / 1e3:.5f}",
                    "Z_m": f"{Z_OFFSET_M + float(r['z_cmd_mm']) / 1e3:.5f}", "alpha_deg": r["angle_deg"],
                    **{c: f"{round(v, 6) + 0.0:.6f}" for c, v in zip(("nx", "ny", "nz"), n)},
                    **{f"rss_{f}kHz_V": r[f"{f}kHz_wave_Vrms"] for f in freqs},
                    "unix_time_s": r["unix_time_s"]})
    return out


def human(n):
    for unit in ("B", "kB", "MB", "GB"):
        if n < 1000 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1000


def write_zip(path, entries, force):
    """Archive of [(name in the archive, bytes or source Path, mtime)]: the .npz waveforms are stored as they are
    (already compressed), the tables are deflated. Written to a .part file, renamed when complete."""
    if path.exists() and not force:
        print(f"  {path.name}: exists, kept (--force rebuilds it)")
        return
    tmp = path.with_name(path.name + ".part")
    t0 = time.time()
    with zipfile.ZipFile(tmp, "w", allowZip64=True) as zf:
        for name, data, mtime in entries:
            if isinstance(data, Path):
                zf.write(data, name, compress_type=zipfile.ZIP_STORED)
            else:
                info = zipfile.ZipInfo(name, date_time=time.localtime(mtime)[:6])
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o644 << 16
                zf.writestr(info, data)
    tmp.replace(path)
    print(f"  {path.name}: {len(entries)} files, {human(path.stat().st_size)} ({time.time() - t0:.0f} s)")


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 22), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser(description="Builds the Zenodo upload folder (upload/).")
    parser.add_argument("--force", action="store_true", help="rebuild the archives that already exist")
    args = parser.parse_args()
    missing = [str(src) for sessions in DATASETS.values() for src, _ in sessions if not (src / "points.csv").exists()]
    if missing:
        raise SystemExit("Missing sessions:\n  " + "\n  ".join(missing))
    OUT.mkdir(exist_ok=True)
    for stale in OUT.glob("*.part"):
        stale.unlink()

    archives = []
    for dataset, sessions in DATASETS.items():
        print(dataset)
        rss, tables, waves = [], [], []
        for src, last_site in sessions:
            content, kept, wave_files = load_session(src, last_site)
            mtime = (src / "points.csv").stat().st_mtime
            tables += [(f"{dataset}/{src.name}/{name}", data, mtime) for name, data in content.items()]
            waves += [(f"{dataset}/{src.name}/wave/{w.name}", w, None) for w in wave_files]
            if dataset in RSS_TABLES:
                rss += rss_rows(src.name, kept, RSS_TABLES[dataset][1])
            print(f"  {src.name}: {len({r['site_id'] for r in kept})} positions, {len(kept)} rows of points.csv")
        if rss:
            (OUT / f"{dataset}_RSS.csv").write_bytes(csv_bytes(list(rss[0]), rss))
        if dataset == "D1_calibration_scan":
            name = f"{dataset}_tables.zip"
            write_zip(OUT / name, tables, args.force)
            archives.append((name, "D1 session: points.csv, plan.csv, trajectory.csv, session.json"))
            parts = [waves[i:i + D1_RECORDS_PER_PART] for i in range(0, len(waves), D1_RECORDS_PER_PART)]
            for i, part in enumerate(parts, 1):
                name = f"{dataset}_waveforms_part{i}of{len(parts)}.zip"
                write_zip(OUT / name, part, args.force)
                first, last = (int(Path(part[j][0]).stem[1:]) for j in (0, -1))
                archives.append((name, f"D1 raw waveforms, records {first} to {last}"))
        else:
            write_zip(OUT / f"{dataset}.zip", tables + waves, args.force)
            archives.append((f"{dataset}.zip", ARCHIVES[dataset]))

    for name in STATIC_FILES:
        (OUT / name).write_bytes((STATIC / name).read_bytes())
    catalog = ([("README.md", "This description")] + [(f"{d}_RSS.csv", v[0]) for d, v in RSS_TABLES.items()]
               + archives + list(STATIC_FILES.items()) + [("checksums.md5", "MD5 checksums of all the other files")])
    table = ["| File | Size | Content |", "|---|---|---|"]
    for name, text in catalog:
        size = "" if name in ("README.md", "checksums.md5") else human((OUT / name).stat().st_size)
        table.append(f"| `{name}` | {size} | {text} |")
    doi_link = f"[https://doi.org/{DOI}](https://doi.org/{DOI})" if DOI else "TODO: DOI reserved on Zenodo"
    readme = (STATIC / "README.md").read_text(encoding="utf-8")
    for key, value in {"TITLE": TITLE, "VERSION": VERSION, "DOI_LINK": doi_link, "ARTICLE": ARTICLE,
                       "CREATORS": CREATORS, "YEAR": str(date.today().year), "ACKNOWLEDGEMENTS": ACKNOWLEDGEMENTS,
                       "CONTACT": CONTACT, "FILES": "\n".join(table)}.items():
        readme = readme.replace("{" + key + "}", value)
    (OUT / "README.md").write_bytes(readme.encode("utf-8"))

    expected = {name for name, _ in catalog}
    extra = sorted(p.name for p in OUT.iterdir() if p.name not in expected)
    if extra:
        print("WARNING, files in upload/ that are not part of the package (remove them): " + ", ".join(extra))
    names = sorted(name for name in expected if name != "checksums.md5")
    (OUT / "checksums.md5").write_bytes("".join(f"{md5(OUT / n)}  {n}\n" for n in names).encode("utf-8"))
    total = sum((OUT / n).stat().st_size for n in expected)
    print(f"upload/: {len(expected)} files, {human(total)}. Next: python check_package.py")


if __name__ == "__main__":
    main()
