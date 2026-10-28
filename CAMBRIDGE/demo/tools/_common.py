"""Shared helpers of the command-line tools: import paths and campaign loading."""

import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO_ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(DEMO_ROOT, "app"))
sys.path.insert(0, DEMO_ROOT)

import numpy as np                      # noqa: E402

from settings import check_z_convention, load_settings, resolve   # noqa: E402,F401


def read_csv(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def load_sites(campaign_dirs, column):
    """Complete sites of database_acquisition campaigns: list of dicts gantry_mm, angles, rss, campaign."""
    sites = []
    for c, d in enumerate(campaign_dirs):
        check_z_convention(d)
        groups = {}
        rows = read_csv(os.path.join(d, "points.csv"))
        K = len({r["k"] for r in rows})
        for r in rows:
            groups.setdefault(r["site_id"], []).append(r)
        for sid, g in groups.items():
            if len(g) != K or len({r["k"] for r in g}) != K:
                continue
            g.sort(key=lambda r: int(r["k"]))
            sites.append({"campaign": c, "site_id": int(sid),
                          "gantry_mm": tuple(float(g[0][k]) for k in ("x_cmd_mm", "y_cmd_mm", "z_cmd_mm")),
                          "angles": np.array([float(r["angle_deg"]) for r in g]),
                          "rss": np.array([float(r[column]) for r in g])})
    return sites
