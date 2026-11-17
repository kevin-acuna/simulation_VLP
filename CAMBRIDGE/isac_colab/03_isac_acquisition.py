"""
03_isac_acquisition.py - Step 3: ISAC database acquisition with the gantry + MTRS (GUI).

At every gantry position the MTRS is turned to K orientations; at every pose the PD output is captured while the
AWG plays the combined waveform (pilot tone slot + OFDM slot, repeated) and the capture is processed like the
ICS program: pilot tone RMS (Vrms) of every pilot window and OFDM communication (BER, training-averaged BER, EVM,
frames). Only data registration: no position is estimated.

    python 03_isac_acquisition.py          real devices (config/devices.toml)
    python 03_isac_acquisition.py --sim    simulated gantry, MTRS, AWG and oscilloscope

GUI: "Start plan" runs the plan below (Pause / Resume / Skip / STOP; STOP keeps the position in the plan, which
can then be continued). "Go & measure" moves to the typed X, Y, Z [mm] and rotation [deg] and measures;
"Measure here" measures without moving. Instrument or motion errors pause the plan (Resume retries, Skip records
the measurement as failed). Closing the window ends the session.

Output: data/isac_<date>_<plan>[_<label>]/ (results.xlsx, CSV tables, raw records; see isac/storage.py).

Before: AWG profile ready (01_check_instruments.py), oscilloscope with the working vertical / trigger settings,
gantry referenced in iRC, MTRS homed in Kinesis and Kinesis closed. Only the ISAC LED should be modulated: the
OFDM carriers span ~305-794 kHz and the pilot quality check uses 200-900 kHz.
"""

import sys
from pathlib import Path

import matplotlib.pyplot as plt

import isac
from acquisition.engine import Engine
from acquisition.gui import GUI
from acquisition.plan import check_plan, grid_sites, make_plan, orientation_angles, plan_label
from hardware.testbed import Testbed
from isac.storage import Session

# ============================================================
# HYPERPARAMETERS
# ============================================================
# --- ISAC waveform and capture: ICS config.py of the successful test (13/11/2026) ---
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

# --- Plan: gantry sites [mm] (X, Y, Z grid, or an explicit list) ---
X_MM = [100.0, 400.0, 700.0, 1000.0, 1300.0]
Y_MM = [100.0, 400.0, 700.0, 1000.0, 1300.0]
Z_MM = [180.0]
SITES_MM = []                          # explicit [(x, y, z), ...] used instead of the grid when not empty
SERPENTINE_XY = True                   # serpentine route over the grid

# --- MTRS orientations at every site ---
K_ORIENTATIONS = 5                     # theta_k = (ANGLE_OFFSET_DEG + 360 k / K) mod 360
ANGLE_OFFSET_DEG = 0.0
ALTERNATE_ANGLE_ORDER = True           # increasing angles at one site, decreasing at the next
MTRS_TILT_DEG = 0.0                    # motorized MTRS tilt (+/-3 deg), commanded again at every new site
PD_TILT_DEG = 0.0                      # tilt of the 3D-printed PD adapter (metadata only)

# --- Measurement ---
N_CAPTURES = 1                         # captures per pose (100 ms each, ~3 pilot windows + ~45 OFDM frames)
SETTLE_TIME_S = 1.0                    # wait after arrival before capturing (vibrations)
LABEL = ""                             # appended to the session folder name
AWG_OFF_AT_EXIT = True                 # stop the playback and turn output 1 off when the program ends
GUI_REFRESH_MS = 100
OUTPUT_ROOT = Path(__file__).resolve().parent / "data"


def build_plan():
    grid = None if SITES_MM else (X_MM, Y_MM, Z_MM)
    sites = [tuple(map(float, s)) for s in SITES_MM] if SITES_MM else grid_sites(X_MM, Y_MM, Z_MM, SERPENTINE_XY)
    angles = orientation_angles(K_ORIENTATIONS, ANGLE_OFFSET_DEG)
    plan = make_plan(sites, angles, N_CAPTURES, MTRS_TILT_DEG, ALTERNATE_ANGLE_ORDER)
    return plan, angles, plan_label(sites, angles, N_CAPTURES, grid)


def hyperparameters():
    return {k: v for k, v in globals().items() if k.isupper() and isinstance(v, (int, float, str, list, dict, Path))}


def main(sim=False):
    devices = isac.load_devices(sim=sim)
    cfg = isac.make_config(ISAC, devices)
    experiment = isac.prepare(cfg)
    print(isac.describe(experiment))
    plan, angles, label = build_plan()
    tb = Testbed(modes=devices["modes"])

    def pd_pose():                     # pose seen by the simulated oscilloscope
        p = tb.pose()
        return p["pos"], p["angle"], p["tilt"]

    rig = session = engine = None
    status, started = "error", False
    try:
        tb.connect()
        problems = check_plan(plan, tb)
        if problems:
            raise ValueError("Plan outside the limits: " + "; ".join(problems[:10]))
        print(f"Plan: {len(plan)} measurements ({len({m['site_id'] for m in plan})} sites x {len(angles)} "
              f"orientations x {N_CAPTURES} captures); angles {angles} deg.")
        session = Session(OUTPUT_ROOT, "_".join(p for p in (label, LABEL) if p),
                          {"script": Path(__file__).name, "hyperparameters": hyperparameters(), "angles_deg": angles,
                           "n_plan": len(plan), "devices": devices, "testbed": tb.info(),
                           "waveform": isac.describe(experiment)})
        session.save_experiment(experiment)
        print(f"Session: {session.dir}")
        rig = isac.open_rig(cfg, devices, pd_pose)
        report = rig.check(experiment)
        if not report["ready"]:
            raise RuntimeError("AWG not ready (mode {modeReady}, voltage {voltageReady}, other outputs off "
                               "{otherOutputsOff}, memory {fitsCurrentFreeMemory}): see 01_check_instruments.py"
                               .format(**report))
        started = True
        tx = rig.transmit(experiment, session.dir, backup_dir=OUTPUT_ROOT / "awg_backups")
        session.write_meta(instruments=rig.idn, transmission={k: tx.get(k) for k in ("reused", "transmittedAt", "Vpp")})
        engine = Engine(tb, rig, experiment, session, plan, SETTLE_TIME_S, N_CAPTURES, MTRS_TILT_DEG,
                        backup_dir=OUTPUT_ROOT / "awg_backups")
        engine.start()
        engine._set(status=f"Ready: {len(plan)} plan measurements. 'Start plan', or type a pose and 'Go & measure'.")
        gui = GUI(engine, GUI_REFRESH_MS, f"ISAC acquisition - {session.dir.name}")
        plt.show()
        gui.timer.stop()
        status = f"closed ({engine.next_index}/{len(plan)} plan measurements done)"
    except KeyboardInterrupt:
        status = "interrupted"
        print("\nInterrupted.")
    finally:
        if engine is not None:
            engine.shutdown()
        if rig is not None:
            rig.disconnect() if AWG_OFF_AT_EXIT and started else rig.close()
        tb.close()
        if session is not None:
            session.close(status)
            print(f"Saved: {session.dir}")


if __name__ == "__main__":
    main(sim="--sim" in sys.argv[1:])
