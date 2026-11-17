"""Edit these settings. Importing this file never opens an instrument."""
from pathlib import Path

def get_config():
    return {
        # Complete resource strings, not MATLAB's display names.
        "awg_address": "TCPIP0::localhost::inst0::INSTR",
        "scope_address": "USB0::0x0957::0x17BC::MY63420113::0::INSTR",
        "visa_library": "@ivi",  # Installed Keysight/IVI VISA, not pyvisa-py.
        # Main experiment variables; prepare + transmit again after changes.
        "pilot_frequency_hz": 500e3,
        "pilot_measurement_s": 10e-3,
        "pilot_lead_s": 1e-3,
        "pilot_tail_s": 1e-3,
        "ofdm_duration_s": 10e-3,  # Rounded UP to complete OFDM frames.
        "qam_order": 64,
        "ber_target": 1e-3,
        "training_average": True,
        # Preserve the lab-validated physical profile.
        "awg_sample_rate_hz": 16e9,
        "awg_vpp": 1.0,
        "awg_offset_v": 0.0,
        "awg_channel": 1,
        "scope_channel": 1,
        "awg_timeout_s": 60.0,
        "scope_timeout_s": 30.0,
        "upload_chunk_samples": 512000,
        "scope_timebase_s_per_div": 10e-3,  # Explicit working 10 ms/div.
        "scope_requested_points": 2000000,
        "scope_min_sample_rate_hz": 5e6,
        "capture_target_s": 100e-3,
        "minimum_complete_cycles": 2,
        "max_waveform_samples": 1000000000,
        "backup_existing": True,
        "output_dir": str(Path(__file__).resolve().parent / "results_python"),
    }
