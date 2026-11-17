"""MAT v7 bridge checks using synthetic fixtures, not native MATLAB execution."""
import contextlib
import copy
import io
from pathlib import Path
import tempfile
import unittest
import numpy as np
from scipy.io import savemat
from config import get_config
from ics import modem, processing
from ics.workflow import prepare, process, replay_matlab_reference


def matlab_doubles(value):
    """MATLAB bench numerical fields are doubles, including integer counts."""
    if isinstance(value,dict):
        return {k:matlab_doubles(v) for k,v in value.items()}
    if isinstance(value,np.ndarray) and value.dtype.kind in "iu":
        return value.astype(float)
    if isinstance(value,(int,np.integer)) and not isinstance(value,(bool,np.bool_)):
        return float(value)
    return value


def make_reference_fixture(folder):
    cfg=get_config();cfg["output_dir"]=str(folder)
    exp=prepare(cfg);p=exp["packet"];core=exp["cfg"];plan=exp["plan"]
    fs_base=p["FsBase"];fs=5e6
    nt=int(round(plan["toneDuration_s"]*fs_base))
    tone=np.sin(2*np.pi*core["toneFrequencyHz"]*np.arange(nt)/fs_base)
    cycle=np.r_[tone,np.tile(p["baseFrame"],int(plan["communicationFrames"]))]
    count=int(round(.1*fs_base));offset=int(round(.005731*fs_base))
    tiled=np.tile(cycle,int(np.ceil((count+offset)/len(cycle)))+1)
    raw=modem.resample_matlab(tiled[offset:offset+count],8,25)*.007+.523
    cap=dict(YData=raw,XData=np.arange(raw.size)/fs-.05,FsCapture=fs,
             capturedAt="MAT_bridge_synthetic",validForProcessing=True,
             experimentSignature=exp["signature"],savedPath="")
    state=process(cap,exp,save=False)
    reference=dict(packet=matlab_doubles(p),core_config=matlab_doubles(core),
                   plan=matlab_doubles(plan),reference_capture=cap,
                   expected_summary=state["summary"])
    return reference,state


class MatlabReferenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp=tempfile.TemporaryDirectory()
        cls.root=Path(cls.tmp.name)
        with contextlib.redirect_stdout(io.StringIO()):
            cls.reference,cls.state=make_reference_fixture(cls.root)
        cls.path=cls.root/"python_reference.mat"
        savemat(cls.path,cls.reference,do_compression=True,oned_as="column")

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_matlab_v7_double_counts_roundtrip_and_average(self):
        with contextlib.redirect_stdout(io.StringIO()):
            r=replay_matlab_reference(self.path,self.root/"roundtrip")
        self.assertTrue(r["analysisOK"],r["analysisError"])
        self.assertTrue(r["receiverAverage"]["available"],r["receiverAverage"].get("reason"))
        self.assertTrue(r["combinedCriteriaMet"])
        for key in ("OriginalBER","AveragedBER","AcceptedFrames","RejectedFrames","DecodedBits"):
            self.assertEqual(r["summary"][key],self.state["summary"][key])
            self.assertEqual(r["matlabComparison"][key]["matlab"],r["matlabComparison"][key]["python"])
        self.assertAlmostEqual(r["summary"]["ToneRMS_mV"],self.state["summary"]["ToneRMS_mV"],places=12)
        np.testing.assert_array_equal(r["packet"]["payloadBits"],self.state["packet"]["payloadBits"])
        np.testing.assert_array_equal(r["capture"]["YData"],self.state["capture"]["YData"])
        self.assertFalse(r["positionEstimateComputed"])

    def test_comparison_preserves_disagreement_in_expected_result(self):
        reference=copy.deepcopy(self.reference)
        reference["expected_summary"]["OriginalBER"]=.123
        path=self.root/"different_expected.mat"
        savemat(path,reference,do_compression=True,oned_as="column")
        with contextlib.redirect_stdout(io.StringIO()):
            r=replay_matlab_reference(path,self.root/"mismatch")
        self.assertEqual(r["matlabComparison"]["OriginalBER"]["matlab"],.123)
        self.assertNotEqual(r["matlabComparison"]["OriginalBER"]["python"],.123)
        self.assertEqual(r["summary"]["OriginalBER"],self.state["summary"]["OriginalBER"])


if __name__=="__main__":
    unittest.main(verbosity=2)
