"""Unit tests of the vlp package (noise-free recovery, range, calibration).

    python -m unittest discover -s tests -v        (from the demo folder)
"""

import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from vlp import (CosinePowerResponse, Lambertian, SQResponse, VLPModel, estimate_position,  # noqa: E402
                 fit_lambertian, profile_amplitude, tilted_normals)

LED = np.array([0.28, 0.90, 3.0])
RNG = np.random.default_rng(1)


def positions(n=40):
    """PD positions spread like the testbed (X, Y in [0.1, 1.3] m, Z in [0.9, 1.4] m)."""
    return np.column_stack([RNG.uniform(0.1, 1.3, n), RNG.uniform(0.1, 1.3, n), RNG.uniform(0.9, 1.4, n)])


def cone(K, tilt_deg=15.0, start_deg=0.0):
    return tilted_normals(np.radians(start_deg + 360.0 * np.arange(K) / K), np.radians(tilt_deg))


class TestResponses(unittest.TestCase):
    def test_sq_values(self):
        r = SQResponse(0.61)
        self.assertAlmostEqual(float(r.value(1.0)), 1.0)
        self.assertAlmostEqual(float(r.value(np.cos(0.61))), 1 / np.sqrt(2), places=12)
        self.assertAlmostEqual(r.zero_deg, 64.58, places=2)
        self.assertEqual(float(r.value(np.cos(np.radians(70)))), 0.0)

    def test_derivatives_match_finite_differences(self):
        for resp in (SQResponse(0.61), CosinePowerResponse(1.9, 64), CosinePowerResponse(1.0, 64)):
            s = np.linspace(0.5, 0.999, 25)
            fd = (resp.value(s + 1e-7) - resp.value(s - 1e-7)) / 2e-7
            np.testing.assert_allclose(resp.derivative(s), fd, rtol=1e-5, err_msg=resp.name)


class TestEstimators(unittest.TestCase):
    def check(self, response, method, K, tol=1e-6):
        model = VLPModel(LED, response, Lambertian(6.0), A=0.06)
        normals = cone(K)
        errors = []
        for r in positions():
            y = model.rss(r, normals)
            est = estimate_position(method, y, normals, model)
            self.assertTrue(est.ok, f"{response.name} {method} K={K}: {est.status}")
            errors.append(np.linalg.norm(est.position - r))
        self.assertLess(max(errors), tol, f"{response.name} {method} K={K}")

    def test_sq_all_methods(self):
        for method in ("GLS", "WLS", "NLS"):
            for K in (4, 5, 10):
                self.check(SQResponse(0.61), method, K)

    def test_cosine_power_linear_and_nls(self):
        for resp in (CosinePowerResponse(1.9, 64), CosinePowerResponse(1.0, 64)):
            for method in ("GLS", "WLS", "NLS"):
                self.check(resp, method, 5)

    def test_linear_flag(self):
        model = VLPModel(LED, CosinePowerResponse(1.9, 64), Lambertian(6.0), A=0.06)
        y = model.rss(np.array([0.7, 0.7, 1.1]), cone(5))
        self.assertTrue(estimate_position("GLS", y, cone(5), model).linear)
        self.assertFalse(estimate_position("NLS", y, cone(5), model).linear)

    def test_range_is_the_broadcast_dual(self):
        model = VLPModel(LED, SQResponse(0.61), Lambertian(5.6), A=0.0605)
        r, normals = np.array([1.0, 0.4, 1.0]), cone(10)
        y = model.rss(r, normals) * (1 + 0.01 * RNG.standard_normal(10))
        est = estimate_position("NLS", y, normals, model)
        h = model.response.value(normals @ est.direction)
        eta = profile_amplitude(y, h)
        d = np.sqrt(model.A * (model.q @ est.direction) ** model.emitter.m / eta)
        self.assertAlmostEqual(est.distance, d, places=12)

    def test_noise_gives_small_error(self):
        model = VLPModel(LED, SQResponse(0.61), Lambertian(5.6), A=0.0605)
        normals, errs = cone(10), []
        for r in positions(30):
            y = model.rss(r, normals) * (1 + 0.003 * RNG.standard_normal(10))
            errs.append(np.linalg.norm(estimate_position("NLS", y, normals, model).position - r))
        self.assertLess(np.mean(errs), 0.05)

    def test_outside_field_of_view_is_flagged(self):
        model = VLPModel(LED, CosinePowerResponse(1.0, 20), Lambertian(6.0), A=0.06)
        normals = cone(5, tilt_deg=15)
        y = np.abs(model.rss(np.array([1.3, 0.1, 1.0]), normals)) + 1e-6
        est = estimate_position("GLS", y, normals, model)
        self.assertFalse(est.ok)


class TestCalibration(unittest.TestCase):
    def test_fit_lambertian_recovers_a_and_m(self):
        resp, h = SQResponse(0.61), 1.865
        g = np.arange(0.0, 1.01, 0.05)
        xy = np.array([(x, y) for x in g for y in g])
        led_xy = np.array([0.30, 0.90])
        d = np.sqrt(np.sum((xy - led_xy) ** 2, axis=1) + h ** 2)
        c = h / d
        y = 0.06 * resp.value(c) * c ** 6.0 / d ** 2
        for method in ("staged", "joint"):
            A, m, _ = fit_lambertian(xy, y, led_xy, h, resp, method)
            self.assertAlmostEqual(A, 0.06, places=10)
            self.assertAlmostEqual(m, 6.0, places=8)


if __name__ == "__main__":
    unittest.main()
