# Cambridge testbed - implementation (Python)

Environment: `implementation/.venv` (Python 3.13; pythonnet, pyvisa, numpy, matplotlib/TkAgg, cri_lib 0.4.0).
Code comments are in Spanish, but GUI text, console messages and exceptions in `hardware/` and
`experiments/` are in English. Hyperparameters go in a commented block at the top of each script.
Studied frequencies for exp01 are `FREQUENCIES_KHZ` (points.csv gets per-frequency columns
`<f>kHz_fft_<units>` from the scope FFT and `<f>kHz_wave_Vrms` from the raw waveform). The scope FFT
bin can be much wider than `led_freq_band_hz` (610 Hz measured at 700 kHz), so `fft_peak` searches at
least +/-1.5 bins.

## Layout
- `config/testbed.toml`: the ONLY place for device parameters (IP, workspace, speeds, tolerances,
  serials, scope address/channel, LED frequency source, real/sim modes, motion wait policy, view
  orientation). Configured once by the investigator; experiments must not duplicate these values.
- `hardware/testbed.py`: `Testbed` reads the config, builds real or simulated devices, connects/closes
  them (context manager) and provides joint methods: `pose`, `check_pose`, `move_to_pose`, `wait_pose`
  (raises `Stopped`/`TimeoutError`/`RuntimeError` and stops the devices), `go_to_pose`, `stop`, `info`.
  `Testbed(devices=(...), modes={...})` selects a subset or overrides modes.
- `hardware/{gantry,mtrs,scope}.py`: drivers; shared logic lives in `GantryBase`/`MTRSBase`/`ScopeBase`
  (`arrived`, `outside_workspace`, `valid_angle`, `led_frequency`, `led_peak`), which `sim.py` reuses.
  Constructor parameter names equal the TOML keys (`Gantry(**cfg["gantry"])`).
- `basic_tests/{GANTRY,MTRS,SCOPE}`: standalone per-device tests (run from their folder; independent of config).
- `experiments/exp01_point_acquisition.py`: GUI point-by-point acquisition; only experiment parameters
  at the top (`DEVICE_MODE_OVERRIDE`, settle time, acquisitions...). Output: `data/exp01/exp01_<date>/`.
- `experiments/exp02_database/`: database acquisition (XYZ grid x K MTRS angles theta_k = 360k/K).
  `exp02_database.py` (entry, defaults at the top) starts `Testbed`, `engine.Engine` (plan, threads for
  telemetry / scope / runner, pause-resume-stop, auto-pause on errors, saving) and `server.py` (stdlib
  HTTP + Server-Sent Events on 127.0.0.1:8765). `web/` is a no-build HTML/CSS/JS UI that only sends
  commands; all control and rigor stay in Python. pyvisa is used only from the scope thread
  (`Engine.scope_call`). `pd_tilt_deg` is metadata of the 3D-printed mount: never sent to the MTRS (its
  tilt stays at `tilt_target_deg` = 0). Output `data/exp02/exp02_<date>[_label]/`: points.csv (compact,
  one row per measurement), plan.csv, trajectory.csv, fft/mNNNNN.csv, wave/mNNNNN.npz, session.json, README.txt.
  The plan is compact (sites list + `plan_measurement(plan, i)`, no per-measurement dicts) so plans of
  10^5-10^6 measurements work; `MAX_MEASUREMENTS` (5e6) is only a memory guard, long plans get a warning.
  Time estimate (`estimate_times`) uses the NOMINAL speeds from testbed.toml (sim devices are sped up by
  `sim_speedup`) and constants calibrated on real data: MTRS trapezoid 1.5 deg/s, 1.5 deg/s2 (72 deg = 49.1 s);
  gantry 50 mm/s with ~250 mm/s2 effective (100 mm = 2.2 s); 1.25 s per acquisition + 0.15 s saving.
  UI: light, plain style (university tool, title "Database Acquisition Tool"); the configuration panel is
  a collapsible sidebar (button at the top left); Start/Pause/Stop stay in the header; Top view / 3D view
  (orbit, wheel zoom, double-click reset). UI screenshot without hardware: run with all-sim modes and
  `msedge --headless=new --screenshot=... "http://127.0.0.1:8765/?snapshot=1&view=3d&config=0&color=500kHz"`
  (`?snapshot` avoids the never-ending SSE stream).

## Hardware facts (verified)
- Gantry igus DLE-RG-0012-BLDC at 192.168.3.11:3920 (PC 192.168.3.100/24); iRC simulator 127.0.0.1:3921.
  Real controller firmware V980-14-003-3 (simulator V980-14-004-4): Move Cart acceleration parameter
  needs >= V14-004-1, so it is omitted on the real robot. Cartesian Z = -A3: Z = 0 top, negative downwards;
  workspace used X,Y in [0,1400], Z in [-700,0]. cri_lib hard-codes a 0.1 s connect timeout and the first
  TCP connect can take ~1 s -> always retry connect with a new CRIController. The simulator reports
  E-stop not OK (normal). A started Move Cart completes even if the CRI connection drops.
- MTRS = Kinesis DeviceType 117 -> `BenchtopDCServo` (not BenchtopStepperMotor); channels "MTRS Rotate"/"MTRS Tilt",
  possibly different serials. Rotation max 1.5 deg/s. Homing is done in Kinesis; Kinesis must be closed before
  connecting. LinearRange mode keeps rotation in [0,360] so the PD cable never winds.
- Scope is an Agilent MSO-X 4154A (not the MSOX6004A). Never send *RST/:AUToscale (its WGEN drives the LED).
  Scope FFT = Math function `:FUNCtion<m>:OPERation FFT`, read via `:WAVeform:SOURce FUNCtion<m>` (x in Hz).
  VISA may list the serial in lowercase; `VI_ERROR_NCIC` on open means another program holds the instrument.
  Measured 2026-10-09: waveform record = 10 x timebase (51 us/div -> 10200 samples at 20 MSa/s, even if more
  points are requested); the scope FFT = Hanning over that record zero-padded to 32768 points (bin 610.35 Hz,
  true resolution ~2-3.7 kHz); FFT span/center only select the displayed/downloaded bins. One synchronized
  acquisition (:DIGitize + FFT + waveform) takes ~1.05 s. The lab has 4 LEDs at 300/500/700/900 kHz (WGEN = 700 kHz).
  `SimScope` emulates this (4 Lambertian LEDs, same FFT format).

## Verification
- No hardware: run experiments/drivers with `DEVICE_MODE` = sim (Agg backend for headless tests).
- `python -m py_compile` on changed files; real-device tests only with the user's consent (physical motion).
