"""
geometry.py - Cambridge testbed geometry: gantry coordinates <-> photodetector (PD) pose.

Physical frame used by the estimators: X, Y of the gantry and Z = height above the floor (up), metres.
The gantry z is in real millimetres, positive upwards, z = 0 at the reference (lowest PD position):

    Z_pd = base_height + z_gantry / 1000 + pd_elevation

PD normal at MTRS angle theta (adapter tilted pd_tilt from the vertical):
    n = [sin(t) sin(a), sin(t) cos(a), cos(t)],   a = mtrs_direction * (theta - mtrs_offset)
i.e. at theta = mtrs_offset the PD is tilted towards +Y; increasing theta turns it towards +X.
"""

from dataclasses import dataclass

import numpy as np

from vlp import tilted_normals


@dataclass(frozen=True)
class TestbedGeometry:
    base_height_m: float = 0.858          # height of the gantry base at gantry z = 0
    pd_elevation_m: float = 0.09696       # gantry base -> PD centre (MTRS + adapter)
    pd_tilt_deg: float = 15.0
    mtrs_offset_deg: float = 67.3         # MTRS angle that points the tilt towards +Y
    mtrs_direction: int = 1

    def pd_position(self, gantry_xyz_mm):
        """PD centre [m] (X, Y, Z up) for a gantry position (x, y, z) [mm]."""
        x, y, z = (float(v) for v in gantry_xyz_mm)
        return np.array([x / 1e3, y / 1e3, self.pd_height(z)])

    def pd_height(self, z_gantry_mm):
        return self.base_height_m + z_gantry_mm / 1e3 + self.pd_elevation_m

    def gantry_z(self, pd_height_m):
        """Inverse of pd_height: gantry z [mm] that puts the PD centre at pd_height_m."""
        return (pd_height_m - self.base_height_m - self.pd_elevation_m) * 1e3

    def normals(self, mtrs_angles_deg):
        """PD normals (K, 3) for the measured MTRS angles."""
        a = self.mtrs_direction * (np.asarray(mtrs_angles_deg, dtype=float) - self.mtrs_offset_deg)
        return tilted_normals(np.radians(90.0 - a), np.radians(self.pd_tilt_deg))
