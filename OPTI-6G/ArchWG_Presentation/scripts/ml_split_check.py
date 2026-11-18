"""Sensitivity of the ML results to stricter train/test splits (spatial blocks, whole sessions)."""
import os, numpy as np
src = open(os.path.join(os.path.dirname(__file__), "ml_positioning.py"), encoding="utf-8").read()
src = src.split("variants = {")[0]                      # dataset, NLS matching and model factories only
ns = {"__file__": os.path.join(os.path.dirname(__file__), "ml_positioning.py")}
exec(compile(src, "ml_positioning", "exec"), ns)
Y, E, RSS, NR, groups, kind = (ns[k] for k in ("Y", "E", "RSS", "NR", "groups", "kind"))
from sklearn.model_selection import GroupKFold, LeaveOneGroupOut
zone = (np.abs(Y[:, 0]) <= 1 + 1e-9) & (np.abs(Y[:, 1]) <= 1 + 1e-9)
sess = np.array([g.split("P")[0] for g in groups])
col = np.array([f"{x:.1f}_{y:.1f}" for x, y in Y[:, :2]])
blk = np.array([f"{np.floor((x + 2) / 0.6):.0f}_{np.floor((y + 2) / 0.6):.0f}" for x, y in Y[:, :2]])
splits = {
    "location (5-fold)": list(GroupKFold(5, shuffle=True, random_state=0).split(Y, Y, groups)),
    "xy column (5-fold)": list(GroupKFold(5, shuffle=True, random_state=0).split(Y, Y, col)),
    "0.6 m blocks (5-fold)": list(GroupKFold(5, shuffle=True, random_state=0).split(Y, Y, blk)),
    "leave-one-session-out": list(LeaveOneGroupOut().split(Y, Y, sess)),
}
cfg = {"hybrid ET": (np.c_[E, RSS, NR], E, ns["extra_trees"]),
       "hybrid NN": (np.c_[E, RSS, NR], E, ns["neural_net"]),
       "fingerprint NN": (np.c_[RSS, NR], np.zeros_like(Y), ns["neural_net"])}
zv, zt = zone & (kind == "vertical"), zone & (kind == "tilt")
e0 = 100 * np.linalg.norm(E - Y, axis=1)
print(f"{'NLS':16s} {'(no training)':24s} zone vertical P90 {np.percentile(e0[zv], 90):5.2f}  tilt P90 {np.percentile(e0[zt], 90):5.2f}")
for sname, sp in splits.items():
    for cname, (F, off, make) in cfg.items():
        P = np.full_like(Y, np.nan)
        for tr, te in sp:
            P[te] = off[te] + make().fit(F[tr], Y[tr] - off[tr]).predict(F[te])
        e = 100 * np.linalg.norm(P - Y, axis=1)
        print(f"{cname:16s} {sname:24s} zone vertical med {np.median(e[zv]):5.2f} P90 {np.percentile(e[zv], 90):5.2f}  tilt P90 {np.percentile(e[zt], 90):5.2f}")
