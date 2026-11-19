"""
02_single_capture.py - Step 2: one ISAC measurement at the current PD pose (no gantry / MTRS motion).

The same sequence that was typed by hand in the ICS console, in one script:
    prepare -> connect -> check -> transmit (or reuse the waveform already in the AWG) -> capture -> process
and the ICS summary is printed (ToneRMS_mV, OriginalBER, AveragedBER, frames, CombinedCriteriaMet).
Use it to confirm that the results match the ICS / MATLAB test before running 03_isac_acquisition.py.

    python 02_single_capture.py            real AWG + oscilloscope (config/devices.toml)
    python 02_single_capture.py --sim      simulated AWG + oscilloscope

Output: data/isac_<date>_single/ (same files as 03_isac_acquisition.py, see isac/storage.py), including
figures/cNNNNN.png: PD record (pilot windows / OFDM slots), its spectrum and the OFDM constellation.
"""

import sys
import time
from pathlib import Path

import isac
from isac.plotting import save_capture_figure
from isac.storage import Session, isac_tables

# ============================================================
# HYPERPARAMETERS
# ============================================================
# ISAC waveform and capture = ICS config.py of the successful test (13/11/2026). After a change the waveform
# is uploaded again (the AWG keeps the previous one only if it is identical).
ISAC = dict(
    pilot_frequency_hz=500e3,          # pilot tone (positioning)
    pilot_measurement_s=10e-3,         # pilot observation window
    pilot_lead_s=1e-3,                 # settling before the window   -> tone slot = 1 + 10 + 1 = 12 ms
    pilot_tail_s=1e-3,                 # guard after the window
    ofdm_duration_s=10e-3,             # rounded UP to whole OFDM frames (15 frames = 10.4448 ms)
    qam_order=64,                      # 4, 16, 64 or 256
    ber_target=1e-3,
    training_average=True,             # also report the training-averaged BER
    scope_timebase_s_per_div=10e-3,    # 10 ms/div -> 100 ms record
    scope_requested_points=2_000_000,  # -> 20 MSa/s
    scope_min_sample_rate_hz=5e6,
    capture_target_s=100e-3,
    minimum_complete_cycles=2,
)
N_CAPTURES = 1                         # consecutive captures (same pose)
STOP_AWG_AT_END = True                 # True: playback stopped + output 1 off at the end; False: keeps playing
SAVE_FIGURES = True                    # figures/cNNNNN.png of every capture (record, spectrum, constellation)
SHOW_PLOT = True                       # show the figure of the last capture at the end
LABEL = "single"                       # appended to the session folder name
OUTPUT_ROOT = Path(__file__).resolve().parent / "data"


def main(sim=False):
    devices = isac.load_devices(sim=sim)
    cfg = isac.make_config(ISAC, devices)
    experiment = isac.prepare(cfg)
    print(isac.describe(experiment))
    session = Session(OUTPUT_ROOT, LABEL, {"script": Path(__file__).name, "isac": ISAC,
                                           "n_captures_planned": N_CAPTURES, "devices": devices})
    session.save_experiment(experiment)
    print(f"Session: {session.dir}")
    rig = isac.open_rig(cfg, devices)
    state, status, started = None, "error", False
    try:
        report = rig.check(experiment)
        if not report["ready"]:
            raise RuntimeError("AWG not ready (mode {modeReady}, voltage {voltageReady}, other outputs off "
                               "{otherOutputsOff}, memory {fitsCurrentFreeMemory}): see 01_check_instruments.py"
                               .format(**report))
        session.write_meta(scope_settings=rig.scope_settings())
        started = True
        tx = rig.transmit(experiment, session.dir, backup_dir=OUTPUT_ROOT / "awg_backups")
        session.write_meta(instruments=rig.idn, transmission={k: tx.get(k) for k in ("reused", "transmittedAt", "Vpp")})
        for i in range(N_CAPTURES):
            capture = rig.capture(experiment)
            unix = time.time()
            state = isac.process(capture, experiment)
            print(f"\nCapture {i + 1}/{N_CAPTURES}")
            isac.print_summary(state)
            row, windows, slots = isac_tables(state)
            cid = session.add({**row, "mode": "single", "unix_time_s": round(unix, 3)}, capture, windows, slots)
            session.write_excel()
            if SAVE_FIGURES:
                print(f"Figure: {save_capture_figure(state, session.figure_path(cid), f'{session.dir.name}  capture {cid}')}")
        status = "done"
    except KeyboardInterrupt:
        status = "interrupted"
        print("\nInterrupted.")
    finally:
        rig.disconnect() if STOP_AWG_AT_END and started else rig.close()
        session.close(status)
        print(f"Saved: {session.dir}")
    if SHOW_PLOT and state is not None:
        import matplotlib.pyplot as plt
        from isac.plotting import show_capture

        show_capture(state, session.dir.name)
        plt.show()


if __name__ == "__main__":
    main(sim="--sim" in sys.argv[1:])
