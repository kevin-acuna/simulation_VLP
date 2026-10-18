# Position from the directions of 2+ LEDs

Data: `campaign_20261014-185628_…_K10-off65_pd15_tilt0_100ms` (50 positions, 2 heights, K = 10; the RSS of
the 4 LEDs at 300 / 500 / 700 / 900 kHz is in every row). The 500 kHz LED is always used and is paired
with each of the others (and all four together). No range is estimated: no A, m, LED power or gain.

| Scenario | Script | Results | What is known |
|---|---|---|---|
| 1. Known yaw | `estimate_position_known_yaw.m` | `results_known_yaw/` | LED positions, MTRS offset (yaw, 66.5°), adapter tilt |
| 2. Unknown yaw | `estimate_position_unknown_yaw.m` | `results_unknown_yaw/` | LED positions, adapter tilt and the *relative* MTRS angles; the yaw is estimated with the position |

Run scenario 1 first: scenario 2 reads its LED positions (`results_known_yaw/led_positions.csv`, not
recalibrated) and its errors for the comparison. Run: `matlab -batch "cd('<this folder>'); estimate_position_known_yaw"`.

Reusable functions:

| Function | Purpose |
|---|---|
| `led_direction.m` | Direction PD → LED from the K RSS of one LED (shape only; `pd_fit_estimate` of `simulations`) |
| `rays_intersection.m` | Least-squares point closest to N lines (+ range, miss distance, angle between rays) |
| `rays_intersection_yaw.m` | Position **and** yaw from N ≥ 2 rays known up to a rotation about the vertical |
| `pd_normals.m` | PD normals of the testbed (MTRS angle, offset, adapter tilt) |

Results (K = 10, mean 3D error):

| LEDs | Known yaw | Unknown yaw | Yaw error (std) |
|---|---|---|---|
| 500 + 300 kHz | 4.46 cm | 5.05 cm | 1.4° |
| 500 + 700 kHz | 6.27 cm | 7.38 cm | 2.2° |
| 500 + 900 kHz | 3.30 cm | 3.60 cm | 1.2° |
| 500 + 300 + 700 + 900 kHz | 2.77 cm | 2.92 cm | 0.7° |
| 500 kHz only, range with A, m (scenario 1) | 2.98 cm | — | — |
