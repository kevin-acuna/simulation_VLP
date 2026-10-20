"""
run.py - VLP Positioning Demo: launcher.

The gantry moves the photodetector to a random position (or one chosen in the interface), the MTRS
turns it to K orientations, the RSS of the LED is recorded at each one and the 3D position is
estimated and compared with the true one. It goes on to the next point until Stop. Every orientation
is also saved as in database_acquisition (random-position database).

Usage (from the demo folder, with the database_acquisition virtual environment active):
    python app/run.py            # real devices (database_acquisition/config/testbed.toml)
    python app/run.py --sim      # all devices simulated, signal from the positioning model
    python app/run.py --help

Interface: http://127.0.0.1:8766 (8765 is the Database Acquisition Tool).
Positioning hyperparameters (PD model, estimator, LED, calibration, geometry): config/demo.toml.
"""

import argparse
import os
import sys
import threading
import time
import webbrowser
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from settings import DEMO_ROOT, add_import_paths, load_settings   # noqa: E402

SETTINGS = load_settings()
add_import_paths(SETTINGS)

from engine import DemoEngine                    # noqa: E402
from hardware.testbed import Testbed             # noqa: E402
from positioner import Positioner                # noqa: E402
from server import make_server, serve_in_thread  # noqa: E402

# ============================================================
# APPLICATION SETTINGS
# ============================================================
HOST, PORT = "127.0.0.1", 8766
OPEN_BROWSER = True
LOG_DIR = os.path.join(DEMO_ROOT, "logs")

# Initial values of the configuration panel (all of them can be changed in the interface)
DEFAULT_CONFIG = {
    "mode": "random",                       # "random" | "manual"
    "region_x": [100.0, 1300.0],            # random positions [mm, gantry]
    "region_y": [100.0, 1300.0],
    "region_z": [-600.0, 0.0],              # -700 = highest PD position, 0 = lowest
    "k_angles": 5,
    "n_samples": 1,
    "settle_s": 1.0,
    "record_ms": 100.0,
    "record_fs_msa": 10.0,
    "freqs_khz": [300.0, 500.0, 700.0, 900.0],
    "save_waveforms": True,
    "max_points": 0,                        # 0 = until Stop
    "label": "",
}


class _Tee:
    """Writes to the console and, with a timestamp per line, to the log file."""

    def __init__(self, stream, logfile, lock):
        self.stream, self.logfile, self.lock, self._bol = stream, logfile, lock, True

    def write(self, s):
        self.stream.write(s)
        with self.lock:
            for line in s.splitlines(keepends=True):
                if self._bol:
                    self.logfile.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} ")
                self.logfile.write(line)
                self._bol = line.endswith("\n")
            self.logfile.flush()
        return len(s)

    def flush(self):
        self.stream.flush()
        self.logfile.flush()

    def __getattr__(self, name):
        return getattr(self.stream, name)


def start_log():
    os.makedirs(LOG_DIR, exist_ok=True)
    path = os.path.join(LOG_DIR, f"demo_{datetime.now():%Y%m%d_%H%M%S}.log")
    f = open(path, "a", encoding="utf-8")
    lock = threading.Lock()
    sys.stdout, sys.stderr = _Tee(sys.stdout, f, lock), _Tee(sys.stderr, f, lock)
    print(f"[demo] Log file: {path}")


def parse_args(argv=None):
    p = argparse.ArgumentParser(description="VLP Positioning Demo (gantry + MTRS + oscilloscope).")
    p.add_argument("--sim", action="store_true", help="simulate every device (no hardware needed)")
    p.add_argument("--host", default=HOST)
    p.add_argument("--port", type=int, default=PORT)
    p.add_argument("--no-browser", action="store_true", help="do not open the browser")
    p.add_argument("--output", default=SETTINGS["paths"]["output_root"], help="folder for the sessions")
    p.add_argument("--no-log", action="store_true", help="do not write logs/demo_<date>.log")
    return p.parse_args(argv)


def build_testbed(sim, positioner):
    modes = {"mtrs_optional": False}             # the demo needs the MTRS to reorient the photodetector
    if sim:
        modes.update(gantry="sim", mtrs="sim", scope="sim", sim_speedup=SETTINGS["sim"].get("speedup", 4.0))
    tb = Testbed(modes=modes)
    if tb.modes.get("scope") == "sim":           # signal consistent with the positioning model
        from sim_scope import DemoSimScope
        tb.scope = DemoSimScope(positioner, SETTINGS["sim"], SETTINGS["positioning"]["led_frequency_khz"],
                                pose_fn=tb._sim_pose, **tb.cfg["scope"])
    return tb


def main(argv=None):
    args = parse_args(argv)
    if not args.no_log:
        start_log()
    positioner = Positioner.from_settings(SETTINGS)
    d = positioner.describe()
    print(f"[demo] Positioning: {d['pd_response']}, {d['estimator']}; LED at "
          f"({1e3 * d['led_position_m'][0]:.1f}, {1e3 * d['led_position_m'][1]:.1f}) mm, "
          f"m = {d['led_m']:.3f}; settings {SETTINGS['_path']}")
    tb = build_testbed(args.sim, positioner)
    engine = server = None
    try:
        tb.connect()
        if not tb.has_mtrs:
            raise RuntimeError("The demo needs the MTRS (config/testbed.toml [modes] mtrs = 'none').")
        engine = DemoEngine(tb, positioner, SETTINGS, args.output, DEFAULT_CONFIG)
        engine.start_threads()
        server = make_server(engine, args.host, args.port)
        serve_in_thread(server)
        url = f"http://{args.host}:{server.server_address[1]}"
        print(f"\n[demo] Interface: {url}   (Ctrl+C here to quit)\n")
        if OPEN_BROWSER and not args.no_browser:
            webbrowser.open(url)
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\n[demo] Ctrl+C: stopping...")
    finally:
        if engine is not None:
            engine.shutdown()
        if server is not None:
            server.shutdown()
        tb.close()


if __name__ == "__main__":
    main()
