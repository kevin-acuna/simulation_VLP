"""Experiment preparation, receiver summary and session storage (no hardware)."""

import copy
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np

import isac
from isac.common import load_record, save_record, signature, validate_experiment
from isac.sim import SimRig
from isac.storage import CAPTURE_COLUMNS, Session, isac_tables, load_capture, load_experiment
from tests.common import get_config
from tests.test_processing import synthetic_capture


class ExperimentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.exp = isac.prepare(get_config())
        cls.record = synthetic_capture(cls.exp["packet"], cls.exp["cfg"], fs=5e6)
        cls.record.update(experimentSignature=cls.exp["signature"], validForProcessing=True)
        cls.state = isac.process(cls.record, cls.exp)

    def test_public_processing_complete(self):
        self.assertTrue(self.state["combinedCriteriaMet"], self.state["analysisError"])
        self.assertEqual(self.state["summary"]["AveragedBER"], 0)
        self.assertGreater(self.state["summary"]["DecodedBits"], 0)
        self.assertAlmostEqual(self.state["summary"]["ToneRMS_mV"], 7 / np.sqrt(2), delta=0.03)
        self.assertTrue(all(w["validLogical"] for w in self.state["windows"]))

    def test_invalid_capture_and_signature(self):
        for edits in ({"validForProcessing": False}, {"experimentSignature": "stale"}, {"FsCapture": 2e6}):
            with self.assertRaises(ValueError):
                isac.process(dict(self.record, **edits), self.exp)
        changed = copy.deepcopy(self.exp)
        changed["config"]["pilot_measurement_s"] = 0.005
        with self.assertRaises(ValueError):
            validate_experiment(changed)
        self.assertNotEqual(signature(changed), self.exp["signature"])

    def test_disabled_average_uses_original_ber(self):
        exp = copy.deepcopy(self.exp)
        exp["config"]["training_average"] = False
        exp["signature"] = signature(exp)
        cap = dict(self.record, experimentSignature=exp["signature"], validForProcessing=np.bool_(True))
        result = isac.process(cap, exp)
        self.assertTrue(result["summary"]["OFDMTargetMet"])
        self.assertFalse(result["summary"]["TrainingAverageAvailable"])
        self.assertTrue(np.isnan(result["summary"]["AveragedBER"]))

    def test_duration_and_target_settings_take_effect(self):
        exp = isac.prepare(get_config(pilot_measurement_s=0.005, ofdm_duration_s=0.02, ber_target=2e-4,
                                      capture_target_s=0.2))
        self.assertEqual(exp["packet"]["cfg"]["targetBER"], 2e-4)
        self.assertAlmostEqual(exp["plan"]["positionWindowActual_s"], 0.005)
        self.assertAlmostEqual(exp["plan"]["captureTarget_s"], 0.2)

    def test_default_plan_is_the_ics_waveform(self):
        p = self.exp["plan"]
        self.assertAlmostEqual(p["toneDuration_s"], 0.012, 12)
        self.assertEqual(p["communicationFrames"], 15)
        self.assertAlmostEqual(p["cycleDuration_s"], 0.0224448, 12)
        self.assertEqual(p["totalSamplesAWG"], 359116800)

    def test_record_storage_complex_arrays_and_nonfinite(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "roundtrip.npz"
            obj = dict(z=np.array([1 + 2j, -3j]), flags=np.array([True, False]),
                       nested=[None, {"nan": np.nan, "inf": np.inf}], scalar=2j)
            loaded = load_record(save_record(path, obj))
            np.testing.assert_array_equal(loaded["z"], obj["z"])
            self.assertTrue(np.isnan(loaded["nested"][1]["nan"]))
            self.assertEqual(loaded["scalar"], 2j)
            with self.assertRaises(TypeError):
                save_record(path, {"bad": np.array([{}], dtype=object)})


class SessionTests(unittest.TestCase):
    def test_session_files_excel_and_reprocessing_of_raw_records(self):
        cfg = get_config()
        exp = isac.prepare(cfg)
        with tempfile.TemporaryDirectory() as tmp:
            s = Session(tmp, "test", {"isac": "x"})
            s.save_experiment(exp)
            rig = SimRig(cfg, lambda: ((500.0, 600.0, 100.0), 40.0, 0.0), seed=7)
            rig.transmit(exp, s.dir)
            cap = rig.capture(exp)
            state = isac.process(cap, exp)
            row, windows, slots = isac_tables(state)
            cid = s.add({**row, "mode": "test"}, cap, windows, slots)
            s.add({"mode": "plan", "error": "skipped by the user"})
            self.assertTrue(s.write_excel())
            for name in ("session.json", "experiment.npz", "transmission.npz", "captures.csv", "tone_windows.csv",
                         "ofdm_slots.csv", "results.xlsx", "wave/c00001.npz"):
                self.assertTrue((s.dir / name).is_file(), name)
            header = (s.dir / "captures.csv").read_text(encoding="utf-8").splitlines()[0].split(",")
            self.assertEqual(header, CAPTURE_COLUMNS)
            from openpyxl import load_workbook

            wb = load_workbook(s.excel_path, read_only=True)
            self.assertEqual(wb.sheetnames, ["captures", "tone_windows", "ofdm_slots", "session"])
            rows = list(wb["captures"].values)
            self.assertEqual(len(rows), 3)
            self.assertAlmostEqual(rows[1][CAPTURE_COLUMNS.index("tone_Vrms")], row["tone_Vrms"], 12)
            self.assertEqual(rows[2][CAPTURE_COLUMNS.index("error")], "skipped by the user")
            wb.close()
            again = isac.process(load_capture(s.dir, cid, load_experiment(s.dir)), load_experiment(s.dir))
            row2 = isac_tables(again)[0]
            for k in ("tone_Vrms", "ber", "ber_avg", "frames_accepted", "n_bits"):
                self.assertEqual(row2[k], row[k], k)
            self.assertAlmostEqual(row["tone_Vrms"], cap["simulatedPilotVrms"], delta=5e-5)
            with patch("isac.storage.os.replace", side_effect=PermissionError("open in Excel")):
                self.assertFalse(s.write_excel())
            self.assertTrue(s.write_excel())


if __name__ == "__main__":
    unittest.main()
