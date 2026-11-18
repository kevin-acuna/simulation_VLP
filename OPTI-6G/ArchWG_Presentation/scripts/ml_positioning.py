"""Data-driven 3D positioning on the exp3 campaign: Extra-Trees and a neural network (MLP).

Two ways of using the same models are evaluated:
  * fingerprint : inputs = log10 RSS of the K = 9 beams + receiver normal n_r (IMU)      -> (x, y, z)
  * hybrid      : inputs = model-based NLS estimate + log10 RSS + n_r                     -> correction of the
                  NLS estimate (the model learns the residual bias of the physical model)
Validation: 5-fold cross-validation grouped by location. All the fixes of a location (vertical + 3 tilts)
are in the same fold, so every location is predicted by models that never saw it during training.
Needs results/nls_estimates.csv (scripts/matlab/export_nls_estimates.m).
Writes results/ml_predictions.csv and results/ml_metrics.txt
"""
import csv, os
import numpy as np
from sklearn.ensemble import ExtraTreesRegressor
from sklearn.model_selection import GroupKFold
from sklearn.neural_network import MLPRegressor
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM = os.path.dirname(os.path.dirname(ROOT))
DATA = os.path.join(SIM, "ExpValidation_Journal", "Experiments", "exp3_SpatialDF", "data")
RES = os.path.join(ROOT, "results")
K_ID = list(range(1, 10))      # same 9-beam codebook as the model-based results
V_DARK = 0.05                   # same dark floor as the model-based pipeline
ZONE = 1.0                      # 2 m x 2 m target zone: |x|, |y| <= 1 m

# ------------------------------------------------------------------ dataset
sessions = sorted(d for d in os.listdir(DATA) if os.path.isfile(os.path.join(DATA, d, "master.csv")))
fixes = {}
for sidx, sess in enumerate(sessions, start=1):
    with open(os.path.join(DATA, sess, "master.csv")) as f:
        for r in csv.DictReader(f):
            key = (sidx, r["point_id"], r["repeat_id"], r["scan_kind"], r["tilt_cmd_deg"], r["tilt_cmd_az"])
            d = fixes.setdefault(key, {"v": {}, "row": r})
            d["v"][int(r["orientation_id"])] = float(r["v_mean"])

RSS, NR, V, Y, groups, kind = [], [], [], [], [], []
for (sidx, pid, rep, sk, tdeg, taz), d in sorted(fixes.items()):
    if not all(k in d["v"] for k in K_ID):
        continue
    r = d["row"]
    v = np.array([d["v"][k] for k in K_ID])
    inc, az = np.radians(float(r["nr_incl"])), np.radians(float(r["nr_az"]))
    RSS.append(np.log10(np.maximum(v - V_DARK, 1e-4)))
    NR.append([np.sin(inc) * np.cos(az), np.sin(inc) * np.sin(az), np.cos(inc)])
    V.append(v)
    Y.append([float(r["x"]), float(r["y"]), float(r["z"])])
    groups.append(f"S{sidx}P{int(pid.rsplit('_', 1)[1])}")
    kind.append(sk.strip())
RSS, NR, V, Y, groups, kind = map(np.array, (RSS, NR, V, Y, groups, kind))
print(f"{len(Y)} fixes, {len(set(groups))} locations, {np.sum(kind == 'vertical')} vertical / {np.sum(kind == 'tilt')} tilted")

# model-based NLS estimate of every fix (matched by location label and beam voltages)
nls = {}
with open(os.path.join(RES, "nls_estimates.csv")) as f:
    for r in csv.DictReader(f):
        nls.setdefault(r["label"].split(".")[0], []).append(
            (np.array([float(r[f"V_k{k}"]) for k in K_ID]), [float(r[c]) for c in ("nls_x", "nls_y", "nls_z")]))
E, worst = [], 0.0
for i in range(len(Y)):
    cands = nls[groups[i]]
    dv = [np.max(np.abs(c[0] - V[i])) for c in cands]
    j = int(np.argmin(dv))
    worst = max(worst, dv[j])
    E.append(cands[j][1])
E = np.array(E)
assert worst < 1e-5, f"NLS matching failed ({worst})"

# ------------------------------------------------------------------ models
def extra_trees():
    return ExtraTreesRegressor(n_estimators=500, max_features=1.0, min_samples_leaf=1, n_jobs=-1, random_state=0)


def neural_net():
    return make_pipeline(StandardScaler(),
                         MLPRegressor(hidden_layer_sizes=(128, 64), activation="relu", alpha=1e-3,
                                      learning_rate_init=1e-3, max_iter=5000, early_stopping=True,
                                      validation_fraction=0.15, n_iter_no_change=100, random_state=0))


variants = {
    "fingerprint": (np.c_[RSS, NR], np.zeros_like(Y)),   # features, offset added to the prediction
    "hybrid":      (np.c_[E, RSS, NR], E),
}
models = {"ET": extra_trees, "NN": neural_net}
pred = {}
cv = list(GroupKFold(n_splits=5, shuffle=True, random_state=0).split(Y, Y, groups))
for tr, te in cv:
    assert not set(groups[tr]) & set(groups[te]), "train/test locations overlap"
for vname, (F, off) in variants.items():
    for mname, make in models.items():
        P = np.full_like(Y, np.nan)
        for tr, te in cv:
            mdl = make().fit(F[tr], Y[tr] - off[tr])
            P[te] = off[te] + mdl.predict(F[te])
        pred[f"{vname}_{mname}"] = P
print("folds:", [(len(set(groups[tr])), len(set(groups[te]))) for tr, te in cv], "(train/test locations)")

# ------------------------------------------------------------------ metrics
def stats(e):
    e = np.sort(e)
    x = (np.arange(1, e.size + 1) - 0.5) / e.size * 100      # same percentile convention as the MATLAB figures
    p = lambda q: np.interp(q, np.r_[0, x, 100], np.r_[e[0], e, e[-1]])
    return e.size, p(50), p(90), np.sqrt(np.mean(e ** 2)), np.mean(e <= 5) * 100


zone = (np.abs(Y[:, 0]) <= ZONE + 1e-9) & (np.abs(Y[:, 1]) <= ZONE + 1e-9)
err = {k: 100 * np.linalg.norm(P - Y, axis=1) for k, P in pred.items()}
err["NLS"] = 100 * np.linalg.norm(E - Y, axis=1)
sels = [("zone vertical", zone & (kind == "vertical")), ("zone tilt", zone & (kind == "tilt")),
        ("all vertical", kind == "vertical"), ("all tilt", kind == "tilt")]
lines = []
for k in ["NLS"] + list(pred):
    for sname, sel in sels:
        n, med, p90, rmse, b5 = stats(err[k][sel])
        lines.append(f"{k:15s} {sname:14s} n={n:5d}  median {med:5.2f}  P90 {p90:5.2f}  RMSE {rmse:5.2f}  <=5cm {b5:5.1f}%")
txt = "\n".join(lines)
print(txt)
with open(os.path.join(RES, "ml_metrics.txt"), "w") as f:
    f.write("5-fold CV grouped by location (no location shared between training and test); 3D errors in cm\n" + txt + "\n")

with open(os.path.join(RES, "ml_predictions.csv"), "w", newline="") as f:
    w = csv.writer(f)
    keys = ["NLS"] + list(pred)
    w.writerow(["label", "kind", "x", "y", "z", "in_zone"] + [f"err_{k}_cm" for k in keys])
    for i in range(len(Y)):
        w.writerow([groups[i], kind[i], *Y[i], int(zone[i])] + [f"{err[k][i]:.4f}" for k in keys])
print("written", os.path.join(RES, "ml_predictions.csv"))
