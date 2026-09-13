import unittest
from dataclasses import replace

import numpy as np
from numpy.testing import assert_allclose

from optics import OpticalConfig, OpticalModel, ReceiverNoise, rotation_x, rotation_y


class OpticalTests(unittest.TestCase):
    def setUp(self):
        self.config = OpticalConfig()
        self.model = OpticalModel(self.config)

    def test_snell_and_unit_vectors(self):
        x, y = self.model.local_xy.T
        radius = self.config.radii[0]
        normals = np.column_stack((x, y, np.sqrt(radius**2 - x*x - y*y))) / radius
        incoming = np.broadcast_to([0., 0., 1.], normals.shape)
        outgoing = self.model.local_directions[0]
        assert_allclose(np.linalg.norm(outgoing, axis=1), 1., atol=1e-14)
        assert_allclose(np.cross(normals, outgoing), self.config.index * np.cross(normals, incoming), atol=1e-14)
        assert_allclose(outgoing[12], [0., 0., 1.], atol=1e-14)
        self.assertTrue(np.all(outgoing[:, 0] * x <= 0))

    def test_concave_snell_and_beam_expansion(self):
        config = replace(self.config, radii=(-.012,), edge_thickness=.004)
        model = OpticalModel(config)
        x, y = model.local_xy.T
        radius = config.radii[0]
        normals = np.column_stack((x/radius, y/radius, np.sqrt(1-(x*x+y*y)/radius**2)))
        incoming = np.broadcast_to([0., 0., 1.], normals.shape)
        outgoing = model.local_directions[0]
        assert_allclose(np.linalg.norm(outgoing, axis=1), 1., atol=1e-14)
        assert_allclose(np.cross(normals, outgoing), config.index*np.cross(normals, incoming), atol=1e-14)
        self.assertTrue(np.all(outgoing[:, 0]*x >= 0))
        self.assertTrue(np.all(model.thicknesses[0] > 0))
        self.assertGreater(model.width_squared([3.])[0, 12], self.model.width_squared([3.])[0, 12])
        f = radius/(config.index-1)
        zr = np.pi*config.waist**2/config.wavelength
        u = config.array_lens_distance+model.thicknesses[0]/config.index
        expected = (u+1j*zr)/(1-(u+1j*zr)/f)
        assert_allclose(model.local_q[0], expected, rtol=1e-13)

    def test_abcd_closed_form_and_determinant(self):
        for radius, thickness, transformed in zip(self.config.radii, self.model.thicknesses, self.model.local_q):
            f = radius / (self.config.index - 1)
            zr = np.pi * self.config.waist**2 / self.config.wavelength
            u = self.config.array_lens_distance + thickness / self.config.index
            den = (1-u/f)**2 + (zr/f)**2
            expected = (u*(1-u/f)-zr*zr/f)/den + 1j*zr/den
            assert_allclose(transformed, expected, rtol=1e-13)
            b = thickness / self.config.index
            c = -1/f
            d = 1-b/f
            assert_allclose(d-b*c, 1., atol=1e-14)

    def test_width_at_exit_and_power_integral(self):
        from scipy.integrate import quad
        q = self.model.local_q[0][12]
        thickness = self.model.thicknesses[0][12]
        zr = np.pi*self.config.waist**2/self.config.wavelength
        expected = self.config.waist**2 * (1+((self.config.array_lens_distance+thickness/self.config.index)/zr)**2)
        actual = self.config.wavelength / np.pi * abs(q)**2 / q.imag
        assert_allclose(actual, expected, rtol=1e-13)
        width2 = self.model.width_squared(np.array([3.]))[0, 12]
        integral = quad(lambda r: 2*self.config.power/(np.pi*width2)*np.exp(-2*r*r/width2)*2*np.pi*r, 0, 8*np.sqrt(width2))[0]
        assert_allclose(integral, self.config.power, rtol=1e-10)

    def test_analytic_jacobian(self):
        for tiles in (1, 9):
            model = OpticalModel(replace(self.config, tiles=tiles, radii=(.013, .015, .020)))
            position = np.array([.217, -.138, .37])
            _, jac = model.power_and_jacobian(position)
            h = 1e-6
            numerical = np.column_stack([(model.power_at(position+h*np.eye(3)[j])-model.power_at(position-h*np.eye(3)[j]))/(2*h) for j in range(3)])
            assert_allclose(jac, numerical, rtol=2e-5, atol=1e-13)

    def test_tuning_changes_direction_width_and_surface(self):
        model = OpticalModel(replace(self.config, radii=(.013, .020)))
        self.assertGreater(np.linalg.norm(model.local_directions[0][0]-model.local_directions[1][0]), .01)
        self.assertFalse(np.allclose(model.local_q[0], model.local_q[1]))
        self.assertFalse(np.allclose(model.origins[:25], model.origins[25:]))

    def test_single_pd_projection_and_fov(self):
        p = np.array([0., 0., 0.])
        self.assertGreater(self.model.power_at(p)[12], 0)
        assert_allclose(self.model.power_at(p, normal=[0, 0, -1]), 0)
        narrow = OpticalModel(replace(self.config, fov_deg=1.))
        self.assertEqual(np.count_nonzero(narrow.power_at(p)), 1)

    def test_invalid_lens_and_pitch_rejected(self):
        for changes in ({'radii': (.007,)}, {'pitch': .003}, {'edge_thickness': -.001}):
            with self.assertRaises(ValueError):
                OpticalModel(replace(self.config, **changes))

    def test_full_grid_geometry_and_label_order(self):
        model = OpticalModel(replace(self.config, tiles=9, radii=(.015, .017)))
        self.assertEqual(model.power_at([0, 0, 0]).shape, (450,))
        assert_allclose(model.directions[100:125], self.model.directions, atol=1e-14)
        assert_allclose(model.origins[100:125], self.model.origins, atol=1e-14)
        rotation = rotation_y(np.pi + .31) @ rotation_x(.19)
        assert_allclose(rotation.T @ rotation, np.eye(3), atol=1e-14)
        self.assertAlmostEqual(np.linalg.det(rotation), 1.)

    def test_finite_aperture_point_pd_approximation(self):
        position = np.array([.1, .1, .2])
        offsets = np.linspace(-.0005, .0005, 31)
        xx, yy = np.meshgrid(offsets, offsets)
        positions = position + np.column_stack((xx.ravel(), yy.ravel(), np.zeros(xx.size)))
        averaged = self.model.power_at(positions).mean(axis=0)
        point = self.model.power_at(position)
        strong = point > point.max()*1e-4
        assert_allclose(averaged[strong], point[strong], rtol=.003)

    def test_noise_scaling(self):
        noise = ReceiverNoise(repeatability=0.)
        assert_allclose(replace(noise, bandwidth=400.).sigma([0., 1e-6]), 2*noise.sigma([0., 1e-6]))
        self.assertGreater(noise.sigma(1e-6), noise.sigma(0.))


if __name__ == '__main__':
    unittest.main()
