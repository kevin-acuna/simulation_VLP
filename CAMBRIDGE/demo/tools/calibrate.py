"""
calibrate.py - A and m of the LED from the horizontal calibration scan, with the PD response and the
LED position of config/demo.toml (copy the printed values into [led] A, m).

    python tools/calibrate.py                     # staged and joint fits
    python tools/calibrate.py --led 281.1 904.8   # another LED position
"""

import argparse
import os

import numpy as np

from _common import check_z_convention, load_settings, read_csv, resolve

from geometry import TestbedGeometry       # noqa: E402
from vlp import fit_lambertian, make_response   # noqa: E402


def main():
    s = load_settings()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--led", nargs=2, type=float, default=s["led"]["xy_mm"], help="LED X Y [mm]")
    ap.add_argument("--response", default=s["positioning"]["pd_response"])
    ap.add_argument("--csv", default=resolve(s["paths"]["calibration_csv"]))
    a = ap.parse_args()
    check_z_convention(os.path.dirname(a.csv))
    p, g = s["positioning"], TestbedGeometry(**{k: v for k, v in s["geometry"].items()
                                               if k in TestbedGeometry.__dataclass_fields__})
    rows = read_csv(a.csv)
    z = {float(r["z_cmd_mm"]) for r in rows}
    if len(z) != 1 or any(float(r["pd_tilt_deg"]) != 0 for r in rows):
        raise SystemExit("The calibration scan must be horizontal (pd_tilt 0) at a single gantry z.")
    h = s["led"]["height_m"] - g.pd_height(z.pop())
    col = f"{p['led_frequency_khz']:g}kHz_wave_Vrms"
    xy = np.array([[float(r["x_cmd_mm"]) / 1e3, float(r["y_cmd_mm"]) / 1e3] for r in rows])
    y = np.array([float(r[col]) for r in rows])
    resp = make_response(a.response, p["psi_3db_rad"], p["m_R"], p["pd_fov_deg"])
    print(f"{os.path.basename(os.path.dirname(a.csv))}: {len(rows)} points, {col}, h = {h:.5f} m, "
          f"PD response {resp.describe()}, LED ({a.led[0]:g}, {a.led[1]:g}) mm")
    for method in ("staged", "joint"):
        A, m, info = fit_lambertian(xy, y, np.array(a.led) / 1e3, h, resp, method)
        print(f"  {method:6s}: A = {A:.5g} V m^2, m = {m:.4f}  (half-power {np.degrees(np.arccos(2 ** (-1 / m))):.2f} deg, "
              f"rms {100 * info['rms_log']:.2f} %, phi <= {info['max_phi_deg']:.1f} deg)")


if __name__ == "__main__":
    main()
