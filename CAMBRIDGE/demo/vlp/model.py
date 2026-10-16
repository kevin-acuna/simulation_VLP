"""
Forward model of one fixed LED and a PD with known normals.

    y = A * R(n . u) * L(c) / d^2,   u = (t - r) / d,  c = -n_LED . u,  L(c) = c^m (Lambertian)

All positions in metres, any right-handed frame (the estimators only use dot products).
"""

from dataclasses import dataclass, field

import numpy as np

from .responses import Response


@dataclass
class Lambertian:
    """Generalized Lambertian pattern of the LED, normalized to L(0) = 1."""

    m: float

    def gain(self, c):
        c = np.asarray(c, dtype=float)
        return np.where(c > 0, np.clip(c, 0, None) ** self.m, 0.0)

    @property
    def half_power_angle_deg(self):
        return float(np.degrees(np.arccos(2.0 ** (-1.0 / self.m))))


def tilted_normals(azimuth_rad, tilt_rad):
    """Unit normals tilted by tilt_rad from +Z, towards the azimuth (from +X towards +Y). Shape (K, 3)."""
    a, t = np.asarray(azimuth_rad, dtype=float), np.broadcast_to(np.asarray(tilt_rad, dtype=float),
                                                                  np.shape(azimuth_rad))
    return np.column_stack([np.sin(t) * np.cos(a), np.sin(t) * np.sin(a), np.cos(t)])


@dataclass
class VLPModel:
    led_position: np.ndarray
    response: Response
    emitter: Lambertian
    A: float                                            # calibration constant [RSS units * m^2]
    led_normal: np.ndarray = field(default_factory=lambda: np.array([0.0, 0.0, -1.0]))

    def __post_init__(self):
        self.led_position = np.asarray(self.led_position, dtype=float).reshape(3)
        n = np.asarray(self.led_normal, dtype=float).reshape(3)
        self.led_normal = n / np.linalg.norm(n)

    @property
    def q(self):
        """Direction of the LED axis seen from the receivers (unit vector pointing back to the LED)."""
        return -self.led_normal

    def geometry(self, position):
        """(u, d, c) for a PD at `position`: direction to the LED, distance, emission cosine."""
        v = self.led_position - np.asarray(position, dtype=float).reshape(3)
        d = float(np.linalg.norm(v))
        u = v / d
        return u, d, float(self.q @ u)

    def amplitude(self, u, d):
        """beta = A L(c) / d^2: RSS of a PD facing the LED (R = 1)."""
        return self.A * float(self.emitter.gain(self.q @ u)) / d ** 2

    def distance(self, u, beta):
        """Inverse of amplitude(): d = sqrt(A L(c) / beta); nan if not physical."""
        gain = float(self.emitter.gain(self.q @ u))
        return float(np.sqrt(self.A * gain / beta)) if beta > 0 and gain > 0 else float("nan")

    def rss(self, position, normals):
        """Noise-free RSS of the K orientations (normals shape (K, 3)) at `position`."""
        u, d, _ = self.geometry(position)
        return self.amplitude(u, d) * self.response.value(np.asarray(normals) @ u)
