"""End-to-end test of the demo engine with simulated devices (fast motion, short records).

    python -m unittest tests.test_engine_sim -v      (from the demo folder; ~20 s)
"""

import csv
import os
import shutil
import sys
import tempfile
import time
import unittest

DEMO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(DEMO, "app"))

from settings import add_import_paths, load_settings   # noqa: E402

SETTINGS = load_settings()
add_import_paths(SETTINGS)

from engine import DemoEngine          # noqa: E402
from hardware.testbed import Testbed   # noqa: E402
from positioner import Positioner      # noqa: E402
from sim_scope import DemoSimScope     # noqa: E402


class TestEngineSim(unittest.TestCase):
    def test_three_points(self):
        out = tempfile.mkdtemp(prefix="vlp_demo_test_")
        pos = Positioner.from_settings(SETTINGS)
        tb = Testbed(modes={"gantry": "sim", "mtrs": "sim", "scope": "sim", "sim_speedup": 100.0})
        tb.scope = DemoSimScope(pos, {**SETTINGS["sim"], "led_error_mm": [0, 0], "rss_noise_rel": 0.002},
                                SETTINGS["positioning"]["led_frequency_khz"], pose_fn=tb._sim_pose, **tb.cfg["scope"])
        tb.connect()
        eng = DemoEngine(tb, pos, SETTINGS, out)
        try:
            eng.start_threads()
            eng.add_target([700.0, 700.0, 180.0])             # manual position first, then random ones
            eng.start({"k_angles": 5, "max_points": 3, "settle_s": 0.0, "record_ms": 2.0, "save_waveforms": True})
            t0 = time.time()
            while eng.state in ("RUNNING", "STOPPING") and time.time() - t0 < 120:
                time.sleep(0.2)
            self.assertEqual(eng.state, "FINISHED", eng.message)
            self.assertEqual(len(eng.done), 3)
            self.assertEqual(eng.done[0]["gantry"][:2], [700.0, 700.0])
            for d in eng.done:
                self.assertTrue(d["ok"], d["status"])
                self.assertLess(d["err_3d_mm"], 30.0)           # 0.2 % noise -> a few mm
            with open(os.path.join(eng.session.dir, "points.csv"), newline="") as f:
                rows = list(csv.DictReader(f))
            self.assertEqual(len(rows), 15)
            self.assertIn("500kHz_wave_Vrms", rows[0])
            with open(os.path.join(eng.session.dir, "estimates.csv"), newline="") as f:
                self.assertEqual(len(list(csv.DictReader(f))), 3)
            self.assertTrue(os.path.isfile(os.path.join(eng.session.dir, "wave", "m00015.npz")))
            state = eng.full_state()
            self.assertEqual(state["stats"]["n_ok"], 3)
        finally:
            eng.shutdown()
            tb.close()
            shutil.rmtree(out, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
