"""Demonstrate the complete receiver and exports using synthetic samples only."""
from config import get_config
from ics import prepare, process, export_pilot, pilot_fft
from tests.test_processing import synthetic_capture
cfg = get_config()
experiment = prepare(cfg)
record = synthetic_capture(experiment["packet"], experiment["cfg"], fs=20e6)
record.update(experimentSignature=experiment["signature"], validForProcessing=True)
result = process(record, experiment, 1)
pilot = export_pilot(result)
spectrum = pilot_fft(pilot)
print("SYNTHETIC DEMONSTRATION ONLY. No hardware was connected.")
