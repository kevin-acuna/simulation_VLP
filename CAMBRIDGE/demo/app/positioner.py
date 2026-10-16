"""
positioner.py - Positioning of the demo: testbed geometry + VLP model + estimator.

    pos = Positioner.from_settings(settings)
    result = pos.locate(rss_V, mtrs_angles_deg, true_gantry_xyz_mm)   # dict for the UI and the files
"""

import numpy as np

from vlp import Lambertian, VLPModel, estimate_position, make_response

from geometry import TestbedGeometry


class Positioner:
    def __init__(self, model, geometry, method="NLS", starts=3):
        self.model, self.geometry, self.method, self.starts = model, geometry, method.upper(), starts

    @classmethod
    def from_settings(cls, s):
        p, led, g = s["positioning"], s["led"], s["geometry"]
        response = make_response(p["pd_response"], p["psi_3db_rad"], p["m_R"], p["pd_fov_deg"])
        model = VLPModel(led_position=[led["xy_mm"][0] / 1e3, led["xy_mm"][1] / 1e3, led["height_m"]],
                         response=response, emitter=Lambertian(led["m"]), A=led["A"])
        geometry = TestbedGeometry(**{k: g[k] for k in TestbedGeometry.__dataclass_fields__ if k in g})
        return cls(model, geometry, p["estimator"], p.get("starts", 3))

    def describe(self):
        m, g = self.model, self.geometry
        return {"estimator": self.method, "pd_response": m.response.describe(),
                "led_position_m": m.led_position.tolist(), "led_m": m.emitter.m, "led_A": m.A,
                "led_half_power_deg": m.emitter.half_power_angle_deg, **g.__dict__}

    def predicted_rss(self, est, mtrs_angles_deg):
        """RSS predicted by an estimate (direction + amplitude) for any MTRS angles (fit curve)."""
        if not est.ok:
            return None
        n = self.geometry.normals(mtrs_angles_deg)
        return est.amplitude * self.model.response.value(n @ est.direction)

    def locate(self, rss, mtrs_angles_deg, true_gantry_mm=None):
        """Estimate from the K RSS [V] measured at the given MTRS angles. Errors if the truth is given."""
        rss = np.asarray(rss, dtype=float)
        normals = self.geometry.normals(mtrs_angles_deg)
        est = estimate_position(self.method, rss, normals, self.model, self.starts)
        out = {"ok": est.ok, "status": est.status, "method": est.method, "K": int(rss.size),
               "est_m": est.position.tolist() if est.ok else None,
               "distance_m": est.distance if est.ok else None, "amplitude_V": est.amplitude if est.ok else None}
        if est.ok:
            fit = self.predicted_rss(est, mtrs_angles_deg)
            out["fit_rms_pct"] = float(100 * np.sqrt(np.mean((rss / fit - 1) ** 2)))
            out["est_gantry_z_mm"] = float(self.geometry.gantry_z(est.position[2]))
        if true_gantry_mm is not None:
            truth = self.geometry.pd_position(true_gantry_mm)
            out["true_m"] = truth.tolist()
            if est.ok:
                e = est.position - truth
                u_true, d_true, _ = self.model.geometry(truth)
                out.update(err_m=e.tolist(), err_3d_m=float(np.linalg.norm(e)),
                           err_h_m=float(np.hypot(e[0], e[1])), err_v_m=float(e[2]),
                           err_dir_deg=float(np.degrees(np.arccos(np.clip(u_true @ est.direction, -1, 1)))),
                           err_range_m=float(est.distance - d_true))
        out["_estimate"] = est
        return out
