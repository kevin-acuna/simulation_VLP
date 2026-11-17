"""Public Python workflow/storage/raw-pilot tests. No hardware needed."""
import copy
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
from scipy.io import loadmat
from config import get_config
from ics import workflow
from ics.common import save_record,load_record,signature,validate_experiment
from tests.test_processing import synthetic_capture

class WorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=tempfile.TemporaryDirectory(prefix="ics_workflow_")
        cfg=get_config();cfg["output_dir"]=cls.temp.name
        cls.exp=workflow.prepare(cfg)
        cls.record=synthetic_capture(cls.exp["packet"],cls.exp["cfg"],fs=5e6)
        cls.record.update(experimentSignature=cls.exp["signature"],validForProcessing=True)
        cls.state=workflow.process(cls.record,cls.exp,1,save=True)
    @classmethod
    def tearDownClass(cls):cls.temp.cleanup()
    def test_public_processing_complete(self):
        self.assertTrue(self.state["combinedCriteriaMet"],self.state["analysisError"])
        self.assertEqual(self.state["summary"]["AveragedBER"],0)
        self.assertGreater(self.state["summary"]["DecodedBits"],0)
        loaded=load_record(self.state["lastSavePath"])["state"]
        np.testing.assert_array_equal(loaded["capture"]["YData"],self.record["YData"])
        self.assertEqual(loaded["summary"],self.state["summary"])
    def test_raw_pilot_mat_csv_exact_and_fft(self):
        pilot=workflow.export_pilot(self.state)
        first=pilot["firstSampleIndex"]-1;last=pilot["lastSampleIndex"]
        np.testing.assert_array_equal(pilot["voltage_V"],self.record["YData"][first:last])
        self.assertEqual(pilot["nSamples"],50000)
        self.assertAlmostEqual(pilot["recordDuration_s"],.01)
        mat=loadmat(pilot["matPath"],simplify_cells=True)["pilot"]
        np.testing.assert_array_equal(mat["voltage_V"],pilot["voltage_V"])
        csv=np.loadtxt(pilot["csvPath"],delimiter=",",skiprows=1)
        np.testing.assert_allclose(csv[:,2],pilot["voltage_V"],rtol=0,atol=0)
        sp=workflow.pilot_fft(pilot,padding_factor=4,plot=False)
        self.assertEqual(sp["unpaddedBinSpacing_Hz"],100)
        self.assertEqual(sp["displayBinSpacing_Hz"],25)
        self.assertAlmostEqual(sp["equivalentNoiseBandwidth_Hz"],150)
        peak=np.argmax(sp["amplitudePeak_mV"])
        self.assertEqual(sp["frequency_Hz"][peak],500000)
        self.assertAlmostEqual(sp["amplitudePeak_mV"][peak],7,delta=.03)
        self.assertGreater(pilot["voltage_V"].mean(),.5) # DC preserved in raw export.
    def test_invalid_capture_and_signature(self):
        for edits in ({"validForProcessing":False},{"experimentSignature":"stale"},{"FsCapture":2e6}):
            cap=dict(self.record,**edits)
            with self.assertRaises(ValueError):workflow.process(cap,self.exp,1,save=False)
        changed=copy.deepcopy(self.exp);changed["config"]["pilot_measurement_s"]=.005
        with self.assertRaises(ValueError):validate_experiment(changed)
        self.assertNotEqual(signature(changed),self.exp["signature"])
    def test_disabled_average_uses_original_ber(self):
        exp=copy.deepcopy(self.exp);exp["config"]["training_average"]=False;exp["signature"]=signature(exp)
        cap=dict(self.record,experimentSignature=exp["signature"],validForProcessing=np.bool_(True))
        result=workflow.process(cap,exp,1,save=False)
        self.assertTrue(result["summary"]["OFDMTargetMet"])
        self.assertFalse(result["summary"]["TrainingAverageAvailable"])
        self.assertTrue(np.isnan(result["summary"]["AveragedBER"]))
    def test_storage_complex_arrays_and_nonfinite(self):
        path=Path(self.temp.name)/"roundtrip.npz"
        obj=dict(z=np.array([1+2j,-3j]),flags=np.array([True,False]),nested=[None,{"nan":np.nan,"inf":np.inf}],scalar=2j)
        loaded=load_record(save_record(path,obj))
        np.testing.assert_array_equal(loaded["z"],obj["z"])
        self.assertTrue(np.isnan(loaded["nested"][1]["nan"]))
        self.assertEqual(loaded["scalar"],2j)
        with self.assertRaises(TypeError):save_record(path,{"bad":np.array([{}],dtype=object)})
    def test_scan_cancel_has_no_capture(self):
        with patch("ics.instruments.capture",side_effect=AssertionError("Unexpected hardware call")):
            result=workflow.scan(None,self.exp,input_fn=lambda _:"q")
        self.assertTrue(result["cancelled"]);self.assertEqual(result["completedOrientations"],0)
        self.assertFalse(result["estimatorCalled"]);self.assertTrue(Path(result["savedPath"]).exists())
    def test_five_orientations_and_dummy_handoff(self):
        with patch("ics.instruments.capture",return_value=self.record) as cap:
            result=workflow.scan(None,self.exp,input_fn=lambda _:"")
        self.assertEqual(cap.call_count,5)
        self.assertTrue(result["complete"],result["error"])
        self.assertEqual(result["completedOrientations"],5)
        self.assertFalse(result["estimatorOutput"]["positionEstimateComputed"])
        self.assertEqual([p["orientationId"] for p in result["pilots"]],[1,2,3,4,5])
        self.assertEqual(len(set(result["pilotMatFiles"])),5)
        swapped=list(result["pilots"]);swapped[0],swapped[1]=swapped[1],swapped[0]
        with self.assertRaises(ValueError):workflow.position_dummy(swapped)
    def test_scan_failure_keeps_partial_results(self):
        with patch("ics.instruments.capture",side_effect=[self.record,RuntimeError("mock capture failure")]):
            result=workflow.scan(None,self.exp,input_fn=lambda _:"")
        self.assertFalse(result["complete"]);self.assertEqual(result["completedOrientations"],1)
        self.assertFalse(result["estimatorCalled"]);self.assertIn("mock capture failure",result["error"])
        saved=load_record(result["savedPath"])["scan"]
        self.assertEqual(saved["completedOrientations"],1)
    def test_duration_and_target_settings_take_effect(self):
        cfg=get_config();cfg.update(pilot_measurement_s=.005,ofdm_duration_s=.02,ber_target=2e-4,capture_target_s=.2)
        exp=workflow.prepare(cfg)
        self.assertEqual(exp["packet"]["cfg"]["targetBER"],2e-4)
        self.assertAlmostEqual(exp["plan"]["positionWindowActual_s"],.005)
        self.assertAlmostEqual(exp["plan"]["captureTarget_s"],.2)

if __name__=="__main__":unittest.main()
