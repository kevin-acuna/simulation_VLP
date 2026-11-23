# {TITLE}

Version {VERSION} · DOI: {DOI_LINK} · License: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

This dataset contains the measurements of the article

> {ARTICLE}

A photodiode (PD), tilted by a fixed adapter and turned by a motorized rotation stage, measures the received
signal strength (RSS) of a ceiling-mounted LED at a few known orientations. A Cartesian gantry places the receiver
at known positions, which provide the ground truth. Four LEDs of the same type, on the same ceiling, are modulated
at 300, 500, 700 and 900 kHz, so that the RSS of each LED is obtained from the same record. The article uses the
500 kHz LED; the other three repeat the evaluation as independent single-LED systems. Every RSS value comes with
the raw oscilloscope record (100 ms) from which it was computed.

## 1. Datasets

| | D1 calibration scan | D2 regular grid | D3 blind random test | R repeated records |
|---|---|---|---|---|
| Positions | 19 881 | 125 | 131 | 47 (three sessions over the same grid) |
| Layout | 141 × 141 grid, step 10 mm, X, Y from 0 to 1.4 m | 5 × 5 grid (X, Y from 0.1 to 1.3 m, step 0.3 m) at 5 heights | Random, uniform in X, Y ∈ [0.1, 1.3] m, Z ∈ [0.955, 1.315] m | 5 × 5 grid (X, Y from 0.1 to 1.3 m, step 0.3 m) |
| PD height Z | 1.135 m | 0.955, 1.015, 1.075, 1.135, 1.315 m | 0.955–1.315 m | 1.135 m |
| Adapter tilt θ | 0° (PD facing up) | 15° | 15° | 0° |
| Orientations K per position | 1 | 10, 36° apart | 5, 72° apart | 1 |
| Records of 100 ms | 19 881 | 1 250 | 655 | 230 (2, 10 or 5 consecutive records per position) |
| Sessions | 1 | 2 | 2 (47 + 84 positions) | 3 (25, 14 and 8 positions) |
| Acquired | 13–15 Oct. 2026 | 14–15 Oct. 2026 | 16 Oct. 2026 | 13 Oct. 2026 |
| Use in the article | Radiation patterns of the LEDs, calibration of the LED model | Evaluation of the receiver models and estimators | Blind test: positions estimated live by a real-time demonstrator, with parameters fixed beforehand | Noise of the RSS |

## 2. Files

{FILES}

## 3. Getting started

1. **Tables only.** The three `*_RSS.csv` files give, for every record, the position of the receiver, the angle of
   the stage, the normal of the PD and the RSS of the LEDs (Section 6.1).
2. **Full data.** Extract all the archives into the same folder (e.g. with 7-Zip "Extract here", `unzip "*.zip"`,
   or by choosing the same destination folder in Windows). The result is:

   ```text
   D1_calibration_scan/
     campaign_20261013-182008_grid141x141x1-xy0to1400-s10-z180_K1-off65_pd0_tilt0_100ms/
       points.csv  plan.csv  trajectory.csv  session.json  wave/m00001.npz ... wave/m19881.npz
   D2_grid/
     campaign_20261014-185628_grid5x5x2-xy100to1300-s300-z180to360_K10-off65_pd15_tilt0_100ms/   Z = 1.315, 1.135 m
     campaign_20261015-000723_grid5x5x3-xy100to1300-s300-z0to120_K10-off65_pd15_tilt0_100ms/     Z = 1.075, 1.015, 0.955 m
   D3_blind_test/
     demo_20261016-113422_random-xy100to1300-z0to360_K5-off65_pd15_tilt0_100ms/   points.csv  estimates.csv  session.json  wave/
     demo_20261016-174621_random-xy100to1300-z0to360_K5-off65_pd15_tilt0_100ms/
   R_repeated_records/
     campaign_20261013-101402_grid5x5x1-xy100to1300-s300-z180_K1-off65_pd0_tiltU-1to1_100msx2/
     campaign_20261013-103703_grid5x5x1-xy100to1300-s300-z180_K1-off65_pd0_tiltU-2to2_100msx10/
     campaign_20261013-113114_grid5x5x1-xy100to1300-s300-z180_K1-off65_pd0_tiltU-1to1_100msx5/
   ```

   `D1_calibration_scan_tables.zip` and the four D1 waveform archives fill the same D1 folder.
3. **Examples.** `example_load_data.py` (Python 3 with NumPy) and `example_load_data.m` (MATLAB, with
   `read_npz.m`) read a table and a raw waveform, and recompute the RSS of the four LEDs from the waveform.

A session folder is named after its start time (`YYYYmmdd-HHMMSS`) and its plan: grid size, X-Y range and step,
range of the gantry height z_g (mm), number of orientations K, first stage angle (`off`, degrees), adapter tilt
(`pd`, degrees), tilt of the stage (`tilt0`: zero; `tiltU<a>to<b>`: uniform random in [a, b] degrees), record
length and number of consecutive records (`x<n>`).

## 4. Coordinate frame and geometry

- X and Y are the horizontal axes of the gantry and Z is the height above the floor, pointing up
  (right-handed frame). Coordinates are in metres in the RSS tables and in millimetres in the session tables.
- The position of the receiver is the centre of the PD, which lies on the rotation axis of the stage: it does not
  move when the stage turns. X = x_cmd_mm / 1000 and Y = y_cmd_mm / 1000; the commanded and measured positions
  (`x_mm`, `y_mm`, `z_mm`) agree in all records.
- PD height: **Z = 0.95496 m + z_g**, where z_g = z_cmd_mm / 1000 is the vertical coordinate of the gantry. The offset
  is the measured height of the gantry carriage at z_g = 0 (0.858 m) plus the elevation of the PD centre above it,
  from the CAD model of the stage and adapter (0.09696 m).
- PD normal at the stage angle α (`angle_deg`, encoder reading):
  **n = [sin θ sin(α − α0), sin θ cos(α − α0), cos θ]**, where θ is the adapter tilt (`pd_tilt_deg`) and α0, the
  stage zero, is the stage angle at which the PD tilts toward +Y; increasing α turns it toward +X. The nominal
  stage zero is 65°; the value calibrated in the article, used for the normals of the RSS tables, is α0 = 66.5°.
- 500 kHz LED: facing down, at the measured height of 3.000 m; its horizontal position, calibrated from D1, is
  (X, Y) = (0.2811, 0.9048) m. The LED model and receiver response of the article (gain A = 0.062707 V m²,
  Lambertian order m = 6.0918, SQ response with ψ3dB = 0.61 rad) are also recorded in the `positioning` block of
  the session.json files of D3, which the demonstrator used for the live estimates.
- The positions of the other three LEDs were not surveyed; they can be calibrated from D1 in the same way.

## 5. RSS

The RSS of an LED is the RMS amplitude of its tone in a record, obtained by digital lock-in detection at the
nominal frequency f (300, 500, 700 or 900 kHz):

  y = (√2 / N) · | Σ_{n=0}^{N−1} (v[n] − v̄) · exp(−j 2π f n / f_s) |,  with N = 10^6 samples and f_s = 10 MSa/s,

where v[n] is the record in volts and v̄ its mean. It is the column `<f>kHz_wave_Vrms` of points.csv and
`rss_<f>kHz_V` of the RSS tables. The record holds an integer number of periods of every tone, so that the
projection rejects the other tones. The generators deviate from the nominal frequencies by about 1 ppm (0.4 to
1 Hz); over 100 ms, the projection at the nominal frequency is then lower than at the actual frequency by 0.2, 0.5,
1.1 and 1.5 % for the 300, 500, 700 and 900 kHz tones. The article uses the values at the nominal frequency; the raw
records allow any other choice.

## 6. File formats

All tables are comma-separated (UTF-8, header in the first row, `.` as decimal separator).

### 6.1 RSS tables (`D1_calibration_scan_RSS.csv`, `D2_grid_RSS.csv`, `D3_blind_test_RSS.csv`)

One row per record.

| Column | Unit | Description |
|---|---|---|
| `session` | | Session folder |
| `site_id` | | Position number within the session |
| `k` | | Orientation index, 0 to K − 1 |
| `meas_id` | | Record number within the session; raw waveform `wave/m<meas_id, 5 digits>.npz` of the session |
| `X_m`, `Y_m`, `Z_m` | m | Position of the PD centre (Section 4) |
| `alpha_deg` | ° | Stage angle α (encoder reading) |
| `nx`, `ny`, `nz` | | PD normal, with θ = `pd_tilt_deg` and α0 = 66.5° (Section 4) |
| `rss_<f>kHz_V` | V | RSS of the LED modulated at f (Section 5); D3: 500 kHz only |
| `unix_time_s` | s | Start of the record (Unix time, UTC) |

### 6.2 `points.csv` (every session)

One row per record (a position and an orientation).

| Column | Unit | Description |
|---|---|---|
| `meas_id` | | Record number |
| `pass` | | Repetition of the whole route (1 in all sessions) |
| `site_id` | | Position number |
| `ix`, `iy`, `iz` | | Grid indices of the position (0 in D3) |
| `k` | | Orientation index; commanded angle = (first stage angle + 360° k / K) mod 360° |
| `iso_time` | | Local time (UTC+1) at which the row was written |
| `unix_time_s` | s | Start of the (first) record, Unix time (UTC) |
| `x_cmd_mm`, `y_cmd_mm`, `z_cmd_mm` | mm | Commanded gantry position (z = z_g) |
| `angle_cmd_deg` | ° | Commanded stage angle |
| `mtrs_tilt_cmd_deg` | ° | Commanded tilt of the stage |
| `x_mm`, `y_mm`, `z_mm`, `angle_deg`, `mtrs_tilt_deg` | mm, ° | Measured pose (gantry and stage feedback) |
| `pd_tilt_deg` | ° | Adapter tilt θ |
| `<f>kHz_fft_Vrms` | V | Peak of the Hann-windowed spectrum of the record within ±50 Hz of f |
| `<f>kHz_wave_Vrms` | V | RSS of the LED modulated at f (Section 5) |
| `<f>kHz_fft_Vrms_std`, `<f>kHz_wave_Vrms_std` | V | R only: standard deviation over the `n_acq` records (the two columns above are then their mean) |
| `pos_err_mm`, `angle_err_deg` | mm, ° | Measured minus commanded position and angle |
| `n_acq` | | Number of consecutive records |
| `clip_frac` | | Fraction of samples at the edge of the oscilloscope range (0: no saturation) |
| `wave_ac_rms_V` | V | RMS of the whole record (all tones and noise) |
| `wave_file` | | Raw waveform, relative to the session folder |

### 6.3 `estimates.csv` (D3)

One row per position: the estimate computed live by the demonstrator (SQ response, NLS estimator) from the K = 5
RSS values of the 500 kHz LED. The mean of `err_3d_cm` over the 131 positions is the 4.10 cm of the article.

| Column | Unit | Description |
|---|---|---|
| `point_id` | | Position number (= `site_id` of points.csv) |
| `iso_time` | | Local time (UTC+1) of the estimate |
| `K`, `status`, `estimator`, `pd_response` | | Number of orientations, status and settings of the estimator |
| `x_cmd_mm`, `y_cmd_mm`, `z_cmd_mm` | mm | Gantry position |
| `true_X_m`, `true_Y_m`, `true_Z_m` | m | True position of the PD centre |
| `est_X_m`, `est_Y_m`, `est_Z_m` | m | Estimated position |
| `est_gantry_z_mm` | mm | Estimated height, as a gantry coordinate z_g |
| `err_X_cm`, `err_Y_cm`, `err_Z_cm` | cm | Estimated minus true position |
| `err_3d_cm`, `err_h_cm` | cm | 3-D and horizontal position error |
| `err_dir_deg` | ° | Angle between the estimated and true directions of the LED |
| `err_range_cm` | cm | Estimated minus true distance to the LED |
| `distance_m`, `amplitude_V` | m, V | Estimated distance and common amplitude of the RSS profile |
| `fit_rms_pct` | % | RMS relative residual of the fitted RSS profile |
| `angles_deg`, `rss_V` | °, V | The K stage angles and RSS values used (space-separated) |
| `mtrs_tilt_cmd_deg`, `mtrs_tilts_deg` | ° | Second session only: commanded tilt of the stage and its K readings (all 0) |

### 6.4 `plan.csv`, `trajectory.csv` and `session.json` (sessions)

- `plan.csv`: the planned records (position, angle, stage tilt and estimated duration `est_s`). Two sessions of R
  were stopped before the end of their plan (14 and 8 of 25 positions).
- `trajectory.csv`: telemetry of the gantry and the stage at 10 Hz during the session (state, phase, current
  record, position, speed, angle, tilt and targets).
- `session.json`: settings of the session: plan, record (100 ms at 10 MSa/s, 10^6 samples), LED frequencies,
  oscilloscope (identification, vertical scale, coupling, sample rate), stage and gantry parameters, and the
  times at which an interrupted session was resumed. For D3, also the parameters of the demonstrator
  (`positioning`).

### 6.5 Raw waveforms (`wave/mNNNNN.npz`)

NumPy archive (a ZIP of `.npy` arrays, an open format), one per record of points.csv; readable with
`numpy.load` in Python and with `read_npz.m` in MATLAB.

| Array | Type, shape | Description |
|---|---|---|
| `codes` | uint8 (D1, D2, D3) or uint16 (R), n_acq × 10^6 | ADC codes of the PD output |
| `y_increment`, `y_origin`, `y_reference` | float64, n_acq | Vertical scale |
| `fs` | float64 | Sample rate (Sa/s) |
| `unix` | float64, n_acq | Start time of each record (Unix time, UTC) |

Volts: `v = (codes − y_reference) · y_increment + y_origin`, one row per record. The oscilloscope (AC coupling,
1 MΩ, 75 mV/div) digitizes with 8 bits (2.51 mV per code); in R the codes are 16-bit words whose low byte is zero.

## 7. Acquisition and notes

- Transmitter: ceiling-mounted LUCICUP LEDs, 3.0 m above the floor and facing down, each biased by a DC supply
  (16 V, 0.65 A) and modulated by a 2 Vpp sinusoidal tone added through a bias tee.
- Receiver: Thorlabs PDA100A2 amplified silicon photodetector (75.4 mm², gain 20 dB) on a 3-D printed adapter
  (0° or 15°), mounted on a Thorlabs MTRS motorized rotation stage (vertical rotation axis, 1.5°/s), carried by an
  igus DLE-RG-0012-BLDC three-axis Cartesian gantry.
- Acquisition: Keysight (Agilent) InfiniiVision MSO-X 4154A oscilloscope, one record of 100 ms at 10 MSa/s per
  orientation, after a settling time of 1 s (0.5 s in D1). The tilt axis of the stage is kept at 0°, except in R,
  where it is drawn at random for each position (`mtrs_tilt_cmd_deg`).
- Times: `iso_time` is local time (UTC+1); `unix_time_s` and the `unix` arrays are Unix times (UTC).
- D1 was acquired from 13 to 15 October 2026 in five runs: the scan was resumed four times (`resumes` in its
  session.json).
- D3 is a single-LED test: only the 500 kHz LED is used, and the tones of the other LEDs are absent from most of
  its records, so that the other tone columns of its points.csv are not meaningful.
- Position numbers are never reused: a missing number is a position without records.
- For publication, the reduced spectra written by the acquisition software (`fft/*.csv`) were not included, as
  they can be recomputed from the raw waveforms, and local file paths and the internal configuration of the
  control software were removed from session.json.

## 8. License

The dataset is distributed under the Creative Commons Attribution 4.0 International License (CC BY 4.0,
LICENSE.txt).

## 9. How to cite

Please cite both the dataset and the article:

- {CREATORS} ({YEAR}). *{TITLE}* (Version {VERSION}) [Data set]. Zenodo. {DOI_LINK}
- {ARTICLE}

## 10. Acknowledgements and contact

{ACKNOWLEDGEMENTS}

Contact: {CONTACT}
