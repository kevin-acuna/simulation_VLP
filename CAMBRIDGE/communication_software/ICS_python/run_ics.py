"""Launch with python -i run_ics.py; then issue one command at a time."""
from config import get_config
from ics import (prepare, connect, check, transmit, capture, process, print_summary,
                 export_pilot, pilot_fft, scan, stop, disconnect, replay,
                 replay_matlab_reference, load_record)
cfg = get_config()
print("ICS Python: configuration loaded; NO instruments connected or started.")
print("Run one command at a time:")
print("  experiment = prepare(cfg)")
print("  rig = connect(cfg)")
print("  status = check(rig, experiment)")
print("  print(status['ready'])  # Continue only if True")
print("  tx = transmit(rig, experiment)")
print("  record = capture(rig, experiment)")
print("  result = process(record, experiment, 1)")
print("  pilot = export_pilot(result)")
print("  spectrum = pilot_fft(pilot)")
print("  scan_result = scan(rig, experiment)  # Five NEW stopped orientations")
print("  disconnect(rig)  # Stop output and release owned connections when done")
