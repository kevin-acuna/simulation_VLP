# Cambridge testbed - implementation (Python)

This file lives in `CAMBRIDGE/` on purpose: it must NOT be inside the released repository.
Two folders (the old `CAMBRIDGE/implementation/` was split on 2026-10-12):
- `CAMBRIDGE/database_acquisition/`: standalone repository (own GitHub later) shared with the research
  group. Contents: README.md, requirements.txt, .gitignore (generic only: Python, .venv, data/, editors -
  never list private files there), `app/` (the tool), `hardware/`, `config/`, `docs/`; local `.venv/` and
  `data/` (sessions) are ignored. Run from its root: `python app/run.py [--sim]`.
- `CAMBRIDGE/testbed_dev/`: private material, never released: `basic_tests/`, `experiments/` (exp01,
  exp03), `CRI-Python-Lib/` (clone), `data/exp01|exp02/` (sessions before the split), `notes/` (docx,
  pdf). exp01 imports the drivers/config from `../database_acquisition` and writes to `testbed_dev/data/exp01`.
Environment: `database_acquisition/.venv` (Python 3.13; pythonnet, pyvisa, numpy, matplotlib/TkAgg,
cri_lib 0.4.0 copied from the CRI-Python-Lib clone = GitHub commit 21995a1, pinned in requirements.txt).
The venv was moved from implementation/: python.exe works, but the pip.exe launchers point to the old
path -> use `python -m pip`.
EVERYTHING in the released code is in English (comments, docstrings, GUI, messages): the repository is
shared with the research group. Hyperparameters go in a commented block at the top of each script.
Studied frequencies for exp01 are `FREQUENCIES_KHZ` (points.csv gets per-frequency columns
`<f>kHz_fft_<units>` from the scope FFT and `<f>kHz_wave_Vrms` from the raw waveform). The scope FFT
bin can be much wider than `led_freq_band_hz` (610 Hz measured at 700 kHz), so `fft_peak` searches at
least +/-1.5 bins.

## Layout (paths below relative to `database_acquisition/` unless they start with `testbed_dev/`)
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
- `testbed_dev/basic_tests/{GANTRY,MTRS,SCOPE}`: standalone per-device tests (run from their folder;
  independent of config).
- `testbed_dev/experiments/exp01_point_acquisition.py`: GUI point-by-point acquisition (comments still in
  Spanish; private); only experiment parameters at the top. Output: `testbed_dev/data/exp01/exp01_<date>/`.
- `app/` (formerly `tests/experiments/exp02_database/`, "exp02"): database acquisition
  (XYZ grid x K MTRS angles theta_k = (angle_offset_deg + 360k/K) mod 360, default offset 65 deg; measured
  in increasing MTRS angle). Run `python app/run.py [--sim] [--port] [--no-browser]
  [--output]`. `run.py` (entry, defaults at the top) starts `Testbed`, `engine.Engine` (plan, threads for
  telemetry / scope / runner, pause-resume-stop, auto-pause on errors, saving) and `server.py` (stdlib
  HTTP + Server-Sent Events on 127.0.0.1:8765). `web/` is a no-build HTML/CSS/JS UI that only sends
  commands; all control and rigor stay in Python. pyvisa is used only from the scope thread
  (`Engine.scope_call`). `pd_tilt_deg` is metadata of the 3D-printed mount: never sent to the MTRS (its
  tilt stays at `tilt_target_deg` = 0). Output `data/session_<date>[_label]/`
  (sessions recorded before the split are in `testbed_dev/data/exp02/exp02_<date>/`): points.csv (compact,
  one row per measurement), plan.csv, trajectory.csv, fft/mNNNNN.csv, wave/mNNNNN.npz, session.json, README.txt.
  The plan is compact (sites list + `plan_measurement(plan, i)`, no per-measurement dicts) so plans of
  10^5-10^6 measurements work; `MAX_MEASUREMENTS` (5e6) is only a memory guard, long plans get a warning.
  Time estimate (`estimate_times`) uses the NOMINAL speeds from testbed.toml (sim devices are sped up by
  `sim_speedup`) and constants calibrated on real data: MTRS trapezoid 1.5 deg/s, 1.5 deg/s2 (72 deg = 49.1 s);
  gantry 50 mm/s with ~160 mm/s2 effective (MOVING 6.75 s for 300 mm, 8.73 s for 400 mm, incl. arrival);
  acquisition time measured at Preview with the real scope (model 0.30 s + 0.65 us/point [+1.4 s with
  scope_fft] for the simulated scope) + saving. Checked against 3 real exp02 sessions: -2 to -7 %.
  Record per sample: `record_ms` (default 100 ms; 0 = oscilloscope settings) at `record_fs_msa`
  (default 10 MSa/s); set at Start / Preview and restored at the end. `scope_fft` (default False): FFT from
  Python over the whole record; the scope FFT display is hidden during the session (the UI shows the Python
  FFT of the last measurement) and restored at the end. fft/mNNNNN.csv is reduced to <= 4000 bins (max per
  group); full resolution is recomputable from wave/*.npz (codes + y_increment/y_origin/y_reference).
  UI: light, plain style (university tool, title "Database Acquisition Tool"); the configuration panel is
  a collapsible sidebar (button at the top left); Start/Pause/Stop stay in the header; Top view / 3D view
  (orbit, wheel zoom, double-click reset). UI screenshot without hardware: `run.py --sim --no-browser` and
  `msedge --headless=new --screenshot=... "http://127.0.0.1:8765/?snapshot=1&view=3d&config=0&color=500kHz"`
  (`?snapshot` avoids the never-ending SSE stream).

## Hardware facts (verified)
- Gantry igus DLE-RG-0012-BLDC at 192.168.3.11:3920 (PC 192.168.3.100/24); iRC simulator 127.0.0.1:3921.
  Real controller firmware V980-14-003-3 (simulator V980-14-004-4): Move Cart acceleration parameter
  needs >= V14-004-1, so it is omitted on the real robot. Cartesian Z = -A3; workspace X,Y in [0,1400],
  Z in [-700,0]. Per the investigator, in this setup Z = -700 is the HIGHEST PD position and Z = 0 the
  lowest (`[view] z_negative_up = true`; exp02 draws -700 at the top of the Z bar and 3D view). cri_lib hard-codes a 0.1 s connect timeout and the first
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
  Since 2026-10-12 the investigator uses Digitizer mode (10 MSa/s, 100 kpts requested, 500 us/div):
  records are 50,000 points = 5 ms. Profiled 2026-10-12: the slow part is NOT the USB transfer
  (50 kpts 35-170 ms, 1 Mpts 0.64 s) but the scope computing its own Math FFT after every acquisition
  (~1.4 s with 50 kpts, ~2 s with 1 Mpts; queries block until it finishes). :DIGitize + *OPC? took ~2.8 s;
  `record()` now uses :STOP/:SINGle + polling the Run bit (bit 3 of :OPERegister:CONDition?). With
  `record(..., scope_fft=False)` the scope FFT display is turned off during the capture and the FFT is
  computed in Python (`spectrum_vrms`, Hanning, same values as the scope within ~1 %).
  :WAVeform:DATA? only returns on-screen data -> record length = 10 x timebase. `configure_record(s, fs)`
  sets :ACQuire:POINts (2x, RUN halves), :ACQuire:SRATe, then :TIMebase:SCALe (this order; Digitizer mode
  rejects a timebase longer than memory/rate) and retries the timebase; the 4154A may answer "-222 Data out
  of range" while applying 10 ms/div, so actual values are checked. Max request 4 Mpts (8 Mpts rejected).
  :ACQuire:POINts? describes the LAST acquisition (half in RUN, full after :SINGle), not the request, so
  `restore_record()` requests 2 x on-screen points. Measured: 100 ms at 10 MSa/s (1 Mpts) = ~1.1-1.4 s per
  sample with the scope FFT hidden. Waveforms are saved as raw uint16 ADC codes + scale (lossless).
  `connect()` sends a device clear first: a previously interrupted session leaves the scope answering
  VI_ERROR_IO to *IDN?. After any VISA error the exp02 scope thread calls `Scope.recover()` (device clear +
  drain errors): a timed-out query otherwise desynchronises later ones ("-420 Query UNTERMINATED",
  "-221 Settings conflict", seen 2026-10-12).
  IMPORTANT (measured 2026-10-12): with the Math FFT displayed, the 4154A reduces the channel record to
  ~62,500 points (50 ms -> 62,500 pts at 1.25 MSa/s instead of 500,000 at 10 MSa/s) and its FFT then only
  reaches fs/2 (625 kHz): 700/900 kHz were empty in the FFT and aliased in the waveform (+1.5-4 % bias).
  exp02 therefore rejects `scope_fft` with records > 62,500 points and `_check_record` refuses to save (and
  pauses) any sample whose point count/sample rate differ from the plan or alias the studied frequencies.
  Session exp02_20261012_173036 (50 ms + scope FFT) is affected: use only its 300/500 kHz columns.
  LED generators are ~1.1-1.3 ppm off nominal (measured 2026-10-12 from 43 records of 100 ms, spread
  < 0.01 Hz: 299999.654 / 499999.456 / 700000.834 / 900000.984 Hz). With 100 ms records the lock-in at the
  NOMINAL frequency (`<f>kHz_wave_Vrms`) reads 0.2 / 0.5 / 1.1 / 1.6 % low. By the investigator's decision
  the acquisition code works only with the nominal frequencies (simple, general for other experiments);
  any correction belongs to the analysis stage (raw waveforms are saved). Do not reintroduce "tone" /
  real-frequency handling in the acquisition code.
  The LEDs recorded in points.csv (number and frequencies) are configured in the exp02 UI ("LEDs" panel);
  duplicate or non-positive frequencies are rejected.
  exp02 `n_passes`: the whole route is repeated (odd passes reversed when serpentine_xy; angle order keeps
  alternating per visit, so no long gantry/MTRS moves between passes); `pass` column in points/plan.csv.
  The parent repository (simulation_VLP) .git is already ~1.4 GB because session data were committed;
  the new standalone repository ignores `data/`.
  `SimScope` emulates this (4 Lambertian LEDs, same FFT format).

## Verification
- No hardware: `python app/run.py --sim` (from `database_acquisition/`); other scripts with
  `DEVICE_MODE` = sim (Agg backend for headless tests). `node --check app/web/app.js` after JS changes.
- `python -m py_compile` on changed files; real-device tests only with the user's consent (physical motion).
