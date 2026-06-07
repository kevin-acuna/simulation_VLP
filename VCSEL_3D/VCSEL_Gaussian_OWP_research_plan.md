# Research Plan: Single Steerable Gaussian VCSEL for 3D Optical Wireless Positioning

## Purpose of this document

This document summarizes the planned first paper on **3D optical wireless positioning (OWP) with a single steerable Gaussian VCSEL source**. It is written for an LLM or research assistant that must understand the technical context, reproduce the simulation workflow, and generate scripts/figures for the paper.

The paper is intended as the next step after two previous works:

1. A TCOM-style paper on **single-LED beam-steered OWP** with a Lambertian radiation pattern.
2. A broadcast-positioning paper where the receiver orientation is assumed known and the distance is recovered from the same `K` steered-orientation RSS measurements.

The new work should **not** simply repeat the earlier framework with `cos^m(phi)` replaced by a Gaussian. The paper should be framed around the new system-level design problem introduced by VCSELs:

> VCSEL beams are narrow and power-concentrated. This can improve local angular sensitivity, but it creates coverage holes unless the divergence angle and the number of steered orientations are properly designed.

Therefore, the main technical theme is the trade-off among:

- divergence angle `theta_div`,
- number of steered orientations `K`,
- positioning accuracy,
- spatial coverage,
- outage probability,
- scan latency.

---

## High-level paper concept

### Tentative title

**Sparse Beam-Steered 3D Optical Wireless Positioning with Gaussian VCSEL Sources: Accuracy, Coverage, and Divergence Trade-offs**

Alternative shorter title:

**Gaussian VCSEL Beam-Steered Optical Wireless Positioning: Bounds, Codebook Design, and Sparse-Scan Performance**

### Core research question

Given a **single steerable VCSEL** with an effective Gaussian far-field profile, how should the orientation codebook and divergence angle be designed to achieve accurate 3D RSS-based positioning over a target indoor region?

More specifically:

> For each divergence angle `theta_div`, how many beam orientations `K` are needed to obtain sufficient coverage and positioning accuracy?

### Main novelty relative to prior Lambertian LED OWP

The prior Lambertian framework uses a wide radiation pattern, where most positions receive non-negligible optical power from most orientations. In contrast, a VCSEL beam may be narrow, so a position may receive useful RSS only from a subset of orientations. This changes the design problem:

- A smaller `theta_div` gives high boresight intensity and sharp angular gradients.
- A larger `theta_div` improves coverage but reduces boresight irradiance and angular selectivity.
- Increasing `K` improves coverage and Fisher information but increases scan time.
- Therefore, the relevant metric is not only RMSE or PEB, but the joint accuracy-coverage-latency trade-off.

---

## Scope and assumptions

### Source model

Use a **single steerable VCSEL** mounted at a known position, typically the ceiling. It can transmit sequentially along `K` known orientations:

```text
n_t,1, n_t,2, ..., n_t,K
```

Each orientation is one measurement slot.

The source is modeled as an effective Gaussian beam. This is a first-order model appropriate for a VCSEL operating in a quasi-Gaussian far-field regime or for a VCSEL package plus optics whose effective beam is Gaussian-like.

Do **not** claim that every VCSEL is Gaussian. Practical multimode or high-power VCSELs can have non-Gaussian, annular, or current-dependent patterns. Those are future work.

### Receiver model

Use a single photodiode receiver at unknown position `r`. The receiver orientation `n_r` is assumed known, as in the broadcast-positioning paper. This known orientation may be provided by an IMU or another attitude-estimation subsystem.

The receiver collects RSS/power measurements from the `K` steered VCSEL orientations.

### Steering assumption

The first paper assumes **active or effective beam steering**. Coverage is obtained temporally through the orientation codebook, not spatially through a dense parallel VCSEL array.

This is important: a compact array of parallel VCSELs does not automatically cover a large room. If all emitters point in the same direction, increasing divergence only broadens the footprint around the optical axis. Room-scale coverage requires steering, pre-oriented/microlensed emitters, spatially distributed access points, or large divergence.

### Divergence angle

Treat `theta_div` as a **design parameter**, not necessarily a dynamically controlled actuator.

For a given VCSEL package and operating point, the divergence angle can be considered fixed and calibrated. The paper should evaluate multiple fixed divergence angles:

```text
theta_div in {5 deg, 10 deg, 15 deg, 20 deg, 30 deg}
```

A separate discussion may note that dynamically adjustable divergence is possible using optics, lensing, or system-level beam control, but this is not required for the baseline paper.

---

## Channel model

### Geometry

Let:

- `r_t` be the known transmitter position.
- `r` be the unknown receiver position.
- `d = ||r - r_t||`.
- `n_d = (r - r_t) / d`, the unit direction from transmitter to receiver.
- `n_t,i` be the unit orientation of the VCSEL beam in slot `i`.
- `n_r` be the known receiver normal.

Define the beam angular offset:

```math
phi_i = arccos(n_t,i^T n_d).
```

Define receiver incidence:

```math
cos(psi) = - n_r^T n_d
```

assuming the receiver normal points toward the transmitter under nominal alignment. Check the sign convention with the existing TCOM/broadcast codebase and keep it consistent.

### Gaussian VCSEL pattern

There are two useful versions of the Gaussian model.

#### 1. Shape-only normalized model

```math
R_G(phi_i; theta_div) = exp[-2 (phi_i / theta_div)^2].
```

This model normalizes the boresight gain to 1. It is useful to isolate the effect of angular shape.

#### 2. Fixed emitted-power model

For a physically fair comparison across divergence angles, include the spreading factor:

```math
mu_i(r) = C * [1 / (theta_div^2 d^2)]
          * exp[-2 (phi_i / theta_div)^2]
          * cos(psi)
```

with visibility/FOV constraints.

This follows the far-field Gaussian beam relation:

```math
w(d) approx d * theta_div,
I(d, phi) proportional to P_t / [theta_div^2 d^2]
                 * exp[-2 (phi / theta_div)^2].
```

The fixed-power model should be the main physical model. The shape-only model can be used as a control experiment.

### Compact amplitude form

The model can still be written as:

```math
mu_i = eta * R_G(phi_i; theta_div)
```

where `eta` includes distance, transmit power, receiver incidence, optical area, concentrator gain, etc. If using fixed emitted power, `eta` may also include `1 / theta_div^2`, or that factor can be kept outside explicitly.

Be explicit and consistent.

### Noise model

Assume averaged RSS observations:

```math
hat_mu_i = mu_i + epsilon_i,
epsilon_i ~ N(0, sigma^2 / N)
```

or equivalently define the variance of the averaged measurement directly as `sigma_mu^2`.

Use the same convention as the previous papers where possible.

---

## Estimation methods

### Main estimator: pattern-aware NLS / MLE

The main estimator should be NLS/MLE using the correct Gaussian pattern.

For direction estimation, define:

```math
R_i(n) = R_G(arccos(n_t,i^T n); theta_div).
```

Given measured RSS vector `hat_mu`, use the profiled-amplitude objective:

```math
hat_eta(n) = [R(n)^T hat_mu] / [R(n)^T R(n)]
```

and estimate direction by:

```math
hat_n_d = argmin_n ||hat_mu - hat_eta(n) R(n)||^2
```

or equivalently maximize the normalized correlation:

```math
hat_n_d = argmax_n [R(n)^T hat_mu]^2 / [R(n)^T R(n)].
```

Then recover distance using the same broadcast-positioning logic, with the correct Gaussian model and known receiver orientation.

### Baseline estimators

Use Lambertian GLS/WLS only as weak or mismatched baselines if useful. They are not exact for Gaussian patterns.

Recommended baseline set:

1. **Gaussian NLS / pattern-aware MLE**: main method.
2. **Lambertian-equivalent GLS using m_eff**: optional mismatch baseline.
3. **Coarse grid + NLS refinement**: robust version of the main estimator.
4. **kNN fingerprinting or small MLP**: optional data-driven baseline, especially if later extending to arrays or measured patterns.

Do not let machine learning replace the model-based core of the paper. The paper's strength is bounds + physically interpretable estimation.

---

## Bounds and metrics

### Fisher information and PEB

Compute the Fisher information matrix:

```math
I(r) = (N / sigma^2) sum_i [grad_r mu_i(r)] [grad_r mu_i(r)]^T.
```

Then:

```math
PEB(r) = sqrt(trace(I(r)^(-1))).
```

If `I(r)` is singular or poorly conditioned, mark the position as uncovered or outage.

The Gaussian derivative is:

```math
R'_G(phi) = -4 phi / theta_div^2 * exp[-2 (phi / theta_div)^2].
```

The full gradient should include distance dependence, incidence dependence, and the angular derivative through `phi_i`. Implement carefully and validate numerically with finite differences.

### Coverage

Coverage is essential for VCSEL.

Define a covered point as one satisfying both:

1. SNR/received-power condition:

```math
max_i mu_i(r) >= mu_min
```

or an averaged SNR threshold.

2. Information condition:

```math
I(r) is full rank and cond(I(r)) <= cond_max
```

or equivalently `PEB(r)` is finite and below a maximum bound.

Coverage percentage:

```math
Coverage = (# covered positions) / (# all testbed positions).
```

### Outage

Define outage probability or outage fraction:

```math
Outage = 1 - Coverage.
```

For Monte Carlo simulations, also define error-outage:

```math
P_out(tau) = Pr(||hat_r - r|| > tau).
```

Use thresholds such as 5 cm or 10 cm depending on the scenario.

### RMSE and local RMSE

For each testbed position `p` and Monte Carlo trial `m`:

```math
e_{p,m} = ||hat_r_{p,m} - r_p||.
```

Local RMSE at position `p`:

```math
rho_p = sqrt(1/M sum_m e_{p,m}^2).
```

Spatial RMSE:

```math
RMSE = sqrt(1/P sum_p rho_p^2).
```

Report metrics over:

1. All positions, with outage handled explicitly.
2. Covered positions only.

Do not hide poor coverage by reporting RMSE only on points that receive strong signal.

### Recommended table metrics

For each `(K, theta_div)`:

- Coverage [%]
- Spatial RMSE over covered region [cm]
- P90 local RMSE over covered region [cm]
- Mean local RMSE over covered region [cm]
- Outage [%]
- PEB mean / P90 over covered region [cm]
- Scan slots `K`
- Relative scan latency

---

## Codebook design

### Orientation codebooks

Study several codebook types:

1. **Inherited Lambertian/TCOM codebooks**: baseline.
2. **Uniform spherical cap codebooks**: simple non-optimized baseline.
3. **Gaussian-PEB-optimized codebooks**: optimized specifically for each `theta_div` and `K`.
4. **Coverage-aware optimized codebooks**: optimize PEB plus coverage/outage.

### Optimization objective

A good objective for Gaussian VCSEL should combine accuracy and coverage:

```math
J = mean_{covered r} PEB(r) + lambda_out * Outage + lambda_cond * penalty_conditioning.
```

Alternative:

```math
J = P90_PEB_covered + lambda_out * Outage.
```

Use a genetic algorithm, differential evolution, simulated annealing, or multi-start local optimization. Reuse the previous TCOM codebook optimization framework when possible.

### Key design variable

For each divergence angle, optimize or evaluate:

```text
K in {5, 9, 15, 25, 49}
theta_div in {5, 10, 15, 20, 30} degrees
```

The key result should be a map showing which combinations of `(K, theta_div)` achieve acceptable coverage and accuracy.

---

## Comparison baselines

### Lambertian LED baseline

Compare against the previous LED Lambertian model using:

- same room/testbed geometry,
- same receiver height(s),
- same measurement noise convention,
- comparable scan slots `K`,
- either fixed boresight SNR or fixed emitted optical power.

Do not overclaim VCSEL superiority. Expect:

- VCSEL may outperform in central/covered regions.
- LED may outperform in full-region coverage for small `K`.
- VCSEL may require larger `K` or larger divergence for full coverage.

### Dense scanning VCSEL baseline

Optional but useful. Compare sparse codebook against dense scanning:

- Dense scan: many orientations over a regular angular grid.
- Sparse scan: optimized `K` orientations.

Metric:

```text
Accuracy vs number of scan slots
Coverage vs number of scan slots
```

The paper should not claim to beat dense scanning in best-case accuracy. The argument is that sparse optimized scans may achieve useful positioning with much lower scan overhead.

### Cambridge-style VCSEL OWC coverage context

Use Cambridge/Tavakkolnia-style work as motivation, not as a direct competitor:

- Their focus: OWC coverage/SINR, dense VCSEL arrays, divergence adaptation.
- Our focus: RSS-based 3D positioning with a single steerable VCSEL and optimized sparse scans.

The paper can include a discussion:

> Dense VCSEL-array OWC systems achieve coverage spatially through many emitters and/or divergence adaptation. This work studies the complementary single-beam positioning problem, where coverage is achieved temporally through a sparse orientation codebook.

---

## Proposed figures

### Fig. 1: Radiation pattern comparison

**Script:** `fig01_pattern_comparison.py`

Plot angular radiation profiles:

- Lambertian LED: `cos^m(phi)` for representative `m`.
- Gaussian VCSEL for `theta_div = 5, 10, 20, 30 deg`.

Use both linear and dB scale if possible.

Message:

> VCSEL beams are much narrower than Lambertian LEDs; divergence is a key design parameter.

---

### Fig. 2: Footprint / coverage intuition

**Script:** `fig02_vcsel_footprint.py`

For a ceiling height `H`, plot the floor footprint of a single downward VCSEL for several `theta_div` values.

Approximate radius:

```math
r = H tan(theta_div).
```

Optionally show Gaussian intensity heatmaps on the floor.

Message:

> A single non-steered VCSEL covers only a limited area; steering or large divergence is needed for room-scale OWP.

---

### Fig. 3: Coverage vs K for several divergence angles

**Script:** `fig03_coverage_vs_K_theta.py`

For each `theta_div`, evaluate codebooks with different `K` and compute coverage percentage.

Curves:

```text
theta_div = 5, 10, 15, 20, 30 deg
```

X-axis:

```text
K
```

Y-axis:

```text
Coverage [%]
```

Message:

> Narrow beams require more orientations to cover the same testbed.

---

### Fig. 4: PEB vs K for several divergence angles

**Script:** `fig04_peb_vs_K_theta.py`

Compute mean/P90 PEB over covered points.

Two possible panels:

1. Mean PEB over covered positions.
2. P90 PEB over covered positions.

Message:

> Small divergence can provide strong local accuracy where covered, but coverage must be considered jointly.

---

### Fig. 5: Accuracy-coverage trade-off map

**Script:** `fig05_accuracy_coverage_tradeoff.py`

Each point corresponds to a pair `(K, theta_div)`. Plot:

- X-axis: Coverage [%]
- Y-axis: P90 PEB or P90 local RMSE [cm]
- Marker color: `theta_div`
- Marker size or label: `K`

Message:

> The useful operating region is a Pareto frontier in coverage and accuracy.

---

### Fig. 6: Heatmaps of PEB for representative cases

**Script:** `fig06_peb_heatmaps.py`

Show floor heatmaps for selected configurations:

- `K=9, theta_div=10 deg`
- `K=25, theta_div=10 deg`
- `K=9, theta_div=20 deg`
- LED Lambertian baseline, optional.

Message:

> The spatial structure of errors/coverage changes strongly with divergence and number of orientations.

---

### Fig. 7: Monte Carlo RMSE vs PEB

**Script:** `fig07_mc_rmse_vs_peb.py`

Run Monte Carlo simulations for selected configurations and compare:

- Gaussian NLS RMSE.
- PEB.
- Optional mismatched Lambertian estimator.

Use local RMSE over positions and spatial CDF if useful.

Message:

> Pattern-aware NLS tracks the VCSEL PEB in the covered region.

---

### Fig. 8: Sparse scan vs dense scan

**Script:** `fig08_sparse_vs_dense_scan.py`

Compare optimized sparse codebooks against a dense angular raster scan.

X-axis:

```text
Number of scan slots
```

Y-axis:

```text
Coverage [%], P90 RMSE, or P90 PEB
```

Message:

> Sparse optimized codebooks can approach dense-scan performance with fewer slots.

---

### Fig. 9: Optional estimator comparison

**Script:** `fig09_estimators_comparison.py`

Compare:

- Gaussian NLS / MLE.
- Coarse grid + NLS refinement.
- Lambertian GLS with `m_eff`.
- kNN fingerprinting or small MLP.

Message:

> Model-aware NLS is efficient and accurate when the VCSEL pattern is known; data-driven baselines are useful but require training samples.

---

## Proposed scripts and modules

### Core modules

#### `patterns.py`

Implements radiation patterns:

```python
class Pattern:
    def value(phi): ...
    def derivative(phi): ...

class LambertianPattern(Pattern):
    # R(phi) = cos(phi)^m

class GaussianVCSELPattern(Pattern):
    # R(phi) = exp(-2*(phi/theta_div)^2)
```

Include both normalized Gaussian and fixed-power Gaussian scaling.

#### `geometry.py`

Functions:

- generate testbed grid.
- compute distances.
- compute `n_d`.
- compute incidence angle.
- compute beam offset `phi_i`.
- enforce FOV/visibility.

#### `channel.py`

Functions:

- compute noiseless `mu_i(r)`.
- compute SNR.
- add Gaussian noise.
- handle fixed boresight SNR vs fixed emitted power.

#### `fim.py`

Functions:

- analytic gradient of `mu_i`.
- numerical finite-difference gradient for validation.
- compute FIM.
- compute PEB.
- compute rank/conditioning.

#### `coverage.py`

Functions:

- coverage mask based on SNR threshold.
- coverage mask based on FIM rank/conditioning.
- outage fraction.
- covered-region statistics.

#### `codebooks.py`

Functions:

- load previous Lambertian codebooks.
- generate uniform spherical cap codebooks.
- generate dense scanning codebooks.
- optimize codebooks for VCSEL using GA/differential evolution.

#### `estimators.py`

Functions:

- Gaussian pattern-aware NLS.
- profiled amplitude estimator.
- distance recovery using known receiver orientation.
- coarse grid search initializer.
- optional GLS with effective Lambertian exponent.
- optional fingerprinting baseline.

#### `metrics.py`

Functions:

- local RMSE.
- spatial RMSE.
- P90 local RMSE.
- APE.
- P_out.
- PEB mean/P90.
- coverage-aware summaries.

#### `config.py`

Central configuration:

- room dimensions.
- transmitter height.
- receiver height(s).
- receiver FOV.
- photodiode area.
- optical power.
- noise variance.
- `theta_div` list.
- `K` list.
- Monte Carlo trials.

---

## Recommended simulation workflow

### Step 1: Validate Gaussian pattern implementation

- Plot `R(phi)` and `R'(phi)`.
- Verify derivative using finite differences.
- Verify fixed-power scaling: boresight intensity decreases as `1/theta_div^2` for larger divergence.

### Step 2: Reproduce Lambertian baseline

Use the previous Lambertian code and verify that PEB/RMSE results match the old TCOM/broadcast scripts.

### Step 3: Implement Gaussian VCSEL FIM

- Compute PEB heatmaps for fixed simple codebooks.
- Validate analytic gradients against numerical gradients.
- Check rank/conditioning maps.

### Step 4: Sweep `(K, theta_div)`

For each combination:

1. Generate or load codebook.
2. Compute coverage.
3. Compute PEB statistics.
4. Store results in a structured CSV/JSON.

Output file:

```text
results/sweep_K_theta.csv
```

Columns:

```text
K, theta_div_deg, codebook_type, coverage, outage, mean_peb_cm, p90_peb_cm, median_peb_cm, mean_snr_db, p90_rmse_cm, notes
```

### Step 5: Optimize VCSEL codebooks

For each selected `(K, theta_div)`, optimize orientations using objective:

```text
P90_PEB_covered + lambda_out * outage
```

Store codebooks:

```text
codebooks/vcsel_K09_theta10.json
codebooks/vcsel_K25_theta10.json
...
```

### Step 6: Monte Carlo estimator validation

For selected cases only, run MC simulations:

- `K=9, theta=20 deg`
- `K=15, theta=15 deg`
- `K=25, theta=10 deg`
- LED baseline, optional.

Compare RMSE to PEB.

### Step 7: Dense scan comparison

Generate dense scans with increasing number of slots and compare against sparse optimized codebooks.

### Step 8: Paper figures and tables

Produce final figures and tables from saved results, not directly from long simulations.

---

## Suggested paper structure

### I. Introduction

- VCSELs are attractive for OWC/6G due to narrow beams, high bandwidth, and compatibility with optical wireless communication.
- Narrow beams make positioning different from Lambertian LED OWP.
- The challenge is not only accuracy but coverage.
- Existing dense scanning or array-based VCSEL approaches can achieve coverage through many beams or adaptive divergence.
- This paper studies the complementary sparse single-beam problem.

### II. System model

- Single steerable Gaussian VCSEL.
- Receiver with known orientation.
- RSS measurements over `K` orientations.
- Gaussian beam model.
- Fixed-power and/or fixed-boresight-SNR normalization.

### III. Bounds and coverage metrics

- FIM and PEB.
- Coverage definition.
- Outage.
- Accuracy-coverage trade-off.

### IV. Estimation

- Pattern-aware NLS/MLE.
- Amplitude profiling.
- Distance recovery.
- Optional mismatched baselines.

### V. Codebook design

- Uniform vs inherited vs VCSEL-optimized codebooks.
- Objective combining PEB and coverage.

### VI. Numerical results

- Pattern comparison.
- Coverage vs `K` and `theta_div`.
- PEB/RMSE vs `K` and `theta_div`.
- Heatmaps.
- NLS vs PEB.
- Sparse vs dense scan.

### VII. Conclusion

- VCSEL beam narrowing creates a fundamental divergence-coverage-accuracy trade-off.
- Sparse optimized scans can recover useful 3D positioning information, but coverage must be explicitly designed.
- Future work: arrays, divergence control, measured/non-Gaussian VCSEL far-field patterns, ambiguity-aware design.

---

## Important technical cautions

1. Do not claim all VCSELs are Gaussian.
2. Do not claim divergence is dynamically controllable unless the hardware supports it.
3. Do not compare divergence angles only under fixed boresight SNR; include fixed-power comparison.
4. Do not report RMSE only over covered positions without also reporting coverage/outage.
5. Do not use Lambertian GLS/WLS as if exact for Gaussian VCSELs.
6. Do not claim to outperform dense scanning in best-case precision; compare scan efficiency.
7. Do not rely on a parallel VCSEL array for coverage unless elements are pre-oriented, steered, microlensed, or spatially distributed.

---

## Minimal viable result set

If time is limited, produce only these:

1. Fig. 1: Radiation pattern comparison.
2. Fig. 2: Coverage vs `K` for multiple `theta_div`.
3. Fig. 3: P90 PEB vs `K` for multiple `theta_div`.
4. Fig. 4: Accuracy-coverage Pareto plot.
5. Fig. 5: PEB heatmaps for three representative cases.
6. Table 1: Best `(K, theta_div)` configurations under coverage constraints.
7. Fig. 6: Monte Carlo NLS RMSE vs PEB for one or two configurations.

This is enough for a focused conference/letter-style paper.

---

## Recommended first coding task for an LLM/research assistant

Create the following Python scripts first:

```text
patterns.py
geometry.py
channel.py
fim.py
coverage.py
codebooks.py
metrics.py
run_sweep_K_theta.py
plot_pattern_comparison.py
plot_coverage_vs_K.py
plot_peb_vs_K.py
plot_accuracy_coverage_tradeoff.py
```

Then validate on a small testbed before running full simulations.

---

## One-sentence paper pitch

A single steerable Gaussian VCSEL can provide highly informative RSS measurements for 3D optical wireless positioning, but unlike a Lambertian LED its narrow beam makes coverage a first-order design constraint; this paper quantifies and optimizes the resulting divergence-coverage-accuracy-latency trade-off.
