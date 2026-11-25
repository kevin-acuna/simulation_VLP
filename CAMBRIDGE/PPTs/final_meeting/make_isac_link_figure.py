"""Link SNR at an unvisited orientation (Fig. 4(b) of the 23/11 ISAC report) without the outage line, for the
ISAC slide. Recomputes the leave-one-orientation-out prediction with the report scripts (%TEMP%/isac_report,
version of 23/11 22:50) and writes assets/isac_link_prediction.png; the plotted points are kept in
assets/isac_link_prediction.csv, which is used when the report scripts are no longer there.
Run from this folder: ../../isac_colab/.venv/Scripts/python.exe make_isac_link_figure.py
"""
import contextlib
import csv
import io
import os
import runpy
from pathlib import Path

import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

# ---- hyperparameters --------------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
REPORT_CODE = Path(os.environ["TEMP"]) / "isac_report"
OUT_PNG = HERE / "assets" / "isac_link_prediction.png"
OUT_CSV = HERE / "assets" / "isac_link_prediction.csv"
FIGSIZE = (3.908, 2.6)                     # same panel size and aspect as the crop used before (1144 x 761 px)
DPI = 300
COLORS, MARKERS = ["tab:blue", "tab:orange", "tab:green"], ["o", "s", "^"]
plt.rcParams.update({"font.family": "serif", "font.size": 8, "axes.titlesize": 8, "axes.labelsize": 8,
                     "legend.fontsize": 7, "xtick.labelsize": 7, "ytick.labelsize": 7, "lines.linewidth": 1.0})
# ------------------------------------------------------------------------------------------------


def points():
    if (REPORT_CODE / "loo_link_prediction.py").exists():
        with contextlib.redirect_stdout(io.StringIO()):
            L = runpy.run_path(str(REPORT_CODE / "loo_link_prediction.py"), run_name="lib")
        sid = {s: i for i, s in enumerate(dict.fromkeys(d["site"] for d in L["g"]["data"]))}
        rows = [dict(site=sid[x["site"]], meas=x["meas_snr"], pred=x["pred_snr"], mean=x["base_mean"])
                for x in L["out"] if x["key"] == "csi1" and "pred_snr" in x and np.isfinite(x["meas_snr"])]
        with open(OUT_CSV, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=["site", "meas", "pred", "mean"])
            w.writeheader()
            w.writerows(rows)
        return rows
    with open(OUT_CSV, encoding="utf-8") as f:
        return [dict(site=int(r["site"]), meas=float(r["meas"]), pred=float(r["pred"]), mean=float(r["mean"]))
                for r in csv.DictReader(f)]


def main():
    rows = points()
    rmse = lambda k: float(np.sqrt(np.mean([(r[k] - r["meas"]) ** 2 for r in rows])))
    fig, a = plt.subplots(figsize=FIGSIZE)
    for r in rows:
        a.plot(r["meas"], r["pred"], MARKERS[r["site"]], color=COLORS[r["site"]], ms=4)
        a.plot(r["meas"], r["mean"], MARKERS[r["site"]], color="0.55", ms=4, mfc="none")
    lim = (13, 25)
    a.plot(lim, lim, "k--", lw=0.8)
    a.fill_between(lim, [lim[0] - 1, lim[1] - 1], [lim[0] + 1, lim[1] + 1], color="0.85", alpha=0.6, lw=0)
    a.plot([], [], "o", color="tab:blue", ms=4, label=f"position + model (RMSE {rmse('pred'):.2f} dB)")
    a.plot([], [], "o", color="0.55", ms=4, mfc="none", label=f"mean of visited (RMSE {rmse('mean'):.2f} dB)")
    a.set(xlabel="Measured link SNR at the held-out orientation [dB]", ylabel="Predicted link SNR [dB]", xlim=lim,
          ylim=lim)
    a.legend(loc="upper left")
    a.grid(alpha=0.3)
    a.set_title("(b) Link SNR at an unvisited orientation", loc="left")
    fig.tight_layout()
    fig.savefig(OUT_PNG, dpi=DPI, facecolor="white")
    print(f"{OUT_PNG} ({len(rows)} points, RMSE {rmse('pred'):.2f} / {rmse('mean'):.2f} dB)")


if __name__ == "__main__":
    main()
