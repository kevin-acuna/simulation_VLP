"""
Calibration helpers.

fit_lambertian: A and m of y = A R(psi) cos(phi)^m / d^2 from a horizontal scan (PD facing up under
    a LED facing down, so psi = phi and cos(phi) = h / d). As in
    analysis/Lambertian_order_LED_500khz/estimate_led_pattern.m:
      'staged'  A from the point closest to the LED axis, then m by least squares of
                log(y d^2 / (A R)) = m log cos(phi)
      'joint'   log A and m together by linear least squares
    The scan only fixes the product R * L: m depends on the PD response used (use the same response
    for the calibration and for the estimation).

fit_scalar: bounded 1-D minimization (grid + golden section), e.g. for the MTRS angle offset.
"""

import math

import numpy as np


def fit_lambertian(xy_m, rss, led_xy_m, h_m, response, method="staged"):
    """Returns (A, m, info). xy_m: (P, 2) PD positions [m], rss: (P,), led_xy_m: (2,), h_m: LED-PD height."""
    xy, y = np.asarray(xy_m, dtype=float), np.asarray(rss, dtype=float)
    r = np.hypot(xy[:, 0] - led_xy_m[0], xy[:, 1] - led_xy_m[1])
    d = np.sqrt(r ** 2 + h_m ** 2)
    c = h_m / d
    R = response.value(c)
    ok = (R > 0) & (y > 0)
    Y = np.log(y[ok] * d[ok] ** 2 / R[ok])
    X = np.log(c[ok])
    if method == "staged":
        log_a = Y[int(np.argmin(r[ok]))]
        m = float(np.sum((Y - log_a) * X) / np.sum(X ** 2))
    elif method == "joint":
        log_a, m = np.linalg.lstsq(np.column_stack([np.ones_like(X), X]), Y, rcond=None)[0]
    else:
        raise ValueError("method must be 'staged' or 'joint'")
    resid = Y - log_a - m * X
    info = {"n_points": int(ok.sum()), "rms_log": float(np.sqrt(np.mean(resid ** 2))),
            "max_phi_deg": float(np.degrees(np.arccos(c[ok].min())))}
    return float(np.exp(log_a)), float(m), info


def fit_scalar(cost, lo, hi, grid_step=0.25, tol=1e-4):
    """Minimizes cost(x) on [lo, hi]: coarse grid, then golden section around the best node."""
    xs = np.arange(lo, hi + 1e-12, grid_step)
    vals = [cost(x) for x in xs]
    k = int(np.argmin(vals))
    a, b = xs[max(k - 1, 0)], xs[min(k + 1, len(xs) - 1)]
    g = (math.sqrt(5) - 1) / 2
    c, d = b - g * (b - a), a + g * (b - a)
    fc, fd = cost(c), cost(d)
    while b - a > tol:
        if fc < fd:
            b, d, fd = d, c, fc
            c = b - g * (b - a)
            fc = cost(c)
        else:
            a, c, fc = c, d, fd
            d = a + g * (b - a)
            fd = cost(d)
    x = 0.5 * (a + b)
    return float(x), float(cost(x))
