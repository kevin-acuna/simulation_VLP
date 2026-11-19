"""Simulated AWG + oscilloscope with the interface of instruments.Rig (try the software without hardware).

The AWG "plays" the prepared cycle (pilot tone slot + OFDM frames, the same samples as the real waveform at the
modem base rate). Each capture is a record of that cycle, starting at a random point, received with the
amplitude of a Lambertian LED seen by a tilted photodetector at the current gantry + MTRS pose, plus DC,
100 Hz ambient flicker and white noise, and quantized like the 8-bit oscilloscope (WORD codes, low byte 0).
"""

import math

import numpy as np

from . import processing
from .common import now_iso, save_record, validate_experiment

LED_MM = (700.0, 700.0, 2045.0)  # LED in the gantry frame (Z up; gantry Z = 0 -> PD about 0.955 m above the floor)
LAMBERTIAN_M = 6.0
PD_TILT_DEG = 15.0  # photodetector tilt on the MTRS; azimuth = MTRS rotation
PEAK_V_AT_1M = 0.03  # pilot peak amplitude [V] on axis at 1 m (about 10 mV at 1.75 m)
DC_V, FLICKER_V, NOISE_V = 0.30, 0.02, 4e-4  # PD DC level, 100 Hz flicker amplitude, white noise rms
SCOPE_V_DIV = 0.02  # vertical scale (8 divisions centred on the DC level)


def pd_amplitude(pos_mm, angle_deg, tilt_deg=0.0):
    """Peak amplitude [V] of the received pilot at a gantry position and MTRS rotation / tilt."""
    d = (np.asarray(LED_MM) - np.asarray(pos_mm, dtype=float)) / 1000.0
    dist = float(np.linalg.norm(d))
    u = d / dist
    t, a = math.radians(PD_TILT_DEG + tilt_deg), math.radians(angle_deg)
    n = np.array([math.sin(t) * math.sin(a), math.sin(t) * math.cos(a), math.cos(t)])
    cos_phi, cos_psi = u[2], float(n @ u)
    return PEAK_V_AT_1M * cos_phi**LAMBERTIAN_M * max(cos_psi, 0.0) / dist**2


class SimRig:
    def __init__(self, config, pose_fn=None, seed=None):
        self.config = dict(config)
        self.pose_fn = pose_fn or (lambda: ((700.0, 700.0, 300.0), 0.0, 0.0))
        self.rng = np.random.default_rng(seed)
        self.idn = {"awg": "SIMULATED,M8195A,0,0", "scope": "SIMULATED,MSO-X 4154A,0,0"}
        self.connection_errors = {"awg": [], "scope": []}
        self.connected, self.last_transmission, self._cycle = True, None, None

    def check(self, experiment):
        validate_experiment(experiment)
        print("Simulated AWG: profile ready (FOUR, DIV4, EXT, 16 GSa/s, 1 Vpp, other outputs off).")
        return dict(ready=True, modeReady=True, voltageReady=True, otherOutputsOff=True, fitsCurrentFreeMemory=True,
                    simulated=True, idn=self.idn["awg"], scopeIdn=self.idn["scope"])

    def transmit(self, experiment, folder=None, backup_dir=None):
        validate_experiment(experiment)
        plan, packet, core = experiment["plan"], experiment["packet"], experiment["cfg"]
        base = packet["FsBase"]
        n_tone = processing._round(plan["toneDuration_s"] * base)
        tone = np.sin(2 * np.pi * core["toneFrequencyHz"] * np.arange(n_tone) / base)
        self._cycle = np.r_[tone, np.tile(packet["baseFrame"], plan["communicationFrames"])]
        tx = dict(signature=experiment["signature"], simulated=True, reused=False, idn=self.idn["awg"],
                  Vpp=core["txVpp"], segment=1, totalSamples=plan["totalSamplesAWG"], plan=plan,
                  transmittedAt=now_iso(), savedPath="")
        if folder is not None:
            tx["savedPath"] = str(folder / "transmission.npz")
            save_record(tx["savedPath"], {"tx": tx, "experiment": experiment})
        self.last_transmission = tx
        print("Simulated AWG: combined pilot/OFDM waveform playing on channel 1.")
        return tx

    def capture(self, experiment):
        validate_experiment(experiment)
        tx = self.last_transmission
        if tx is None or tx["signature"] != experiment["signature"]:
            raise RuntimeError("Run transmit(experiment) successfully before capture.")
        cfg, base = experiment["config"], experiment["packet"]["FsBase"]
        n = int(cfg["scope_requested_points"])
        fs = n / (10 * cfg["scope_timebase_s_per_div"])
        pos, angle, tilt = self.pose_fn()
        amp = pd_amplitude(pos, angle, tilt or 0.0)
        count = int(math.ceil(n / fs * base)) + 64
        start = int(self.rng.integers(len(self._cycle)))
        idx = (start + np.arange(count)) % len(self._cycle)
        x = processing._resample(self._cycle[idx], fs, base)[:n]
        t = np.arange(n) / fs
        flicker = FLICKER_V * np.sin(2 * np.pi * 100.0 * t + self.rng.uniform(0, 2 * np.pi))
        y = DC_V + amp * x + flicker + self.rng.normal(scale=NOISE_V, size=n)
        y_inc, y_ref = 8 * SCOPE_V_DIV / 65536, 32768.0
        codes = np.clip(np.round((y - DC_V) / y_inc / 256) * 256 + y_ref, 256, 65280).astype(np.uint16)
        y = (codes - y_ref) * y_inc + DC_V
        preamble = dict(Format=1, Type=0, Points=n, Count=1, XIncrement=1 / fs, XOrigin=0.0, XReference=0.0,
                        YIncrement=y_inc, YOrigin=DC_V, YReference=y_ref)
        print(f"Simulated scope record: {n} samples, {fs / 1e6:.6g} MSa/s, pilot {amp / math.sqrt(2) * 1e3:.3f} mVrms.")
        return dict(YData=y, XData=t, codes=codes, FsCapture=fs, XIncrement=1 / fs, preamble=preamble,
                    preambleText=",".join(f"{v:.10g}" for v in preamble.values()), idn=self.idn["scope"],
                    channel=int(cfg["scope_channel"]), requestedPoints=n, actualPoints=n,
                    durationSeconds=(n - 1) / fs, peakToPeakVolts=float(np.ptp(y)),
                    timebase_sPerDiv=cfg["scope_timebase_s_per_div"], capturedAt=now_iso(),
                    experimentSignature=experiment["signature"], txMetadata=dict(tx), validForProcessing=True,
                    validationError="", status="Simulated record.", simulatedPilotVrms=amp / math.sqrt(2))

    def stop(self):
        self.last_transmission = None
        print("Simulated AWG: playback stopped; channel 1 output off.")

    def disconnect(self):
        if self.connected:
            self.stop()
        self.connected = False

    def scope_settings(self):
        return dict(channel=int(self.config["scope_channel"]), idn=self.idn["scope"], acquire_type="NORM",
                    timebase_s_div=self.config["scope_timebase_s_per_div"], ch_scale_V_div=SCOPE_V_DIV,
                    ch_offset_V=DC_V, ch_coupling="DC", ch_impedance="ONEM", ch_bw_limit=False, simulated=True)

    def recover(self):
        pass

    def close(self):
        self.connected = False
