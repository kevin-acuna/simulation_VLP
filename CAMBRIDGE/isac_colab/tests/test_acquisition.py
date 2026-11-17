"""Measurement plan and acquisition engine with simulated gantry, MTRS, AWG and oscilloscope."""

import csv
import io
import tempfile
import time
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

import isac
from acquisition.engine import Engine
from acquisition.plan import check_plan, grid_sites, make_plan, orientation_angles, plan_label
from hardware.testbed import Testbed
from isac.sim import SimRig
from isac.storage import Session
from tests.common import get_config


class PlanTests(unittest.TestCase):
    def test_serpentine_grid_and_reversed_levels(self):
        s = grid_sites([0, 1], [10, 20, 30], [5, 6])
        self.assertEqual([p[:2] for p in s[:6]], [(0, 10), (0, 20), (0, 30), (1, 30), (1, 20), (1, 10)])
        self.assertEqual(s[6:], [(x, y, 6.0) for x, y, _ in s[:6][::-1]])

    def test_orientations_alternate_and_repetitions(self):
        angles = orientation_angles(4, 30)
        self.assertEqual(angles, [30.0, 120.0, 210.0, 300.0])
        plan = make_plan([(0, 0, 0), (1, 1, 0)], angles, n_captures=2)
        self.assertEqual(len(plan), 16)
        self.assertEqual([m["angle"] for m in plan[:8:2]], [30.0, 120.0, 210.0, 300.0])
        self.assertEqual([m["angle"] for m in plan[8::2]], [300.0, 210.0, 120.0, 30.0])
        self.assertEqual([m["new_pose"] for m in plan[:4]], [True, False, True, False])
        self.assertEqual([m["new_site"] for m in plan[:4]], [True, False, False, False])
        self.assertTrue(plan[8]["new_site"])
        self.assertEqual(plan_label([(0, 0, 0)] * 2, angles, 2), "sites2_K4x2")
        self.assertEqual(plan_label([], angles, 1, ([1, 2], [3], [4, 5])), "grid2x1x2_K4")

    def test_check_plan_reports_workspace(self):
        tb = Testbed(modes={"gantry": "sim", "mtrs": "sim"})
        bad = make_plan([(100, 100, 100), (2000, 100, 100)], [0.0, 400.0])
        problems = check_plan(bad, tb)
        self.assertTrue(any("X=2000.0" in p for p in problems))
        self.assertTrue(any("angle 400.0" in p for p in problems))


class EngineTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.out = redirect_stdout(io.StringIO())
        self.out.__enter__()
        self.addCleanup(self.out.__exit__, None, None, None)
        cfg = get_config()
        self.exp = isac.prepare(cfg)
        self.tb = Testbed(modes={"gantry": "sim", "mtrs": "sim", "sim_speedup": 40.0}).connect()
        self.addCleanup(self.tb.close)
        pose = lambda: (lambda p: (p["pos"], p["angle"], p["tilt"]))(self.tb.pose())
        self.rig = SimRig(cfg, pose, seed=11)
        self.session = Session(self.tmp.name, "engine", {})
        self.session.save_experiment(self.exp)
        self.rig.transmit(self.exp, self.session.dir)
        plan = make_plan([(300.0, 300.0, 100.0), (500.0, 300.0, 100.0)], orientation_angles(2, 10.0))
        self.engine = Engine(self.tb, self.rig, self.exp, self.session, plan, settle_s=0.0)
        self.engine.start()
        self.addCleanup(self.engine.shutdown)

    def wait(self, cond, timeout=120):
        t0 = time.time()
        while not cond() and time.time() - t0 < timeout:
            time.sleep(0.05)
        return cond()

    def rows(self):
        with open(self.session.dir / "captures.csv", newline="", encoding="utf-8") as f:
            return list(csv.DictReader(f))

    def test_plan_runs_to_completion_and_records_poses(self):
        e = self.engine
        e.start_plan()
        self.assertTrue(self.wait(lambda: e.mode == "IDLE" and e.next_index == 4))
        rows = self.rows()
        self.assertEqual([(r["site_id"], r["angle_cmd_deg"]) for r in rows],
                         [("1", "10"), ("1", "190"), ("2", "190"), ("2", "10")])
        for r in rows:
            self.assertLess(float(r["pos_err_mm"]), 1.0)
            self.assertLess(abs(float(r["angle_err_deg"])), 0.1)
            self.assertGreater(float(r["tone_Vrms"]), 0)
            self.assertEqual(r["mode"], "plan")
            self.assertTrue((self.session.dir / r["wave_file"]).is_file())
        self.assertTrue(self.session.excel_path.is_file())
        self.assertIn("Plan complete", e.status)

    def test_error_pauses_then_resume_retries_and_skip_records_failure(self):
        e = self.engine
        real = self.rig.capture
        with patch.object(self.rig, "capture", side_effect=[RuntimeError("VISA timeout (injected)"), real(self.exp),
                                                            RuntimeError("again"), real(self.exp), real(self.exp)]):
            e.start_plan()
            self.assertTrue(self.wait(lambda: e.mode == "PAUSED"))
            self.assertIn("injected", e.status)
            self.assertEqual(e.next_index, 0)
            e.resume()
            self.assertTrue(self.wait(lambda: e.mode == "PAUSED" and e.next_index == 1))
            e.skip()
            self.assertTrue(self.wait(lambda: e.mode == "IDLE" and e.next_index == 4))
        rows = self.rows()
        self.assertEqual(len(rows), 4)
        self.assertEqual(rows[1]["error"], "skipped after error: again")
        self.assertEqual(rows[1]["tone_Vrms"], "")
        self.assertTrue(all(r["error"] == "" for i, r in enumerate(rows) if i != 1))

    def test_stop_then_manual_and_continue(self):
        e = self.engine
        e.start_plan()
        self.assertTrue(self.wait(lambda: e.next_index >= 1))
        e.stop()
        self.assertTrue(self.wait(lambda: e.mode == "IDLE"))
        done = e.next_index
        e.go_and_measure((700.0, 650.0, 50.0), 123.0)
        self.assertTrue(self.wait(lambda: e.mode == "IDLE" and len(e.history) >= done + 1))
        e.measure_here()
        self.assertTrue(self.wait(lambda: e.mode == "IDLE" and len(e.history) >= done + 2))
        e.start_plan()
        self.assertTrue(self.wait(lambda: e.mode == "IDLE" and e.next_index == 4))
        modes = [r["mode"] for r in self.rows()]
        self.assertEqual(modes.count("plan"), 4)
        self.assertEqual(modes[done:done + 2], ["manual", "here"])
        manual = self.rows()[done]
        self.assertEqual((manual["x_cmd_mm"], manual["angle_cmd_deg"]), ("700", "123"))
        e.go_and_measure((5000.0, 0.0, 0.0), 0.0)
        self.assertIn("Invalid pose", e.status)


if __name__ == "__main__":
    unittest.main()
