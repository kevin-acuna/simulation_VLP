"""
Position estimators for one fixed LED and K orientations of the PD (numpy port of
CAMBRIDGE/simulations: Estimators/rx_estimate.m and Receiver models/Bastiaens 2020/Estimators/pd_fit_*.m).

Stage 1, direction u (unit vector PD -> LED), from the K RSS only (no A, no m):
    GLS  ratios to the strongest orientation with their full first-order covariance
    WLS  same ratios with the diagonal of that covariance
    NLS  joint least squares of the RSS with a free amplitude (direction + log-amplitude)
  With a power-law response R = s^nu, GLS/WLS are the linear TCOM estimators (ratio roots and the
  eigenvector of the smallest eigenvalue). For any other response (SQ) the ratios are fitted with a
  nonlinear Levenberg-Marquardt on the sphere (no closed form exists).

Stage 2, range (dual of F_broadcast_Konly/core/broadcast_distance.m):
    beta = sum(y h) / sum(h^2),  h_i = R(n_i . u),   d = sqrt(A L(c) / beta),   r = t - d u
  With NLS this is the Gaussian maximum-likelihood position for known A and m, because
  (u, beta) <-> (u, d) is one-to-one through beta = A L(u) / d^2.

All orientations must see the LED (full visibility); otherwise the estimate is flagged.
"""

from dataclasses import dataclass, field

import numpy as np

from .optim import lm_sphere, tangent_basis

METHODS = ("GLS", "WLS", "NLS")
RANK_TOL = 1e-10
BOUNDARY_TOL = 1e-12


@dataclass
class Estimate:
    ok: bool
    status: str
    method: str
    direction: np.ndarray = field(default_factory=lambda: np.full(3, np.nan))
    amplitude: float = float("nan")          # beta, RSS of a PD facing the LED at that distance
    distance: float = float("nan")           # m
    position: np.ndarray = field(default_factory=lambda: np.full(3, np.nan))
    cost: float = float("nan")               # sum of squared RSS residuals (RSS units^2)
    iterations: int = 0
    linear: bool = False                     # True: closed-form TCOM GLS/WLS (power-law response)

    def as_dict(self):
        return {"ok": self.ok, "status": self.status, "method": self.method,
                "direction": self.direction.tolist(), "amplitude": self.amplitude,
                "distance_m": self.distance, "position_m": self.position.tolist(), "cost": self.cost,
                "iterations": self.iterations, "linear": self.linear}


# ----------------------------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------------------------
def profile_amplitude(y, h):
    """Least-squares amplitude of y ~ beta h (equal variances); nan if not positive."""
    den = float(h @ h)
    beta = float(h @ y) / den if den > 0 else float("nan")
    return beta if beta > 0 else float("nan")


def _visible(u, H, q, response):
    s = H @ u
    return bool(q @ u > 0 and np.all(s > 0) and np.all(s > response.cutoff_cos))


def _seeds(q, H):
    """Fixed seed directions in the illuminated hemisphere (as pd_fit_context.m) + the normals."""
    E = tangent_basis(q)
    th, az = np.meshgrid(np.radians([20, 40, 60, 80]), np.radians(np.arange(0, 360, 45)), indexing="ij")
    th, az = th.ravel(), az.ravel()
    dirs = (np.outer(np.cos(th), q) + np.outer(np.sin(th) * np.cos(az), E[:, 0])
            + np.outer(np.sin(th) * np.sin(az), E[:, 1]))
    seeds = np.vstack([q, dirs, H[H @ q > 0]])
    seeds /= np.linalg.norm(seeds, axis=1, keepdims=True)
    _, keep = np.unique(np.round(seeds * 1e12), axis=0, return_index=True)
    return seeds[np.sort(keep)]


# ----------------------------------------------------------------------------------------------
# linear TCOM GLS / WLS (power-law response R = s^nu)
# ----------------------------------------------------------------------------------------------
def _ratio_eigen(y, H, nu, q, full_covariance):
    if nu != 1 and np.any(y <= 0):
        return None, "nonpositive_power_for_root"
    z = y if nu == 1 else y ** (1.0 / nu)
    dz = np.ones_like(y) if nu == 1 else y ** (1.0 / nu - 1.0) / nu
    ref = int(np.argmax(z))
    if z[ref] <= 0:
        return None, "nonpositive_reference"
    idx = np.array([i for i in range(y.size) if i != ref])
    t = z[idx] / z[ref]
    var = dz ** 2
    C = np.diag(var[idx]) + var[ref] * np.outer(t, t)
    C /= np.max(np.diag(C))
    A = H[idx] - np.outer(t, H[ref])
    if full_covariance:
        try:
            G = np.linalg.solve(np.linalg.cholesky(C), A)
        except np.linalg.LinAlgError:
            return None, "invalid_ratio_covariance"
    else:
        G = A / np.sqrt(np.diag(C))[:, None]
    M = G.T @ G
    w, V = np.linalg.eigh(0.5 * (M + M.T))
    u = V[:, int(np.argmin(w))]
    u = u if q @ u >= 0 else -u
    return u / np.linalg.norm(u), "success"


# ----------------------------------------------------------------------------------------------
# nonlinear estimators for a general response (pd_fit_estimate.m)
# ----------------------------------------------------------------------------------------------
class _Problem:
    """Residuals and Jacobians (tangent coordinates of u, and log-amplitude for NLS) of one fit."""

    def __init__(self, method, y, H, response, q):
        self.method, self.y, self.H, self.R, self.q = method, y, H, response, q
        if method in ("GLS", "WLS"):
            self.ref = int(np.argmax(y))
            self.idx = np.array([i for i in range(y.size) if i != self.ref])
            self.target = y[self.idx] / y[self.ref]
            C = np.eye(self.idx.size) + np.outer(self.target, self.target)     # equal variances
            C /= np.max(np.diag(C))
            self.chol = np.linalg.cholesky(C) if method == "GLS" else None
            self.sd = np.sqrt(np.diag(C))

    def residual(self, u, log_gamma=0.0):
        if self.q @ u <= 0:
            return None, None
        s = self.H @ u
        h, dh = self.R.value(s), self.R.derivative(s)
        D = dh[:, None] * (self.H @ tangent_basis(u))
        if self.method == "NLS":
            g = np.exp(log_gamma)
            return g * h - self.y, np.column_stack([g * D, g * h])
        href = h[self.ref]
        if href <= np.sqrt(np.finfo(float).tiny):
            return None, None
        r = h[self.idx] / href - self.target
        J = (D[self.idx] * href - np.outer(h[self.idx], D[self.ref])) / href ** 2
        if self.chol is not None:
            return np.linalg.solve(self.chol, r), np.linalg.solve(self.chol, J)
        return r / self.sd, J / self.sd[:, None]

    def cost(self, u, log_gamma=0.0):
        r, _ = self.residual(u, log_gamma)
        return float(r @ r) if r is not None and np.all(np.isfinite(r)) else np.inf


def _nonlinear_direction(method, y, H, response, q, starts=3):
    prob = _Problem(method, y, H, response, q)
    seeds = _seeds(q, H)
    shapes = response.value(seeds @ H.T)                               # (n_seeds, K)
    with np.errstate(divide="ignore", invalid="ignore"):
        amps = (shapes @ y) / np.sum(shapes ** 2, axis=1)
    scores = np.array([prob.cost(sd, np.log(a)) if np.isfinite(a) and a > 0 else np.inf
                       for sd, a in zip(seeds, amps)])
    order = [i for i in np.argsort(scores) if np.isfinite(scores[i])][:starts]
    if not order:
        return None, "no_physical_solution", np.inf, 0
    best = (None, "no_physical_solution", np.inf, 0)
    solutions = []
    for i in order:
        extra = np.array([np.log(amps[i])]) if method == "NLS" else np.zeros(0)
        u, ex, cost, status, it = lm_sphere(lambda uu, pp: prob.residual(uu, *pp), seeds[i], extra)
        if status == "success":
            solutions.append((u, cost))
            if cost < best[2]:
                best = (u, status, cost, it)
    if best[0] is not None:                       # several minima with the same cost: ambiguous
        for u, cost in solutions:
            if cost <= best[2] + 1e-12 * (1 + best[2]) and np.linalg.norm(u - best[0]) > 1e-3:
                return best[0], "multiple_competing_minima", best[2], best[3]
    return best


# ----------------------------------------------------------------------------------------------
# public API
# ----------------------------------------------------------------------------------------------
def estimate_direction(method, rss, normals, response, q, starts=3):
    """Stage 1 only. Returns (u, status, iterations, linear)."""
    method = method.upper()
    if method not in METHODS:
        raise ValueError(f"Unknown method {method} ({', '.join(METHODS)}).")
    y = np.asarray(rss, dtype=float)
    H = np.asarray(normals, dtype=float)
    scale = np.max(np.abs(y))
    if not scale > 0:
        return None, "zero_power_vector", 0, False
    y = y / scale
    if np.linalg.svd(H, compute_uv=False)[-1] <= RANK_TOL * np.linalg.norm(H, 2) or H.shape[0] < 3:
        return None, "rank_deficient", 0, False
    nu = response.power_law_order
    if method in ("GLS", "WLS") and nu is not None:
        u, status = _ratio_eigen(y, H, nu, q, method == "GLS")
        if u is not None and not _visible(u, H, q, response):
            status = "outside_full_visibility_domain"
        return u, status, 0, True
    u, status, _, it = _nonlinear_direction(method, y, H, response, q, starts)
    return u, status, it, False


def estimate_position(method, rss, normals, model, starts=3):
    """Direction (GLS / WLS / NLS) + range from the same K RSS. rss: (K,), normals: (K, 3)."""
    method = method.upper()
    y = np.asarray(rss, dtype=float)
    H = np.asarray(normals, dtype=float)
    q, R = model.q, model.response
    u, status, it, linear = estimate_direction(method, y, H, R, q, starts)
    est = Estimate(ok=False, status=status, method=method, iterations=it, linear=linear)
    if u is None or status != "success":
        return est
    est.direction = u
    s = H @ u
    h = R.value(s)
    if not linear:
        if np.any(np.abs(s - R.cutoff_cos) <= BOUNDARY_TOL):
            est.status = "boundary_solution"
            return est
        G = np.column_stack([h, R.derivative(s)[:, None] * (H @ tangent_basis(u))])
        sv = np.linalg.svd(G, compute_uv=False)
        if sv.size < 3 or sv[2] <= RANK_TOL * sv[0]:
            est.status = "rank_deficient_solution"
            return est
    beta = profile_amplitude(y, h)
    if not np.isfinite(beta):
        est.status = "nonpositive_amplitude"
        return est
    d = model.distance(u, beta)
    if not (np.isfinite(d) and d > 0):
        est.status = "invalid_distance"
        return est
    est.amplitude, est.distance = beta, d
    est.position = model.led_position - d * u
    est.cost = float(np.sum((beta * h - y) ** 2))
    est.ok = True
    return est
