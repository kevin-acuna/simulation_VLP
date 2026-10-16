"""
Angular responses R(s) of the photodetector, s = cos(psi) = n . u (incidence cosine), R(1) = 1.

    CosinePowerResponse(order, fov_deg)   R = s^order inside the FOV        (cos: order 1; cos^mR)
    SQResponse(psi_3db_rad, fov_deg)      R = 1 - a psi^2,  a = (1 - 1/sqrt(2)) / psi_3dB^2
                                          (Bastiaens et al., IEEE Access 2020, eq. 5; natural zero at
                                          psi = 1/sqrt(a), 64.58 deg for the PDA100A2)

Published PDA100A2 values (Bastiaens 2020, Table 1): psi_3dB = 0.61 rad, cosine order 1.9.
Outside the support (s below the cutoff cosine) R = 0 and dR/ds = 0.
"""

import math

import numpy as np


class Response:
    """Base class: value(s), derivative(s) = dR/ds, support cosine (R > 0 only for s > cutoff_cos)."""

    name = "response"
    power_law_order = None          # exponent if R = s^order (enables the linear TCOM GLS/WLS)

    def __init__(self, fov_deg=90.0):
        self.fov_deg = float(fov_deg)
        self.cutoff_cos = math.cos(math.radians(self.fov_deg))

    def value(self, s):
        raise NotImplementedError

    def derivative(self, s):
        raise NotImplementedError

    def describe(self):
        return self.name


class CosinePowerResponse(Response):
    def __init__(self, order=1.0, fov_deg=90.0):
        super().__init__(fov_deg)
        self.order = float(order)
        self.power_law_order = self.order
        self.name = "cosine" if self.order == 1 else f"cosine^{self.order:g}"

    def _active(self, s):
        return (s > 0) & (s >= self.cutoff_cos)

    def value(self, s):
        s = np.asarray(s, dtype=float)
        return np.where(self._active(s), np.clip(s, 0, None) ** self.order, 0.0)

    def derivative(self, s):
        s = np.asarray(s, dtype=float)
        return np.where(self._active(s), self.order * np.clip(s, 1e-300, None) ** (self.order - 1), 0.0)

    def describe(self):
        return f"{self.name}, FOV {self.fov_deg:g} deg"


class SQResponse(Response):
    name = "SQ"

    def __init__(self, psi_3db_rad=0.61, fov_deg=90.0):
        super().__init__(fov_deg)
        self.psi_3db = float(psi_3db_rad)
        self.a = (1.0 - 1.0 / math.sqrt(2.0)) / self.psi_3db ** 2
        zero = 1.0 / math.sqrt(self.a)                      # natural zero of 1 - a psi^2
        self.cutoff_cos = max(self.cutoff_cos, math.cos(min(zero, math.pi / 2)))
        self.zero_deg = math.degrees(zero)

    def value(self, s):
        psi = np.arccos(np.clip(np.asarray(s, dtype=float), -1.0, 1.0))
        return np.where(np.asarray(s) >= self.cutoff_cos, np.clip(1.0 - self.a * psi ** 2, 0.0, None), 0.0)

    def derivative(self, s):
        s = np.asarray(s, dtype=float)
        psi = np.arccos(np.clip(s, -1.0, 1.0))
        sin_psi = np.sin(psi)
        ratio = np.where(psi > 1e-7, psi / np.where(sin_psi > 0, sin_psi, 1.0), 1.0 + psi ** 2 / 6.0)
        return np.where((s >= self.cutoff_cos) & (1.0 - self.a * psi ** 2 > 0), 2.0 * self.a * ratio, 0.0)

    def describe(self):
        return f"SQ 1 - a psi^2, psi_3dB = {self.psi_3db:g} rad (zero at {self.zero_deg:.2f} deg)"


def make_response(name, psi_3db_rad=0.61, order=1.9, fov_deg=64.0):
    """Response by name: 'SQ' | 'cosine_mR' (cos^order) | 'cosine' (cos). fov_deg applies to the cosines."""
    key = str(name).lower()
    if key == "sq":
        return SQResponse(psi_3db_rad)
    if key in ("cosine_mr", "cosine_power"):
        return CosinePowerResponse(order, fov_deg)
    if key in ("cosine", "cosine_1"):
        return CosinePowerResponse(1.0, fov_deg)
    raise ValueError(f"Unknown PD response '{name}' (SQ, cosine_mR, cosine).")
