"""
Levenberg-Marquardt on the unit sphere (port of pd_fit_lm.m).

The direction u is updated with two tangent coordinates (no azimuth singularity at the pole):
    u+ = cos(rho) u + sin(rho)/rho E dw,   rho = |dw|,   E = tangent_basis(u)
Extra parameters (e.g. a log-amplitude) are updated additively. A step is accepted only if the
cost does not increase; the damping is adapted as in the MATLAB implementation.
"""

import numpy as np

EPS = np.finfo(float).eps


def tangent_basis(n):
    """Two orthonormal vectors orthogonal to the unit vector n (3, 2), as rx_tangent_basis.m."""
    axis = np.zeros(3)
    axis[int(np.argmin(np.abs(n)))] = 1.0
    a = axis - n * (n @ axis)
    a /= np.linalg.norm(a)
    return np.column_stack([a, np.cross(n, a)])


def lm_sphere(residual, u, extra, max_iterations=80, gradient_tol=1e-10, step_tol=1e-9):
    """Minimizes |r(u, extra)|^2. residual(u, extra) -> (r, J) with J = [dr/dw (2 cols), dr/dextra],
    or (None, None) outside the physical domain. Returns (u, extra, cost, status, iterations)."""
    u = np.asarray(u, dtype=float)
    u = u / np.linalg.norm(u)
    extra = np.asarray(extra, dtype=float)
    lam, cost, status = 1e-3, np.inf, "iteration_limit"

    def cost_of(uu, ee):
        r, _ = residual(uu, ee)
        return float(r @ r) if r is not None and np.all(np.isfinite(r)) else np.inf

    for it in range(1, max_iterations + 1):
        r, J = residual(u, extra)
        if r is None or not np.all(np.isfinite(r)):
            return u, extra, np.inf, "invalid_model_region", it
        cost = float(r @ r)
        g = J.T @ r
        if np.max(np.abs(g)) <= gradient_tol * (1 + cost):
            return u, extra, cost, "success", it
        Hm = J.T @ J
        diag = np.maximum(np.diag(Hm), np.max(np.diag(Hm)) * 1e-12)
        E = tangent_basis(u)
        accepted = False
        for _ in range(16):
            try:
                step = -np.linalg.solve(Hm + lam * np.diag(diag), g)
            except np.linalg.LinAlgError:
                lam = min(lam * 10, 1e16)
                continue
            rho = float(np.linalg.norm(step[:2]))
            factor = np.sin(rho) / rho if rho > 0 else 1.0
            cand = np.cos(rho) * u + factor * (E @ step[:2])
            cand /= np.linalg.norm(cand)
            cand_extra = extra + step[2:]
            new_cost = cost_of(cand, cand_extra)
            if np.isfinite(new_cost) and new_cost <= cost:
                u, extra, cost = cand, cand_extra, new_cost
                lam = max(lam / 3, 1e-12)
                accepted = True
                break
            lam = min(lam * 10, 1e16)
        if accepted and np.linalg.norm(step) <= step_tol:
            return u, extra, cost, "success", it
        if not accepted:
            corr = np.linalg.lstsq(J, r, rcond=None)[0]
            roundoff = EPS * (np.linalg.norm(r) + 1) * np.linalg.norm(r)
            ok = np.linalg.norm(corr) <= step_tol or (np.linalg.norm(corr) <= np.sqrt(EPS)
                                                      and np.linalg.norm(J @ corr) ** 2 <= roundoff)
            return u, extra, cost, "success" if ok else "step_rejected", it
    return u, extra, cost, status, max_iterations
