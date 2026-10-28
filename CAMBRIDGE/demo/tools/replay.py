"""
replay.py - Replays recorded campaigns (database_acquisition points.csv) through the demo positioner
and reports the 3D errors. Validates the Python estimators against the MATLAB analysis
(analysis/Experiment_01_3D_estimation/estimate_3d_positions.m) and helps tuning config/demo.toml.

    python tools/replay.py                          # configured model, estimator, LED, offset
    python tools/replay.py --offset-fit cross       # MTRS offset fitted per height from the other ones
    python tools/replay.py --offset-fit all         # one offset from all sites (value for demo.toml)
    python tools/replay.py --led 281.1 904.8 --A 0.062707 --m 6.0918 --K 5
"""

import argparse
import dataclasses
import os
import time

import numpy as np

from _common import load_settings, load_sites, resolve

from positioner import Positioner          # noqa: E402
from vlp import fit_scalar                 # noqa: E402


def shape_rms(pos, sites, offset):
    """rms (%) of RSS_k / R(psi_k) around its per-site mean at the true positions (independent of A, m)."""
    g = dataclasses.replace(pos.geometry, mtrs_offset_deg=offset)
    dev = []
    for st in sites:
        u, _, _ = pos.model.geometry(g.pd_position(st["gantry_mm"]))
        R = pos.model.response.value(g.normals(st["angles"]) @ u)
        if np.any(R <= 0):
            return np.inf
        ratio = st["rss"] / R
        dev.append(ratio / ratio.mean() - 1)
    return 100 * float(np.sqrt(np.mean(np.concatenate(dev) ** 2)))


def fit_offset(pos, sites):
    x0 = pos.geometry.mtrs_offset_deg
    return fit_scalar(lambda o: shape_rms(pos, sites, o), x0 - 6, x0 + 6)


def subset(K_full, K, rotation=0):
    return np.sort((np.round(np.arange(K) * K_full / K).astype(int) + rotation) % K_full)


def main():
    s = load_settings()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--estimator", default=None)
    ap.add_argument("--response", default=None)
    ap.add_argument("--led", nargs=2, type=float, default=None, help="LED X Y [mm]")
    ap.add_argument("--A", type=float, default=None)
    ap.add_argument("--m", type=float, default=None)
    ap.add_argument("--offset", type=float, default=None, help="MTRS offset [deg]")
    ap.add_argument("--offset-fit", choices=("none", "all", "cross"), default="none")
    ap.add_argument("--K", type=int, default=None, help="use near-uniform subsets of K angles (all rotations)")
    a = ap.parse_args()
    for key, val in (("estimator", a.estimator), ("pd_response", a.response)):
        if val:
            s["positioning"][key] = val
    if a.led:
        s["led"]["xy_mm"] = a.led
    if a.A:
        s["led"]["A"] = a.A
    if a.m:
        s["led"]["m"] = a.m
    col = f"{s['positioning']['led_frequency_khz']:g}kHz_wave_Vrms"
    dirs = [os.path.join(resolve(s["paths"]["campaigns_root"]), c) for c in s["paths"]["campaigns"]]
    pos = Positioner.from_settings(s)
    if a.offset is not None:
        pos = Positioner(pos.model, dataclasses.replace(pos.geometry, mtrs_offset_deg=a.offset), pos.method, pos.starts)
    sites = load_sites(dirs, col)
    heights = sorted({st["gantry_mm"][2] for st in sites})
    print(f"{len(sites)} sites from {len(dirs)} campaigns, gantry z = {heights} mm; {pos.method} + "
          f"{pos.model.response.describe()}; LED {s['led']['xy_mm']} mm, A {pos.model.A:g}, m {pos.model.emitter.m:g}")

    offsets = {z: pos.geometry.mtrs_offset_deg for z in heights}
    if a.offset_fit == "all":
        o, rms = fit_offset(pos, sites)
        offsets = {z: o for z in heights}
        print(f"MTRS offset fitted on all sites: {o:.3f} deg (shape rms {rms:.2f} %)")
    elif a.offset_fit == "cross":
        for z in heights:
            o, _ = fit_offset(pos, [st for st in sites if st["gantry_mm"][2] != z])
            offsets[z] = o
        print("MTRS offset per height (fitted on the other heights): "
              + ", ".join(f"z={z:g}: {o:.3f}" for z, o in offsets.items()))
    else:
        print(f"MTRS offset {pos.geometry.mtrs_offset_deg:g} deg (shape rms {shape_rms(pos, sites, pos.geometry.mtrs_offset_deg):.2f} %)")

    t0 = time.perf_counter()
    rows = []
    for st in sites:
        geo = dataclasses.replace(pos.geometry, mtrs_offset_deg=offsets[st["gantry_mm"][2]])
        p = Positioner(pos.model, geo, pos.method, pos.starts)
        K_full = st["rss"].size
        subsets = [np.arange(K_full)] if not a.K else [subset(K_full, a.K, r) for r in range(K_full)]
        for sub in {tuple(x) for x in subsets}:
            sub = list(sub)
            r = p.locate(st["rss"][sub], st["angles"][sub], st["gantry_mm"])
            rows.append((st["gantry_mm"][2], r))
    dt = time.perf_counter() - t0
    ok = [r for _, r in rows if r["ok"]]
    e = 100 * np.array([r["err_3d_m"] for r in ok])
    print(f"\n{len(ok)}/{len(rows)} estimates ({1e3 * dt / len(rows):.1f} ms each): mean {e.mean():.2f} cm, "
          f"RMSE {np.sqrt(np.mean(e ** 2)):.2f}, median {np.median(e):.2f}, P90 {np.percentile(e, 90):.2f}, "
          f"horizontal {100 * np.mean([r['err_h_m'] for r in ok]):.2f}, vertical bias "
          f"{100 * np.mean([r['err_v_m'] for r in ok]):+.2f}, direction {np.mean([r['err_dir_deg'] for r in ok]):.2f} deg")
    for z in heights:
        sel = [r for zz, r in rows if zz == z and r["ok"]]
        ez = 100 * np.array([r["err_3d_m"] for r in sel])
        print(f"  gantry z = {z:6g} (PD {pos.geometry.pd_height(z):.3f} m): mean {ez.mean():5.2f} cm, "
              f"P90 {np.percentile(ez, 90):5.2f}, vertical bias {100 * np.mean([r['err_v_m'] for r in sel]):+5.2f}")
    failed = [r["status"] for _, r in rows if not r["ok"]]
    if failed:
        print("failures:", {f: failed.count(f) for f in set(failed)})


if __name__ == "__main__":
    main()
