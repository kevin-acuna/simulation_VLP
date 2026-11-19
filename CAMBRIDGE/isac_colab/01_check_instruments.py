"""
01_check_instruments.py - Step 1: checks VISA, the AWG and the oscilloscope (optionally the gantry and the MTRS).

READ ONLY: no reset, no waveform upload, no output change, no acquisition, no motion.
Replaces CHECK_PYTHON_VISA.cmd / START_ICS_KEYSIGHT_FIX.cmd of the ICS program (the Keysight DLL folder of
config/devices.toml [visa] is added inside Python).

    python 01_check_instruments.py

Before: Keysight M8195A soft front panel running, MATLAB / other programs disconnected from the AWG and the
oscilloscope. For the MTRS: homed in Kinesis, Kinesis closed. Gantry referenced in iRC.
"""

import platform
import sys

import numpy as np

from isac import load_devices
from isac.experiment import instrument_config
from isac.instruments import _profile, awg_snapshot, connect, open_resource_manager, read_scope_settings

# ============================================================
# HYPERPARAMETERS
# ============================================================
CHECK_GANTRY = False         # also connect the gantry (reads its position; no motion)
CHECK_MTRS = False           # also connect the MTRS (reads rotation / tilt; no motion)


def check_visa(cfg):
    print(f"Python {sys.version.split()[0]} ({platform.architecture()[0]}), {sys.executable}")
    rm = open_resource_manager(cfg)
    try:
        print(f"VISA library: {rm.visalib}")
        print("VISA resources:", *rm.list_resources("?*::INSTR"), sep="\n  ")
    finally:
        rm.close()


def check_awg_scope(cfg):
    rig = connect(cfg)
    try:
        s = awg_snapshot(rig.awg)
        mode, voltage, others_off = _profile(s, cfg)
        print("\nAWG (M8195A)")
        print(f"  DAC mode {s['dacMode']}, divider {s['divider']}, CH1 memory {s['memoryModes'][0]}, "
              f"raster {s['rasterRate'] / 1e9:g} GSa/s -> profile OK: {mode}")
        print(f"  CH1 {s['Vpp']:g} Vpp, offset {s['offset']:g} V -> OK: {voltage}")
        print(f"  outputs 1-4: {[int(v) for v in s['outputs']]} -> outputs 2-4 off: {others_off}")
        free = s["freeMemory"][0, 2]
        print(f"  CH1 segments [id, samples]: {s['catalogs'][0]}"
              + (f"; contiguous free memory {free / 1e6:.1f} MB" if np.isfinite(free) else ""))
        print(f"  reference clock {s['referenceClock']}, function mode {s['functionMode']}")
        sc = read_scope_settings(rig.scope, cfg["scope_channel"])
        print("\nOscilloscope (MSO-X 4154A)")
        print(f"  timebase {1e3 * sc['timebase_s_div']:g} ms/div ({sc['timebase_mode']}), acquisition "
              f"{sc['acquire_type']}, trigger sweep {sc['trigger_sweep']}")
        print(f"  channel {sc['channel']}: {1e3 * sc['ch_scale_V_div']:g} mV/div, offset {sc['ch_offset_V']:g} V, "
              f"coupling {sc['ch_coupling']}, impedance {sc['ch_impedance']}, BW limit "
              f"{'ON' if sc['ch_bw_limit'] else 'OFF'}, probe {sc['ch_probe']:g}:1")
        ready = mode and voltage and others_off
        print(f"\nAWG profile ready for the ISAC waveform: {ready}"
              + ("" if ready else "  (set it in the M8195A soft front panel: FOUR, DIV4, CH1 EXT, 1 Vpp, 0 V, "
                                  "outputs 2-4 off)"))
    finally:
        rig.close()          # only closes the connections: the AWG output is not touched


def check_motion(devices):
    from hardware.testbed import Testbed

    tb = Testbed(modes=devices["modes"])
    devs = [d for d, on in ((tb.gantry, CHECK_GANTRY), (tb.mtrs, CHECK_MTRS)) if on]
    try:
        for d in devs:
            d.connect()
            tb._connected.append(d)
        if CHECK_GANTRY:
            print(f"Gantry position: {tb.gantry.state()['pos']}")
        if CHECK_MTRS:
            print(f"MTRS rotation {tb.mtrs.angle_deg():.3f} deg, tilt {tb.mtrs.tilt_deg():.3f} deg")
    finally:
        tb.close()


def main():
    devices = load_devices()
    cfg = instrument_config(devices)
    check_visa(cfg)
    check_awg_scope(cfg)
    if CHECK_GANTRY or CHECK_MTRS:
        check_motion(devices)
    print("\nCheck finished. Nothing was changed.")


if __name__ == "__main__":
    main()
