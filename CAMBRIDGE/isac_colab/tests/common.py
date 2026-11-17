"""Shared test configuration: the ISAC values of the ICS config.py (successful test, 13/11/2026)."""

import isac

ISAC = dict(pilot_frequency_hz=500e3, pilot_measurement_s=10e-3, pilot_lead_s=1e-3, pilot_tail_s=1e-3,
            ofdm_duration_s=10e-3, qam_order=64, ber_target=1e-3, training_average=True,
            scope_timebase_s_per_div=10e-3, scope_requested_points=2_000_000, scope_min_sample_rate_hz=5e6,
            capture_target_s=100e-3, minimum_complete_cycles=2)


def get_config(**changes):
    """Flat ICS-style configuration (same keys and values as the ICS config.py, without output_dir)."""
    return isac.make_config({**ISAC, **changes}, isac.load_devices())
