"""Command-by-command experiment, receiver, raw pilot and manual scan workflow."""
import copy
import csv
from pathlib import Path
import math
import numpy as np
from scipy.io import savemat, loadmat
from .common import now_iso, result_folder, save_record, load_record, signature, validate_experiment
from . import modem, processing


def prepare(config):
    cfg = copy.deepcopy(config)
    for name in ("awg_address", "scope_address", "output_dir"):
        if not isinstance(cfg.get(name), str) or not cfg[name].strip():
            raise ValueError(f"Set {name} in config.py")
    if not isinstance(cfg.get("training_average"), bool):
        raise ValueError("training_average must be True or False")
    if cfg.get("awg_channel", 1) != 1 or cfg.get("awg_offset_v", 0) != 0:
        raise ValueError("Retain AWG channel1 and zero offset")
    modem_cfg = modem.modem_config(cfg["qam_order"])
    modem_cfg["targetBER"] = cfg["ber_target"]
    packet = modem.make_frame(modem_cfg)
    core = processing.core_config(cfg)
    plan = processing.plan(core, packet)
    exp = dict(schemaVersion=1, config=cfg, cfg=core, packet=packet, plan=plan, preparedAt=now_iso())
    exp["signature"] = signature(exp)
    print(f"Prepared: {1e3*plan['positionWindowActual_s']:.6f} ms pilot observation; "
          f"{1e3*plan['toneDuration_s']:.6f} ms tone slot; "
          f"{1e3*plan['communicationDuration_s']:.6f} ms OFDM ({plan['communicationFrames']} frames).")
    print(f"Cycle {1e3*plan['cycleDuration_s']:.6f} ms; {plan['waveformBytes']/1e6:.3f} MB. "
          f"Capture needs >= {1e3*plan['minimumCaptureDuration_s']:.6f} ms at >= "
          f"{cfg['scope_min_sample_rate_hz']/1e6:.3f} MSa/s.")
    print("No instruments contacted. Payload rates are nominal repeated-test-data rates.")
    return exp


def _csv(path, rows):
    if not rows:
        return
    keys = list(dict.fromkeys(k for row in rows for k in row))
    with Path(path).open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=keys)
        writer.writeheader()
        writer.writerows(rows)


def print_summary(result):
    summary = result.get("summary", result)
    for name, value in summary.items():
        print(f"{name}: {value}")


def process(capture, experiment, orientation_id=1, *, save=True):
    """Offline processing. Always retain original BER separately from averaged BER."""
    validate_experiment(experiment)
    if isinstance(orientation_id, bool) or orientation_id not in range(1, 6):
        raise ValueError("orientation_id must be an integer from1 to5")
    if capture.get("experimentSignature") != experiment["signature"]:
        raise ValueError("Capture belongs to a different experiment")
    flag = capture.get("validForProcessing", True)
    if not isinstance(flag, (bool, np.bool_, int, np.integer)) or flag != 1:
        raise ValueError("Invalid capture: " + capture.get("validationError", "inspect saved raw data"))
    y = np.asarray(capture["YData"])
    fs = float(capture["FsCapture"])
    if np.iscomplexobj(y) or y.ndim != 1 or not y.size or not np.all(np.isfinite(y)):
        raise ValueError("Capture must contain a finite real sample vector")
    if not math.isfinite(fs) or fs < experiment["config"]["scope_min_sample_rate_hz"] * (1-1e-9):
        raise ValueError("Returned sample rate is below configured minimum")
    if (y.size-1)/fs < experiment["plan"]["minimumCaptureDuration_s"]:
        raise ValueError("Returned capture is shorter than this experiment requires")
    state = dict(version="Python ICS receiver1.0", config=experiment["config"], cfg=experiment["cfg"],
                 packet=experiment["packet"], plan=experiment["plan"], experimentSignature=experiment["signature"],
                 capture=capture, capturedAt=capture.get("capturedAt", now_iso()), orientationId=orientation_id,
                 txMetadata=capture.get("txMetadata", {}), analysisOK=False, analysisError="",
                 positionInput=None, positionError="", receiverAverageError="", lastSavePath="",
                 lastSaveError="", exportError="", positionEstimateComputed=False)
    average = dict(available=False, BER=float("nan"), measuredBERTargetMet=False,
                   reason="Training averaging disabled or unavailable", frameResults=[])
    state["receiverAverage"] = average
    try:
        state["result"] = processing.analyze(state["packet"], capture, state["cfg"])
        state["analysisOK"] = True
    except Exception as exc:
        state["analysisError"] = f"{type(exc).__name__}: {exc}"
    if state["analysisOK"]:
        try:
            state["positionInput"] = processing.position_input(state, orientation_id)
        except Exception as exc:
            state["positionError"] = f"{type(exc).__name__}: {exc}"
        if experiment["config"]["training_average"]:
            try:
                state["receiverAverage"] = processing.average_state(state)
            except Exception as exc:
                state["receiverAverageError"] = f"{type(exc).__name__}: {exc}"
                average["reason"] = state["receiverAverageError"]
    r = state.get("result", {})
    a = state["receiverAverage"]
    ber = r.get("BER", float("nan"))
    original_pass = (np.isfinite(ber) and r.get("nBits", 0) > 0 and ber <= state["cfg"]["targetBER"]
                     and r.get("rejectedSlots", 1) == 0 and r.get("rejectedFrames", 1) == 0
                     and r.get("acceptedFrames", 0) == r.get("expectedFrames", -1))
    comm_pass = bool(a.get("available") and a.get("measuredBERTargetMet")) if experiment["config"]["training_average"] else bool(original_pass)
    position = state["positionInput"]
    state["combinedCriteriaMet"] = bool(state["analysisOK"] and r.get("timingAccepted", False)
          and r.get("rejectedToneWindows", 1) == 0 and position is not None and comm_pass)
    state["summary"] = dict(CapturedAt=state["capturedAt"], Orientation=orientation_id,
        AnalysisOK=state["analysisOK"], ToneAvailable=position is not None,
        ToneRMS_mV=position["rms_mV"] if position else float("nan"),
        Observation_ms=1000*state["plan"]["positionWindowActual_s"], OriginalBER=ber,
        TrainingAverageAvailable=bool(a.get("available", False)), AveragedBER=a.get("BER", float("nan")),
        OFDMTargetMet=comm_pass, AcceptedFrames=r.get("acceptedFrames", 0),
        RejectedFrames=r.get("rejectedFrames", 0), DecodedBits=r.get("nBits", 0),
        CombinedCriteriaMet=state["combinedCriteriaMet"],
        NominalOFDMslotPayload_Mbps=state["plan"]["nominalPayloadRate_bps"]/1e6,
        NominalCyclePayload_Mbps=state["plan"]["nominalCyclePayloadRate_bps"]/1e6,
        PositionEstimateComputed=False)
    if save:
        try:
            folder = result_folder(state["config"]["output_dir"], "analysis")
            state["lastSavePath"] = str(folder / "result.npz")
            _csv(folder/"summary.csv", [state["summary"]])
            for key in ("toneResults", "slotResults", "frameResults"):
                _csv(folder/(key+".csv"), r.get(key, []))
            _csv(folder/"averaged_frames.csv", a.get("frameResults", []))
            save_record(state["lastSavePath"], {"state": state})
        except Exception as exc:
            state["lastSaveError"] = str(exc)
            print("Save failed; result remains in memory:", exc)
    print_summary(state)
    if state["analysisError"]:
        print("Analysis error:", state["analysisError"])
    if position is None:
        print("No valid positioning pilot:", state["positionError"])
    if not a.get("available"):
        print("Training averaging unavailable:", a.get("reason", ""))
    return state


def export_pilot(state, orientation_id=None, output_dir=None):
    if orientation_id is None:
        orientation_id = state["orientationId"]
    position = processing.position_input(state, orientation_id)
    fs = float(state["capture"]["FsCapture"])
    first = int(np.floor(position["windowStart_s"]*fs+0.5))
    n = int(position["nSamples"])
    y = np.asarray(state["capture"]["YData"])
    if first < 0 or n < 2 or first+n > y.size:
        raise ValueError("Pilot samples fall outside capture")
    if abs(first/fs-position["windowStart_s"]) > 64*np.spacing(max(1.0, abs(position["windowStart_s"]))):
        raise ValueError("Pilot start is not on the captured sample grid")
    raw = y[first:first+n].copy()
    if not np.all(np.isfinite(raw)) or fs <= 2*position["frequency_Hz"]:
        raise ValueError("Invalid pilot samples or Nyquist condition")
    pilot = dict(orientationId=int(orientation_id), time_s=np.arange(n)/fs,
        captureTime_s=(first+np.arange(n))/fs, voltage_V=raw, sampleRate_Hz=fs, nSamples=n,
        recordDuration_s=n/fs, sampleSpan_s=(n-1)/fs, fftBinSpacing_Hz=fs/n,
        firstSampleIndex=first+1, lastSampleIndex=first+n,  # MATLAB-compatible indices
        toneFrequency_Hz=position["frequency_Hz"], fittedRMS_mV=position["rms_mV"],
        sourceCapturePath=state["capture"].get("savedPath", ""), capturedAt=state["capturedAt"],
        positionEstimateComputed=False, voltageUnit="V", processing="Exact received subset including DC; no filtering or resampling.")
    x = state["capture"].get("XData")
    if x is not None:
        x = np.asarray(x)
        tolerance = max(1e-8/fs, 64*np.spacing(max(1.0, np.max(np.abs(x)))))
        if x.shape != y.shape or not np.all(np.isfinite(x)) or np.max(np.abs(np.diff(x)-1/fs)) > tolerance:
            raise ValueError("Scope time vector is inconsistent with returned sample rate")
        pilot["scopeTime_s"] = x[first:first+n].copy()
    folder = result_folder(output_dir or state["config"]["output_dir"], "pilots")
    stem = f"orientation_{int(orientation_id):02d}_pilot"
    pilot.update(npzPath=str(folder/(stem+".npz")), matPath=str(folder/(stem+".mat")), csvPath=str(folder/(stem+".csv")))
    save_record(pilot["npzPath"], {"pilot": pilot})
    savemat(pilot["matPath"], {"pilot": pilot}, do_compression=True, oned_as="column")
    np.savetxt(pilot["csvPath"], np.column_stack([pilot["time_s"],pilot["captureTime_s"],raw]),
               delimiter=",", header="time_s,timeFromCaptureStart_s,voltage_V", comments="")
    print("Raw pilot MAT:", pilot["matPath"])
    return pilot


def pilot_fft(pilot, padding_factor=1, *, plot=True):
    if isinstance(padding_factor, bool) or not isinstance(padding_factor, (int, np.integer)) or padding_factor < 1:
        raise ValueError("padding_factor must be a positive integer")
    y = np.asarray(pilot["voltage_V"], dtype=float)
    fs = float(pilot["sampleRate_Hz"])
    if y.ndim != 1 or y.size < 3 or not np.all(np.isfinite(y)) or not np.isfinite(fs) or fs <= 0:
        raise ValueError("Pilot must be a finite waveform with a positive sample rate")
    n = y.size; nfft = n*int(padding_factor)
    w = 0.5-0.5*np.cos(2*np.pi*np.arange(n)/n)  # Periodic Hann, like MATLAB.
    dc = float(y.mean())
    amplitude = np.abs(np.fft.rfft((y-dc)*w, n=nfft))/w.sum()
    if nfft % 2 == 0:
        amplitude[1:-1] *= 2
    else:
        amplitude[1:] *= 2
    result = dict(frequency_Hz=np.fft.rfftfreq(nfft, 1/fs), amplitudePeak_mV=amplitude*1000,
                  unpaddedBinSpacing_Hz=fs/n, displayBinSpacing_Hz=fs/nfft,
                  equivalentNoiseBandwidth_Hz=fs*np.sum(w*w)/(w.sum()**2), dcRemoved_V=dc)
    if plot:
        import matplotlib.pyplot as plt
        plt.figure(); plt.plot(result["frequency_Hz"]/1e3, result["amplitudePeak_mV"])
        plt.xlabel("Frequency (kHz)"); plt.ylabel("Amplitude (mV peak)")
        plt.title(f"Pilot FFT: {fs/n:g} Hz native bin spacing; Hann window")
        plt.grid(True); plt.show(block=False)
    return result


def position_dummy(pilots):
    if len(pilots) != 5:
        raise ValueError("Positioning callback needs five raw pilot waveforms")
    for k, pilot in enumerate(pilots, 1):
        if pilot["orientationId"] != k:
            raise ValueError("Pilots must be ordered by orientation1..5")
        y = np.asarray(pilot["voltage_V"]); t = np.asarray(pilot["time_s"])
        fs = pilot["sampleRate_Hz"]
        if y.ndim != 1 or y.size < 2 or y.shape != t.shape or not np.all(np.isfinite(y)) or not np.isfinite(fs) or fs <= 0:
            raise ValueError("Invalid raw pilot")
        if not np.allclose(t, np.arange(y.size)/fs, rtol=0, atol=1e-12):
            raise ValueError("Pilot time grid does not match sample rate")
    return dict(implemented=False, positionEstimateComputed=False, position_m=np.full(3, np.nan),
                status="Five raw pilots received. Replace position_dummy with a calibrated estimator.")


def scan(rig, experiment, estimator=position_dummy, *, input_fn=input):
    from .instruments import capture
    validate_experiment(experiment)
    folder = result_folder(experiment["config"]["output_dir"], "scans")
    result = dict(orientationIds=np.arange(1, 6), pilots=[None]*5, rms_mV=np.full(5, np.nan),
                  averagedBER=np.full(5, np.nan), completedOrientations=0, complete=False,
                  cancelled=False, error="", saveError="", estimatorCalled=False, estimatorOutput=None,
                  captureFiles=[""]*5, pilotMatFiles=[""]*5, pilotCsvFiles=[""]*5,
                  savedPath=str(folder/"scan.npz"), experimentSignature=experiment["signature"])
    def persist():
        save_record(result["savedPath"], {"scan": result})
        _csv(folder/"scan_summary.csv", [dict(Orientation=k+1, FittedToneRMS_mV=result["rms_mV"][k],
             AveragedOFDM_BER=result["averagedBER"][k], PilotMAT=result["pilotMatFiles"][k],
             PilotCSV=result["pilotCsvFiles"][k]) for k in range(5)])
    def persist_safely():
        try:
            result["saveError"] = ""
            persist()
            return True
        except Exception as exc:
            result["saveError"] = str(exc)
            print("Scan save failed; partial results remain in memory:", exc)
            return False
    persist()
    for k in range(5):
        while True:
            answer = input_fn(f"Orientation{k+1}: move mirror, wait until stopped, then Enter; q cancels: ").strip().lower()
            if answer in ("", "q"):
                break
        if answer == "q":
            result["cancelled"] = True
            persist_safely(); return result
        try:
            record = capture(rig, experiment)
            state = process(record, experiment, k+1)
            pilot = export_pilot(state, k+1, folder)
            result["pilots"][k] = pilot
            result["rms_mV"][k] = pilot["fittedRMS_mV"]
            result["averagedBER"][k] = state["receiverAverage"].get("BER", float("nan"))
            result["captureFiles"][k] = record.get("savedPath", "")
            result["pilotMatFiles"][k] = pilot["matPath"]
            result["pilotCsvFiles"][k] = pilot["csvPath"]
            result["completedOrientations"] = k+1
            persist()
        except Exception as exc:
            result["error"] = f"{type(exc).__name__}: {exc}"
            try: persist()
            except Exception as save_exc: result["saveError"] = str(save_exc)
            print("Scan stopped; partial results retained:", result["error"])
            return result
    result["complete"] = True
    if not persist_safely():  # Preserve all pilots before calling the estimator.
        result["error"] = "All pilots collected but saving failed; estimator not called."
        return result
    try:
        result["estimatorCalled"] = True
        result["estimatorOutput"] = estimator(result["pilots"])
    except Exception as exc:
        result["error"] = "Estimator failed: " + str(exc)
    if persist_safely():
        print("Five-orientation scan saved:", result["savedPath"])
    return result


def replay(path, orientation_id=1):
    record = load_record(path)
    if "capture" in record and "experiment" in record:
        return process(record["capture"], record["experiment"], orientation_id)
    raise ValueError("Replay needs a capture record containing its matching experiment")


def replay_matlab_reference(path, output_dir=None):
    """Decode a MATLAB-v7 export of the SAME successful samples and TX packet."""
    from config import get_config
    reference = loadmat(path, simplify_cells=True)
    cfg = get_config()
    core = reference["core_config"]
    mapping = {"pilot_frequency_hz":"toneFrequencyHz", "pilot_measurement_s":"positionWindow_s",
               "pilot_lead_s":"toneLead_s", "pilot_tail_s":"toneTail_s", "ofdm_duration_s":"communicationDuration_s",
               "qam_order":"payloadQAM", "ber_target":"targetBER"}
    for public, internal in mapping.items(): cfg[public] = core[internal]
    cfg["output_dir"] = str(output_dir or (Path(path).resolve().parent/"python_reference_comparison"))
    packet = reference["packet"]
    # MATLAB uses doubles for counts; NumPy requires integer array indices.
    def integer_fields(target, fields):
        for name in fields:
            value = target[name]
            if not np.isscalar(value) or not np.isfinite(value) or value != int(value):
                raise ValueError("Invalid MATLAB integer field: " + name)
            target[name] = int(value)
    integer_fields(packet["cfg"], ("NFFT", "CP", "samplesPerSymbol", "nTraining", "nPayload",
        "payloadQAM", "seed", "interpolationGuardBase", "receiverEdgeGuardBase", "fftAdvanceBase",
        "timingSearchBase", "maxSyncCandidates"))
    integer_fields(packet, ("frameLengthBase", "symbolLengthBase", "payloadQAM", "bitsPerCarrier", "payloadBitCount"))
    packet["payloadBits"] = np.asarray(packet["payloadBits"], dtype=bool)
    packet["trainingBits"] = np.asarray(packet["trainingBits"], dtype=bool)
    for field in ("activeBins",): packet[field] = np.asarray(packet[field],dtype=int).reshape(-1)
    packet["cfg"]["activeBins"] = np.asarray(packet["cfg"]["activeBins"],dtype=int).reshape(-1)
    exp = dict(config=cfg, cfg=core, packet=packet, plan=reference["plan"], schemaVersion=1)
    exp["signature"] = signature(exp)
    cap = reference["reference_capture"]
    cap.update(experimentSignature=exp["signature"], validForProcessing=True)
    cap["YData"] = np.asarray(cap["YData"]).reshape(-1)
    cap["XData"] = np.asarray(cap["XData"]).reshape(-1)
    result = process(cap, exp, 1)
    expected = reference["expected_summary"]
    keys = ("ToneRMS_mV", "OriginalBER", "AveragedBER", "AcceptedFrames", "RejectedFrames", "DecodedBits")
    comparison = {k: {"matlab": expected[k], "python": result["summary"][k]} for k in keys}
    print("Same-capture MATLAB/Python comparison:")
    for key, values in comparison.items(): print(key, values)
    result["matlabComparison"] = comparison
    if result.get("lastSavePath") and not result.get("lastSaveError"):
        save_record(result["lastSavePath"], {"state": result})
        _csv(Path(result["lastSavePath"]).with_name("matlab_comparison.csv"),
             [dict(Metric=k, MATLAB=v["matlab"], Python=v["python"]) for k, v in comparison.items()])
    return result
