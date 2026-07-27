# exp3_SpatialDF — Direction Finding validation (sub-dataset 3)

Experimental validation of the **GLS / WLS direction-finding** estimators
(`fundamentals/core/vlp_gls.m`, `vlp_wls.m`) and the **broadcast distance**
recovery (`F_broadcast_Konly/core/broadcast_distance.m`) against real
measurements from the spatial campaign (`sub3_spatial`).

## 1. Where the data comes from

The data was produced by `sub3_spatial.cpp` (LiFiStick testbed). For each
receiver position the orchestrator runs:

- **STAGE 1 — vertical `{K}` scan:** the PD points to the zenith and the LED
  gimbal sweeps the `K = 12` codebook orientations. One mean voltage per
  orientation is stored (`scan_kind = vertical`).
- **STAGE 3 — random-tilt `{K}` scans:** the PD is tilted to a random
  orientation (inclination ≤ `TILT_MAX_DEG = 15°`, uniform azimuth) and the
  same codebook sweep is repeated. `N_TILT_SCANS_PER_POINT = 3` tilt scans per
  point (`scan_kind = tilt`).
- STAGE 2 (cooperative `{K+1}`) was **disabled** for this run.

`master.csv` has **one row per (point_id, orientation_id, repeat_id)**.

### Key columns

| column | meaning |
|---|---|
| `point_id` | unique id per receiver position (`<session>_<index>`) |
| `x, y, z` | receiver ground-truth position [m] |
| `scan_kind` | `vertical` or `tilt` |
| `tilt_cmd_deg`, `tilt_cmd_az` | commanded PD tilt (0/0 for vertical) |
| `nr_incl`, `nr_az` | PD-normal inclination/azimuth (= commanded tilt) |
| `orientation_id` | codebook index `1..12` |
| `nt_incl`, `nt_az` | LED orientation (inclination from nadir, azimuth) [deg] |
| `v_mean, v_median, v_std` | statistics of `n_samples` DAQ voltages (~ optical power) |

The LED (Tx) is fixed at **`T = (0, 0, 2)` m** (`transmitter_z` in `metadata.txt`).

### Codebook (`experiment_config.h`)

| id | incl | az | | id | incl | az |
|--|--|--|--|--|--|--|
| 1 | 16 | 90 | | 7 | 60 | 180 |
| 2 | 16 | 210 | | 8 | 64 | 240 |
| 3 | 16 | 330 | | 9 | 64 | 300 |
| 4 | 60 | 0 | | 10 | 0 | 0 |
| 5 | 64 | 60 | | 11 | 60 | 90 |
| 6 | 64 | 120 | | 12 | 60 | 270 |

## 2. Conventions

- **LED orientation** `nt = [sin(incl)cos(az); sin(incl)sin(az); -cos(incl)]`
  (nadir-referenced: `incl = 0` ⇒ straight down). See `lib/df_angles_to_nt.m`.
- **PD normal** `nr = [sin(incl)cos(az); sin(incl)sin(az); +cos(incl)]`
  (zenith-referenced: `incl = 0` ⇒ straight up). See `lib/df_angles_to_nr.m`.
- **Ground-truth direction** `nd_true = (pos - T)/|pos - T|` (Tx → Rx).
- The estimators return `nd_hat` (Tx → Rx); position = `T + nd_hat * d_hat`.
- Voltage is proportional to optical power, so `v_mean` is fed directly as the
  power vector. Direction finding is ratio-based and needs no calibration.

## 3. Scripts

| file | scope |
|---|---|
| `analyze_df_vertical.m` | vertical-PD rows (`nr = [0 0 1]`) |
| `analyze_df_tilted.m` | tilted-PD rows (one instance per random tilt) |
| `lib/df_run_analysis.m` | shared engine: grouping, GLS/WLS, distance, figures |
| `lib/df_load_master.m` | typed CSV reader |
| `lib/df_angles_to_nt.m` / `df_angles_to_nr.m` | angle → unit vector |
| `lib/df_estimate_C.m` | empirical C from all points/orientations (ground truth) |
| `lib/df_estimate_C_nadir.m` | sub2-style C from under-LED + LED-at-nadir rows only |

### Configuration (top of each script)

- **`cfg.K_id`** — codebook IDs used for estimation, e.g. `[1 3 4 5 6 9]`.
  This is the "which orientations" selector requested. All listed IDs must be
  present in a scan for that instance to be used.
- **`cfg.m`** — Lambertian order (default `3.13`, from `exp2_Cone`).
- **`cfg.C_opt`** — radiometric constant. A number is used as-is (takes
  precedence). Set it to `[]` to compute C automatically according to
  **`cfg.C_mode`**.
- **`cfg.C_mode`** — how C is obtained when `cfg.C_opt = []`:
  - `'empirical'` — fit from *all* points and orientations using ground truth
    (median, `df_estimate_C.m`); removes the global scale so distance figures
    show the model *scatter*.
  - `'nadir'` — **sub-dataset-2 analogue** with *fixed* (non-tunable) geometry
    (`df_estimate_C_nadir.m`): only the **vertical** scan of the receiver
    **exactly under the LED** (`x == 0` and `y == 0`, any `z`) with the LED at
    the **nadir** (`nt_incl == 0`). There `Q = cos(psi) = 1`, so it collapses to
    `C = (v_mean - v_dark)*d^2`. For this session the under-LED point
    `P8 = (0,0,1.1)` gives **C ≈ 8.69** (v_dark 0) / **8.65** (v_dark 0.05).
  This calibration is independent of `cfg.K_id` (it reads the nadir row
  directly), so it works even when orientation 10 is excluded from the DF set.
- **`cfg.v_dark`** — dark voltage to subtract (this run has none).
- **`cfg.autoRefMax`** — uses the brightest selected orientation as the ratio
  reference for numerical stability (does not change the set of `K_id`).

Run in MATLAB:

```matlab
cd exp3_SpatialDF
analyze_df_vertical      % or: analyze_df_tilted
```

## 4. Outputs

Console: per-instance table + angular/position RMSE and median for GLS & WLS.

`data/<session>/figures_<scanKind>/`:
- `Fig1_map_topview_*` — X-Y map: ground truth vs GLS/WLS estimates.
- `Fig2_map_3D_*` — 3D localization with the LED.
- `Fig3_errors_*` — per-instance angular and position error bars.
- `Fig4_distance_cdf_*` — estimated vs true distance + position-error CDF.
- `results_<scanKind>.csv` — per-instance numeric results.

## 5. Notes (few-samples caveat)

- This session has **13 points** (point 13 partial); `M_repeats = 1`, so each
  orientation has a single mean voltage. Noise (`v_std ≈ 2 mV`) is tiny, so the
  dominant error is model/calibration mismatch, not photon noise — the figures
  reflect estimator + model accuracy, not a Monte-Carlo RMSE.
- Distance accuracy depends on `C`; until sub-dataset 2 is measured, the
  empirical `C` makes the *average* distance correct by construction and the
  spread is the meaningful quantity.
