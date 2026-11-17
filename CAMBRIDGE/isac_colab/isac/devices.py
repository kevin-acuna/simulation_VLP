"""config/devices.toml and the AWG + oscilloscope rig (real or simulated)."""

import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEVICES_PATH = ROOT / "config" / "devices.toml"


def load_devices(sim=False, path=None):
    """Device configuration; sim=True sets every device to the simulated mode."""
    with open(path or DEVICES_PATH, "rb") as f:
        devices = tomllib.load(f)
    if sim:
        devices["modes"].update(gantry="sim", mtrs="sim", isac="sim")
    return devices


def open_rig(cfg, devices, pose_fn=None):
    """Connected AWG + oscilloscope: instruments.Rig (VISA) or sim.SimRig (pose_fn -> pose of the PD)."""
    if devices["modes"].get("isac", "real") == "sim":
        from .sim import SimRig

        return SimRig(cfg, pose_fn)
    from .instruments import connect

    return connect(cfg)
