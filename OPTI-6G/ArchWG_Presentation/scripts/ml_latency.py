"""Single-fix inference time of the two ML correction models (trained once on all locations)."""
import os, time, numpy as np
src = open(os.path.join(os.path.dirname(__file__), "ml_positioning.py"), encoding="utf-8").read().split("variants = {")[0]
ns = {"__file__": os.path.join(os.path.dirname(__file__), "ml_positioning.py")}
exec(compile(src, "ml_positioning", "exec"), ns)
Y, E, RSS, NR = ns["Y"], ns["E"], ns["RSS"], ns["NR"]
F = np.c_[E, RSS, NR]
for name, make in [("ExtraTrees", ns["extra_trees"]), ("NeuralNet", ns["neural_net"])]:
    m = make().fit(F, Y - E)
    if name == "ExtraTrees":
        m.set_params(n_jobs=1)
    x = F[:1]
    for _ in range(20):
        m.predict(x)                      # warm-up
    t = []
    for i in range(200):
        t0 = time.perf_counter(); m.predict(F[i:i + 1]); t.append(time.perf_counter() - t0)
    print(f"{name}: median {1e3 * np.median(t):.2f} ms, p95 {1e3 * np.percentile(t, 95):.2f} ms per fix")
