"""
calibration_budget.py - How many calibration points are needed for A and m, and where to put them.

Known (physical / measurable): LED position (281.1, 904.8) mm and height, PD response (SQ, Bastiaens
2020), MTRS offset (66.5 deg), testbed geometry (config of the demo). Unknown: the gain A and the
Lambertian order m of the LED in
    RSS = A R(psi) cos(phi)^m / d^2,   horizontal PD under the LED -> psi = phi, cos(phi) = h / d
They are fitted from N points of the HORIZONTAL scan (PD facing up, K = 1, 10 mm grid, z = -300):
    log(RSS d^2 / R) = log A + m log cos(phi)     (linear least squares; N = 2 -> exact solution)
Every calibration point is a real measured point (real noise and real model mismatch, nothing
simulated). The calibrated (A, m) are then evaluated on:
  - map : relative RSS error of the model over the whole horizontal scan (19,881 points)
  - 3D  : mean 3D positioning error over the 125 sites of the two K = 10 campaigns (15 deg adapter),
          SQ + NLS as in the demo. These sites are ONLY a test set (never used to calibrate).
The direction u and the amplitude beta of every site do not depend on (A, m); only the range does:
d = sqrt(A cos(phi_u)^m / beta), so the error of any (A, m) is computed in closed form.

    python calibration_budget.py            # figures/*.png + results.json (about 1 min)
"""

import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.normpath(os.path.join(HERE, "..", "..", "demo"))
sys.path[:0] = [os.path.join(DEMO, "app"), DEMO, os.path.join(DEMO, "tools")]

from settings import add_import_paths, load_settings   # noqa: E402

S = load_settings()
add_import_paths(S)

from _common import load_sites, read_csv, resolve       # noqa: E402
from positioner import Positioner                       # noqa: E402
from vlp import make_response                           # noqa: E402

# ============================================================
# HYPERPARAMETERS
# ============================================================
SCAN_DIR = os.path.join(HERE, "campaign_20261013-182008_grid141x141x1-xy0to1400-s10-z-300_K1-off65_pd0_tilt0_100ms")
FREQ_KHZ = 500.0                     # LED studied
RSS_SOURCE = "wave"                  # "wave" (lock-in on the raw waveform) | "fft"
LED_XY_MM = (281.1, 904.8)           # known LED position (demo.toml)
MTRS_OFFSET_DEG = 66.5               # known MTRS offset (demo.toml)
N_VALUES = [2, 3, 4, 5, 6, 8, 10, 15, 20, 30, 50, 100, 200, 500]
N_DRAWS = 400                        # random draws per (strategy, N)
RADIAL_RMAX_M = 0.60                 # radial pattern: points from the nadir out to this radius
DISC_RADII_M = [0.10, 0.20, 0.30, 0.45, 0.60, 0.80, 1.00, 1.20]   # coverage study (random in a disc)
DISC_N = 10
TWO_POINT_RADII_M = np.arange(0.05, 1.21, 0.05)                   # nadir + one point at radius r
GRID_SPACINGS_M = [0.10, 0.15, 0.20, 0.30, 0.40]                  # square grid centred on the LED
GRID_SIZES = [3, 5]                  # 3x3, 5x5
AREA_GRID_SIZES = [2, 3, 4, 5, 6, 8, 10]   # n x n regular grid over the working area (gantry 100-1300 mm)
AREA_LIMITS_M = (0.10, 1.30)
M_SWEEP = np.linspace(3.0, 10.0, 71)  # sensitivity: A from the nadir point, m assumed
SEED = 1
FIG_DIR = os.path.join(HERE, "figures")


# ============================================================
# DATA
# ============================================================
p, g_cfg = S["positioning"], S["geometry"]
S["led"]["xy_mm"] = list(LED_XY_MM)
S["geometry"]["mtrs_offset_deg"] = MTRS_OFFSET_DEG
pos = Positioner.from_settings(S)
response = make_response("SQ", p["psi_3db_rad"], p["m_R"], p["pd_fov_deg"])
led_xy = np.array(LED_XY_MM) / 1e3

rows = read_csv(os.path.join(SCAN_DIR, "points.csv"))
assert {r["pd_tilt_deg"] for r in rows} == {"0.0"} and {r["mtrs_tilt_cmd_deg"] for r in rows} == {"0.0"}
z_scan = {float(r["z_cmd_mm"]) for r in rows}
assert len(z_scan) == 1
h = S["led"]["height_m"] - pos.geometry.pd_height(z_scan.pop())       # LED - PD vertical distance [m]
col = f"{FREQ_KHZ:g}kHz_{RSS_SOURCE}_Vrms"
X = np.array([float(r["x_cmd_mm"]) for r in rows]) / 1e3
Y = np.array([float(r["y_cmd_mm"]) for r in rows]) / 1e3
RSS = np.array([float(r[col]) for r in rows])
r_led = np.hypot(X - led_xy[0], Y - led_xy[1])
d_led = np.hypot(r_led, h)
cphi = h / d_led
Rpd = response.value(cphi)
ok_map = (RSS > 0) & (Rpd > 0)
LY = np.full(RSS.shape, np.nan)
LY[ok_map] = np.log(RSS[ok_map] * d_led[ok_map] ** 2 / Rpd[ok_map])    # log A + m log cos(phi)
LX = np.log(cphi)
PHI_DEG = np.degrees(np.arccos(cphi))
NADIR = int(np.argmin(r_led))
STEP = 0.01
IDX = {(int(round(x / STEP)), int(round(y / STEP))): i for i, (x, y) in enumerate(zip(X, Y))}

# test sites: direction and amplitude once (independent of A, m)
sites = load_sites([os.path.join(resolve(S["paths"]["campaigns_root"]), c) for c in S["paths"]["campaigns"]],
                   f"{FREQ_KHZ:g}kHz_wave_Vrms")
U, BETA, TRUTH, Z_SITE = [], [], [], []
for st in sites:
    res = pos.locate(st["rss"], st["angles"], st["gantry_mm"])
    est = res["_estimate"]
    if est.ok:
        U.append(est.direction)
        BETA.append(est.amplitude)
        TRUTH.append(res["true_m"])
        Z_SITE.append(st["gantry_mm"][2])
U, BETA, TRUTH = np.array(U), np.array(BETA), np.array(TRUTH)
C_U = U @ pos.model.q                                # cos(phi) of the estimated direction
LED_P = pos.model.led_position
PHI_SITES = np.degrees(np.arccos([pos.model.geometry(t)[2] for t in TRUTH]))


def pos_error_cm(A, m):
    """Mean 3D error (cm) over the test sites for calibration (A, m); vectorised over arrays of A, m."""
    A, m = np.atleast_1d(A).astype(float), np.atleast_1d(m).astype(float)
    d = np.sqrt(A[:, None] * C_U[None, :] ** m[:, None] / BETA[None, :])
    est = LED_P[None, None, :] - d[..., None] * U[None, :, :]
    return 100 * np.linalg.norm(est - TRUTH[None], axis=2).mean(axis=1)


def map_error_pct(A, m, phi_max=None):
    """rms of RSS_measured / RSS_model - 1 (%) over the horizontal scan (optionally phi <= phi_max)."""
    A, m = np.atleast_1d(A).astype(float), np.atleast_1d(m).astype(float)
    sel = ok_map if phi_max is None else ok_map & (PHI_DEG <= phi_max)
    model = np.log(A)[:, None] + m[:, None] * LX[sel][None, :]
    return 100 * np.sqrt(np.mean(np.expm1(LY[sel][None, :] - model) ** 2, axis=1))


def fit(idx):
    """(A, m) by linear least squares on the points idx (needs >= 2 distinct radii)."""
    idx = np.asarray(idx)
    M = np.column_stack([np.ones(idx.size), LX[idx]])
    if idx.size < 2 or np.ptp(LX[idx]) < 1e-9:
        return np.nan, np.nan
    la, m = np.linalg.lstsq(M, LY[idx], rcond=None)[0]
    return float(np.exp(la)), float(m)


def snap(xy):
    """Index of the measured grid point nearest to xy [m] (None if outside the scan)."""
    k = (int(round(xy[0] / STEP)), int(round(xy[1] / STEP)))
    return IDX.get(k)


# ============================================================
# CALIBRATION PATTERNS (indices of real measured points)
# ============================================================
VALID = np.flatnonzero(ok_map)


def pat_random_area(N, rng):
    """N points uniformly at random over the whole scan (1.4 x 1.4 m)."""
    return rng.choice(VALID, N, replace=False)


def pat_random_disc(N, rng, radius):
    """N points at random inside a disc of the given radius around the LED."""
    pool = VALID[r_led[VALID] <= radius]
    return rng.choice(pool, N, replace=False) if pool.size >= N else None


def pat_radial(N, rng, rmax=RADIAL_RMAX_M):
    """Nadir + N-1 points at radii evenly spaced up to rmax, each in a random direction (inside the scan)."""
    out = [NADIR]
    for r in np.linspace(rmax / (N - 1), rmax, N - 1):
        for _ in range(100):
            a = rng.uniform(0, 2 * np.pi)
            i = snap(led_xy + r * np.array([np.cos(a), np.sin(a)]))
            if i is not None and i not in out:
                out.append(i)
                break
    return np.array(out) if len(out) == N else None


def pat_ring(N, rng, radius=0.30):
    """Nadir + N-1 points evenly spaced on one ring (random rotation), only rotations fully inside the scan."""
    for _ in range(200):
        a0 = rng.uniform(0, 2 * np.pi)
        pts = [snap(led_xy + radius * np.array([np.cos(a), np.sin(a)]))
               for a in a0 + 2 * np.pi * np.arange(N - 1) / (N - 1)]
        if all(i is not None for i in pts) and len(set(pts)) == N - 1:
            return np.array([NADIR] + pts)
    return None


def pat_grid(n, spacing):
    """n x n square grid centred on the nadir point (points outside the scan are dropped)."""
    k = (np.arange(n) - (n - 1) / 2) * spacing
    pts = {snap(led_xy + np.array([a, b])) for a in k for b in k}
    pts.discard(None)
    return np.array(sorted(pts))


def pat_area_grid(n, with_nadir=False):
    """n x n regular grid over the working area (AREA_LIMITS_M in X and Y), optionally + the nadir point."""
    v = np.linspace(*AREA_LIMITS_M, n)
    pts = {snap((a, b)) for a in v for b in v}
    if with_nadir:
        pts.add(NADIR)
    pts.discard(None)
    return np.array(sorted(pts))


def run_strategy(name, gen, rng):
    out = {}
    for N in N_VALUES:
        A, m = [], []
        for _ in range(N_DRAWS):
            idx = gen(N, rng)
            if idx is None:
                continue
            a, mm = fit(idx)
            if np.isfinite(a):
                A.append(a)
                m.append(mm)
        if not A:
            continue
        A, m = np.array(A), np.array(m)
        e3d, emap = pos_error_cm(A, m), map_error_pct(A, m)
        out[N] = {"A": A, "m": m, "e3d": e3d, "emap": emap}
        print(f"  {name:22s} N={N:4d}: 3D median {np.median(e3d):5.2f} cm [P10 {np.percentile(e3d, 10):5.2f}, "
              f"P90 {np.percentile(e3d, 90):6.2f}] | m median {np.median(m):5.2f} (IQR {np.subtract(*np.percentile(m, [75, 25])):.2f})"
              f" | map {np.median(emap):5.2f} %")
    return out


def q(a, p):
    return float(np.percentile(a, p))


def main():
    rng = np.random.default_rng(SEED)
    os.makedirs(FIG_DIR, exist_ok=True)
    print(f"Scan: {len(rows)} points, h = {h:.4f} m, phi 0-{PHI_DEG.max():.1f} deg, nadir point at "
          f"{1e3 * r_led[NADIR]:.1f} mm from the LED; test: {len(BETA)} sites (phi {PHI_SITES.min():.1f}-{PHI_SITES.max():.1f} deg)")

    # references
    A_all, m_all = fit(VALID)
    A_demo, m_demo = S["led"]["A"], S["led"]["m"]
    AA, MM = np.meshgrid(np.linspace(0.055, 0.068, 131), np.linspace(4.0, 8.5, 181))
    E = pos_error_cm(AA.ravel(), MM.ravel()).reshape(AA.shape)
    k = np.unravel_index(np.argmin(E), E.shape)
    A_or, m_or, e_or = AA[k], MM[k], E[k]
    ref = {"all_scan_joint": {"A": A_all, "m": m_all, "e3d": float(pos_error_cm(A_all, m_all)[0]),
                              "emap": float(map_error_pct(A_all, m_all)[0])},
           "demo_toml": {"A": A_demo, "m": m_demo, "e3d": float(pos_error_cm(A_demo, m_demo)[0]),
                         "emap": float(map_error_pct(A_demo, m_demo)[0])},
           "oracle_best_for_3D": {"A": float(A_or), "m": float(m_or), "e3d": float(e_or),
                                  "emap": float(map_error_pct(A_or, m_or)[0])}}
    for kname, v in ref.items():
        print(f"reference {kname:20s}: A {v['A']:.5f}, m {v['m']:.3f} -> 3D {v['e3d']:.2f} cm, map {v['emap']:.2f} %")

    # 1 point: A from the nadir, m assumed
    A1 = np.exp(LY[NADIR] - M_SWEEP * LX[NADIR])
    e_sweep = pos_error_cm(A1, M_SWEEP)
    tol = M_SWEEP[e_sweep <= ref["all_scan_joint"]["e3d"] + 0.5]
    print(f"\n1 point (nadir) + assumed m: best m {M_SWEEP[np.argmin(e_sweep)]:.2f} -> {e_sweep.min():.2f} cm; "
          f"m within +0.5 cm of the full calibration: {tol.min():.2f}-{tol.max():.2f}")

    # 2 points: nadir + one point at radius r
    two = []
    for r in TWO_POINT_RADII_M:
        pool = VALID[np.abs(r_led[VALID] - r) <= 0.005]
        A2, m2 = zip(*[fit([NADIR, i]) for i in pool])
        e = pos_error_cm(np.array(A2), np.array(m2))
        two.append((r, np.degrees(np.arctan(r / h)), len(pool), np.median(e), q(e, 10), q(e, 90), np.median(m2)))
    print("\n2 points (nadir + 1 at radius r):")
    for r, ph, n, med, p10, p90, mm in two:
        print(f"  r = {r:4.2f} m (phi {ph:4.1f} deg, {n:3d} candidates): 3D median {med:5.2f} cm [P10 {p10:5.2f}, P90 {p90:5.2f}], m {mm:.2f}")

    # strategies vs N
    print("\nError vs N:")
    strategies = {
        "random_area": pat_random_area,
        f"radial_0to{RADIAL_RMAX_M:g}m": pat_radial,
        "random_disc_0.6m": lambda N, rng: pat_random_disc(N, rng, 0.6),
        "ring_0.3m": pat_ring,
    }
    results = {name: run_strategy(name, gen, rng) for name, gen in strategies.items()}

    # coverage radius (random in a disc, N = DISC_N)
    print(f"\nCoverage radius (random in a disc, N = {DISC_N}):")
    cover = []
    for rad in DISC_RADII_M:
        draws = [pat_random_disc(DISC_N, rng, rad) for _ in range(N_DRAWS)]
        Am = np.array([fit(i) for i in draws if i is not None])
        e = pos_error_cm(Am[:, 0], Am[:, 1])
        cover.append((rad, np.degrees(np.arctan(rad / h)), np.median(e), q(e, 10), q(e, 90), np.median(Am[:, 1])))
        print(f"  R = {rad:4.2f} m (phi <= {cover[-1][1]:4.1f} deg): 3D median {cover[-1][2]:5.2f} cm "
              f"[P10 {cover[-1][3]:5.2f}, P90 {cover[-1][4]:5.2f}], m {cover[-1][5]:.2f}")

    # square grids centred on the LED
    print("\nSquare grids centred on the LED:")
    grids = []
    for n in GRID_SIZES:
        for s in GRID_SPACINGS_M:
            idx = pat_grid(n, s)
            a, mm = fit(idx)
            e = float(pos_error_cm(a, mm)[0])
            grids.append((n, s, idx.size, a, mm, e, float(map_error_pct(a, mm)[0])))
            print(f"  {n}x{n} spacing {s:4.2f} m ({idx.size:2d} points inside the scan): A {a:.5f}, m {mm:.2f} -> 3D {e:.2f} cm")

    print("\nRegular grids over the working area (X, Y in 100-1300 mm):")
    area = []
    for n in AREA_GRID_SIZES:
        for nadir in (False, True):
            idx = pat_area_grid(n, nadir)
            a, mm = fit(idx)
            e = float(pos_error_cm(a, mm)[0])
            area.append((n, int(nadir), idx.size, a, mm, e, float(map_error_pct(a, mm)[0])))
            print(f"  {n:2d}x{n:<2d}{' + nadir' if nadir else '        '} ({idx.size:3d} points, step "
                  f"{1e3 * (AREA_LIMITS_M[1] - AREA_LIMITS_M[0]) / (n - 1):4.0f} mm): A {a:.5f}, m {mm:.2f} -> 3D {e:.2f} cm, map {area[-1][6]:.2f} %")

    figures(ref, M_SWEEP, e_sweep, two, results, cover, grids, area)
    summary = {"h_m": h, "led_xy_mm": LED_XY_MM, "mtrs_offset_deg": MTRS_OFFSET_DEG, "n_scan": len(rows),
               "n_test_sites": int(len(BETA)), "references": ref,
               "one_point": {"m_best": float(M_SWEEP[np.argmin(e_sweep)]), "e_best": float(e_sweep.min()),
                             "m_range_within_0p5cm": [float(tol.min()), float(tol.max())]},
               "two_points": [dict(zip(("r_m", "phi_deg", "n_candidates", "e_median", "e_p10", "e_p90", "m_median"),
                                       map(float, t))) for t in two],
               "strategies": {name: {str(N): {"e3d_median": float(np.median(v["e3d"])), "e3d_p10": q(v["e3d"], 10),
                                              "e3d_p90": q(v["e3d"], 90), "m_median": float(np.median(v["m"])),
                                              "m_p10": q(v["m"], 10), "m_p90": q(v["m"], 90),
                                              "A_median": float(np.median(v["A"])),
                                              "map_median": float(np.median(v["emap"])), "draws": int(v["m"].size)}
                                        for N, v in res.items()} for name, res in results.items()},
               "coverage": [dict(zip(("radius_m", "phi_max_deg", "e_median", "e_p10", "e_p90", "m_median"), map(float, t)))
                            for t in cover],
               "grids": [dict(zip(("n", "spacing_m", "points", "A", "m", "e3d", "emap"), map(float, t))) for t in grids],
               "area_grids": [dict(zip(("n", "with_nadir", "points", "A", "m", "e3d", "emap"), map(float, t)))
                              for t in area]}
    with open(os.path.join(HERE, "results.json"), "w") as f:
        json.dump(summary, f, indent=2)
    print(f"\nresults.json and figures in {FIG_DIR}")


# ============================================================
# FIGURES
# ============================================================
def figures(ref, m_sweep, e_sweep, two, results, cover, grids, area):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    plt.rcParams.update({"font.size": 10, "axes.grid": True, "grid.alpha": 0.3})
    e_full, e_or = ref["all_scan_joint"]["e3d"], ref["oracle_best_for_3D"]["e3d"]

    def refs(ax):
        ax.axhline(e_full, color="k", ls="--", lw=1, label=f"all {len(VALID):,} points ({e_full:.2f} cm)")
        ax.axhline(e_or, color="g", ls=":", lw=1.2, label=f"best possible A, m ({e_or:.2f} cm)")

    # 1) error vs N per strategy
    fig, (ax, ax2) = plt.subplots(1, 2, figsize=(12, 4.6))
    labels = {"random_area": "random, whole area", f"radial_0to{RADIAL_RMAX_M:g}m": f"nadir + radial up to {RADIAL_RMAX_M:g} m",
              "random_disc_0.6m": "random within 0.6 m of the LED", "ring_0.3m": "nadir + ring of 0.3 m"}
    for name, res in results.items():
        Ns = np.array(sorted(res))
        med = np.array([np.median(res[N]["e3d"]) for N in Ns])
        p10 = np.array([q(res[N]["e3d"], 10) for N in Ns])
        p90 = np.array([q(res[N]["e3d"], 90) for N in Ns])
        l, = ax.plot(Ns, med, "o-", ms=3.5, label=labels.get(name, name))
        ax.fill_between(Ns, p10, p90, color=l.get_color(), alpha=0.12)
        mm = np.array([np.median(res[N]["m"]) for N in Ns])
        m10 = np.array([q(res[N]["m"], 10) for N in Ns])
        m90 = np.array([q(res[N]["m"], 90) for N in Ns])
        ax2.plot(Ns, mm, "o-", ms=3.5, color=l.get_color())
        ax2.fill_between(Ns, m10, m90, color=l.get_color(), alpha=0.12)
    ag = np.array([t for t in area if not t[1]])
    ax.plot(ag[:, 2], ag[:, 5], "ks", ms=6, mfc="none", mew=1.5, label="regular n x n grid over the area")
    for t in ag:
        ax.annotate(f"{int(t[0])}x{int(t[0])}", (t[2], t[5]), textcoords="offset points", xytext=(4, 4), fontsize=7)
    ax2.plot(ag[:, 2], ag[:, 4], "ks", ms=6, mfc="none", mew=1.5)
    refs(ax)
    ax.set(xscale="log", ylim=(3, 12), xlabel="Calibration points N (horizontal PD)",
           ylabel="Mean 3D positioning error (cm)", title="3D error on the 125 test sites (median, P10-P90)")
    ax.legend(fontsize=8)
    ax2.axhline(ref["all_scan_joint"]["m"], color="k", ls="--", lw=1)
    ax2.axhline(ref["oracle_best_for_3D"]["m"], color="g", ls=":", lw=1.2)
    ax2.set(xscale="log", ylim=(3, 10), xlabel="Calibration points N", ylabel="Fitted Lambertian order m",
            title="Fitted m (median, P10-P90)")
    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "error_vs_N.png"), dpi=200)

    # 2) two points: nadir + one at radius r; coverage radius
    fig, (ax, ax2) = plt.subplots(1, 2, figsize=(12, 4.4))
    t = np.array(two)
    ax.plot(t[:, 1], t[:, 3], "o-", ms=3.5, label="nadir + 1 point (median)")
    ax.fill_between(t[:, 1], t[:, 4], t[:, 5], alpha=0.15)
    refs(ax)
    ax.axvspan(PHI_SITES.min(), PHI_SITES.max(), color="orange", alpha=0.08, label="phi of the test sites")
    ax.set(ylim=(3, 15), xlabel="Emission angle of the 2nd point (deg)", ylabel="Mean 3D error (cm)",
           title="N = 2: nadir + one point at radius r")
    sec = ax.secondary_xaxis("top", functions=(lambda p_: h * np.tan(np.radians(p_)), lambda r: np.degrees(np.arctan(r / h))))
    sec.set_xlabel("radius r (m)")
    ax.legend(fontsize=8)
    c = np.array(cover)
    ax2.plot(c[:, 1], c[:, 2], "o-", ms=3.5, color="C3", label=f"random N = {DISC_N} within radius R (median)")
    ax2.fill_between(c[:, 1], c[:, 3], c[:, 4], color="C3", alpha=0.15)
    refs(ax2)
    ax2.axvspan(PHI_SITES.min(), PHI_SITES.max(), color="orange", alpha=0.08, label="phi of the test sites")
    ax2.set(ylim=(3, 15), xlabel="Largest emission angle covered (deg)", ylabel="Mean 3D error (cm)",
            title=f"Coverage of the calibration points (N = {DISC_N})")
    sec = ax2.secondary_xaxis("top", functions=(lambda p_: h * np.tan(np.radians(p_)), lambda r: np.degrees(np.arctan(r / h))))
    sec.set_xlabel("radius R (m)")
    ax2.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "where_to_calibrate.png"), dpi=200)

    # 3) sensitivity: 1 point (A from the nadir) with an assumed m; error landscape in (A, m)
    fig, (ax, ax2) = plt.subplots(1, 2, figsize=(12, 4.4))
    ax.plot(m_sweep, e_sweep, "-", lw=1.8)
    refs(ax)
    ax.set(ylim=(0, 25), xlabel="Assumed Lambertian order m", ylabel="Mean 3D error (cm)",
           title="N = 1: A from the point below the LED, m assumed")
    ax.legend(fontsize=8)
    AA, MM = np.meshgrid(np.linspace(0.055, 0.068, 131), np.linspace(4.0, 8.5, 181))
    E = pos_error_cm(AA.ravel(), MM.ravel()).reshape(AA.shape)
    cs = ax2.contourf(AA, MM, E, levels=[3, 3.5, 4, 4.5, 5, 6, 8, 10, 15, 20], cmap="viridis_r", extend="max")
    fig.colorbar(cs, ax=ax2, label="Mean 3D error (cm)")
    ax2.plot(ref["all_scan_joint"]["A"], ref["all_scan_joint"]["m"], "k*", ms=10, label="all scan points")
    ax2.plot(ref["oracle_best_for_3D"]["A"], ref["oracle_best_for_3D"]["m"], "g^", ms=8, label="best possible")
    ax2.plot(np.exp(LY[NADIR] - m_sweep * LX[NADIR]), m_sweep, "w--", lw=1, label="A from the nadir point")
    ax2.set(xlim=(0.055, 0.068), ylim=(4, 8.5), xlabel="A (V m$^2$)", ylabel="m",
            title="3D error for any (A, m)")
    ax2.legend(fontsize=8, loc="upper left")
    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "sensitivity_A_m.png"), dpi=200)

    # 4) why: apparent m of every point with A from the nadir point, m_app = log(L) / log(cos phi)
    fig, ax = plt.subplots(figsize=(7.5, 4.2))
    sel = ok_map & (PHI_DEG >= 2)
    m_app = (LY[sel] - LY[NADIR]) / LX[sel]
    ax.scatter(PHI_DEG[sel], m_app, s=1, alpha=0.15, color="C0", label="every scan point")
    edges = np.arange(2, 39, 1.0)
    b = np.digitize(PHI_DEG[sel], edges)
    centers = [0.5 * (edges[i - 1] + edges[i]) for i in range(1, len(edges)) if np.any(b == i)]
    meds = [np.median(m_app[b == i]) for i in range(1, len(edges)) if np.any(b == i)]
    ax.plot(centers, meds, "k-", lw=1.8, label="median per 1 deg bin")
    ax.axhline(ref["all_scan_joint"]["m"], color="k", ls="--", lw=1, label=f"single m (all points) = {ref['all_scan_joint']['m']:.2f}")
    ax.axvspan(PHI_SITES.min(), PHI_SITES.max(), color="orange", alpha=0.08, label="phi of the test sites")
    ax.set(ylim=(3, 12), xlabel="Emission angle phi (deg)", ylabel="Apparent m (A from the nadir point)",
           title="The pattern R(phi) L(phi) is not SQ x cos^m with one m")
    ax.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "apparent_m_vs_phi.png"), dpi=200)

    # 5) the patterns on the map (examples)
    rng = np.random.default_rng(3)
    fig, axs = plt.subplots(1, 4, figsize=(15, 4.2), sharey=True)
    examples = [("Regular 4x4 grid over the area (16)", pat_area_grid(4)),
                ("Random, whole area (N = 10)", pat_random_area(10, rng)),
                (f"Nadir + radial up to {RADIAL_RMAX_M:g} m (N = 6)", pat_radial(6, rng)),
                ("3x3 grid, 0.2 m, centred on the LED", pat_grid(3, 0.2))]
    for ax, (title, idx) in zip(axs, examples):
        ax.scatter(Y[::7], X[::7], c=1e3 * RSS[::7], s=1, cmap="magma")
        ax.plot(Y[idx], X[idx], "co", ms=6, mec="k")
        ax.plot(led_xy[1], led_xy[0], "y*", ms=12, mec="k")
        for rr in (0.3, 0.6):
            a = np.linspace(0, 2 * np.pi, 200)
            ax.plot(led_xy[1] + rr * np.sin(a), led_xy[0] + rr * np.cos(a), "w:", lw=0.8)
        ax.set(title=title, xlabel="Y (m)", xlim=(1.4, 0), ylim=(0, 1.4), aspect="equal")
        ax.grid(False)
    axs[0].set_ylabel("X (m)")
    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "patterns.png"), dpi=200)
    plt.close("all")


if __name__ == "__main__":
    main()
