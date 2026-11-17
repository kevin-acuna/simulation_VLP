"""Offline combined-receiver tests: no VISA or instruments are opened."""
import copy
import unittest
import numpy as np
from isac import modem, processing


def synthetic_capture(packet, core, fs=20e6, offset_s=.005731, amplitude=.007,
                      noise=0., missing_training=False, bad_payload=False,
                      wrong_frames=0, duration_s=None):
    p=processing.plan(core,packet);base_rate=packet["FsBase"]
    nt=processing._round(p["toneDuration_s"]*base_rate)
    tone=np.sin(2*np.pi*core["toneFrequencyHz"]*np.arange(nt)/base_rate)
    frames=[packet["baseFrame"].copy() for _ in range(p["communicationFrames"]+wrong_frames)]
    if missing_training:
        frames[0][:packet["cfg"]["nTraining"]*packet["symbolLengthBase"]]=0
    if bad_payload:
        changed=packet["payloadBits"].copy();changed[0,0]=not changed[0,0]
        payload=modem.modulate(changed,packet["payloadQAM"])
        X=np.zeros((packet["cfg"]["NFFT"],10),complex)
        positive=np.c_[packet["trainingSymbols"],payload]
        k=packet["activeBins"].astype(int);X[k]=positive;X[packet["cfg"]["NFFT"]-k]=positive.conj()
        symbols=np.fft.ifft(X,axis=0).real*np.sqrt(packet["cfg"]["NFFT"])
        frame=np.r_[symbols[-packet["cfg"]["CP"]:],symbols].reshape(-1,order="F")*packet["normalizationGain"]
        frames[-1]=frame
    cycle=np.r_[tone,np.concatenate(frames)]
    duration_s=max(.1,p["minimumCaptureDuration_s"]+.015) if duration_s is None else duration_s
    count=processing._round(duration_s*base_rate);offset=processing._round(offset_s*base_rate)
    tiled=np.tile(cycle,int(np.ceil((count+offset)/len(cycle)))+1)
    raw=processing._resample(tiled[offset:offset+count],fs,base_rate)
    if noise:raw+=np.random.default_rng(117).normal(scale=noise,size=len(raw))
    raw=.523+amplitude*raw
    return dict(YData=raw,FsCapture=fs,XData=np.arange(len(raw))/fs,capturedAt="synthetic",savedPath="")


def processed(packet,core,capture):
    result=processing.analyze(packet,capture,core)
    state=dict(packet=packet,cfg=core,capture=capture,result=result,plan=processing.plan(core,packet),capturedAt="synthetic")
    state["receiverAverage"]=processing.average_state(state)
    return state


class ProcessingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.packet=modem.make_frame(modem.modem_config(64))
        cls.core=processing.core_config({})
        cls.good=synthetic_capture(cls.packet,cls.core)
        cls.state=processed(cls.packet,cls.core,cls.good)

    def test_default_arithmetic(self):
        p=processing.plan(self.core,self.packet)
        self.assertEqual(p["totalSamplesAWG"],359116800)
        self.assertEqual(p["communicationFrames"],15)
        self.assertAlmostEqual(p["minimumCaptureDuration_s"],.0675344,12)
        self.assertAlmostEqual(p["positionWindowActual_s"],.01,12)
        self.assertAlmostEqual(p["nominalPayloadRate_bps"],2274816.176470588,7)
        altered=processing.core_config({"capture_target_s":.15})
        self.assertEqual(processing.plan(altered,self.packet)["captureTarget_s"],.15)

    def test_default_capture_and_averaging(self):
        r=self.state["result"];a=self.state["receiverAverage"]
        self.assertTrue(r["measuredBERTargetMet"],r["reason"])
        self.assertGreaterEqual(r["completeCycles"],2)
        self.assertEqual(r["acceptedFrames"],r["completeCycles"]*15)
        self.assertEqual(r["rejectedFrames"],0)
        self.assertEqual(r["bitErrors"],0)
        self.assertTrue(a["available"],a["reason"])
        self.assertTrue(a["baselineReproduced"])
        self.assertEqual(a["bitErrors"],0)
        self.assertEqual(a["nBits"],r["nBits"])
        self.assertTrue(all(row["TrainingFramesUsed"]==14 for row in a["frameResults"]))

    def test_pilot_selection_full_window(self):
        pos=processing.position_input(self.state)
        self.assertEqual(pos["nSamples"],200000)
        self.assertAlmostEqual(pos["windowDuration_s"],.01,12)
        self.assertAlmostEqual(pos["rms_mV"],7/np.sqrt(2),delta=.03)
        times=[x["windowStart_s"] for x in pos["windows"] if x["validLogical"]]
        self.assertEqual(pos["windowStart_s"],min(times))
        self.assertFalse(pos["positionEstimateComputed"])

    def test_changed_duration_qam_and_sample_phase(self):
        for qam,fs,offset in ((4,5e6,.000137),(16,10e6,.015371)):
            with self.subTest(qam=qam):
                c=processing.core_config(dict(qam_order=qam,pilot_measurement_s=.005,ofdm_duration_s=.020))
                p=modem.make_frame(modem.modem_config(qam))
                state=processed(p,c,synthetic_capture(p,c,fs=fs,offset_s=offset,amplitude=-.003))
                self.assertTrue(state["result"]["measuredBERTargetMet"],state["result"]["reason"])
                self.assertEqual(state["receiverAverage"]["BER"],0)
                pos=processing.position_input(state)
                self.assertAlmostEqual(pos["windowDuration_s"],.005,12)

    def test_held_out_payload_errors_counted(self):
        state=processed(self.packet,self.core,synthetic_capture(self.packet,self.core,fs=5e6,bad_payload=True))
        r=state["result"]
        self.assertEqual(r["bitErrors"],r["completeCycles"])
        self.assertEqual(state["receiverAverage"]["bitErrors"],r["completeCycles"])
        self.assertEqual(r["rejectedFrames"],0)

    def test_missing_training_disables_average_without_dropping_frames(self):
        state=processed(self.packet,self.core,synthetic_capture(self.packet,self.core,fs=5e6,missing_training=True))
        r=state["result"]
        self.assertFalse(r["measuredBERTargetMet"])
        self.assertGreater(r["rejectedFrames"],0)
        self.assertFalse(state["receiverAverage"]["available"])
        self.assertTrue(np.isnan(state["receiverAverage"]["BER"]))

    def test_wrong_slot_duration_retained_as_failure(self):
        r=processing.analyze(self.packet,synthetic_capture(self.packet,self.core,fs=5e6,wrong_frames=-2),self.core)
        self.assertFalse(r["measuredBERTargetMet"])
        self.assertGreater(r["rejectedSlots"],0)

    def test_incomplete_or_constant_input(self):
        for data in (np.full(500000,.523),self.good["YData"][:200000]):
            r=processing.analyze(self.packet,dict(YData=data,FsCapture=20e6),self.core)
            self.assertFalse(r["accepted"])
            self.assertFalse(r["measuredBERTargetMet"])
        with self.assertRaises(ValueError):
            processing.analyze(self.packet,dict(YData=np.ones(200000),FsCapture=2e6),self.core)
        for invalid in (np.array([1+1j,2+2j]),np.array([1.,np.inf]),np.ones((3,3))):
            with self.assertRaises(ValueError):processing.analyze(self.packet,dict(YData=invalid,FsCapture=20e6),self.core)
        for change in ({"pilot_measurement_s":60},{"ofdm_duration_s":.0001},{"pilot_lead_s":0},{"awg_vpp":.5}):
            with self.assertRaises(ValueError):processing.plan(processing.core_config(change),self.packet)

    def test_averaging_baseline_tamper_detected(self):
        state=copy.deepcopy(self.state)
        state["result"]["ofdmResults"][0]["frameResults"][0]["bitErrors"]+=1
        with self.assertRaises(ValueError):processing.average_state(state)

    def test_matlab_float_integer_metadata(self):
        state=copy.deepcopy(self.state)
        for key in ("CP","NFFT","nTraining","nPayload","fftAdvanceBase"):
            state["packet"]["cfg"][key]=float(state["packet"]["cfg"][key])
        state["packet"]["symbolLengthBase"]=float(state["packet"]["symbolLengthBase"])
        averaged=processing.average_state(state)
        self.assertTrue(averaged["available"])
        self.assertEqual(averaged["bitErrors"],0)


if __name__=="__main__":unittest.main()
