"""Training-only narrowband OFDM modem, ported from the working MATLAB bench.

Dictionary names follow the MATLAB packet/result schema. Frame diagnostic
indices are ONE-BASED (``indexBase=1``); ``training_fit`` takes a ZERO-BASED
Python index. No instrument or file access occurs here. Known repeated payload
BER is a laboratory measurement, not application goodput.
"""

from __future__ import annotations

import copy
import math
from fractions import Fraction
import numpy as np
from scipy.signal import fftconvolve, resample_poly


def modem_config(qam_order=64):
    return dict(
        version="Python narrowband modem 1.0",
        FsAWG=16e9,
        samplesPerSymbol=1024,
        FsBase=15.625e6,
        NFFT=1024,
        CP=64,
        activeBins=np.arange(20, 53, dtype=int),
        nTraining=2,
        nPayload=8,
        payloadQAM=qam_order,
        targetBER=1e-3,
        seed=1109,
        scopeSampleRateTarget=5e6,
        captureDuration=3e-3,
        interpolationGuardBase=64,
        receiverEdgeGuardBase=64,
        fftAdvanceBase=32,
        timingSearchBase=32,
        minSyncScore=0.35,
        maxTrainingEVM=0.40,
        maxSyncCandidates=64,
        minRelativeChannelMagnitude=1e-3,
    )


def _integer(value, name, minimum=0):
    if not np.isscalar(value) or not np.isfinite(value) or value != int(value) or value < minimum:
        raise ValueError(f"{name} must be an integer >= {minimum}")
    return int(value)


def _real_vector(value, name):
    a = np.asarray(value)
    if not np.isrealobj(a) or a.size == 0 or not np.all(np.isfinite(a)):
        raise ValueError(f"{name} must be a nonempty real finite vector")
    if a.ndim > 2 or (a.ndim == 2 and min(a.shape) != 1):
        raise ValueError(f"{name} must be a vector")
    return np.ravel(a).astype(float)


def round_matlab(value):
    """Round ties away from zero, including signed DAC quantization ties."""
    a = np.asarray(value)
    return np.copysign(np.floor(np.abs(a) + 0.5), a)


def _qam_table(order):
    if order not in (4, 16, 64, 256):
        raise ValueError("QAM order must be 4, 16, 64 or 256")
    order = int(order)
    levels = math.isqrt(order)
    m = int(math.log2(levels))
    index = np.arange(levels, dtype=np.int64)
    gray = index ^ (index >> 1)
    scale = math.sqrt(2 * (order - 1) / 3)
    amplitudes = (levels - 1 - 2 * index) / scale
    by_gray = np.empty(levels)
    by_gray[gray] = amplitudes
    return levels, m, gray, scale, by_gray


def modulate(bits, order):
    """Gray square QAM: rows are carrier bit words [I MSB..LSB,Q MSB..LSB]."""
    _, m, _, _, by_gray = _qam_table(order)
    bits = np.asarray(bits)
    if bits.ndim != 2 or bits.size == 0 or bits.shape[0] % (2 * m) or not np.all((bits == 0) | (bits == 1)):
        raise ValueError("Bits must be a binary matrix with rows divisible by log2(QAM)")
    shaped = bits.reshape((-1, 2 * m, bits.shape[1]))
    weights = 2 ** np.arange(m - 1, -1, -1)
    gi = np.sum(shaped[:, :m, :] * weights[None, :, None], axis=1).astype(int)
    gq = np.sum(shaped[:, m:, :] * weights[None, :, None], axis=1).astype(int)
    return by_gray[gi] + 1j * by_gray[gq]


def demodulate(symbols, order):
    """Nearest-neighbour demapping with MATLAB's away-from-zero tie rule."""
    levels, m, gray, scale, _ = _qam_table(order)
    z = np.asarray(symbols)
    if z.ndim != 2 or z.size == 0 or not np.all(np.isfinite(z)):
        raise ValueError("QAM symbols must be a nonempty finite matrix")
    ni = np.clip(round_matlab((levels - 1 - z.real * scale) / 2), 0, levels - 1).astype(int)
    nq = np.clip(round_matlab((levels - 1 - z.imag * scale) / 2), 0, levels - 1).astype(int)
    gi, gq = gray[ni], gray[nq]
    shifts = np.arange(m - 1, -1, -1)
    parts = np.concatenate((((gi[:, :, None] >> shifts) & 1), ((gq[:, :, None] >> shifts) & 1)), axis=2)
    return parts.transpose(0, 2, 1).reshape((-1, z.shape[1])).astype(bool)


def rate_ratio(target_rate, source_rate):
    if not np.isfinite(target_rate) or not np.isfinite(source_rate) or target_rate <= 0 or source_rate <= 0:
        raise ValueError("Sample rates must be finite and positive")
    ratio = target_rate / source_rate
    rational = Fraction(float(ratio)).limit_denominator(100000)
    p, q = rational.numerator, rational.denominator
    if max(p, q) > 100000 or abs(p / q - ratio) > 1e-10:
        raise ValueError("Capture-rate ratio requires an impractically long resampling filter")
    return p, q


def resample_matlab(values, up, down):
    """Default 10*max(p,q), beta=5 polyphase convention used by bench references.

    Filter and output alignment match the independently checked NumPy/MATLAB
    reference. Native MATLAB floating-point bit identity is not claimed.
    """
    up, down = _integer(up, "up", 1), _integer(down, "down", 1)
    divisor = math.gcd(up, down)
    up, down = up // divisor, down // divisor
    x = np.asarray(values)
    if x.ndim == 0 or not np.all(np.isfinite(x)):
        raise ValueError("Resampling input must be a finite array")
    if up == down:
        return x.copy()
    highest = max(up, down)
    if highest > 100000:
        raise ValueError("Resampling ratio is too large")
    half = 10 * highest
    t = np.arange(-half, half + 1, dtype=float)
    h = np.sinc(t / highest) / highest * np.kaiser(2 * half + 1, 5.0)
    h /= h.sum()
    return resample_poly(x, up, down, axis=0, window=h, padtype="constant")


def make_frame(cfg=None):
    c = copy.deepcopy(modem_config() if cfg is None else cfg)
    order = c.get("payloadQAM", 4)
    _qam_table(order)
    n = _integer(c["NFFT"], "NFFT", 2)
    cp = _integer(c["CP"], "CP")
    if n % 2 or cp >= n:
        raise ValueError("NFFT must be even and CP smaller than NFFT")
    nt = _integer(c["nTraining"], "nTraining", 1)
    npay = _integer(c["nPayload"], "nPayload", 1)
    if nt != 2:
        raise ValueError("This bench uses exactly two training symbols")
    interpolation = _integer(c["samplesPerSymbol"], "samplesPerSymbol", 1)
    if (
        not np.isfinite(c["FsAWG"])
        or c["FsAWG"] <= 0
        or abs(c["FsBase"] - c["FsAWG"] / interpolation) >= 1e-6
    ):
        raise ValueError("FsBase must equal FsAWG/samplesPerSymbol")
    bins = np.ravel(np.asarray(c["activeBins"]))
    if (
        bins.size == 0
        or not np.all(np.isfinite(bins))
        or np.any(bins != np.floor(bins))
        or np.any(bins <= 0)
        or np.any(bins >= n / 2)
        or np.unique(bins).size != bins.size
    ):
        raise ValueError("Active bins must be unique positive integers below Nyquist")
    bins = bins.astype(int)
    seed = _integer(c["seed"], "seed")
    if seed > 2**32 - 1:
        raise ValueError("Seed is outside uint32 range")
    # MATLAB rng(seed,'twister') randi([0 1],rows,cols): consume doubles in
    # column order. This convention was checked against an actual saved MATLAB
    # QPSK packet in the original reference audit. Seed 0 maps to MT default5489.
    rng = np.random.RandomState(5489 if seed == 0 else seed)
    k, b = bins.size, int(math.log2(order))
    tb = np.floor(2 * rng.random_sample(2 * k * nt)).reshape((2 * k, nt), order="F").astype(bool)
    pb = np.floor(2 * rng.random_sample(b * k * npay)).reshape((b * k, npay), order="F").astype(bool)
    training, payload = modulate(tb, 4), modulate(pb, order)
    positive = np.hstack((training, payload))
    spectrum = np.zeros((n, nt + npay), dtype=complex)
    spectrum[bins, :] = positive
    spectrum[-bins, :] = np.conj(positive)
    time = np.fft.ifft(spectrum, axis=0) * np.sqrt(n)
    if np.max(np.abs(time.imag)) >= 1e-10:
        raise ValueError("Spectrum is not Hermitian")
    time = time.real
    with_cp = np.vstack((time[-cp:, :], time)) if cp else time
    base = with_cp.ravel(order="F")
    gain = 1 / np.max(np.abs(base))
    base = base * gain
    symbol_length = n + cp
    frame_duration = base.size / c["FsBase"]
    return dict(
        cfg=c,
        FsBase=c["FsBase"],
        baseFrame=base,
        trainingReference=base[: nt * symbol_length],
        trainingSymbols=training,
        payloadSymbols=payload,
        payloadBits=pb,
        trainingBits=tb,
        allPositiveSymbols=positive,
        activeBins=bins,
        activeFrequencyHz=bins * c["FsBase"] / n,
        frameLengthBase=base.size,
        symbolLengthBase=symbol_length,
        normalizationGain=gain,
        frameDuration=frame_duration,
        payloadQAM=int(order),
        bitsPerCarrier=b,
        payloadBitCount=pb.size,
        payloadRateIncludingTraining=pb.size / frame_duration,
        payloadSymbolRate=k * b / (symbol_length / c["FsBase"]),
        description="Uniform QAM bench; known repeated data, no FEC; validate BER and rejected frames",
    )


def training_fit(y, start_zero_based, packet):
    """Return positive-bin received symbols, training-derived H and training EVM."""
    c = packet["cfg"]
    n, nt = int(c["NFFT"]), int(c["nTraining"])
    count = nt + int(c["nPayload"])
    start = int(start_zero_based)
    indices = (
        start
        + int(c["CP"])
        - int(c["fftAdvanceBase"])
        + np.arange(n)[:, None]
        + np.arange(count)[None, :] * int(packet["symbolLengthBase"])
    )
    if indices.min() < 0 or indices.max() >= len(y):
        raise ValueError("FFT window is outside the capture")
    Y = (np.fft.fft(y[indices], axis=0) / np.sqrt(n))[np.asarray(packet["activeBins"], dtype=int), :]
    Xt = packet["trainingSymbols"]
    H = np.sum(Y[:, :nt] * np.conj(Xt), axis=1) / np.sum(np.abs(Xt) ** 2, axis=1)
    if (
        not np.all(np.isfinite(H))
        or np.any(np.abs(H) < c["minRelativeChannelMagnitude"] * np.sqrt(np.mean(np.abs(H) ** 2)))
        or np.any(np.abs(H) <= np.finfo(float).tiny)
    ):
        return Y, H, np.inf
    evm = float(np.sqrt(np.sum(np.abs(Y[:, :nt] / H[:, None] - Xt) ** 2) / np.sum(np.abs(Xt) ** 2)))
    return Y, H, evm


def synchronization_scores(y, packet):
    ref = np.ravel(packet["trainingReference"]).astype(float)
    ref -= ref.mean()
    m = len(ref)
    correlation = fftconvolve(y, ref[::-1], mode="valid")
    # Cumulative sums replace long boxcar convolutions without changing the
    # formula. Differences from MATLAB summation order are floating-point only.
    sums = np.r_[0.0, np.cumsum(y)]
    squares = np.r_[0.0, np.cumsum(y * y)]
    window_sum = sums[m:] - sums[:-m]
    energy = np.maximum(squares[m:] - squares[:-m] - window_sum**2 / m, 0.0)
    score = np.abs(correlation) / np.sqrt(np.maximum(energy * np.sum(ref * ref), np.finfo(float).tiny))
    score[energy <= np.spacing(energy.max()) * m] = 0
    guard = int(packet["cfg"]["receiverEdgeGuardBase"])
    n = int(packet["frameLengthBase"])
    starts = np.arange(score.size)
    score[(starts < guard) | (starts > len(y) - guard - n)] = 0
    return score


def _empty_result(fs):
    return dict(
        accepted=False,
        reason="",
        BER=np.nan,
        EVM=np.nan,
        decisionEVM=np.nan,
        bitErrors=0,
        nBits=0,
        syncScore=0.0,
        trainingEVM=np.inf,
        meanTrainingEVM=np.nan,
        frameStartBase=np.nan,
        channelEstimate=[],
        equalizedPayload=[],
        decodedBits=[],
        firstFrameEVM=np.nan,
        perCarrierEVM=[],
        nFrames=0,
        acceptedFrames=0,
        rejectedFrames=0,
        nAttemptedBits=0,
        detectionFraction=np.nan,
        frameErrorRate=np.nan,
        frameResults=[],
        FsCapture=fs,
        FsDecoded=np.nan,
        resampleNumerator=np.nan,
        resampleDenominator=np.nan,
        resampleRateErrorPPM=np.nan,
        syncCandidatesExamined=0,
        indexBase=1,
    )


def decode(packet, y, FsCapture):
    """Synchronize using training only, decode every complete frame, pool BER."""
    y = _real_vector(y, "Capture")
    fs = float(FsCapture)
    if not np.isfinite(fs) or fs <= 0:
        raise ValueError("Capture sample rate must be finite and positive")
    r = _empty_result(fs)
    c = packet["cfg"]
    order = int(packet.get("payloadQAM", 4))
    r.update(
        payloadQAM=order,
        frameDuration=packet["frameDuration"],
        payloadRateIncludingTraining=packet["payloadBitCount"] / packet["frameDuration"],
    )
    if fs <= 2 * np.max(packet["activeFrequencyHz"]):
        r["reason"] = "Capture rate is at or below Nyquist for the highest active carrier."
        return r
    if np.max(y) == np.min(y):
        r["reason"] = "Capture is constant; no training signal is present."
        return r
    y -= y.mean()
    try:
        p, q = rate_ratio(packet["FsBase"], fs)
    except ValueError as failure:
        r["reason"] = str(failure)
        return r
    y = resample_matlab(y, p, q)
    r.update(
        resampleNumerator=p,
        resampleDenominator=q,
        FsDecoded=fs * p / q,
        resampleRateErrorPPM=1e6 * (fs * p / q / packet["FsBase"] - 1),
    )
    n, guard = int(packet["frameLengthBase"]), int(c["receiverEdgeGuardBase"])
    if len(y) < n + 2 * guard:
        r["reason"] = "Capture is too short for a complete frame plus receiver edge guards."
        return r
    score = synchronization_scores(y, packet)
    r["syncScore"] = float(score.max())
    if r["syncScore"] < c["minSyncScore"]:
        r["reason"] = "Training correlation is below the configured detection threshold."
        return r
    peaks = np.flatnonzero(
        (score >= np.r_[0.0, score[:-1]]) & (score > np.r_[score[1:], 0.0]) & (score >= c["minSyncScore"])
    )
    peaks = peaks[np.argsort(-score[peaks], kind="stable")][: int(c["maxSyncCandidates"])]
    r["syncCandidatesExamined"] = len(peaks)
    best_evm, anchor, anchor_score = np.inf, None, 0.0
    for start in peaks:
        _, _, evm = training_fit(y, int(start), packet)
        if evm < best_evm - 1e-8 or (abs(evm - best_evm) <= 1e-8 and score[start] > anchor_score):
            best_evm, anchor, anchor_score = evm, int(start), float(score[start])
    r["trainingEVM"] = best_evm
    if not np.isfinite(best_evm) or best_evm > c["maxTrainingEVM"]:
        r["reason"] = "Training consistency failed: noise, timing, fading or channel spread may be excessive."
        return r
    phase = anchor % n
    first_start = phase + math.ceil((guard - phase) / n) * n
    last_start = len(y) - guard - n
    starts = range(first_start, last_start + 1, n)
    r["nFrames"] = len(starts)
    r["nAttemptedBits"] = len(starts) * int(packet["payloadBitCount"])
    search = _integer(c.get("timingSearchBase", 32), "timingSearchBase")
    if search >= n / 2:
        raise ValueError("Timing search must be less than half a frame")
    error_energy = reference_energy = decision_error = training_evm_sum = 0.0
    carrier_error = np.zeros(len(packet["activeBins"]))
    carrier_reference = np.zeros_like(carrier_error)
    bad_payload = 0
    for expected in starts:
        lo, hi = max(guard, expected - search), min(last_start, expected + search)
        start = lo + int(np.argmax(score[lo : hi + 1]))
        local_score = float(score[start])
        fr = dict(
            expectedStart=expected + 1,
            start=start + 1,
            accepted=False,
            reason="",
            syncScore=local_score,
            trainingEVM=np.inf,
            bitErrors=np.nan,
            nBits=0,
            EVM=np.nan,
        )
        r["frameResults"].append(fr)
        if local_score < c["minSyncScore"]:
            fr["reason"] = "Training correlation below threshold."
            continue
        Y, H, evm = training_fit(y, start, packet)
        fr["trainingEVM"] = evm
        if not np.isfinite(evm) or evm > c["maxTrainingEVM"]:
            fr["reason"] = "Training consistency failed."
            continue
        Z = Y[:, int(c["nTraining"]) :] / H[:, None]
        bits = demodulate(Z, order)
        if bits.shape != packet["payloadBits"].shape:
            raise ValueError("Packet bit dimensions do not match its QAM order")
        nearest = modulate(bits, order)
        frame_error = np.sum(np.abs(Z - packet["payloadSymbols"]) ** 2, axis=1)
        frame_reference = np.sum(np.abs(packet["payloadSymbols"]) ** 2, axis=1)
        errors = int(np.count_nonzero(bits != packet["payloadBits"]))
        fr.update(
            bitErrors=errors,
            nBits=bits.size,
            EVM=float(np.sqrt(frame_error.sum() / frame_reference.sum())),
            accepted=True,
            reason="Training accepted; held-out payload evaluated.",
        )
        r["acceptedFrames"] += 1
        r["nBits"] += bits.size
        r["bitErrors"] += errors
        bad_payload += errors > 0
        carrier_error += frame_error
        carrier_reference += frame_reference
        error_energy += frame_error.sum()
        reference_energy += frame_reference.sum()
        decision_error += np.sum(np.abs(Z - nearest) ** 2)
        training_evm_sum += evm
        if r["acceptedFrames"] == 1:
            r.update(
                frameStartBase=start + 1,
                syncScore=local_score,
                trainingEVM=evm,
                channelEstimate=H,
                equalizedPayload=Z,
                decodedBits=bits,
                firstFrameEVM=fr["EVM"],
            )
    r["rejectedFrames"] = r["nFrames"] - r["acceptedFrames"]
    if r["nFrames"]:
        r["detectionFraction"] = r["acceptedFrames"] / r["nFrames"]
        r["frameErrorRate"] = (r["rejectedFrames"] + bad_payload) / r["nFrames"]
    if r["acceptedFrames"] == 0:
        r["bitErrors"] = np.nan
        r["reason"] = "No complete frame passed training checks on the periodic grid."
        return r
    r.update(
        BER=r["bitErrors"] / r["nBits"],
        EVM=float(np.sqrt(error_energy / reference_energy)),
        perCarrierEVM=np.sqrt(carrier_error / carrier_reference),
        decisionEVM=float(np.sqrt(decision_error / (r["acceptedFrames"] * packet["payloadSymbols"].size))),
        meanTrainingEVM=training_evm_sum / r["acceptedFrames"],
        accepted=True,
        reason=f"{r['acceptedFrames']}/{r['nFrames']} complete frames accepted using training only; payload errors pooled.",
        note="BER covers accepted payloads; rejected slots are separate failures. Repeated test data are not application goodput.",
    )
    return r


def awg_frame(packet):
    """Periodically interpolate one frame, normalize peaks, return signed DAC bytes."""
    c = packet["cfg"]
    interpolation = _integer(c["samplesPerSymbol"], "samplesPerSymbol", 1)
    if abs(c["FsAWG"] / c["FsBase"] - interpolation) >= 1e-10 * interpolation:
        raise ValueError("FsAWG/FsBase must equal samplesPerSymbol")
    x = _real_vector(packet["baseFrame"], "Base frame")
    if np.max(np.abs(x)) == 0:
        raise ValueError("Base frame is all zero")
    total = len(x) * interpolation
    if total > 32_000_000:
        raise ValueError("Interpolated frame exceeds 32 million sample limit")
    guard = 64
    padded = np.r_[x[np.arange(-guard, 0) % len(x)], x, x[np.arange(guard) % len(x)]]
    interpolated = resample_matlab(padded, interpolation, 1)
    waveform = np.real(interpolated[guard * interpolation : guard * interpolation + total])
    if len(waveform) != total or not np.all(np.isfinite(waveform)):
        raise ValueError("Unexpected interpolated waveform length or values")
    peak = np.max(np.abs(waveform))
    if peak <= 0:
        raise ValueError("Interpolation produced zero waveform")
    waveform /= peak
    return round_matlab(127 * waveform).astype(np.int8)
