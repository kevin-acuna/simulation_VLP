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
- `CAMBRIDGE/demo/` (2026-10-16): VLP Positioning Demo, same UI style as database_acquisition, port 8766.
  `vlp/` = generic numpy library (responses SQ / cos^m, Lambertian VLPModel, GLS/WLS/NLS + broadcast-dual
  range, LM on the sphere, fit_lambertian) - port of simulations/ rx_estimate + pd_fit_*, meant to be shared;
  `app/` = run.py, engine (random/manual point loop, K orientations, pause after the orientation, Stop
  immediate), geometry.py (gantry -> PD: z scale 0.6, elevation 0.09696, n = [sin t sin a, sin t cos a,
  cos t], a = theta - offset), positioner.py, storage.py (points.csv = database_acquisition columns +
  estimates.csv), sim_scope.py (DemoSimScope: RSS from the model + LED offset + noise), server.py, web/.
  Hyperparameters ONLY in `config/demo.toml` (not in the UI): SQ + NLS, LED (281.1, 904.8), A 0.062707,
  m 6.0918, offset 66.5 (LED XY and offset are correlated; (270, 890) goes with 67.3, A 0.06273, m 6.151).
  `tools/replay.py` reproduces the MATLAB results exactly (3.92 / 3.66 cm on 125 sites), `tools/calibrate.py`
  prints A, m. Run with database_acquisition/.venv: `python app/run.py [--sim]`; tests:
  `python -m unittest discover -s tests -v` (13 tests, ~20 s). Headless screenshot: run.py --sim --no-browser,
  then msedge --headless=new --screenshot=... "http://127.0.0.1:8766/?snapshot=1&view=top&config=0".
Environment: `database_acquisition/.venv` (Python 3.13; pythonnet, pyvisa, numpy, matplotlib/TkAgg,
cri_lib 0.4.0 copied from the CRI-Python-Lib clone = GitHub commit 21995a1, pinned in requirements.txt).
The venv was moved from implementation/: python.exe works, but the pip.exe launchers point to the old
path -> use `python -m pip`.
EVERYTHING in the released code is in English (comments, docstrings, GUI, messages): the repository is
shared with the research group. Hyperparameters go in a commented block at the top of each script.
Released defaults must stay NEUTRAL (K=1, offset 0, adapter/pd tilt 0, MTRS tilt fixed 0): the
investigator's own values (offset 65 deg, 15 deg adapter used in the analysis) are unpublished results and
must not appear as defaults or recommendations (the README only lists that 0/15 deg adapters exist).
The tool is presented as general position+orientation sampling (no research question in the README).
README sections: Quick start, features, system/adapters (figures in docs/), ..., Credits (author Kevin
Acuna-Condori, LISV Universite Paris-Saclay - UVSQ, visiting PhD at the LiFi R&D Centre, Cambridge),
How to acknowledge, Usage (internal use, do not redistribute).
MTRS tilt (since 2026-10-12): +/-3 deg, 0.5 deg/s, 0.5 deg/s2 (Thorlabs spec; [mtrs] tilt_limit_deg,
tilt_velocity_deg_s, tilt_acceleration_deg_s2). `MTRS.move_tilt/tilt_moving/tilt_arrived`, Testbed
`move_to_pose/wait_pose/go_to_pose(..., tilt=)`. The app: `mtrs_tilt_mode` fixed | random (uniform in
[min,max], one value per (site, k) reused by passes, numpy default_rng(tilt_seed), seed drawn at every
Preview and stored in session.json; commanded tilt in plan.csv / points.csv `mtrs_tilt_cmd_deg`). Real
tilt tested 2026-10-13 (session_20261013_101402, random [-1, 1]): measured = commanded, estimate 316 s vs
311 s real. UI: "MTRS tilt" gauge panel between MTRS rotation and Live pose; FFT amplitude axis can be
fixed by double-clicking the FFT (display only, stored in localStorage "dbacq.fftYfix").
Incident 2026-10-13 (sessions 103703, 113114 with 10 and 5 samples x 1 Mpts): VI_ERROR_IO in the middle of
a waveform transfer, then VI_ERROR_TMO/NCIC; the scope's USB interface hung (front panel Run/Stop red, no
answer to *IDN? even after device clear or reopening the session; Windows logged no USB disconnect). Only
replugging its USB cable / power-cycling recovers it. The 2-sample session that morning was fine. Changes:
waveforms transferred as BYTE when acquire_type is NORM/PEAK (WORD had the low byte always 0 -> half the
USB traffic, uint8 codes in wave/*.npz), :SINGle completion polled every 20 ms (was 5 ms),
`Scope.recover()` reopens the VISA session and sets `alive=False` if it still fails (restore/close then
skip commands instead of hanging), the engine re-applies the record setup (`_reapply_scope_setup`) before
retrying / after Resume, and pauses with replug instructions. The laptop runs the Balanced plan with USB
selective suspend enabled (suggested: disable it, scope on a direct USB port, not a hub shared with the MTRS).
Stress tests 2026-10-13 (scope alone, 1 Mpts BYTE records back to back, ~0.78 s each): chunk_size 4 MB ->
lock-up after 205 transfers; 256 kB -> after 590 (VI_ERROR_SYSTEM_ERROR). Known Keysight KB issue
("InfiniiVision-X ... connection loss during long, repetitive waveform data transfers over USB"): fixes =
scope Utility > I/O > Configure USB > Compatibility Mode, and/or a USB 2.0-only hub. The scope is on the
laptop's internal Genesys hub (VID_05E3 PID_0610, shared with internal devices) under the AMD USB 3.10 xHCI;
the MTRS is on the root hub. pnputil /restart-device (admin) does NOT unfreeze it: the user must unplug USB,
power-cycle the scope, then reconnect. Yesterday's sessions had only ~43 transfers of 1 Mpts in total.
More tests (1 Mpts back to back): *OPC? sync after :SINGle -> lock-up after 150; scope moved to a port
directly on the root hub (MTRS moved to the internal hub) -> lock-up after 60. Neither helps; the failure looks
random per transfer (~1/60-1/600). Compatibility Mode was already enabled. No USB 2.0 hub, single Ethernet
port (gantry). 20 ms records (200 kpts, 5x less data), :SINGle back to back -> lock-up after 285: the
size barely matters, the number of STOP/:SINGle/poll cycles does. Sessions with :DIGitize + *OPC? on 10-12
(148 small records) never failed. Next test: :DIGitize instead of :SINGle polling (stress script
%TEMP%\scope_stress3.py --mode digitize).
LAN test (laptop Ethernet temporarily moved from the gantry to the scope; scope set to manual IP
192.168.3.50/24, ports 111/4880/5025 open): over HiSLIP the FIRST 1 Mpts read crashed inside Keysight VISA
(`OSError: access violation` in viRead) and the scope locked up again (ping OK, no SCPI on LAN or USB).
Installed: Keysight IO Libraries Suite 2026 Update 1 (21.4.204), VISA shared 8.0.7331, installed 2026-10-02.
Hypothesis: VISA aborts/corrupts large reads -> the scope firmware hangs on an aborted transfer. Test
without VISA: %TEMP%\scope_socket_stress.py (raw TCP socket to port 5025, same capture cycle).
RESULT 2026-10-13: raw socket over LAN = 1500 captures of 1 Mpts back to back in 17.4 min, 0 errors,
0 wrong records, 0.69 s per capture (VISA USB: 0.78 s and lock-ups after 60-590). => Keysight VISA is the
culprit (USB and HiSLIP). Options: LAN + socket transport (needs a switch: single Ethernet port is for the
gantry), older IO Libraries / NI-VISA over USB, or pyvisa-py over USB (WinUSB driver).
But then, through the driver over the socket with STOP/:SINGle polling: total freeze (no ping, front panel
dead) after 530 -> the root cause is the STOP/:SINGle/poll/RUN cycle at a high rate (VISA made it worse).
FINAL SOLUTION (2026-10-13): oscilloscope on LAN through `hardware/scpi_socket.py` (address
"TCPIP::192.168.4.50::5025::SOCKET"), acquisitions with `:DIGitize` + `*OPC?` (no polling) and the scope
kept stopped during a session (record() only sends :RUN when no record is configured; restore_record()
sends :RUN). Test: 1500 records of 1 Mpts in batches of 10, 0 errors, 0.55 s per record; a full app
session (sim motion, 6 points x 10 samples) OK. Network: gantry on the USB-Ethernet adapter ASIX AX88772B
("Ethernet 3", PC 192.168.3.10), scope on the built-in Realtek port ("Ethernet", PC 192.168.4.100,
scope 192.168.4.50) - different subnets on purpose. The Realtek port has energy saving enabled
(not changed). `_find_fft` re-shows a Math FFT left hidden by an interrupted session.
If configure_record runs while the scope was left in the session setup (failed restore), the "previous
settings" saved are the session ones: restore the scope by hand first.
Lab fact (2026-10-13): the PD signal is dominated by ~100 Hz ambient-light flicker (~120 mVrms, peaks
~220 mV at 75 mV/div = +/-300 mV screen, only x1.4 headroom) while the LED tones are 1-16 mVrms; it does not
bias the tone amplitudes but limits the vertical scale (lights off -> finer scale, less clipping risk).
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
- `testbed_dev/experiments/exp03_FrecuencyResponse/exp03_frequency_response.py`: console-only frequency sweep
  of ONE LED driven by one of the TWO WaveGens of the measuring MSO-X 4154A (hyperparameter `WGEN` = 1 | 2,
  `:WGEN<n>:FREQuency`; ":WGEN" without number = WaveGen 1, which was at 700 kHz with output ON on 10-13);
  the program never turns the output on: it stops with a message if it is OFF;
  PD position typed in the console (or `--pos X Y Z`), gantry + scope only (no MTRS). Per frequency:
  N_SAMPLES x RECORD_MS records (`Scope.record`, :DIGitize, LAN), peak of the Python FFT (Hanning, whole
  record) at f within +/-FFT_BAND_HZ. Hyperparameters F_START/STOP/STEP_HZ (default 5 kHz..1 MHz step 5 kHz).
  Output `testbed_dev/data/exp03/exp03_<date>/`: frequency_response.csv (frequency_Hz, amplitude_mVrms only,
  written incrementally), session.json (settings, std per point), frequency_response.png. Restores the WGEN
  frequency and the scope settings at the end. `--sim` (sim scope = a single LED at f, flat response),
  `--no-show`. Verified in sim (200 points, 1.5 min); not yet run on the real hardware.
- `app/` (formerly `tests/experiments/exp02_database/`, "exp02"): database acquisition
  (XYZ grid x K MTRS angles theta_k = (angle_offset_deg + 360k/K) mod 360, default offset 65 deg; measured
  in increasing MTRS angle). Run `python app/run.py [--sim] [--port] [--no-browser]
  [--output]`. `run.py` (entry, defaults at the top) starts `Testbed`, `engine.Engine` (plan, threads for
  telemetry / scope / runner, pause-resume-stop, auto-pause on errors, saving) and `server.py` (stdlib
  HTTP + Server-Sent Events on 127.0.0.1:8765). `web/` is a no-build HTML/CSS/JS UI that only sends
  commands; all control and rigor stay in Python. pyvisa is used only from the scope thread
  (`Engine.scope_call`). `pd_tilt_deg` is metadata of the 3D-printed mount: never sent to the MTRS (its
  tilt stays at `tilt_target_deg` = 0). Output `data/campaign_<date>[_label]/` (older: `session_<date>`;
  both can be continued). Continue an interrupted campaign: `Engine.list_campaigns()` (unfinished =
  points.csv rows < n_meas), `Engine.load_campaign(name)` rebuilds the plan from session.json plan_config
  (incl. tilt_seed), checks contiguity/consistency, removes a cut last row, loads `done` from points.csv and
  sets `next_index`; `start()` then calls `_reopen_session()` (append mode) instead of `_open_session()`.
  session.json stores `resumes`, `scope_user_settings` (restored on continuation instead of the current scope
  state) and n_done (updated every 200 measurements and on error pauses). API GET /api/campaigns,
  POST /api/campaign/load; UI panel "Continue a campaign", Start button reads "Continue".
  run.py tees stdout/stderr to `logs/acq_<date>.log` (timestamped, git-ignored; `--no-log`); measurement
  failures also print the traceback. Campaign 20261013_182008 (141x141 grid, 10 mm, K=1, 100 ms): 3879/19881
  done in 2.4 h (~2.2 s/measurement), measurement 3880 failed at 20:44 (cause unknown: no log yet) and it
  stayed paused until the PC restart. Continued 10-14 10:24 from 3880; measurement 5942 failed at 11:41
  (2062 captures later): ConnectionResetError (WinError 10054) inside `:WAVeform:DATA?` recv, scope front
  panel frozen again -> with :DIGitize over LAN the scope firmware still freezes randomly, ~1 per 2000-5000
  1 Mpts captures (1.3-2.4 h). No link events, EEE / Power Saving already disabled. After that power cycle
  WaveGen 1 came back with output OFF (it drives the 700 kHz LED). Since then: `AUTO_RESUME` (run.py,
  Engine(auto_resume=True)): while paused with the scope dead (`_scope_dead`), `_scope_answers()` every
  SCOPE_CHECK_S = 15 s and continues by itself; `Scope.wgen_state()/set_wgen()`, the WaveGen state at start
  is stored in session.json `wgen_at_start` and `_check_wgen()` restores outputs/frequencies that were ON
  (after every recovery and when continuing a campaign). Campaign 20261013_182008 has no wgen_at_start:
  the reference is read at Continue, so WaveGen 1 must be ON before pressing it. Older output `data/session_<date>[_label]/`
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

## Analysis of real data (`CAMBRIDGE/analysis/`, MATLAB R2026a, one script per folder)
Scripts follow the same style: commented hyperparameter block at the top, `export_figures` (PNG 300 dpi +
FIG in `figures/`), top views in the acquisition-tool orientation (`app_orientation`: Y horizontal growing
to the left, X vertical). The investigator adds `close all` and edits the hyperparameters directly.
Headless check: `matlab -batch "run('script.m')"` from the script folder (local functions cannot be
called from outside the script).
- `RSS_Distribution/plot_rss_distribution.m`: heatmaps + 3D surfaces of the 4 LEDs (XY scan, PD horizontal).
- `Frecuency_Response/plot_frequency_response.m`: exp03 response, linear/dB.
- `Lambertian_order_LED_500khz/estimate_led_pattern.m`: RSS = A R(psi) L(phi)/d^2, PD horizontal so psi = phi
  (only R*L is identifiable: m depends on the assumed PD model). Calibration scan at gantry z = -300 with
  h = H_LED - H_PD = 3 - 1.13496 = 1.86504 m (H_PD = 103.8 + 9.696 cm). LED 500 kHz at (270, 890) mm
  (grid maximum); joint fit of A, m, LED XY with SQ gives (281.1, 904.8) mm. SQ: staged m = 6.15,
  joint m = 5.71, joint_xy m = 5.60. The scan shows 1-2 % steps after the overnight resume (LED/gain drift).
- `Experiment_01_3D_estimation/estimate_3d_positions.m`: campaign_01 (PD on the gantry, 15 deg adapter,
  K = 10 MTRS angles). Reuses `simulations/` estimators via `cambridge_setup` (cos/cos^mR: rx_estimate
  GLS/WLS/NLS_TCOM; SQ: pd_fit_estimate ratio_gls/ratio_wls/joint_nls) and refits A, m from the
  calibration scan with the same PD model and LED position. Frame: X, Y gantry (m), Z = height above
  the floor (up): Z_pd = H_base(1.038 m at gantry z = -300) + gantry_z_scale*(-300 - z)/1000 + 0.09696
  (gantry base -> PD centre, MTRS + adapter); LED at Z = 3 m, normal [0 0 -1]; PD normal
  [sin t sin a, sin t cos a, cos t], a = theta - offset (tilt towards +Y at theta = offset; increasing
  theta turns it towards +X). The investigator once wrote [0, cos15, -sin15]: the data reject it. Range
  recovery = exact dual of F_broadcast_Konly/core/broadcast_distance.m (eta = sum(y h)/sum(h^2),
  d = sqrt(A cos^m(phi)/eta)); with NLS it is already the position ML. The RSS shape over K gives a real
  MTRS offset of ~67.5 deg (same on both levels and PD models, default orientation_fit = 'offset' cross
  height); the tilt is NOT identifiable apart from the PD slope (13.8-14.7, cos needs 25) -> keep 15.
  Open issue (2026-10-15): at gantry z = -600 the estimates sit ~9-11 cm below the nominal height, from
  both direction-only triangulation (LED Z = 2.99 m, level offset -93 mm) and amplitude; with
  gantry_z_scale = 0.667 SQ+NLS gives 3.3 cm mean (nominal geometry 8.2 cm, 2.7 cm at z = -300).
  To verify: tape-measure the PD height at gantry z = -300 / -600. Report: report/experiment01_report.pdf.
  The 1.038 m base height must be at gantry z = -300 (at z = 0 the data give 27 cm errors, LED at 3.27 m).
  Campaign folders (2026-10-15): campaign_20261014_185628 (z -600, -300) and campaign_20261015_000723
  (z -200, -100, 0; same XY grid and K = 10 angles), analysed together via `campaign_dirs`. The second
  campaign confirmed the vertical compression out of sample: nominal geometry gives a vertical bias linear
  in z (-11.5 ... +9.7 cm), real/commanded travel 0.647 (estimated heights) / 0.632 (direction-only
  triangulation); with the a-priori gantry_z_scale = 0.667 all 5 levels give 3.6-3.75 cm (125 sites: SQ+NLS
  3.69 cm) and in-situ A (0.0605), tilt (14.80 deg) and triangulation become height-independent; cos^1.9
  stays inconsistent. Fitted MTRS offset drifts 67.55 -> 67.06 deg in acquisition order (10 h).
  MEASURED (tape, 2026-10-15): gantry_z_scale = 0.6 (real vertical travel per commanded mm), now the
  default. Final result, 125 sites, K = 10: SQ+NLS 3.92 cm mean (RMSE 4.30, P90 6.73), SQ+GLS 3.91,
  nominal offset 65 deg 4.98; per level 3.1 (Z 1.315 m) ... 4.6 cm (Z 0.955 m) with a residual vertical
  bias +0.5 ... -2.3 cm (in-situ m drifts 5.98 -> 5.39 with distance: cos^m LED model limitation);
  H_led = 3.00 m is the best value; LED (281.1, 904.8) gives 3.66 cm. K study (0.6): K = 5 -> 4.00,
  K = 3 -> 5.20 cm (offset fixed from K = 10).
  `k_study = true`: error vs K with near-uniform subsets of the measured angles (all rotations); SQ+NLS,
  z scale 0.667: K = 10 -> 4.8 cm (nominal 65 deg) / 3.65 cm (offset fitted once with K = 10), K = 5 same,
  K = 3 -> 5.8 / 4.7 cm, no failures. Campaign timing (campaign_01, real): 27.2 s per 36 deg MTRS step,
  8.5 s per site change -> per step ~ step_deg/1.5 + 3.2 s; 500 measurements took 3.52 h.

## Verification
- No hardware: `python app/run.py --sim` (from `database_acquisition/`); other scripts with
  `DEVICE_MODE` = sim (Agg backend for headless tests). `node --check app/web/app.js` after JS changes.
- `python -m py_compile` on changed files; real-device tests only with the user's consent (physical motion).
