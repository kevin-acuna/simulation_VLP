"""
vlp - visible light positioning with one fixed LED and one reorientable photodetector (PD).

Pure numpy, no hardware and no testbed constants: it can be shared and reused on its own.

Model (one LED, K orientations of the PD at the same position):
    y_i = A * R(n_i . u) * L(c) / d^2,     L(c) = c^m,  c = -n_LED . u
    u    unit vector from the PD to the LED, d distance, n_i PD normal of orientation i
    R    angular response of the PD (responses.py), L Lambertian pattern of the LED
    A    calibration constant (power, area, gains) [RSS units * m^2]

Estimation (estimators.py), the algorithms studied in CAMBRIDGE/simulations:
    1. direction u from the K RSS (GLS / WLS from ratios, or NLS with a free amplitude)
    2. range by profiling the amplitude beta = sum(y h) / sum(h^2) and d = sqrt(A L(c) / beta)
       (dual of F_broadcast_Konly/core/broadcast_distance.m)

    from vlp import SQResponse, Lambertian, VLPModel, estimate_position
    model = VLPModel(led_position=[0.28, 0.90, 3.0], response=SQResponse(0.61),
                     emitter=Lambertian(6.0), A=0.06)
    est = estimate_position("NLS", rss, normals, model)
    est.position, est.direction, est.distance, est.status
"""

from .calibration import fit_lambertian, fit_scalar
from .estimators import METHODS, Estimate, estimate_direction, estimate_position, profile_amplitude
from .model import Lambertian, VLPModel, tilted_normals
from .responses import CosinePowerResponse, Response, SQResponse, make_response

__all__ = [
    "METHODS", "Estimate", "estimate_direction", "estimate_position", "profile_amplitude",
    "Lambertian", "VLPModel", "tilted_normals",
    "CosinePowerResponse", "Response", "SQResponse", "make_response",
    "fit_lambertian", "fit_scalar",
]
