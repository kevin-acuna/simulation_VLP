# VLP Positioning Demo

Live demonstration of 3D visible light positioning with **one fixed LED and one reorientable
photodetector (PD)** on the Cambridge testbed. The gantry moves the PD to a random position (or one
chosen in the interface), the MTRS turns it to **K orientations**, the RSS of the LED is recorded at
each one, and the 3D position is estimated and compared with the true one. Then it goes on to the next
point, without end, until **Stop**.

Every orientation is also saved exactly as in the Database Acquisition Tool, so the demo doubles as a
**random-position database** (same `points.csv` columns; the MATLAB analysis reads it unchanged).

Same visual style as `database_acquisition`; it reuses its device drivers and `config/testbed.toml`.

---

## Quick start

```bash
cd CAMBRIDGE/demo
..\database_acquisition\.venv\Scripts\activate     # the drivers' virtual environment (numpy, pyvisa, pythonnet, cri_lib)
python app/run.py --sim                            # no hardware: simulated devices and signal
python app/run.py                                  # real gantry + MTRS + oscilloscope
```

The interface opens at <http://127.0.0.1:8766> (8765 is the Database Acquisition Tool, both can run).

1. Configuration panel: **Random** positions (box in gantry coordinates) or **Manual** positions
   (type X, Y, Z or click on the top view, then *Measure here*; queued positions are measured first in
   both modes), **K** (default 5), recorded LEDs, record length, settle time, waveforms, label.
2. **Start**. **Pause** takes effect after the current orientation (the point continues on Resume);
   **Stop** is immediate (the point in progress is not estimated; its orientations stay saved).
   The mode can be switched and positions queued while running.

### What the interface shows

| Panel | Content |
|---|---|
| Header | Configuration, current status message, devices, Start / Pause / Stop |
| Real vs estimated | top view (as the acquisition tool) and orbitable 3D view; real (hollow) vs estimated (colour = 3D error, 0-20 cm) with the error vector; live PD; hover a point for its values; *Error drawn* x1 (default, true scale) to x20 magnifies only the drawing; **Enlarge** shows only this view below the header (Esc or *Back to normal view*) |
| RSS per orientation | polar plot (MTRS angle around, RSS radial) that fills up orientation by orientation, live MTRS needle, and the model fitted by the estimator once the point is finished |
| 3D error per point | bars of the last 80 points with mean and P90 (hover a bar: its error in cm), CDF of all the points |

Z in the views is the **height of the PD centre above the floor** (physical frame of the estimator).
The LED position is not drawn unless `[display] show_led = true`.

---

## Positioning (hyperparameters, not in the interface)

`config/demo.toml` holds everything that the interface must not change:

| Section | Content |
|---|---|
| `[positioning]` | LED frequency (500 kHz), PD response (`SQ` / `cosine_mR` / `cosine`), estimator (`NLS` / `GLS` / `WLS`) |
| `[led]` | LED XY and height, calibration constant `A` and Lambertian order `m` |
| `[geometry]` | gantry base height, PD elevation (9.696 cm), **gantry z scale 0.6** (measured), adapter tilt 15 deg, **real MTRS offset** (calibrated) |
| `[plan]` | **nominal MTRS offset** (65 deg) of the commanded angles |
| `[display]` | `show_led` (default false) |
| `[sim]` | `--sim`: speed-up, model mismatch (LED offset) and RSS noise |

**MTRS offset, as in the MATLAB analysis**: the MTRS is commanded with the nominal offset of every
campaign, theta_k = (65 + 360 k / K) mod 360 (K = 5: 65, 137, 209, 281, 353 deg), and the estimator
builds the PD normals from the measured angles with the real offset calibrated from the campaigns
(`[geometry] mtrs_offset_deg` = 66.5 deg).

Default (best validated configuration): **SQ + NLS**, LED (281.1, 904.8) mm, A = 0.062707 V m², m = 6.0918,
real MTRS offset 66.5 deg, gantry z scale 0.6. The LED XY and the real offset are correlated: change them
together and recompute A and m with `tools/calibrate.py` (the alternative LED (270, 890) goes with a
real offset of 67.3 deg and A = 0.06273, m = 6.151).

Model: `RSS = A R(psi) cos(phi)^m / d^2` with R the PD response. Estimation in two stages: direction
from the K RSS (ratios or joint fit with a free amplitude), then range from the same RSS,
`beta = sum(y h) / sum(h^2)`, `d = sqrt(A L(phi) / beta)` (dual of `F_broadcast_Konly/core/broadcast_distance.m`).

### Tools

```bash
python tools/calibrate.py                 # A and m from the Lambertian scan (configured model and LED)
python tools/calibrate.py --led 270 890
python tools/replay.py                    # replays the recorded campaigns through the demo positioner
python tools/replay.py --offset-fit all   # MTRS offset fitted on all sites (value for demo.toml)
python tools/replay.py --K 5              # near-uniform subsets of 5 of the 10 recorded angles
```

`tools/replay.py` reproduces the MATLAB analysis (`analysis/Experiment_01_3D_estimation`) on the 125
sites of the two campaigns: SQ + NLS, LED (270, 890), offset fitted per height, **3.92 cm** (MATLAB 3.92),
and 3.66 cm with LED (281.1, 904.8) (MATLAB 3.66). With the demo configuration: 3.66 cm (K = 10),
3.73 cm (K = 5).

---

## Code structure

```
demo/
  vlp/                 generic library (numpy only, no hardware, no testbed constants): can be shared
    responses.py       PD angular responses: SQResponse (Bastiaens 2020), CosinePowerResponse
    model.py           Lambertian LED, VLPModel (forward model), tilted_normals
    estimators.py      GLS / WLS / NLS + range: estimate_position(), estimate_direction()
    optim.py           Levenberg-Marquardt on the unit sphere
    calibration.py     fit_lambertian (A, m), fit_scalar
  app/                 the demo application
    run.py             launcher (--sim, --port, --no-browser, --output)
    settings.py        config/demo.toml and import paths
    geometry.py        Cambridge testbed: gantry coordinates <-> PD position and normals
    positioner.py      geometry + VLP model + estimator -> estimate and errors
    engine.py          point loop, pause / stop, live state
    storage.py         session files
    sim_scope.py       simulated oscilloscope consistent with the positioning model
    server.py          HTTP + Server-Sent Events (standard library)
    web/               interface (no-build HTML / CSS / JS)
  config/demo.toml     hyperparameters
  tools/               calibrate.py, replay.py
  tests/               unittest (python -m unittest discover -s tests -v)
```

`vlp` is independent of the testbed: `from vlp import SQResponse, Lambertian, VLPModel, estimate_position`.
Its estimators are a numpy port of `CAMBRIDGE/simulations` (`Estimators/rx_estimate.m`, `Receiver
models/Bastiaens 2020/Estimators/pd_fit_*.m`):

| Response | GLS | WLS | NLS |
|---|---|---|---|
| `cos^m_R` (power law) | ratio roots, full covariance, smallest eigenvector (TCOM) | same, diagonal covariance | joint direction + amplitude, LM |
| `SQ` (any other) | nonlinear ratio fit, full covariance, LM | same, diagonal covariance | joint direction + amplitude, LM, multi-start |

**Extending**: a new PD response = a subclass of `vlp.responses.Response` (`value`, `derivative`,
`cutoff_cos`); a new estimator = a function in `vlp/estimators.py` added to `estimate_direction`; a new
testbed = another `geometry.py` (the library does not change).

## Session files (`data/demo_<date>[_label]/`)

| File | Content |
|---|---|
| `points.csv` | one row per orientation, database_acquisition columns (`site_id` = point) |
| `estimates.csv` | one row per point: true / estimated PD position (m), errors (cm), direction / range error, status, angles and RSS used |
| `wave/mNNNNN.npz` | raw waveforms (optional, lossless ADC codes) |
| `session.json` | interface configuration, positioning hyperparameters, devices, summary |

## Tests

```bash
python -m unittest discover -s tests -v     # vlp (noise-free recovery, range, calibration), geometry, engine in sim
```
