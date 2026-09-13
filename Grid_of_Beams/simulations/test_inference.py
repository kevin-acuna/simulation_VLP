import unittest

import numpy as np
from numpy.testing import assert_allclose

from inference import PositionEstimator, information_metrics
from optics import OpticalConfig, OpticalModel, ReceiverNoise


class InferenceTests(unittest.TestCase):
    def test_noiseless_2d_and_3d_without_true_initialization(self):
        for config in (OpticalConfig(), OpticalConfig(radii=(.012, .015)),
                       OpticalConfig(radii=(-.010, -.011), edge_thickness=.006),
                       OpticalConfig(tiles=9, radii=(.012, .015))):
            model = OpticalModel(config)
            for dimensions in (2, 3):
                bounds = [[-.6, .6], [-.6, .6]] + ([[0., 1.]] if dimensions == 3 else [])
                estimator = PositionEstimator(model, bounds, grid_counts=(21, 21, 5)[:dimensions])
                position = np.array([.2137, -.1463, .436 if dimensions == 3 else 0.])
                result = estimator.fit(model.power_at(position))
                assert_allclose(result.position, position, atol=1e-7)
                self.assertLess(result.cost, 1e-10)

    def test_full_grid_seed_search_recovers_bright_region(self):
        from run_study import boundary_positions, sample_positions, study_cases
        case = next(c for c in study_cases() if c.name == 'grid_convex_core_2d')
        rng = np.random.default_rng(20260912)
        truth = sample_positions(case, 300, rng)
        model = OpticalModel(case.config)
        noise = ReceiverNoise(bandwidth=200.)
        mean = model.power_at(np.vstack((truth, boundary_positions(case))))
        observations = mean+noise.sigma(mean)*rng.normal(size=mean.shape)
        estimator = PositionEstimator(model, [[-1.8, 1.8]]*2, noise, grid_counts=(51, 51), starts=6)
        fit = estimator.fit(observations[229])
        self.assertLess(np.linalg.norm(fit.position-truth[229]), .001)
        self.assertLess(fit.cost, 600.)

    def test_information_matches_direct_inverse(self):
        model = OpticalModel()
        point = [.14, .21, .4]
        power, j = model.power_and_jacobian(point)
        j /= ReceiverNoise().sigma(power)[:, None]
        expected = np.sqrt(np.diag(np.linalg.inv(j.T @ j)))
        assert_allclose(information_metrics(model, point)['axis_std'][0], expected, rtol=1e-10)

    def test_unknown_gain_never_adds_information(self):
        model = OpticalModel(OpticalConfig(radii=(.012, .015)))
        points = [[.1, .2, .3], [0., 0., .5], [.4, .1, .7]]
        calibrated = information_metrics(model, points)['peb']
        common = information_metrics(model, points, gain_mode='common')['peb']
        per_state = information_metrics(model, points, gain_mode='per_state')['peb']
        self.assertTrue(np.all(common >= calibrated))
        self.assertTrue(np.all(per_state >= common*(1-1e-6)))

    def test_dark_region_is_not_reported_as_zero_bound(self):
        result = information_metrics(OpticalModel(), [[2., 2., 1.]])
        self.assertTrue(np.isinf(result['peb'][0]))
        self.assertLess(result['rank'][0], 3)

    def test_labelled_symmetry_is_not_an_ambiguity(self):
        model = OpticalModel()
        p = model.power_at([.18, .13, .2])
        reflected = model.power_at([-.18, -.13, .2])
        self.assertAlmostEqual(p.sum(), reflected.sum(), places=18)
        self.assertGreater(np.linalg.norm(p-reflected), 1e-8)

    def test_unknown_common_gain_noiseless(self):
        model = OpticalModel(OpticalConfig(radii=(-.010, -.011), edge_thickness=.006))
        estimator = PositionEstimator(model, [[-.8, .8], [-.8, .8], [0., 1.]], gain_unknown=True, starts=8)
        position = np.array([.283, -.164, .43])
        fit = estimator.fit(1.08*model.power_at(position))
        assert_allclose(fit.position, position, atol=1e-5)
        self.assertAlmostEqual(fit.gain, 1.08, places=5)


if __name__ == '__main__':
    unittest.main()
