"""ISAC experiment: prepare the transmitted waveform and process one received capture.

    experiment = prepare(cfg)               OFDM packet + pilot/OFDM timing plan (no instrument access)
    state = process(capture, experiment)    receiver: pilot tone RMS of every tone window, OFDM decoding
                                            (BER, EVM, frames) and the training-averaged BER

`cfg` is a flat dictionary with the keys of the original ICS config.py (see make_config). The receiver
(processing.py, modem.py) is the one of the ICS program, ported from the working MATLAB bench. No position
is estimated here: the pilot RMS is only measured.
"""

import copy
import math

import numpy as np

from . import modem, processing
from .common import now_iso, signature, validate_experiment

# Keys of the ISAC hyperparameters (top of each script) = signal / capture part of the ICS config.py
ISAC_KEYS = (
    "pilot_frequency_hz",
    "pilot_measurement_s",
    "pilot_lead_s",
    "pilot_tail_s",
    "ofdm_duration_s",
    "qam_order",
    "ber_target",
    "training_average",
    "scope_timebase_s_per_div",
    "scope_requested_points",
    "scope_min_sample_rate_hz",
    "capture_target_s",
    "minimum_complete_cycles",
)


def instrument_config(devices):
    """AWG / oscilloscope part of the flat ICS-style configuration (from config/devices.toml)."""
    awg, scope, visa = devices["awg"], devices["scope"], devices.get("visa", {})
    return {
        "awg_address": awg["address"], "scope_address": scope["address"],
        "visa_library": visa.get("library", "@ivi"), "keysight_dll_dir": visa.get("keysight_dll_dir", ""),
        "awg_sample_rate_hz": float(awg["sample_rate_hz"]), "awg_vpp": float(awg["vpp"]),
        "awg_offset_v": float(awg["offset_v"]), "awg_channel": int(awg["channel"]),
        "scope_channel": int(scope["channel"]), "awg_timeout_s": float(awg["timeout_s"]),
        "scope_timeout_s": float(scope["timeout_s"]), "upload_chunk_samples": int(awg["upload_chunk_samples"]),
        "max_waveform_samples": int(awg["max_waveform_samples"]), "backup_existing": bool(awg["backup_existing"]),
    }


def make_config(isac, devices):
    """Flat ICS-style configuration (keys of the ICS config.py) from the script hyperparameters + devices."""
    missing = [k for k in ISAC_KEYS if k not in isac]
    if missing:
        raise ValueError(f"Missing ISAC hyperparameters: {missing}")
    return {**instrument_config(devices), **{k: isac[k] for k in ISAC_KEYS}}


def prepare(cfg):
    """OFDM packet + combined pilot/OFDM plan. Contacts no instrument."""
    cfg = copy.deepcopy(cfg)
    for name in ("awg_address", "scope_address"):
        if not isinstance(cfg.get(name), str) or not cfg[name].strip():
            raise ValueError(f"Set the {name.split('_')[0]} address in config/devices.toml")
    if not isinstance(cfg.get("training_average"), bool):
        raise ValueError("training_average must be True or False")
    if cfg.get("awg_channel", 1) != 1 or cfg.get("awg_offset_v", 0) != 0:
        raise ValueError("Retain AWG channel 1 and zero offset")
    modem_cfg = modem.modem_config(cfg["qam_order"])
    modem_cfg["targetBER"] = cfg["ber_target"]
    packet = modem.make_frame(modem_cfg)
    core = processing.core_config(cfg)
    plan = processing.plan(core, packet)
    exp = dict(schemaVersion=1, config=cfg, cfg=core, packet=packet, plan=plan, preparedAt=now_iso())
    exp["signature"] = signature(exp)
    return exp


def describe(experiment):
    """Text summary of the prepared waveform."""
    p, cfg, packet = experiment["plan"], experiment["config"], experiment["packet"]
    f = packet["activeFrequencyHz"]
    return (
        f"Pilot {cfg['pilot_frequency_hz'] / 1e3:g} kHz: {1e3 * p['toneDuration_s']:.6g} ms slot "
        f"({1e3 * p['positionWindowActual_s']:.6g} ms observation). OFDM {packet['payloadQAM']}-QAM, "
        f"{len(f)} carriers {f[0] / 1e3:.1f}-{f[-1] / 1e3:.1f} kHz: {1e3 * p['communicationDuration_s']:.6g} ms "
        f"({p['communicationFrames']} frames).\nCycle {1e3 * p['cycleDuration_s']:.6g} ms, "
        f"{p['waveformBytes'] / 1e6:.3f} MB in the AWG. Capture needs >= {1e3 * p['minimumCaptureDuration_s']:.6g} ms "
        f"at >= {cfg['scope_min_sample_rate_hz'] / 1e6:g} MSa/s. Nominal payload rate "
        f"{p['nominalPayloadRate_bps'] / 1e6:.4g} Mb/s in the OFDM slot."
    )


def process(capture, experiment):
    """Receiver on one capture. Original BER is always kept apart from the training-averaged BER.

    Communication failures (no sync, rejected frames, high BER, rejected tone windows) are results, not
    errors: they are reported in the returned state. Raises only for an invalid capture.
    """
    validate_experiment(experiment)
    if capture.get("experimentSignature") != experiment["signature"]:
        raise ValueError("Capture belongs to a different experiment")
    flag = capture.get("validForProcessing", True)
    if not isinstance(flag, (bool, np.bool_, int, np.integer)) or flag != 1:
        raise ValueError("Invalid capture: " + capture.get("validationError", "inspect saved raw data"))
    y = np.asarray(capture["YData"])
    fs = float(capture["FsCapture"])
    if np.iscomplexobj(y) or y.ndim != 1 or not y.size or not np.all(np.isfinite(y)):
        raise ValueError("Capture must contain a finite real sample vector")
    if not math.isfinite(fs) or fs < experiment["config"]["scope_min_sample_rate_hz"] * (1 - 1e-9):
        raise ValueError("Returned sample rate is below configured minimum")
    if (y.size - 1) / fs < experiment["plan"]["minimumCaptureDuration_s"]:
        raise ValueError("Returned capture is shorter than this experiment requires")
    state = dict(
        version="Python ICS receiver1.0",
        config=experiment["config"],
        cfg=experiment["cfg"],
        packet=experiment["packet"],
        plan=experiment["plan"],
        experimentSignature=experiment["signature"],
        capture=capture,
        capturedAt=capture.get("capturedAt", now_iso()),
        txMetadata=capture.get("txMetadata", {}),
        analysisOK=False,
        analysisError="",
        positionInput=None,
        positionError="",
        receiverAverageError="",
        windows=[],
        positionEstimateComputed=False,
    )
    average = dict(
        available=False,
        BER=float("nan"),
        measuredBERTargetMet=False,
        reason="Training averaging disabled or unavailable",
        frameResults=[],
    )
    state["receiverAverage"] = average
    try:
        state["result"] = processing.analyze(state["packet"], capture, state["cfg"])
        state["analysisOK"] = True
    except Exception as exc:
        state["analysisError"] = f"{type(exc).__name__}: {exc}"
    if state["analysisOK"]:
        try:
            state["windows"] = processing.validate_windows(state)[0]
            state["positionInput"] = processing.position_input(state)
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
    original_pass = (
        np.isfinite(ber)
        and r.get("nBits", 0) > 0
        and ber <= state["cfg"]["targetBER"]
        and r.get("rejectedSlots", 1) == 0
        and r.get("rejectedFrames", 1) == 0
        and r.get("acceptedFrames", 0) == r.get("expectedFrames", -1)
    )
    comm_pass = (
        bool(a.get("available") and a.get("measuredBERTargetMet"))
        if experiment["config"]["training_average"]
        else bool(original_pass)
    )
    position = state["positionInput"]
    state["combinedCriteriaMet"] = bool(
        state["analysisOK"]
        and r.get("timingAccepted", False)
        and r.get("rejectedToneWindows", 1) == 0
        and position is not None
        and comm_pass
    )
    state["ofdmTargetMet"] = comm_pass
    state["summary"] = dict(
        CapturedAt=state["capturedAt"],
        AnalysisOK=state["analysisOK"],
        ToneAvailable=position is not None,
        ToneRMS_mV=position["rms_mV"] if position else float("nan"),
        Observation_ms=1000 * state["plan"]["positionWindowActual_s"],
        OriginalBER=ber,
        TrainingAverageAvailable=bool(a.get("available", False)),
        AveragedBER=a.get("BER", float("nan")),
        OFDMTargetMet=comm_pass,
        AcceptedFrames=r.get("acceptedFrames", 0),
        RejectedFrames=r.get("rejectedFrames", 0),
        DecodedBits=r.get("nBits", 0),
        CombinedCriteriaMet=state["combinedCriteriaMet"],
        NominalOFDMslotPayload_Mbps=state["plan"]["nominalPayloadRate_bps"] / 1e6,
        NominalCyclePayload_Mbps=state["plan"]["nominalCyclePayloadRate_bps"] / 1e6,
        PositionEstimateComputed=False,
    )
    return state


def print_summary(state):
    for name, value in state["summary"].items():
        print(f"  {name}: {value}")
    if state["analysisError"]:
        print("  Analysis error:", state["analysisError"])
    if state["positionInput"] is None:
        print("  No valid pilot window:", state["positionError"])
    if not state["receiverAverage"].get("available"):
        print("  Training averaging unavailable:", state["receiverAverage"].get("reason", ""))
