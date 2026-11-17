"""Combined pilot/OFDM analysis, faithful to the established MATLAB receiver.

Hardware-independent. Packet/result keys retain MATLAB names. Saved decoder
frame starts and selectedRow retain MATLAB ONE-BASED numbering. NumPy slices
are zero based. Detection and channel estimation never use payload decisions.
"""
from fractions import Fraction
from math import ceil, gcd
import numpy as np
from . import modem

_TINY = np.finfo(float).tiny
_NAN = float("nan")


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _real_vector(value, name):
    values=np.asarray(value)
    _require(np.isrealobj(values) and values.size>0 and np.isfinite(values).all() and
             (values.ndim==1 or (values.ndim==2 and min(values.shape)==1)),
             name+" must be a finite real sample vector.")
    return values.astype(float).ravel()


def _round(value):
    return int(np.floor(float(value) + 0.5))


def _ratio(output_rate, input_rate):
    ratio = Fraction(float(output_rate) / float(input_rate)).limit_denominator(100000)
    _require(max(ratio.numerator, ratio.denominator) <= 100000 and
             abs(float(ratio) - output_rate / input_rate) <= 1e-10,
             "Impractical resampling ratio.")
    return ratio.numerator, ratio.denominator


def _resample(values, output_rate, input_rate):
    p, q = _ratio(output_rate, input_rate)
    return modem.resample_matlab(values, p, q) if p != q else np.asarray(values).copy()


def core_config(public_config):
    """Map editable public settings to the original combined-receiver schema."""
    c = public_config
    return dict(version="Python combined receiver 1.0", FsAWG=c.get("awg_sample_rate_hz", 16e9),
        txVpp=c.get("awg_vpp", 1.0), txOffsetV=c.get("awg_offset_v", 0.0),
        payloadQAM=c.get("qam_order", 64), targetBER=c.get("ber_target", 1e-3),
        toneFrequencyHz=c.get("pilot_frequency_hz", 500e3),
        toneLead_s=c.get("pilot_lead_s", .001), positionWindow_s=c.get("pilot_measurement_s", .010),
        toneTail_s=c.get("pilot_tail_s", .001), communicationDuration_s=c.get("ofdm_duration_s", .010),
        detectorSampleRate=2e6, detectorWindow_s=100e-6,
        minBlockTonePurity=.70, minWindowTonePurity=.80, timingTolerance_s=300e-6,
        ofdmContext_s=200e-6, minimumCompleteCycles=c.get("minimum_complete_cycles", 2),
        captureTarget_s=c.get("capture_target_s", .100),
        captureRequestedPoints=c.get("scope_requested_points", 2000000),
        minimumCaptureSampleRate=c.get("scope_min_sample_rate_hz", 5e6),
        segmentGranularity=128, minimumSegmentSamples=640, maximumToneTileSamples=1000000,
        uploadChunkSamples=c.get("upload_chunk_samples", 512000),
        maximumCombinedSamples=c.get("max_waveform_samples", 1000000000))


def _ceil_units(x):
    r = _round(x)
    return r if abs(x-r) <= 32*np.spacing(max(1., abs(x))) else int(ceil(x))


def plan(cfg, packet):
    """Quantize tone periods and whole OFDM frames without allocating the ARB."""
    for key in ("FsAWG", "txVpp", "toneFrequencyHz", "positionWindow_s", "communicationDuration_s",
                "detectorSampleRate", "detectorWindow_s", "timingTolerance_s", "ofdmContext_s",
                "captureTarget_s", "minimumCaptureSampleRate"):
        _require(np.isscalar(cfg[key]) and np.isfinite(cfg[key]) and cfg[key] > 0, key+" must be positive and finite.")
    for key in ("toneLead_s", "toneTail_s"):
        _require(np.isscalar(cfg[key]) and np.isfinite(cfg[key]) and cfg[key] >= 0, key+" must be nonnegative.")
    for key in ("segmentGranularity", "minimumSegmentSamples", "maximumToneTileSamples", "minimumCompleteCycles",
                "captureRequestedPoints", "uploadChunkSamples", "maximumCombinedSamples"):
        v=cfg[key]; _require(np.isscalar(v) and np.isfinite(v) and v > 0 and v == int(v), key+" must be a positive integer.")
    for key in ("targetBER", "minBlockTonePurity", "minWindowTonePurity"):
        _require(np.isscalar(cfg[key]) and np.isfinite(cfg[key]) and 0 < cfg[key] < 1, key+" must lie between zero and one.")
    _require(cfg["txVpp"] == 1 and cfg["txOffsetV"] == 0, "Retain 1 Vpp and zero AWG offset.")
    _require(cfg["segmentGranularity"] == 128 and cfg["minimumSegmentSamples"] == 640, "Retain 128/640 sample memory profile.")
    _require(cfg["captureRequestedPoints"] >= 2 and cfg["minimumCaptureSampleRate"] >= 5e6, "Capture requires at least 5 MSa/s and two points.")
    _require(cfg["FsAWG"] == 16e9 and packet["cfg"]["FsAWG"] == cfg["FsAWG"], "Retain the 16 GSa/s waveform profile.")
    _require(packet["payloadQAM"] == cfg["payloadQAM"] and cfg["payloadQAM"] in (4,16,64,256), "Packet and requested QAM do not match.")
    _require(2*max(cfg["toneFrequencyHz"], np.max(packet["activeFrequencyHz"])) < cfg["detectorSampleRate"] <= 5e6,
             "Detector rate must cover tone and OFDM carriers and not exceed 5 MSa/s.")
    _require(min(cfg["toneLead_s"],cfg["toneTail_s"]) >= 2*cfg["detectorWindow_s"], "Tone guards need at least two detector windows.")
    _require(cfg["minimumCompleteCycles"] >= 2, "At least two complete cycles are required.")
    _require(cfg["ofdmContext_s"] >= 2*cfg["detectorWindow_s"] and
             cfg["ofdmContext_s"]+cfg["detectorWindow_s"] < packet["frameDuration"], "Invalid OFDM boundary context.")
    _require(2*cfg["detectorWindow_s"] <= cfg["timingTolerance_s"] < packet["frameDuration"], "Invalid timing tolerance.")
    period=cfg["FsAWG"]/cfg["toneFrequencyHz"]
    _require(abs(period-_round(period)) <= 32*np.spacing(max(1.,period)), "Tone needs an integer AWG samples-per-period ratio.")
    period=_round(period); gran=int(cfg["segmentGranularity"])
    tile=period*gran//gcd(period,gran);tile*=int(ceil(cfg["minimumSegmentSamples"]/tile))
    _require(tile <= cfg["maximumToneTileSamples"], "Coherent tone tile is too long.")
    dt=tile/cfg["FsAWG"]
    lead=_ceil_units(cfg["toneLead_s"]/dt);window=_ceil_units(cfg["positionWindow_s"]/dt);tail=_ceil_units(cfg["toneTail_s"]/dt)
    frames=_ceil_units(cfg["communicationDuration_s"]/packet["frameDuration"])
    _require(window >= 1 and 4 <= frames <= 2**32-1 and lead+window+tail <= 2**32-1, "Use at least four OFDM frames and valid repeat counts.")
    frame=int(packet["frameLengthBase"]*packet["cfg"]["samplesPerSymbol"])
    _require(frame % gran == 0 and frame >= cfg["minimumSegmentSamples"], "OFDM frame violates AWG granularity.")
    tone_samples=tile*(lead+window+tail);total=tone_samples+frames*frame
    _require(total <= cfg["maximumCombinedSamples"] and total % gran == 0,
             "Combined waveform exceeds configured sample memory limit; shorten the slots.")
    _require(cfg["uploadChunkSamples"] >= 640 and cfg["uploadChunkSamples"] % 128 == 0,
             "Upload chunks must be at least 640 samples and a multiple of 128.")
    cycle=total/cfg["FsAWG"];minimum=(cfg["minimumCompleteCycles"]+1)*cycle+2*cfg["detectorWindow_s"]
    maximum=(cfg["captureRequestedPoints"]-1)/cfg["minimumCaptureSampleRate"]
    target=max(cfg["captureTarget_s"], minimum)
    _require(minimum <= maximum, "Requested slots exceed scope duration at the minimum acceptable sample rate.")
    _require(target <= maximum, "Requested capture target exceeds scope point/rate limit.")
    return dict(toneTileSamplesAWG=tile,toneCyclesPerTile=tile/period,toneTotalRepeats=lead+window+tail,
        toneLeadActual_s=lead*dt,positionWindowActual_s=window*dt,toneTailActual_s=tail*dt,
        toneDuration_s=(lead+window+tail)*dt,communicationFrames=frames,ofdmFrameSamplesAWG=frame,
        ofdmFrameDuration_s=packet["frameDuration"],communicationRequested_s=cfg["communicationDuration_s"],
        communicationDuration_s=frames*packet["frameDuration"],toneSamplesAWG=tone_samples,totalSamplesAWG=total,
        waveformBytes=total,cycleDuration_s=cycle,minimumCaptureDuration_s=minimum,
        nominalPayloadRate_bps=packet["payloadBitCount"]/packet["frameDuration"],
        nominalCyclePayloadRate_bps=frames*packet["payloadBitCount"]/cycle,
        detectorTimingResolution_s=cfg["detectorWindow_s"],maximumCaptureAtMinimumRate_s=maximum,
        captureTarget_s=target,note="Single repeating ARB; no SEQ required. Manual stopped orientations.")


def _slot():
    r={k:_NAN for k in ("toneStart_s","toneEnd_s","communicationStart_s","communicationEnd_s",
       "toneDurationMeasured_s","communicationDurationMeasured_s","cycleDurationMeasured_s",
       "decoderCropStart_s","decoderCropEnd_s","bitErrors","BER","EVM")}
    r.update({k:0 for k in ("cycleIndex","expectedFrames","framesLocated","acceptedFrames","rejectedFrames","nBits")})
    r.update(timingAccepted=False,toneAccepted=False,frameCountAccepted=False,reason="")
    return r


def _tone():
    r={k:_NAN for k in ("measuredStart_s","measuredEnd_s","measuredDuration_s","windowStart_s",
        "windowDuration_s","rms_V","peakToPeakFit_V","dc_V","bandPurity","peakFrequencyHz","frequencyResolutionHz")}
    r.update(cycleIndex=0,nSamples=0,accepted=False,reason="")
    return r


def _empty_result(p,c):
    r={k:0 for k in ("bitErrors","nBits","acceptedFrames","rejectedFrames","expectedFrames","nFrames",
        "nAttemptedBits","completeCycles","validTimingCycles","rejectedSlots","rejectedToneWindows",
        "detectedToneRuns","partialEdgeToneRuns","partialEdgeCyclesExcluded","excludedOFDMEdgeFrames")}
    r.update(accepted=False,reason="",plan=p,BER=_NAN,EVM=_NAN,timingAccepted=False,
        measuredBERTargetMet=False,targetBER=c["targetBER"],FsCapture=_NAN,captureDuration_s=_NAN,
        detectorBlockDuration_s=c["detectorWindow_s"],firstFrameEVM=_NAN,positioningEstimateComputed=False)
    r.update({k:[] for k in ("slotResults","toneResults","frameResults","ofdmResults")})
    r.update({k:np.array([]) for k in ("equalizedPayload","detectorTime_s","detectorTonePurity")})
    return r


def _measure_tone(v,fs,c,tone):
    n=len(v);t=np.arange(n)/fs;freq=c["toneFrequencyHz"]
    A=np.column_stack((np.cos(2*np.pi*freq*t),np.sin(2*np.pi*freq*t),np.ones(n)))
    b=np.linalg.lstsq(A,v,rcond=None)[0]
    rms=float(np.hypot(b[0],b[1])/np.sqrt(2));z=v-np.mean(v)
    F=np.fft.rfft(z);f=np.fft.rfftfreq(n,1/fs)
    band=(f>=max(1,.4*freq)) & (f<=min(.49*fs,1.8*freq))
    power=2*np.sum(abs(F[band])**2)/n**2
    purity=min(1.,rms*rms/max(power,_TINY));Fw=np.fft.rfft(z*np.hanning(n))
    near=np.flatnonzero(abs(f-freq)<=max(5e3,3*fs/n));peak=float(f[near[np.argmax(abs(Fw[near]))]])
    accepted=bool(np.isfinite(rms) and rms>0 and purity>=c["minWindowTonePurity"] and
                  abs(peak-freq)<=max(2*fs/n,100e-6*freq))
    tone.update(rms_V=rms,peakToPeakFit_V=float(2*np.hypot(b[0],b[1])),dc_V=float(b[2]),
        bandPurity=float(purity),peakFrequencyHz=peak,frequencyResolutionHz=fs/n,accepted=accepted,
        reason="Full stable observation measured; amplitude is not a position estimate." if accepted else
               "Tone-frequency or useful-band purity check failed.")
    return tone


def analyze(packet,capture,cfg):
    """Detect tone boundaries independently, then decode every planned OFDM frame."""
    p=plan(cfg,packet);r=_empty_result(p,cfg)
    y=_real_vector(capture["YData"],"Received data");fs=float(capture["FsCapture"])
    _require(len(y)>0 and np.isfinite(y).all(), "Received data must be nonempty finite real samples.")
    _require(np.isfinite(fs) and fs>=5e6, "Scope sample rate must be at least 5 MSa/s.")
    r.update(FsCapture=fs,captureDuration_s=(len(y)-1)/fs)
    if np.ptp(y)==0:
        r["reason"]="Capture is constant; no received waveform can be evaluated.";return r
    if r["captureDuration_s"]<p["minimumCaptureDuration_s"]:
        r["reason"]="Capture is too short for the required complete cycles.";return r
    z=_resample(y-y.mean(),cfg["detectorSampleRate"],fs);fd=cfg["detectorSampleRate"]
    block_n=_round(cfg["detectorWindow_s"]*fd);_require(block_n>=20,"Detector window is too short.")
    block_t=block_n/fd;nb=len(z)//block_n
    blocks=z[:nb*block_n].reshape(block_n,nb,order="F");t=np.arange(block_n)/fd
    A=np.column_stack((np.cos(2*np.pi*cfg["toneFrequencyHz"]*t),np.sin(2*np.pi*cfg["toneFrequencyHz"]*t),np.ones(block_n)))
    coefs=np.linalg.lstsq(A,blocks,rcond=None)[0];centred=blocks-blocks.mean(axis=0)
    fit=A[:,:2]@coefs[:2];fit-=fit.mean(axis=0)
    energy=np.sum(centred**2,axis=0);purity=np.sum(fit**2,axis=0)/np.maximum(energy,_TINY)
    purity[energy<=np.max(energy)*1e-14]=0;purity=np.clip(purity,0,1)
    mask=purity>=cfg["minBlockTonePurity"]
    edges=np.diff(np.r_[False,mask,False].astype(int));starts=np.flatnonzero(edges==1);ends=np.flatnonzero(edges==-1)
    keep=ends-starts>=2;starts=starts[keep];ends=ends[keep]
    r.update(detectorTime_s=(np.arange(nb)+.5)*block_t,detectorTonePurity=purity,
             detectorBlockDuration_s=block_t,detectedToneRuns=len(starts))
    if len(starts)<2:
        r["reason"]="Too few tone-to-OFDM transitions.";return r
    r["partialEdgeToneRuns"]=int(np.count_nonzero((starts==0)|(ends==nb)))
    error_energy=reference_energy=0.
    for j in range(len(starts)-1):
        if starts[j]==0 or ends[j]==nb:
            r["partialEdgeCyclesExcluded"]+=1;continue
        tone_start=starts[j]*block_t;tone_end=ends[j]*block_t;next_start=starts[j+1]*block_t
        slot=_slot();slot.update(cycleIndex=len(r["slotResults"])+1,toneStart_s=tone_start,toneEnd_s=tone_end,
            communicationStart_s=tone_end,communicationEnd_s=next_start,toneDurationMeasured_s=tone_end-tone_start,
            communicationDurationMeasured_s=next_start-tone_end,cycleDurationMeasured_s=next_start-tone_start,
            expectedFrames=p["communicationFrames"])
        slot["timingAccepted"]=bool(abs(slot["toneDurationMeasured_s"]-p["toneDuration_s"])<=cfg["timingTolerance_s"] and
            abs(slot["communicationDurationMeasured_s"]-p["communicationDuration_s"])<=cfg["timingTolerance_s"] and
            abs(slot["cycleDurationMeasured_s"]-p["cycleDuration_s"])<=cfg["timingTolerance_s"])
        r["completeCycles"]+=1;r["expectedFrames"]+=p["communicationFrames"]
        tone=_tone();tone.update(cycleIndex=slot["cycleIndex"],measuredStart_s=tone_start,measuredEnd_s=tone_end,measuredDuration_s=tone_end-tone_start)
        if not slot["timingAccepted"]:
            slot.update(reason="Measured slot durations do not match the planned sequence.",rejectedFrames=p["communicationFrames"])
            tone["reason"]="Slot timing invalid; no positioning window accepted."
            r["rejectedToneWindows"]+=1;r["rejectedSlots"]+=1;r["rejectedFrames"]+=p["communicationFrames"]
            r["slotResults"].append(slot);r["toneResults"].append(tone);r["ofdmResults"].append(None);continue
        r["validTimingCycles"]+=1
        first=_round((tone_start+p["toneLeadActual_s"])*fs);count=_round(p["positionWindowActual_s"]*fs);last=first+count
        if first>=0 and last<=len(y) and last/fs<=tone_end-cfg["detectorWindow_s"]:
            tone=_measure_tone(y[first:last],fs,cfg,tone)
            tone.update(windowStart_s=first/fs,windowDuration_s=count/fs,nSamples=count)
        else:
            tone["reason"]="A full positioning observation does not fit inside the tone slot."
        slot["toneAccepted"]=tone["accepted"]
        if not tone["accepted"]:r["rejectedToneWindows"]+=1
        crop_start=max(0,int(np.floor((tone_end-cfg["ofdmContext_s"])*fs)))
        crop_end=min(len(y),int(np.ceil((next_start+cfg["ofdmContext_s"])*fs)))
        slot.update(decoderCropStart_s=crop_start/fs,decoderCropEnd_s=crop_end/fs)
        d=modem.decode(packet,y[crop_start:crop_end],fs);r["ofdmResults"].append(d)
        slot.update(framesLocated=d["nFrames"],frameCountAccepted=d["nFrames"]==p["communicationFrames"])
        if not slot["frameCountAccepted"]:
            slot.update(reason=f"Expected {p['communicationFrames']} complete frames, located {d['nFrames']}; slot rejected.",rejectedFrames=p["communicationFrames"])
            r["rejectedSlots"]+=1;r["rejectedFrames"]+=p["communicationFrames"]
        else:
            for key in ("acceptedFrames","rejectedFrames","nBits","bitErrors","BER","EVM"):slot[key]=d[key]
            r["acceptedFrames"]+=d["acceptedFrames"];r["rejectedFrames"]+=d["rejectedFrames"]
            if d["nBits"]>0:
                r["nBits"]+=d["nBits"];r["bitErrors"]+=d["bitErrors"]
                ref=float(np.sum(abs(packet["payloadSymbols"])**2))*d["acceptedFrames"]
                error_energy+=d["EVM"]**2*ref;reference_energy+=ref
                if r["equalizedPayload"].size==0:
                    r["equalizedPayload"]=d["equalizedPayload"];r["firstFrameEVM"]=d["firstFrameEVM"]
            for frame in d["frameResults"]:
                entry=dict(frame);entry.update(cycleIndex=slot["cycleIndex"],captureStart_s=crop_start/fs+(frame["start"]-1)/d["FsDecoded"])
                r["frameResults"].append(entry)
            slot["reason"]=d["reason"]
        r["slotResults"].append(slot);r["toneResults"].append(tone)
    r["partialEdgeCyclesExcluded"]+=1;r["nFrames"]=r["expectedFrames"];r["nAttemptedBits"]=r["expectedFrames"]*packet["payloadBitCount"]
    if r["nBits"]>0:r["BER"]=r["bitErrors"]/r["nBits"];r["EVM"]=float(np.sqrt(error_energy/reference_energy))
    else:r["bitErrors"]=_NAN
    r["timingAccepted"]=bool(r["completeCycles"]>=cfg["minimumCompleteCycles"] and r["validTimingCycles"]==r["completeCycles"])
    r["accepted"]=bool(r["validTimingCycles"]>=cfg["minimumCompleteCycles"] and r["nBits"]>0)
    r["measuredBERTargetMet"]=bool(r["accepted"] and r["timingAccepted"] and r["rejectedSlots"]==0 and
        r["rejectedToneWindows"]==0 and r["rejectedFrames"]==0 and r["acceptedFrames"]==r["expectedFrames"] and
        np.isfinite(r["BER"]) and r["BER"]<=cfg["targetBER"])
    if r["completeCycles"]<cfg["minimumCompleteCycles"]:r["reason"]="Too few complete cycles; use a longer capture."
    elif not r["timingAccepted"]:r["reason"]="Received slot timing failed validation; invalid intervals retained as failures."
    elif r["rejectedSlots"]:r["reason"]="A complete OFDM slot failed expected-frame accounting."
    elif r["rejectedToneWindows"]:r["reason"]="A positioning window failed tone-quality checks."
    elif not r["nBits"]:r["reason"]="No usable OFDM BER: no complete frame passed training."
    elif r["measuredBERTargetMet"]:r["reason"]="Switching, full tone windows and all complete OFDM frames met stationary criteria."
    else:r["reason"]="Slot timing identified; BER or complete-frame target was not met."
    r["note"]="Boundaries have detector-window resolution. No position is computed. Repeated known payload; all complete-slot frames counted."
    return r


def empty_average():
    return dict(available=False,reason="Not evaluated.",BER=_NAN,bitErrors=_NAN,nBits=0,
        acceptedFrames=0,rejectedFrames=0,originalBER=_NAN,originalBitErrors=_NAN,
        originalAcceptedFrames=0,originalRejectedFrames=0,targetBER=_NAN,baselineReproduced=False,
        measuredBERTargetMet=False,frameResults=[],method="Same-burst phase-aligned leave-one-frame-out known-training averaging; stationary channel and complete burst buffering required.")


def _check_channel(H,c):
    _require(np.isfinite(H).all() and np.all(abs(H)>_TINY) and
             np.all(abs(H)>=c["minRelativeChannelMagnitude"]*np.sqrt(np.mean(abs(H)**2))),
             "Channel estimate is invalid or too weak; no frame is dropped.")


def average_state(state):
    """Reproduce original decisions, then average OTHER frames' known training."""
    a=empty_average();r=state["result"];p=state["packet"];c=p["cfg"];cfg=state["cfg"]
    a.update(originalBER=r["BER"],originalBitErrors=r["bitErrors"],originalAcceptedFrames=r["acceptedFrames"],
             originalRejectedFrames=r["rejectedFrames"],targetBER=cfg["targetBER"])
    if (not r["slotResults"] or r["nBits"]<=0 or r["acceptedFrames"]<=0 or r["rejectedSlots"] or r["rejectedFrames"] or
        r["validTimingCycles"]!=r["completeCycles"] or r["acceptedFrames"]!=r["expectedFrames"]):
        a["reason"]="Original slots or frames did not all pass detection; averaging not applied and no frame removed.";return a
    raw=_real_vector(state["capture"]["YData"],"Received data");fs=float(state["capture"]["FsCapture"])
    _require(len(r["slotResults"])==len(r["ofdmResults"]), "Saved burst records are inconsistent.")
    Xt=np.asarray(p["trainingSymbols"]);K=len(p["activeBins"]);train_energy=np.sum(abs(Xt)**2,axis=1)
    _require(Xt.shape==(K,2) and c["nTraining"]==2 and np.all(train_energy>0), "Invalid two-symbol known training.")
    original_errors=averaged_errors=total_bits=total_frames=0;rows=[]
    for slot,d in zip(r["slotResults"],r["ofdmResults"]):
        if d is None or not slot["timingAccepted"] or not slot["frameCountAccepted"]:
            a["reason"]="Invalid saved communication burst.";return a
        frames=d["frameResults"];F=len(frames)
        if F!=slot["expectedFrames"] or F<2 or not all(f["accepted"] for f in frames):
            a["reason"]="All planned frames must be present and accepted.";return a
        lo=_round(slot["decoderCropStart_s"]*fs);hi=_round(slot["decoderCropEnd_s"]*fs)
        _require(0<=lo<hi<=len(raw), "Saved crop outside raw waveform.")
        y=raw[lo:hi];y=_resample(y-y.mean(),p["FsBase"],fs)
        spectra=[];aligned=[];phases=[];baseline=[]
        for i,frame in enumerate(frames):
            start=int(frame["start"])-1
            _require(start>=0 and frame["start"]==int(frame["start"]), "Invalid saved frame start.")
            ix=start+int(c["CP"])-int(c["fftAdvanceBase"])+np.arange(int(c["NFFT"]))[:,None]+np.arange(int(c["nTraining"]+c["nPayload"]))[None,:]*int(p["symbolLengthBase"])
            _require(ix.min()>=0 and ix.max()<len(y), "Saved FFT window outside crop.")
            Y=(np.fft.fft(y[ix],axis=0)/np.sqrt(c["NFFT"]))[np.asarray(p["activeBins"],int)]
            H=np.sum(Y[:,:2]*Xt.conj(),axis=1)/train_energy
            try:_check_channel(H,c)
            except ValueError as exc:a["reason"]=str(exc);return a
            Z=Y[:,2:]/H[:,None];evm=float(np.sqrt(np.sum(abs(Z-p["payloadSymbols"])**2)/np.sum(abs(p["payloadSymbols"])**2)))
            _require(np.isfinite(frame["EVM"]) and abs(evm-frame["EVM"])<1e-8, "Saved frame EVM did not reproduce; averaging stopped.")
            bits=modem.demodulate(Z,p["payloadQAM"]);errors=int(np.count_nonzero(bits!=p["payloadBits"]))
            _require(errors==frame["bitErrors"] and frame["nBits"]==p["payloadBits"].size, "Saved frame bit count did not reproduce; averaging stopped.")
            delta=frame["start"]-(frames[0]["start"]+i*p["frameLengthBase"])
            phase=np.exp(1j*2*np.pi*np.asarray(p["activeBins"])*delta/c["NFFT"])
            phases.append(phase);aligned.append(H/phase);spectra.append(Y);baseline.append(errors)
        aligned=np.asarray(aligned);sum_h=aligned.sum(axis=0)
        for i,frame in enumerate(frames):
            H=(sum_h-aligned[i])/(F-1)*phases[i]
            try:_check_channel(H,c)
            except ValueError as exc:a["reason"]=str(exc);return a
            bits=modem.demodulate(spectra[i][:,2:]/H[:,None],p["payloadQAM"])
            errors=int(np.count_nonzero(bits!=p["payloadBits"]));n=p["payloadBits"].size
            rows.append(dict(File=state.get("capturedAt","current capture"),Cycle=slot["cycleIndex"],FrameInBurst=i+1,
                StartBase=frame["start"],OriginalErrors=baseline[i],AveragedErrors=errors,Bits=n,
                OriginalBER=baseline[i]/n,AveragedBER=errors/n,TrainingFramesUsed=F-1,TrainingSymbolsUsed=(F-1)*2))
            original_errors+=baseline[i];averaged_errors+=errors;total_bits+=n;total_frames+=1
    _require(total_frames==r["acceptedFrames"] and total_bits==r["nBits"] and original_errors==r["bitErrors"] and
             abs(original_errors/total_bits-r["BER"])<1e-12, "Original aggregate totals did not reproduce; averaging stopped.")
    ber=averaged_errors/total_bits
    a.update(available=True,BER=ber,bitErrors=averaged_errors,nBits=total_bits,acceptedFrames=total_frames,
             baselineReproduced=True,measuredBERTargetMet=ber<=cfg["targetBER"],frameResults=rows,
             reason="Training-averaged BER meets target; all original frames retained." if ber<=cfg["targetBER"] else
                    "Training averaging completed, but BER exceeds target; all original frames retained.")
    return a


def position_input(state,orientationId):
    """Select the first chronologically valid full raw pilot, never an average."""
    _require(np.isscalar(orientationId) and np.isfinite(orientationId) and orientationId==int(orientationId) and 1<=orientationId<=5,
             "Orientation label must be an integer from 1 to 5.")
    r=state["result"];cfg=state["cfg"];fs=float(state["capture"]["FsCapture"]);n=len(state["capture"]["YData"])
    _require(np.isfinite(fs) and fs>0 and n>=2, "Invalid capture or sample rate.")
    expected=(state["plan"] if "plan" in state else r["plan"])["positionWindowActual_s"];requested=cfg["positionWindow_s"];tol=1/fs
    _require(expected>=requested-tol, "Prepared window is shorter than requested.")
    windows=[];usable=[]
    for i,tone in enumerate(r["toneResults"]):
        entry=dict(tone);entry.update(orientationId=int(orientationId),rms_mV=1000*tone["rms_V"],validLogical=False)
        status="Valid full positioning observation."
        fields=("rms_V","cycleIndex","windowStart_s","windowDuration_s","nSamples")
        if not tone["accepted"]:status="Tone-quality check did not pass."
        elif not all(np.isscalar(tone[k]) and np.isfinite(tone[k]) for k in fields):status="Invalid measurement metadata."
        elif (tone["rms_V"]<=0 or tone["windowStart_s"]<0 or tone["windowDuration_s"]<=0 or
              tone["cycleIndex"]<1 or tone["cycleIndex"]!=int(tone["cycleIndex"]) or
              tone["nSamples"]<1 or tone["nSamples"]!=int(tone["nSamples"])):status="Invalid amplitude or observation bounds."
        elif (abs(tone["windowDuration_s"]-expected)>tol or tone["windowDuration_s"]<requested-tol or
              abs(tone["nSamples"]/fs-tone["windowDuration_s"])>tol or abs(tone["nSamples"]/fs-expected)>tol):status="Observation lacks the full planned window."
        else:
            first=_round(tone["windowStart_s"]*fs);last=first+tone["nSamples"]
            matches=[s for s in r["slotResults"] if s["cycleIndex"]==tone["cycleIndex"]]
            if first<0 or last>n:status="Observation outside saved capture."
            elif len(matches)!=1 or not matches[0]["timingAccepted"]:status="Associated slot timing not valid."
            elif first/fs<matches[0]["toneStart_s"]-tol or last/fs>matches[0]["toneEnd_s"]+tol:status="Observation outside its detected tone slot."
            else:entry["validLogical"]=True;usable.append((i,tone))
        entry["validationStatus"]=status;windows.append(entry)
    _require(bool(usable), "No full valid positioning observation is available.")
    i,tone=min(usable,key=lambda item:item[1]["windowStart_s"])
    return dict(orientationId=int(orientationId),rms_V=tone["rms_V"],rms_mV=1000*tone["rms_V"],
        cycleIndex=tone["cycleIndex"],windowStart_s=tone["windowStart_s"],windowDuration_s=tone["windowDuration_s"],
        nSamples=tone["nSamples"],frequency_Hz=cfg["toneFrequencyHz"],capturedAt=state.get("capturedAt",""),
        selectedRow=i+1,actualTxVpp=state.get("txMetadata",{}).get("Vpp",_NAN),
        sourcePath=state.get("lastSavePath",state["capture"].get("savedPath","")),positionEstimateComputed=False,
        selection="First chronologically valid single positioning window; no averaging.",
        orientationSource="Caller-supplied stopped-orientation label.",windows=windows)


def pilot_fft(pilot,padding_factor=1):
    """Periodic Hann, coherent-gain corrected one-sided PEAK amplitude spectrum."""
    _require(np.isscalar(padding_factor) and np.isfinite(padding_factor) and padding_factor>=1 and padding_factor==int(padding_factor),
             "FFT padding factor must be a positive integer.")
    v=_real_vector(pilot["voltage_V"],"Pilot data");fs=float(pilot["sampleRate_Hz"]);n=len(v)
    _require(n>=2 and np.isfinite(v).all() and np.isfinite(fs) and fs>0, "Invalid pilot samples/rate.")
    w=.5-.5*np.cos(2*np.pi*np.arange(n)/n);nfft=n*int(padding_factor)
    amplitude=np.abs(np.fft.rfft((v-v.mean())*w,nfft))/w.sum()
    if nfft%2==0:amplitude[1:-1]*=2
    else:amplitude[1:]*=2
    return dict(frequency_Hz=np.fft.rfftfreq(nfft,1/fs),amplitudePeak_mV=1000*amplitude,
        unpaddedBinSpacing_Hz=fs/n,displayBinSpacing_Hz=fs/nfft,
        equivalentNoiseBandwidth_Hz=fs*np.sum(w*w)/w.sum()**2,dcRemoved_V=float(v.mean()),
        paddingFactor=int(padding_factor),window="Periodic Hann",amplitudeConvention="One-sided peak amplitude in mV; not RMS or PSD.")
