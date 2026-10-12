"""
run.py - Database Acquisition Tool: launcher.

Measures the optical signal received by the photodetector over a 3D grid of positions
(gantry) and K orientations (MTRS) and stores everything in data/.

Usage (from the repository root, with the virtual environment active):
    python app/run.py            # real devices (config/testbed.toml)
    python app/run.py --sim      # all devices simulated (no hardware needed)
    python app/run.py --help

The user interface opens in the browser (http://127.0.0.1:8765):
  1. Configure the grid (start / end / step of X, Y, Z), the K MTRS angles, the LEDs to record,
     the record length, samples and passes.
  2. "Preview plan": shows the positions and the route, the number of measurements, the
     estimated duration and the disk space. Reconfigure as many times as needed.
  3. "Start": the photodetector follows the plan; every finished position is painted on the map.
     "Pause" (after the current measurement), "Resume" and "Stop" (immediate).

All the control runs in Python (engine.py); the web page only sends commands and shows the
state. Closing the browser does NOT stop the acquisition: just open the URL again.
To quit: Ctrl+C in this console (stops any motion and closes every device).

Device parameters live in config/testbed.toml; the defaults below only pre-fill the UI.
"""

import argparse
import os
import sys
import time
import webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                           # repository root
sys.path.insert(0, ROOT)
sys.path.insert(0, HERE)

from engine import Engine                   # noqa: E402
from hardware.testbed import Testbed        # noqa: E402
from server import make_server, serve_in_thread   # noqa: E402


# ============================================================
# APPLICATION SETTINGS
# ============================================================

DEVICE_MODE_OVERRIDE = {}            # e.g. {"gantry": "sim", "mtrs": "sim"}; empty = config file
HOST, PORT = "127.0.0.1", 8765       # address of the web interface
OPEN_BROWSER = True                  # open the browser on start
OUTPUT_ROOT = os.path.join(ROOT, "data")

# Initial values of the configuration panel (all of them can be changed in the UI)
DEFAULT_CONFIG = {
    "x": [100.0, 1300.0, 300.0],             # start, end, step [mm]
    "y": [100.0, 1300.0, 300.0],
    "z": [-300.0, -300.0, 100.0],            # Z = -700 highest PD position, Z = 0 the lowest
    "k_angles": 4,                           # K angles: (offset + 360*k/K) mod 360
    "angle_offset_deg": 65.0,                # orientation offset (K=4 -> 65, 155, 245, 335)
    "pd_tilt_deg": 15.0,                     # mechanical tilt of the 3D-printed mount (RECORDED ONLY)
    "n_samples": 1,                          # acquisitions per orientation (without moving)
    "n_passes": 1,                           # times the WHOLE route is repeated (variance per
                                             # point); odd passes run in the opposite direction
    "freqs_khz": [300.0, 500.0, 700.0, 900.0],   # LEDs recorded in points.csv
    "settle_s": 1.0,                         # wait after arriving, before measuring
    "record_ms": 100.0,                      # CONTINUOUS record per sample [ms]; 0 = use the
                                             # oscilloscope settings. Restored at the end
    "record_fs_msa": 10.0,                   # sample rate of the record [MSa/s]
                                             # (100 ms x 10 MSa/s = 1 M points; max 4 M)
    "scope_fft": False,                      # True: also read the oscilloscope FFT (+~1.4 s per
                                             # sample, records <= 62,500 points); False: Python FFT
    "serpentine_xy": True,                   # serpentine XY route
    "serpentine_angles": True,               # alternate angle order (no return to 0, cable safe)
    "save_waveforms": True,                  # save the raw waveform (wave/*.npz)
    "time_points": 8000000,                  # waveform points requested (8e6 = the whole record)
    "label": "",                             # optional suffix of the session folder name
}


def parse_args(argv=None):
    p = argparse.ArgumentParser(description="Database Acquisition Tool (gantry + MTRS + oscilloscope).")
    p.add_argument("--sim", action="store_true", help="simulate every device (no hardware needed)")
    p.add_argument("--host", default=HOST, help=f"interface address (default {HOST})")
    p.add_argument("--port", type=int, default=PORT, help=f"interface port (default {PORT})")
    p.add_argument("--no-browser", action="store_true", help="do not open the browser")
    p.add_argument("--output", default=OUTPUT_ROOT, help="folder for the sessions (default data/)")
    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    modes = dict(DEVICE_MODE_OVERRIDE)
    if args.sim:
        modes.update(gantry="sim", mtrs="sim", scope="sim")
    tb = Testbed(modes=modes)
    engine = server = None
    try:
        tb.connect()
        engine = Engine(tb, args.output, DEFAULT_CONFIG)
        engine.start_threads()
        server = make_server(engine, args.host, args.port)
        serve_in_thread(server)
        url = f"http://{args.host}:{server.server_address[1]}"
        print(f"\n[acq] Interface: {url}   (Ctrl+C here to quit)\n")
        if OPEN_BROWSER and not args.no_browser:
            webbrowser.open(url)
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\n[acq] Ctrl+C: stopping...")
    finally:
        if engine is not None:
            engine.shutdown()
        if server is not None:
            server.shutdown()
        tb.close()


if __name__ == "__main__":
    main()
