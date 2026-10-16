"""
sim_scope.py - Simulated oscilloscope for run.py --sim, consistent with the positioning model.

Same interface and data format as hardware.sim.SimScope (waveforms + Python FFT), but the tone of the
positioning LED follows RSS = A R(psi) L(phi) / d^2 at the simulated gantry / MTRS pose, with a
configurable model mismatch (true LED position offset) and multiplicative noise ([sim] in demo.toml).
The other LEDs are recorded with a small constant amplitude.
"""

import math

import numpy as np

from hardware.sim import SimScope
from vlp import VLPModel


class DemoSimScope(SimScope):
    def __init__(self, positioner, sim_settings, led_freq_khz, pose_fn=None, **cfg):
        super().__init__(pose_fn=pose_fn, **cfg)
        m, s = positioner.model, sim_settings
        led = m.led_position + np.array([*s.get("led_error_mm", (0.0, 0.0)), 0.0]) / 1e3
        self.truth = VLPModel(led, m.response, m.emitter, m.A, m.led_normal)
        self.geometry = positioner.geometry
        self.noise_rel = float(s.get("rss_noise_rel", 0.0))
        self.other_v = float(s.get("other_leds_mV", 2.0)) * 1e-3
        self.led_freq = led_freq_khz * 1e3
        self.rng = np.random.default_rng()
        self.info["idn"] = "DemoSimScope (positioning model)"

    def _amplitudes(self):
        pos_mm, angle, _ = self.pose_fn()
        r = self.geometry.pd_position(pos_mm)
        rss = float(self.truth.rss(r, self.geometry.normals([angle]))[0])
        rss *= 1.0 + self.noise_rel * self.rng.standard_normal()
        return [math.sqrt(2) * (max(rss, 0.0) if abs(f - self.led_freq) < 1e3 else self.other_v)
                for f, _ in self.LEDS]
