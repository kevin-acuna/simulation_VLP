"""
make_figures.py - Figures and numbers of the executive summary (final configuration of the demo:
SQ + NLS, LED 500 kHz at (281.1, 904.8) mm / 3.0 m, A and m from the horizontal scan, MTRS offset 66.5 deg).

    python make_figures.py      # fig_accuracy.png, fig_zaxis.png, numbers.json
"""

import csv
import dataclasses
import glob
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

from _common import load_sites, resolve                 # noqa: E402
from positioner import Positioner                       # noqa: E402


def subset(K_full, K, rot):
    return np.sort((np.round(np.arange(K) * K_full / K).astype(int) + rot) % K_full)


def run(pos, sites, K=None):
    out = []
    for st in sites:
        subs = [np.arange(st["rss"].size)] if K is None else [subset(st["rss"].size, K, r) for r in range(st["rss"].size)]
        for sub in {tuple(s) for s in subs}:
            sub = list(sub)
            r = pos.locate(st["rss"][sub], st["angles"][sub], st["gantry_mm"])
            if r["ok"]:
                out.append((st["gantry_mm"][2], 100 * r["err_3d_m"], 100 * r["err_v_m"]))
    return np.array(out)


def main():
    pos = Positioner.from_settings(S)
    dirs = [os.path.join(resolve(S["paths"]["campaigns_root"]), c) for c in S["paths"]["campaigns"]]
    sites = load_sites(dirs, "500kHz_wave_Vrms")
    res = {K: run(pos, sites, K) for K in (None, 5, 3)}

    # demo, random positions (blind): the two main sessions (the first 47 points of 11:34; 17:46 complete)
    demo, demo_true, demo_est = [], [], []
    for d, n_max in (("demo_20261016-113422*", 47), ("demo_20261016-174621*", None)):
        rows = [r for r in csv.DictReader(open(glob.glob(os.path.join(DEMO, "data", d))[0] + "/estimates.csv")) if r["err_3d_cm"]]
        for r in rows[:n_max]:
            demo.append(float(r["err_3d_cm"]))
            demo_true.append([float(r[f"true_{a}_m"]) for a in "XYZ"])
            demo_est.append([float(r[f"est_{a}_m"]) for a in "XYZ"])
    demo, demo_true, demo_est = np.array(demo), np.array(demo_true), np.array(demo_est)

    # gantry z: nominal (scale 1) vs measured (0.6)
    heights = sorted({st["gantry_mm"][2] for st in sites})
    zres = {}
    for sz in (1.0, 0.6):
        p = Positioner(pos.model, dataclasses.replace(pos.geometry, gantry_z_scale=sz), pos.method, pos.starts)
        r = run(p, sites)
        zres[sz] = {z: (r[r[:, 0] == z, 1].mean(), r[r[:, 0] == z, 2].mean()) for z in heights}
        zres[sz]["all"] = (r[:, 1].mean(), r[:, 2].mean())

    def st(e):
        return {"n": int(e.size), "mean": float(e.mean()), "median": float(np.median(e)),
                "rmse": float(np.sqrt(np.mean(e ** 2))), "p90": float(np.percentile(e, 90)), "max": float(e.max())}

    numbers = {"K10": st(res[None][:, 1]), "K5": st(res[5][:, 1]), "K3": st(res[3][:, 1]), "demo_random": st(demo),
               "vertical_bias_K10": float(res[None][:, 2].mean()),
               "z_axis": {f"scale_{sz:g}": {str(k): {"mean": float(v[0]), "vbias": float(v[1])} for k, v in d.items()}
                          for sz, d in zres.items()},
               "pd_height_m": {str(z): float(pos.geometry.pd_height(z)) for z in heights}}
    with open(os.path.join(HERE, "numbers.json"), "w") as f:
        json.dump(numbers, f, indent=2)
    print(json.dumps({k: v for k, v in numbers.items() if k != "z_axis"}, indent=1))
    for sz, d in zres.items():
        print(f"z scale {sz}: " + ", ".join(f"z={k}: {v[0]:.1f} cm (bias {v[1]:+.1f})" for k, v in d.items()))

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams.update({"font.size": 9.5, "axes.grid": True, "grid.alpha": 0.3})

    # accuracy: CDF
    fig, ax = plt.subplots(figsize=(5.2, 3.4))
    for e, lab, c in ((res[None][:, 1], f"Grid, K = 10 (125 positions)", "C0"),
                      (res[5][:, 1], "Grid, K = 5 (subsets)", "C1"),
                      (res[3][:, 1], "Grid, K = 3 (subsets)", "C3"),
                      (demo, f"Live demo, random positions, K = 5 ({demo.size})", "k")):
        x = np.sort(e)
        ax.plot(x, np.arange(1, x.size + 1) / x.size, color=c, lw=1.8, ls="--" if c == "k" else "-",
                label=f"{lab}: mean {e.mean():.1f} cm")
    ax.set(xlim=(0, 12), ylim=(0, 1), xlabel="3D positioning error (cm)", ylabel="CDF")
    ax.legend(fontsize=7.5, loc="lower right")
    fig.tight_layout()
    fig.savefig(os.path.join(HERE, "fig_accuracy.png"), dpi=250)

    # z axis: vertical bias per height, nominal vs measured scale
    fig, ax = plt.subplots(figsize=(5.2, 3.2))
    xs = np.arange(len(heights))
    for i, (sz, lab, c) in enumerate(((1.0, "Nominal Z (as commanded)", "C3"), (0.6, "Measured Z scale (0.6)", "C0"))):
        b = [zres[sz][z][1] for z in heights]
        ax.bar(xs + (i - 0.5) * 0.38, b, 0.38, color=c, label=f"{lab}: mean error {zres[sz]['all'][0]:.1f} cm")
    ax.axhline(0, color="k", lw=0.8)
    ax.set(xticks=xs, xticklabels=[f"{z:g}" for z in heights], xlabel="Commanded gantry z (mm)",
           ylabel="Vertical bias of the estimate (cm)")
    ax.legend(fontsize=7.5, loc="upper left")
    fig.tight_layout()
    fig.savefig(os.path.join(HERE, "fig_zaxis.png"), dpi=250)

    # live demo: true vs estimated positions in 3D (single LED, K = 5)
    cmap, vmax = plt.get_cmap("viridis"), 8.0
    fig = plt.figure(figsize=(12.0, 5.2))
    gs = fig.add_gridspec(1, 2, width_ratios=[1.35, 1.0], wspace=0.28)
    # 3D view
    ax = fig.add_subplot(gs[0], projection="3d")
    for t, e, err in zip(demo_true, demo_est, demo):
        ax.plot(*zip(t, e), color=cmap(min(err / vmax, 1.0)), lw=0.9, alpha=0.9)
    ax.scatter(*demo_true.T, s=9, facecolors="none", edgecolors="k", linewidths=0.6, depthshade=False,
               label="True position")
    sc = ax.scatter(*demo_est.T, s=7, c=demo, cmap=cmap, vmin=0, vmax=vmax, depthshade=False,
                    label="Estimated position")
    ax.set(xlim=(0, 1.4), ylim=(0, 1.4), zlim=(0.9, 1.4))
    ax.set_xlabel("X (m)", labelpad=2)
    ax.set_ylabel("Y (m)", labelpad=2)
    ax.set_zlabel("")
    ax.text(1.4, 1.4, 1.47, "Z (m)", fontsize=10, ha="left", va="bottom")      # above the Z axis (corner 1.4, 1.4)
    ax.set_box_aspect((1.4, 1.4, 0.75), zoom=1.08)
    ax.view_init(elev=22, azim=-60)
    ax.tick_params(labelsize=8, pad=0)
    for pane in (ax.xaxis.pane, ax.yaxis.pane, ax.zaxis.pane):
        pane.set_facecolor((1, 1, 1, 0))
        pane.set_edgecolor("0.8")
    ax.set_title("3D view", fontsize=10)
    ax.legend(loc="upper left", fontsize=8, frameon=False)
    # orthographic top view
    ax2 = fig.add_subplot(gs[1])
    for t, e, err in zip(demo_true, demo_est, demo):
        ax2.plot([t[0], e[0]], [t[1], e[1]], color=cmap(min(err / vmax, 1.0)), lw=1.0)
    ax2.scatter(demo_true[:, 0], demo_true[:, 1], s=10, facecolors="none", edgecolors="k", linewidths=0.6)
    ax2.scatter(demo_est[:, 0], demo_est[:, 1], s=8, c=demo, cmap=cmap, vmin=0, vmax=vmax, zorder=3)
    ax2.set(xlim=(0, 1.4), ylim=(0, 1.4), aspect="equal", xlabel="X (m)", ylabel="Y (m)")
    ax2.set_title("Top view (horizontal error)", fontsize=10)
    ax2.tick_params(labelsize=8)
    cb = fig.colorbar(sc, ax=ax2, fraction=0.046, pad=0.03)
    cb.set_label("3D error (cm)")
    cb.ax.tick_params(labelsize=8)
    fig.savefig(os.path.join(HERE, "fig_demo_3d.png"), dpi=300, bbox_inches="tight")
    plt.close("all")


if __name__ == "__main__":
    main()
