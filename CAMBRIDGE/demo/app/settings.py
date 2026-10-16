"""
settings.py - Hyperparameters of the demo (config/demo.toml) and paths.

The positioning hyperparameters (PD model, estimator, LED, calibration, geometry) are NOT shown in
the interface: edit config/demo.toml. Device parameters stay in database_acquisition/config/testbed.toml.
"""

import os
import sys
import tomllib

DEMO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(DEMO_ROOT, "config", "demo.toml")


def load_settings(path=None):
    with open(path or CONFIG_PATH, "rb") as f:
        s = tomllib.load(f)
    s["_path"] = os.path.abspath(path or CONFIG_PATH)
    s["paths"]["hardware_root"] = resolve(s["paths"]["hardware_root"])
    s["paths"]["output_root"] = resolve(s["paths"]["output_root"])
    return s


def resolve(path):
    """Paths in demo.toml are relative to the demo folder."""
    return path if os.path.isabs(path) else os.path.normpath(os.path.join(DEMO_ROOT, path))


def add_import_paths(settings):
    """Makes `vlp` (demo root) and `hardware` (database_acquisition) importable."""
    for p in (settings["paths"]["hardware_root"], DEMO_ROOT):
        if p not in sys.path:
            sys.path.insert(0, p)
