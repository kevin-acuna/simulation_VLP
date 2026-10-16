"""Testbed geometry and positioner (conventions validated on the real campaigns).

    python -m unittest tests.test_geometry -v
"""

import os
import sys
import unittest

import numpy as np

DEMO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(DEMO, "app"))
sys.path.insert(0, DEMO)

from geometry import TestbedGeometry    # noqa: E402
from positioner import Positioner       # noqa: E402
from settings import load_settings      # noqa: E402


class TestGeometry(unittest.TestCase):
    def test_normals_convention(self):
        g = TestbedGeometry(pd_tilt_deg=15.0, mtrs_offset_deg=65.0)
        t = np.radians(15.0)
        np.testing.assert_allclose(g.normals([65.0])[0], [0, np.sin(t), np.cos(t)], atol=1e-12)   # towards +Y
        np.testing.assert_allclose(g.normals([155.0])[0], [np.sin(t), 0, np.cos(t)], atol=1e-12)  # then +X

    def test_heights(self):
        g = TestbedGeometry(base_height_m=1.038, z_ref_mm=-300, pd_elevation_m=0.09696, gantry_z_scale=0.6)
        self.assertAlmostEqual(g.pd_height(-300), 1.13496)
        self.assertAlmostEqual(g.pd_height(-600), 1.31496)
        self.assertAlmostEqual(g.gantry_z(g.pd_height(-123.0)), -123.0)

    def test_positioner_recovers_simulated_point(self):
        pos = Positioner.from_settings(load_settings())
        gantry = (900.0, 400.0, -250.0)
        angles = 66.5 + 72.0 * np.arange(5)
        rss = pos.model.rss(pos.geometry.pd_position(gantry), pos.geometry.normals(angles))
        res = pos.locate(rss, angles, gantry)
        self.assertTrue(res["ok"], res["status"])
        self.assertLess(res["err_3d_m"], 1e-6)
        self.assertLess(res["fit_rms_pct"], 1e-6)


if __name__ == "__main__":
    unittest.main()
