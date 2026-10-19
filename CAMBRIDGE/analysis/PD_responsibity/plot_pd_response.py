"""
plot_pd_response.py - Angular responsivity models of the PDA100A2 compared in the experiments
(the same implementation used by the estimators: demo/vlp/responses.py).

    SQ          R = 1 - a psi^2,  a = (1 - 1/sqrt(2)) / psi_3dB^2      (Bastiaens et al. 2020)
    cos^m_R     R = cos(psi)^m_R  inside the FOV
    cos         R = cos(psi)      inside the FOV

    python plot_pd_response.py      # pd_response.png / pd_response.pdf
"""

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.normpath(os.path.join(HERE, "..", "..", "demo"))
sys.path[:0] = [os.path.join(DEMO, "app"), DEMO]

from settings import load_settings                      # noqa: E402

S = load_settings()
sys.path.insert(0, DEMO)
from vlp import make_response                            # noqa: E402

p = S["positioning"]                                     # values used by the demo / analysis
PSI_3DB, M_R, FOV = p["psi_3db_rad"], p["m_R"], p["pd_fov_deg"]

import matplotlib                                        # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt                          # noqa: E402

models = [("SQ: $1 - a\\,\\psi^2$", make_response("SQ", PSI_3DB, M_R, FOV), "C0", "-"),
          (f"$\\cos^{{{M_R:g}}}\\psi$ (FOV {FOV:g}°)", make_response("cosine_mR", PSI_3DB, M_R, FOV), "C1", "--"),
          (f"$\\cos\\psi$ (FOV {FOV:g}°)", make_response("cosine", PSI_3DB, M_R, FOV), "C3", ":")]

psi_deg = np.linspace(0, 90, 901)
s = np.cos(np.radians(psi_deg))
plt.rcParams.update({"font.size": 10, "axes.grid": True, "grid.alpha": 0.3})
fig, ax = plt.subplots(figsize=(6.4, 4.0))
for label, resp, c, ls in models:
    ax.plot(psi_deg, resp.value(s), color=c, ls=ls, lw=2, label=label)
sq = models[0][1]
ax.axhline(1 / np.sqrt(2), color="0.5", lw=0.8)
ax.axvline(np.degrees(PSI_3DB), color="C0", lw=0.8, alpha=0.6)
ax.annotate(f"$\\psi_{{3\\mathrm{{dB}}}}$ = {PSI_3DB:g} rad ({np.degrees(PSI_3DB):.1f}°)",
            (np.degrees(PSI_3DB), 1 / np.sqrt(2)), xytext=(4, 0.60), fontsize=8.5, color="C0",
            arrowprops={"arrowstyle": "->", "color": "C0", "lw": 0.8})
ax.annotate(f"SQ zero: {sq.zero_deg:.2f}°", (sq.zero_deg, 0), xytext=(sq.zero_deg + 2, 0.08), fontsize=8.5, color="C0",
            arrowprops={"arrowstyle": "->", "color": "C0", "lw": 0.8})
ax.annotate(f"FOV cut-off {FOV:g}°", (FOV, 0.44), xytext=(FOV + 4, 0.52), fontsize=8.5, color="0.3",
            arrowprops={"arrowstyle": "->", "color": "0.4", "lw": 0.8})
ax.set(xlim=(0, 90), ylim=(0, 1.03), xlabel="Incidence angle $\\psi$ (deg)", ylabel="Normalized responsivity $R(\\psi)$",
       title="PDA100A2 angular responsivity models")
ax.legend(loc="lower left", fontsize=9)
fig.tight_layout()
for ext in ("png", "pdf"):
    fig.savefig(os.path.join(HERE, f"pd_response.{ext}"), dpi=300)
print(f"SQ: psi_3dB = {PSI_3DB} rad ({np.degrees(PSI_3DB):.2f} deg), a = {sq.a:.5f} rad^-2, zero at {sq.zero_deg:.2f} deg; "
      f"cos^mR: m_R = {M_R}, FOV = {FOV} deg")
