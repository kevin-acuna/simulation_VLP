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

## Verification
- No hardware: run experiments/drivers with `DEVICE_MODE` = sim (Agg backend for headless tests).
- `python -m py_compile` on changed files; real-device tests only with the user's consent (physical motion).
