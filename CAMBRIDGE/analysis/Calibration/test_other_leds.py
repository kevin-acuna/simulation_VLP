"""
test_other_leds.py - The 3x3 / 4x4 calibration grids applied to every LED "as if it were the first time".

For every LED (300, 500, 700, 900 kHz) of the horizontal scan (PD facing up, K = 1, z = 180):
  1. Calibration with ONLY the points of a regular n x n grid over the working area (X, Y 100-1300 mm),
     model RSS = A R_SQ(phi) cos(phi)^m / d^2 (LED facing down, height 3.0 m):
       xy_fit   : LED XY, A and m fitted together from those points (nothing else is known)
       xy_known : LED XY given (500 kHz: 281.1, 904.8; others: the positions of
                  ../Estimation_with_2LEDs/results_known_yaw/led_positions.csv, a stand-in for a plumb-line
                  measurement), A and m fitted from those points
     Reference: the same fits with all 19,881 points of the scan.
  2. Single-LED 3D positioning of the 125 test sites (two K = 10 campaigns, 15 deg adapter) with the RSS of
     that LED only, SQ + NLS as in the demo (direction from the K RSS shapes, range from A and m).
Nothing of calibration_budget.py or of the demo configuration is changed.

    python test_other_leds.py            # table on screen, other_leds_results.json, figures/other_leds_*.png
"""

import csv
import json
import os
import sys

import numpy as np
from scipy.optimize import minimize

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.normpath(os.path.join(HERE, "..", "..", "demo"))
sys.path[:0] = [os.path.join(DEMO, "app"), DEMO, os.path.join(DEMO, "tools")]

from settings import add_import_paths, load_settings   # noqa: E402

S = load_settings()
add_import_paths(S)

from _common import load_sites, read_csv, resolve       # noqa: E402
from geometry import TestbedGeometry                    # noqa: E402
from vlp import Lambertian, VLPModel, estimate_position, make_response   # noqa: E402

# ============================================================
# HYPERPARAMETERS
# ============================================================
SCAN_DIR = os.path.join(HERE, "campaign_20261013-182008_grid141x141x1-xy0to1400-s10-z180_K1-off65_pd0_tilt0_100ms")
LEDS_KHZ = [300.0, 500.0, 700.0, 900.0]
RSS_SOURCE = "wave"
LED_HEIGHT_M = 3.0                    # LED plane (assumed, as for the 500 kHz LED)
KNOWN_XY_MM = {500.0: (281.1, 904.8)}  # 500 kHz: experiment 01 / demo
KNOWN_XY_CSV = os.path.join(HERE, "..", "Estimation_with_2LEDs", "results_known_yaw", "led_positions.csv")
GRIDS = [3, 4]                        # n x n regular grids over the working area
AREA_LIMITS_M = (0.10, 1.30)
MTRS_OFFSET_DEG = 66.5
FIG_DIR = os.path.join(HERE, "figures")

# ============================================================
# DATA
# ============================================================
p = S["positioning"]
response = make_response("SQ", p["psi_3db_rad"], p["m_R"], p["pd_fov_deg"])
geo = TestbedGeometry(**{**{k: v for k, v in S["geometry"].items() if k in TestbedGeometry.__dataclass_fields__},
                         "mtrs_offset_deg": MTRS_OFFSET_DEG})
rows = read_csv(os.path.join(SCAN_DIR, "points.csv"))
assert {r["pd_tilt_deg"] for r in rows} == {"0.0"} and {r["mtrs_tilt_cmd_deg"] for r in rows} == {"0.0"}
z_scan = {float(r["z_cmd_mm"]) for r in rows}
assert len(z_scan) == 1
h = LED_HEIGHT_M - geo.pd_height(z_scan.pop())
X = np.array([float(r["x_cmd_mm"]) for r in rows]) / 1e3
Y = np.array([float(r["y_cmd_mm"]) for r in rows]) / 1e3
RSS = {f: np.array([float(r[f"{f:g}kHz_{RSS_SOURCE}_Vrms"]) for r in rows]) for f in LEDS_KHZ}
IDX = {(int(round(x / 0.01)), int(round(y / 0.01))): i for i, (x, y) in enumerate(zip(X, Y))}

known = {f: np.array(xy) / 1e3 for f, xy in KNOWN_XY_MM.items()}
with open(KNOWN_XY_CSV, newline="") as fh:
    tab = list(csv.DictReader(fh))
for f in LEDS_KHZ:
    if f not in known:
        sel = [r for r in tab if float(r["freq_khz"]) == f]
        known[f] = np.array([np.mean([float(r["x_mm"]) for r in sel]), np.mean([float(r["y_mm"]) for r in sel])]) / 1e3

sites = load_sites([os.path.join(resolve(S["paths"]["campaigns_root"]), c) for c in S["paths"]["campaigns"]],
                   "500kHz_wave_Vrms")
camp_rows = {}
for c, d in enumerate(S["paths"]["campaigns"]):
    for r in read_csv(os.path.join(resolve(S["paths"]["campaigns_root"]), d, "points.csv")):
        camp_rows.setdefault((c, int(r["site_id"])), []).append(r)
TRUTH = np.array([geo.pd_position(st["gantry_mm"]) for st in sites])
Z_SITE = np.array([st["gantry_mm"][2] for st in sites])


def grid_idx(n):
    v = np.linspace(*AREA_LIMITS_M, n)
    return np.array(sorted({IDX[(int(round(a / 0.01)), int(round(b / 0.01)))] for a in v for b in v}))


def lin(idx, f, xy):
    """log(RSS d^2 / R) and log cos(phi) of the points idx for an LED at xy."""
    r = np.hypot(X[idx] - xy[0], Y[idx] - xy[1])
    d = np.hypot(r, h)
    c = h / d
    R = response.value(c)
    ok = (R > 0) & (RSS[f][idx] > 0)
    return np.log(RSS[f][idx][ok] * d[ok] ** 2 / R[ok]), np.log(c[ok])


def fit_Am(idx, f, xy):
    ly, lx = lin(idx, f, xy)
    M = np.column_stack([np.ones_like(lx), lx])
    coef, *_ = np.linalg.lstsq(M, ly, rcond=None)
    resid = ly - M @ coef
    return float(np.exp(coef[0])), float(coef[1]), float(np.mean(resid ** 2))


def fit_xyAm(idx, f):
    """LED XY + A + m: Nelder-Mead on XY (A, m linear), several starts around the strongest points."""
    best = None
    for k in np.argsort(RSS[f][idx])[::-1][:4]:
        x0 = np.array([X[idx][k], Y[idx][k]])
        res = minimize(lambda xy: fit_Am(idx, f, xy)[2], x0, method="Nelder-Mead",
                       options={"xatol": 1e-4, "fatol": 1e-12, "maxiter": 2000})
        if best is None or res.fun < best.fun:
            best = res
    A, m, _ = fit_Am(idx, f, best.x)
    return best.x, A, m


def site_estimates(f):
    """Direction and amplitude of every test site with the RSS of LED f (independent of A, m and LED XY)."""
    col = f"{f:g}kHz_wave_Vrms"
    dummy = VLPModel(led_position=[0, 0, LED_HEIGHT_M], response=response, emitter=Lambertian(1.0), A=1.0)
    U, B, ok = [], [], []
    for st in sites:
        rr = sorted(camp_rows[(st["campaign"], st["site_id"])], key=lambda r: int(r["k"]))
        rss = np.array([float(r[col]) for r in rr])
        est = estimate_position(p["estimator"], rss, geo.normals(st["angles"]), dummy, p.get("starts", 3))
        ok.append(est.direction is not None and est.amplitude is not None and est.amplitude > 0)
        U.append(est.direction if ok[-1] else [np.nan] * 3)
        B.append(est.amplitude if ok[-1] else np.nan)
    return np.array(U), np.array(B), np.array(ok)


def position_errors(U, B, ok, xy, A, m):
    led = np.array([xy[0], xy[1], LED_HEIGHT_M])
    c = U[:, 2]                                   # LED facing down: cos(phi) = u_z
    d = np.sqrt(A * np.clip(c, 1e-9, None) ** m / B)
    est = led[None, :] - d[:, None] * U
    e = est - TRUTH
    good = ok & np.isfinite(d)
    return e[good], good


def stats(e):
    n = np.linalg.norm(e, axis=1) * 100
    return {"n": int(len(n)), "mean_cm": float(n.mean()), "median_cm": float(np.median(n)),
            "p90_cm": float(np.percentile(n, 90)), "horizontal_cm": float(np.hypot(e[:, 0], e[:, 1]).mean() * 100),
            "vertical_bias_cm": float(e[:, 2].mean() * 100)}


def main():
    all_idx = np.flatnonzero(np.isfinite(RSS[LEDS_KHZ[0]]))
    out = {}
    print(f"Scan h = {h:.4f} m, LED height {LED_HEIGHT_M} m, {len(sites)} test sites, MTRS offset {MTRS_OFFSET_DEG} deg")
    print(f"{'LED':>7} {'calibration':>11} {'LED XY':>9} | {'XY used (mm)':>17} {'A (V m2)':>9} {'m':>5} | "
          f"{'mean':>6} {'median':>6} {'P90':>6} {'horiz':>6} {'vbias':>6} (cm)")
    for f in LEDS_KHZ:
        U, B, ok = site_estimates(f)
        out[f] = []
        for cal_name, idx in [(f"{n}x{n}", grid_idx(n)) for n in GRIDS] + [("all", all_idx)]:
            for variant in ("xy_fit", "xy_known"):
                if variant == "xy_fit":
                    xy, A, m = fit_xyAm(idx, f)
                else:
                    xy = known[f]
                    A, m, _ = fit_Am(idx, f, xy)
                e, good = position_errors(U, B, ok, xy, A, m)
                st = stats(e)
                per_z = {f"{z:g}": stats(e[Z_SITE[good] == z])["mean_cm"] for z in sorted(set(Z_SITE))}
                out[f].append({"calibration": cal_name, "points": int(idx.size), "led_xy": variant,
                               "xy_mm": (1e3 * np.asarray(xy)).tolist(), "A": A, "m": m, **st, "mean_per_gantry_z": per_z})
                print(f"{f:5g}k {cal_name:>11} {variant:>9} | ({1e3 * xy[0]:7.1f}, {1e3 * xy[1]:7.1f}) {A:9.5f} {m:5.2f} | "
                      f"{st['mean_cm']:6.2f} {st['median_cm']:6.2f} {st['p90_cm']:6.2f} {st['horizontal_cm']:6.2f} "
                      f"{st['vertical_bias_cm']:+6.2f}  ({st['n']}/{len(sites)} sites)")
        print()
    with open(os.path.join(HERE, "other_leds_results.json"), "w") as fh:
        json.dump({f"{f:g}kHz": v for f, v in out.items()}, fh, indent=2)
    figures(out)


def figures(out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    os.makedirs(FIG_DIR, exist_ok=True)
    # bars: mean 3D error per LED and calibration
    fig, axs = plt.subplots(1, 2, figsize=(12, 4.2), sharey=True)
    cals = [f"{n}x{n}" for n in GRIDS] + ["all"]
    for ax, variant, title in zip(axs, ("xy_fit", "xy_known"),
                                  ("LED XY fitted from the same points (first time)", "LED XY given (stand-in for a measurement)")):
        w = 0.8 / len(cals)
        for j, cal in enumerate(cals):
            vals = [next(r["mean_cm"] for r in out[f] if r["calibration"] == cal and r["led_xy"] == variant) for f in LEDS_KHZ]
            p90 = [next(r["p90_cm"] for r in out[f] if r["calibration"] == cal and r["led_xy"] == variant) for f in LEDS_KHZ]
            xs = np.arange(len(LEDS_KHZ)) + (j - (len(cals) - 1) / 2) * w
            bars = ax.bar(xs, vals, w, label=f"{cal} ({'19,881' if cal == 'all' else int(cal[0]) ** 2} points)")
            ax.errorbar(xs, vals, yerr=[np.zeros(len(vals)), np.array(p90) - np.array(vals)], fmt="none", ecolor="k",
                        capsize=2, lw=0.8)
            for b, v in zip(bars, vals):
                ax.text(b.get_x() + b.get_width() / 2, v + 0.3, f"{v:.1f}", ha="center", fontsize=7)
        ax.set(xticks=range(len(LEDS_KHZ)), xticklabels=[f"{f:g} kHz" for f in LEDS_KHZ], title=title)
        ax.grid(axis="y", alpha=0.3)
    axs[0].set_ylabel("Mean 3D error (cm), whisker = P90")
    axs[0].legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "other_leds_error.png"), dpi=200)

    # maps: flat RSS of every LED, grid points and LED XY estimates
    fig, axs = plt.subplots(1, len(LEDS_KHZ), figsize=(16, 4.9), sharey=True)
    for ax, f in zip(axs, LEDS_KHZ):
        ax.scatter(Y[::5], X[::5], c=1e3 * RSS[f][::5], s=1, cmap="Greys")
        g4 = grid_idx(4)
        ax.plot(Y[g4], X[g4], "o", color="0.6", ms=5, mec="k", label="4x4 calibration points")
        marks = {"3x3": ("s", "C0"), "4x4": ("D", "C1"), "all": ("*", "C2")}
        for r in out[f]:
            if r["led_xy"] == "xy_fit":
                mk, colr = marks[r["calibration"]]
                ax.plot(r["xy_mm"][1] / 1e3, r["xy_mm"][0] / 1e3, mk, ms=9, mfc="none", mec=colr, mew=2,
                        label=f"LED XY fitted ({r['calibration']})")
        kxy = known[f]
        ax.plot(kxy[1], kxy[0], "r+", ms=16, mew=2.5, label="LED XY given")
        ax.set(title=f"{f:g} kHz (darker = stronger)", xlabel="Y (m)", xlim=(1.4, 0), ylim=(0, 1.4), aspect="equal")
    axs[0].set_ylabel("X (m)")
    handles, labels = axs[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="lower center", ncol=5, fontsize=8)
    fig.tight_layout(rect=(0, 0.07, 1, 1))
    fig.savefig(os.path.join(FIG_DIR, "other_leds_maps.png"), dpi=200)
    plt.close("all")


if __name__ == "__main__":
    main()
