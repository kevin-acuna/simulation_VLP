"""
convert_z_to_real_mm.py - One-off conversion (2026-10-28) of every dataset recorded BEFORE the gantry Z repair
of 2026-10-20 to the current gantry convention: z in real millimetres, positive upwards, z = 0 at the reference
(lowest photodetector position).

Before the repair the robot configuration had the Z GearScale of the small gantry model (166.067 instead of
276.778 counts/mm, ratio 0.600) and dirA3 = "0 0 -1": the recorded (commanded and measured) gantry z was
negative upwards and the PD really travelled 0.6 mm per recorded mm. Hence, exactly:

    z_real [mm] = -0.6 * z_recorded [mm]          (-600 -> 360, -300 -> 180, 0 -> 0)

Same physical position, new numbers: no analysis needs a z scale any more (PD height = base + z/1000 + elevation).

What is converted (exact decimal arithmetic, nothing else is touched):
  - CSV columns z_cmd_mm, z_mm, z_target_mm, est_gantry_z_mm (points, plan, trajectory, estimates)
  - "# z_mm: ..." header lines of the per-measurement fft/*.csv (and exp01 p*_fft.csv / p*_wave.csv)
  - session.json: plan_config.z, axes_mm.z, gantry workspace (z), [view] z_negative_up -> false, notes.z,
    demo config.region_z and positioning geometry, exp03 position_mm; a "z_conversion" record is added
  - folder names: the "-z<range>" part (e.g. z-600to-300 -> z180to360)
Waveforms (wave/*.npz) contain no position and are not touched.

Idempotent: datasets with a "z_conversion" record are skipped; loose CSV files (no session.json) are listed in
the manifest and refused if any z is positive (already converted). Originals: backed up BEFORE running, in
simulation_VLP_backups/2026-10-28_before_z_real_mm/.

    python convert_z_to_real_mm.py            # dry run: prints what would change
    python convert_z_to_real_mm.py --apply
"""

import argparse
import csv
import io
import json
import os
import re
import time
from decimal import Decimal

# ============================================================
# HYPERPARAMETERS
# ============================================================
CAMBRIDGE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATASET_ROOTS = ["database_acquisition/data", "demo/data", "testbed_dev/data/exp01", "testbed_dev/data/exp02",
                 "testbed_dev/data/exp03"]
ANALYSIS_DATASETS = ["analysis/Calibration", "analysis/Estimation_with_2LEDs", "analysis/Experiment_01_3D_estimation"]
LOOSE_CSV = ["analysis/Lambertian_order_LED_500khz/points.csv", "analysis/RSS_Distribution/points.csv"]
SKIP = ["campaign_20261021-170303"]      # simulated test (simulated gantry: no 0.6 factor to undo), left as is
FACTOR = Decimal("-0.6")
Z_COLUMNS = {"z_cmd_mm", "z_mm", "z_target_mm", "est_gantry_z_mm"}
HEADER_Z = re.compile(r"^(# (?:z_mm|z_cmd_mm|z_target_mm): *)(\S+)(.*)$")
NAME_Z = re.compile(r"-z(-?[0-9p]+)(?:to(-?[0-9p]+))?_")
REPAIR = "2026-10-20T15:00"             # robot configuration corrected in the afternoon of 2026-10-20
MANIFEST = os.path.join(CAMBRIDGE, "testbed_dev", "gantry_reparation", "z_conversion_manifest.json")
RECORD = {"date": "2026-10-28",
          "formula": "z [mm] = -0.6 x z as recorded",
          "reason": ("recorded before the gantry Z repair of 2026-10-20 (robot Z GearScale 166.067 instead of 276.778, "
                     "ratio 0.600, and Cartesian z negative upwards). Converted to the current convention: z in real mm, "
                     "positive upwards, z = 0 at the reference (lowest photodetector position). Same physical "
                     "positions; every z field (CSV columns, fft headers, session.json) and the folder name converted")}
NOTE_Z = "gantry Cartesian Z [mm]: positive upwards (Z = 0 at the reference)"


def conv_str(s):
    """Converts one z value written as text, keeping its style (decimals: as many as needed, at least the original)."""
    s = s.strip()
    if s == "" or s.lower() == "nan":
        return s
    d_in = len(s.split(".")[1]) if "." in s else 0
    out = f"{Decimal(s) * FACTOR:.{d_in + 1}f}"        # x 0.6 needs at most one more decimal
    if out.endswith("0"):
        out = out[:-1].rstrip(".")
    if re.fullmatch(r"-0(\.0*)?", out):
        out = out[1:]
    return out


def conv_num(v):
    return float(Decimal(repr(float(v))) * FACTOR) + 0.0


def conv_range(lo, hi):
    """Old [lo, hi] (lo < hi, negative) -> new sorted [lo', hi']."""
    return sorted([conv_num(lo), conv_num(hi)])


def convert_csv(path, apply):
    with open(path, newline="", encoding="utf-8") as f:
        text = f.read()
    rows = list(csv.reader(io.StringIO(text)))
    if not rows:
        return 0
    cols = [i for i, c in enumerate(rows[0]) if c in Z_COLUMNS]
    if not cols:
        return 0
    n = 0
    for r in rows[1:]:
        for i in cols:
            if i < len(r) and r[i].strip():
                r[i] = conv_str(r[i])
                n += 1
    if apply:
        buf = io.StringIO()
        csv.writer(buf, lineterminator="\r\n" if "\r\n" in text[:2000] else "\n").writerows(rows)
        write_atomic(path, buf.getvalue())
    return n


def convert_header(path, apply):
    with open(path, newline="", encoding="utf-8") as f:
        text = f.read()
    lines = text.splitlines(keepends=True)
    n = 0
    for i, ln in enumerate(lines):
        if not ln.startswith("#"):
            break
        body = ln.rstrip("\r\n")
        m = HEADER_Z.match(body)
        if m:
            lines[i] = m.group(1) + conv_str(m.group(2)) + m.group(3) + ln[len(body):]
            n += 1
    if n and apply:
        write_atomic(path, "".join(lines))
    return n


def write_atomic(path, text):
    tmp = path + ".zconv_tmp"
    with open(tmp, "w", newline="", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def convert_workspace(g):
    if g and "workspace_min_mm" in g and "workspace_max_mm" in g:
        lo, hi = conv_range(g["workspace_min_mm"][2], g["workspace_max_mm"][2])
        g["workspace_min_mm"][2], g["workspace_max_mm"][2] = lo, hi


def convert_session(s, old_name):
    tb = s.get("testbed")
    if isinstance(tb, dict):
        convert_workspace(tb.get("config", {}).get("gantry"))
        convert_workspace(tb.get("gantry"))
        if "config" in tb:
            tb["config"].setdefault("view", {})["z_negative_up"] = False
    pc = s.get("plan_config")
    if pc and isinstance(pc.get("z"), list) and len(pc["z"]) == 3:
        pc["z"] = [conv_num(pc["z"][0]), conv_num(pc["z"][1]), abs(conv_num(pc["z"][2]))]
    if s.get("axes_mm", {}).get("z") is not None:
        s["axes_mm"]["z"] = [conv_num(v) for v in s["axes_mm"]["z"]]
    if isinstance(s.get("notes"), dict) and "z" in s["notes"]:
        s["notes"]["z"] = NOTE_Z
    cfg = s.get("config")
    if isinstance(cfg, dict) and isinstance(cfg.get("region_z"), list):
        cfg["region_z"] = conv_range(*cfg["region_z"])
    pos = s.get("positioning")
    if isinstance(pos, dict) and "gantry_z_scale" in pos:
        assert (pos["gantry_z_scale"], pos["z_ref_mm"], pos["base_height_m"]) == (0.6, -300.0, 1.038), pos
        for k in ("gantry_z_scale", "z_ref_mm", "gantry_z_up"):
            pos.pop(k, None)
        pos["base_height_m"] = 0.858       # gantry base height at z = 0: 1.038 m at the old z = -300 (= 180 now)
    if isinstance(s.get("position_mm"), list) and len(s["position_mm"]) == 3:
        s["position_mm"][2] = conv_num(s["position_mm"][2])
    s["z_conversion"] = {**RECORD, "previous_name": old_name}
    return s


def new_name(name):
    m = NAME_Z.search(name)
    if not m:
        return name
    lo = Decimal(m.group(1).replace("p", "."))
    hi = Decimal(m.group(2).replace("p", ".")) if m.group(2) else lo
    a, b = sorted([lo * FACTOR, hi * FACTOR])
    num = lambda v: f"{float(v) + 0.0:g}".replace(".", "p")
    span = num(a) if a == b else f"{num(a)}to{num(b)}"
    return name[:m.start()] + f"-z{span}_" + name[m.end():]


def dataset_dirs():
    out = []
    for root in DATASET_ROOTS:
        r = os.path.join(CAMBRIDGE, root)
        out += [os.path.join(r, d) for d in sorted(os.listdir(r)) if os.path.isdir(os.path.join(r, d))]
    for root in ANALYSIS_DATASETS:
        r = os.path.join(CAMBRIDGE, root)
        out += [os.path.join(r, d) for d in sorted(os.listdir(r))
                if os.path.isfile(os.path.join(r, d, "points.csv"))]
    return [d for d in out if not any(k in os.path.basename(d) for k in SKIP)]


def convert_dataset(d, apply):
    sj = os.path.join(d, "session.json")
    s = None
    if os.path.isfile(sj):
        with open(sj, encoding="utf-8") as f:
            s = json.load(f)
        if "z_conversion" in s:          # already converted; finish an interrupted rename (name from the ORIGINAL one)
            nn = new_name(s["z_conversion"]["previous_name"])
            if apply and nn != os.path.basename(d):
                rename(d, nn)
            return None, nn
        if (s.get("start") or "") >= REPAIR:
            raise SystemExit(f"{d}: recorded after {REPAIR}, not converted")
    counts = {"csv_values": 0, "headers": 0}
    for fn in ("points.csv", "plan.csv", "trajectory.csv", "estimates.csv"):
        p = os.path.join(d, fn)
        if os.path.isfile(p):
            counts["csv_values"] += convert_csv(p, apply)
    for sub in ("fft", "."):
        sd = os.path.join(d, sub)
        if not os.path.isdir(sd):
            continue
        for fn in os.listdir(sd):
            if fn.endswith(".csv") and (sub == "fft" or re.fullmatch(r"p\d+_(fft|wave)\.csv", fn)):
                counts["headers"] += convert_header(os.path.join(sd, fn), apply)
    name = os.path.basename(d)
    if s is not None:
        s = convert_session(s, name)
        if apply:
            write_atomic(sj, json.dumps(s, indent=2) + "\n")
    nn = new_name(name)
    if apply and nn != name:
        rename(d, nn)
    return counts, nn


def rename(d, nn):
    """Folder rename, retried: a just-rewritten folder can stay locked for a while (indexer, antivirus)."""
    for attempt in range(30):
        try:
            os.rename(d, os.path.join(os.path.dirname(d), nn))
            return
        except PermissionError:
            if attempt == 29:
                raise
            time.sleep(2)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()
    manifest = json.load(open(MANIFEST)) if os.path.isfile(MANIFEST) else {"loose_csv": [], "renamed": {}}
    for rel in LOOSE_CSV:
        if rel in manifest["loose_csv"]:
            print(f"skip (already converted): {rel}")
            continue
        p = os.path.join(CAMBRIDGE, rel)
        with open(p, newline="") as f:
            zs = {float(r[c]) for r in csv.DictReader(f) for c in Z_COLUMNS if c in r and r[c].strip()}
        if any(z > 0 for z in zs) and not any(z < 0 for z in zs):
            print(f"skip (positive z only, already converted): {rel}")          # interrupted first run
        elif any(z > 0 for z in zs):
            raise SystemExit(f"{rel}: mixed-sign z values, not converted")
        else:
            n = convert_csv(p, a.apply)
            print(f"{rel}: {n} z values  z {sorted(zs)} -> {[conv_num(z) for z in sorted(zs)]}")
        if a.apply:
            manifest["loose_csv"].append(rel)
            save_manifest(manifest)
    for d in dataset_dirs():
        rel = os.path.relpath(d, CAMBRIDGE).replace("\\", "/")
        counts, nn = convert_dataset(d, a.apply)
        if counts is None:
            print(f"skip (already converted): {rel}" + (f"\n    -> {nn} (renamed now)" if nn != os.path.basename(d) else ""))
        else:
            print(f"{rel}: {counts['csv_values']} CSV z values, {counts['headers']} header lines"
                  + (f"\n    -> {nn}" if nn != os.path.basename(d) else ""))
        if nn != os.path.basename(d):
            manifest["renamed"][os.path.basename(d)] = nn
        if a.apply:
            save_manifest(manifest)
    if a.apply:                          # rename map: original name (session.json) -> current name
        manifest["renamed"] = {}
        for d in dataset_dirs():
            sj = os.path.join(d, "session.json")
            if os.path.isfile(sj):
                prev = json.load(open(sj, encoding="utf-8")).get("z_conversion", {}).get("previous_name")
                if prev and prev != os.path.basename(d):
                    manifest["renamed"][prev] = os.path.basename(d)
        save_manifest(manifest)
    print("applied" if a.apply else "dry run (use --apply)")


def save_manifest(manifest):
    with open(MANIFEST, "w") as f:
        json.dump(manifest, f, indent=2)


if __name__ == "__main__":
    main()
