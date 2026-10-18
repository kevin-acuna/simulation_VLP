"""
test_led_height.py - Can the LED HEIGHT be calibrated too, from one plane of 3x3 / 4x4 points?

Horizontal scan (PD facing up, K = 1, one gantry z), model RSS = A R_SQ(phi) cos(phi)^m / d^2 with the LED
facing down at (x, y, H). The PD height is known (gantry). Fitted from the calibration points:
  xyH  : LED X, Y, H + A, m      (H free)
  xy   : LED X, Y + A, m         (H = 3.0 m assumed, as in the other studies)
Checks: (1) profile of the fit cost vs H (is H identifiable from one plane?), (2) stability: the fit
repeated on grids shifted by +-10..50 mm and on random subsets, (3) 3D positioning of the 125 test sites
with each calibration (single LED, SQ + NLS as in the demo). Nothing of the other scripts is changed.

    python test_led_height.py            # table on screen, led_height_results.json, figures/led_height_*.png
"""

import json
import os
import sys

import numpy as np
from scipy.optimize import minimize

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_other_leds as T          # noqa: E402  (data, grids, site estimates, positioning)

# ============================================================
# HYPERPARAMETERS
# ============================================================
LEDS_KHZ = [500.0, 300.0, 900.0, 700.0]
GRIDS = [3, 4, "all"]
H_ASSUMED_M = 3.0
H_PROFILE_M = np.arange(2.5, 3.81, 0.02)
SHIFTS_MM = [-50, -30, -10, 10, 30, 50]     # stability: the n x n grid shifted in X and Y
N_RANDOM = 200                              # stability: random subsets of 16 points over the area
SEED = 2
PD_Z_M = T.LED_HEIGHT_M - T.h               # height of the PD centre in the scan


def lin(idx, f, xy, H):
    hh = H - PD_Z_M
    r = np.hypot(T.X[idx] - xy[0], T.Y[idx] - xy[1])
    d = np.hypot(r, hh)
    c = hh / d
    R = T.response.value(c)
    ok = (R > 0) & (T.RSS[f][idx] > 0)
    return np.log(T.RSS[f][idx][ok] * d[ok] ** 2 / R[ok]), np.log(c[ok])


def fit_Am(idx, f, xy, H):
    ly, lx = lin(idx, f, xy, H)
    M = np.column_stack([np.ones_like(lx), lx])
    coef, *_ = np.linalg.lstsq(M, ly, rcond=None)
    return float(np.exp(coef[0])), float(coef[1]), float(np.mean((ly - M @ coef) ** 2))


def fit(idx, f, free_h):
    best = None
    for k in np.argsort(T.RSS[f][idx])[::-1][:4]:
        x0 = [T.X[idx][k], T.Y[idx][k]] + ([H_ASSUMED_M] if free_h else [])
        cost = (lambda v: fit_Am(idx, f, v[:2], v[2])[2]) if free_h else (lambda v: fit_Am(idx, f, v, H_ASSUMED_M)[2])
        res = minimize(cost, x0, method="Nelder-Mead", options={"xatol": 1e-5, "fatol": 1e-14, "maxiter": 4000})
        if best is None or res.fun < best.fun:
            best = res
    xy, H = best.x[:2], (best.x[2] if free_h else H_ASSUMED_M)
    A, m, mse = fit_Am(idx, f, xy, H)
    return xy, H, A, m, mse


def profile(idx, f):
    """min over (x, y, A, m) of the cost for every fixed H."""
    out, x0 = [], None
    for H in H_PROFILE_M:
        k = int(np.argmax(T.RSS[f][idx]))
        start = x0 if x0 is not None else [T.X[idx][k], T.Y[idx][k]]
        res = minimize(lambda v: fit_Am(idx, f, v, H)[2], start, method="Nelder-Mead",
                       options={"xatol": 1e-5, "fatol": 1e-14})
        x0 = res.x
        out.append(res.fun)
    return np.array(out)


def positioning(f, xy, H, A, m, cache={}):
    if f not in cache:
        cache[f] = T.site_estimates(f)
    U, B, ok = cache[f]
    led = np.array([xy[0], xy[1], H])
    d = np.sqrt(A * np.clip(U[:, 2], 1e-9, None) ** m / B)
    e = (led[None, :] - d[:, None] * U) - T.TRUTH
    good = ok & np.isfinite(d)
    n = 100 * np.linalg.norm(e[good], axis=1)
    return float(n.mean()), float(100 * e[good, 2].mean())


def shifted_grid(n, dx, dy):
    v = np.linspace(*T.AREA_LIMITS_M, n)
    pts = {T.IDX.get((int(round((a + dx) / 0.01)), int(round((b + dy) / 0.01)))) for a in v for b in v}
    pts.discard(None)
    return np.array(sorted(pts))


def main():
    rng = np.random.default_rng(SEED)
    all_idx = np.arange(T.X.size)
    res, prof = {}, {}
    print(f"PD centre at {PD_Z_M:.4f} m in the scan; H assumed {H_ASSUMED_M} m in the other studies\n")
    print(f"{'LED':>6} {'cal':>4} {'fit':>4} | {'X (mm)':>7} {'Y (mm)':>7} {'H (m)':>6} {'A':>8} {'m':>5} {'rms %':>6} | "
          f"{'3D mean':>7} {'v.bias':>6} (cm) | H spread over shifted grids / random subsets")
    for f in LEDS_KHZ:
        res[f] = []
        for g in GRIDS:
            idx = all_idx if g == "all" else T.grid_idx(g)
            for free_h in (True, False):
                xy, H, A, m, mse = fit(idx, f, free_h)
                e3, vb = positioning(f, xy, H, A, m)
                spread = ""
                if free_h and g != "all":
                    Hs = [fit(shifted_grid(g, a / 1e3, b / 1e3), f, True)[1] for a in SHIFTS_MM for b in SHIFTS_MM[::2]]
                    spread = f"shifted: {min(Hs):.3f}-{max(Hs):.3f} m"
                elif free_h:
                    pool = np.flatnonzero((T.X >= 0.1) & (T.X <= 1.3) & (T.Y >= 0.1) & (T.Y <= 1.3))
                    Hs = [fit(rng.choice(pool, 16, replace=False), f, True)[1] for _ in range(N_RANDOM if f == 500 else 40)]
                    spread = f"random 16: P10-P90 {np.percentile(Hs, 10):.3f}-{np.percentile(Hs, 90):.3f} m"
                res[f].append({"cal": str(g), "H_free": free_h, "xy_mm": (1e3 * xy).tolist(), "H_m": H, "A": A, "m": m,
                               "rms_pct": 100 * np.sqrt(mse), "e3d_cm": e3, "vbias_cm": vb, "spread": spread})
                print(f"{f:5g}k {str(g):>4} {'xyH' if free_h else 'xy':>4} | {1e3 * xy[0]:7.1f} {1e3 * xy[1]:7.1f} {H:6.3f} "
                      f"{A:8.5f} {m:5.2f} {100 * np.sqrt(mse):6.2f} | {e3:7.2f} {vb:+6.2f}      | {spread}")
            prof[(f, str(g))] = profile(idx, f)
        print()
    with open(os.path.join(HERE, "led_height_results.json"), "w") as fh:
        json.dump({f"{f:g}kHz": v for f, v in res.items()}, fh, indent=2)
    figure(prof, res)


def figure(prof, res):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, axs = plt.subplots(1, len(LEDS_KHZ), figsize=(16, 4), sharey=True)
    for ax, f in zip(axs, LEDS_KHZ):
        for g, c in zip(GRIDS, ("C0", "C1", "k")):
            pr = prof[(f, str(g))]
            rms = 100 * np.sqrt(pr)
            ax.plot(H_PROFILE_M, rms - rms.min(), color=c, label=f"{g}x{g}" if g != "all" else "all points")
            Hf = next(r["H_m"] for r in res[f] if r["cal"] == str(g) and r["H_free"])
            ax.axvline(Hf, color=c, ls=":", lw=1)
        ax.axvline(H_ASSUMED_M, color="r", ls="--", lw=1, label="3.0 m (assumed)")
        ax.set(title=f"{f:g} kHz", xlabel="LED height H (m)", ylim=(0, 1.0))
        ax.grid(alpha=0.3)
    axs[0].set_ylabel("fit rms - min (%)  [X, Y, A, m re-fitted]")
    axs[0].legend(fontsize=8)
    fig.suptitle("Profile of the calibration fit vs the LED height (one plane of points)", fontsize=11)
    fig.tight_layout()
    fig.savefig(os.path.join(T.FIG_DIR, "led_height_profile.png"), dpi=200)
    plt.close("all")


if __name__ == "__main__":
    main()
