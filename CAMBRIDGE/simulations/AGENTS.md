# Cambridge MATLAB research project

## Scope

The fixed-LED / reorientable-PD study lives in `System`, `Bounds (3D)`, `Design of the Parameters (CRLB design)`, and `tests`. `digital_twin_ows` is a separate nested application; do not add its tree to the MATLAB path or modify it for this study. Preserve unrelated existing working-tree changes.

## Execution and verification

Verified with MATLAB R2026a on Windows. The numerical implementation uses base MATLAB (`pagesvd`, `pagemtimes`, `matlab.unittest`) and does not require Optimization, Statistics, or Parallel Computing toolboxes. `pagesvd` requires MATLAB R2021b or later; older releases have not been tested.

From the repository root in MATLAB:

```matlab
addpath('CAMBRIDGE/simulations');
run_cambridge('test');
results = run_cambridge('full');
```

`run_cambridge('quick')` is a coarse-grid integration check, not the publication-resolution design. Each design invocation creates a timestamped output directory. The returned `results.output_directory` locates CSV tables, the complete MAT dataset, and editable FIG/vector PDF/PNG figures. Tests create and clean up their own temporary artifacts.

`System/Parameters/system_parameters.m` contains shared defaults. For exploratory work, edit the parameter block at the top of one independent script in `Design of the Parameters (CRLB design)`: `sim01_PEB_vs_inclination.m`, `sim02_PEB_vs_K.m`, `sim03_PEB_vs_A_PD.m`, or `sim04_PEB_heatmap.m`. Each script runs alone using MATLAB's Run button, prints fixed/swept parameters, saves a timestamped MAT/CSV/parameter manifest, and leaves its figures open. From the repository root, call `addpath('CAMBRIDGE/simulations'); cambridge_setup();` before invoking a script by name.

Calculations live in `studies/study_*.m` and never plot or optimize implicitly. Rendering lives in `plotting/plot_PEB_*.m`; appearance is controlled by a separate `style = ieee_plot_style()` struct. Use `replot_experiment(mat_file, style)` to redraw saved data without recomputing physics, or pass a third argument (`inclination`, `K`, `area`, `heatmap`, `heatmap_best`) to select part of a complete-design dataset. Replots use new sibling directories and resolve paths from the supplied MAT file, not stale paths stored before the project was moved.

`rx_cone_cases` creates editable cases. Cone normals are regenerated from K/tilt/azimuth before evaluation. For arbitrary or optimized normals use `family='explicit'`; these are frozen, printed, and cannot be silently resized by the K sweep. `rx_cases_from_design` imports a complete design only when explicitly requested. The investigator edits the independent scripts directly; do not assume they all use the same tilt or historical optical parameters. Keep their explicit settings and results distinct from the saved full-design benchmark.

The complete workflow remains available as `run_cambridge('full', p)`, with its own `p.output.export_figures` and `p.output.visible` controls. Independent scripts use `style.export`, `style.visible`, and `style.keep_open`. New entry points and renderers do not clear the workspace, close unrelated figures, or overwrite existing exports. Preserve any explicit `clc`/`close all` commands the investigator has added to their earlier scripts.

Compile the mathematical derivation from `Bounds (3D)/Position Error Bound` after ensuring the `build` directory exists:

```text
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=build PEB_derivation.tex
bibtex build/PEB_derivation
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=build PEB_derivation.tex
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=build PEB_derivation.tex
```

The derivation uses `PEB_references.bib` and the TeX Live `IEEEtran.bst` style. Run BibTeX from the source directory as above so it can locate the bibliography while writing its outputs into `build`.

The full project report is `Bounds (3D)/Position Error Bound/Project_report.tex`. Compile it with the same four-command sequence, replacing `PEB_derivation` by `Project_report`. It includes the derivation summary, assumptions, file responsibilities, experiment/replot examples, and the verified benchmark figures. Its result and figure paths deliberately point to a particular saved run, not whichever run happens to be newest. Journal export uses the `exportgraphics` Padding option, verified in R2026a; the full graphics workflow is not claimed to support older releases.

## Constrained-design experiments

- `sim05_tilt_limited_feasibility.m`: joint tilt-constrained search over FOV, LED half-angle, K, area and patterns, with both sample budgets. `tilt_constraint='maximum'` allows tilt up to the cap; `'fixed'` only permits fixed-tilt families and azimuth refinement. Every actual normal must satisfy the cap. `refine_selected` explicitly controls local refinement.
- Feasibility is bound-based: complete regular 3D coverage, full-grid RMS below `target_peb_m`, and `min_target_coverage` of points with PEB below that target. Target coverage is not a probability of achieved estimator error. The selected row minimizes samples, then area, then K, then RMS among feasible grid candidates; `minimum_error_row` and `feasible_tradeoffs.csv` provide other choices. Every resource-frontier candidate is checked on the dense validation grid.
- `sim06_K_information_and_coverage.m`: regenerated cones, nested golden prefixes and repeated triplets distinguish angular diversity from extra observations. K counts acquisition slots for the repeated-triplet control. Do not claim monotonic coverage for nonnested codebooks, or 1/sqrt(K) gain with fixed total samples.
- `sim07_power_noise_and_samples.m`: exact scaling under fixed optical Gaussian noise; the input noise factors multiply standard deviation, not variance. The base sample count is scalar and the sweep sets equal counts per orientation.
- `sim08_tilt_FOV_coverage_limits.m`: finite-codebook coverage versus the optimistic spherical-cap visibility envelope. Increasing area, power or samples cannot repair a point outside all admissible FOV cones.
- Joint area sweeps store base PEB arrays plus scale/index metadata rather than repeating identical physics for every area. This shortcut is only valid for the declared position-independent optical noise model.
- Tests must not hard-code old default power or area into assertions that use current `system_parameters`; the researcher changes these values frequently.

## Generalized receiver, estimators and sensitivity

- `p.receiver.m_R` is the effective total receiver cosine exponent, positive and defaulting to 1. It replaces the original single cosine, not an extra factor on top of it. Missing fields in historical MAT files default to 1. The eight original design scripts expose this parameter without changing their plots.
- Preserve `PEB_derivation.tex` as the original m_R=1 derivation. The generalized derivation is `Bounds (3D)/Position Error Bound/PEB_derivation_mR.tex` and uses the same BibTeX sequence with the new basename.
- Optional `transmitter.pattern_asymmetry` defaults to 0. A nonzero value activates a calibrated positive quadrupolar perturbation with zero azimuthal average, not a measured commercial LED model. `pattern_reference` sets its transverse direction. `rx_emission_pattern` supplies the corresponding derivative.
- `Estimators/rx_estimate` accepts K-by-trial matrices of optical power means, unit normal columns, parameters, optional sample counts, and solver options. LS is a direct root-linear fit; GLS/WLS are explicitly ratio-based first-order methods; NLS fits all three optical coordinates jointly in raw power. For m_R=1 with equal variances, LS and NLS legitimately coincide. The old `System/rx_position_gls` is restricted to m_R=1.
- `Estimator comparisons/sim01_estimators_vs_PEB.m`, `sim02_estimators_vs_mR.m` and `sim03_LED_pattern_calibration.m` are independent comparisons. Their small ROI guarantees complete visibility for all four methods; do not supply a truth mask or claim that these algorithms solve arbitrary unknown clipped masks. Use `replot_estimator_results` to change figures without recomputing estimates.
- Negative Gaussian observations are not clipped. For m_R != 1, root-based methods report invalid roots as failures; NLS uses raw signed observations. CDFs retain failure mass, and conditional RMSE is reported separately. Graphical CDFs may be rank-thinned, while complete observations and errors are saved.
- `Estimators/Algorithms_report.tex` uses local `estimator_references.bib`; compile with pdflatex, bibtex build/Algorithms_report, and two pdflatex passes from that directory.
- `Reorientation sensitivity` was implemented after completing the generalized model and algorithm report. Its three scripts distinguish independent pose-measurement errors, unobserved independent actuation errors, and a common attitude-measurement rotation. Angular inputs are variances per local component in deg^2, not raw azimuth variances, and persist over all optical samples of an orientation.
- `rx_pose_error_peb` is the local joint RSS/pose-measurement nuisance CRLB (full correlated covariance for common attitude). `rx_actuation_peb` is explicitly a small-angle Gaussian-moment approximation, including variance derivatives, not the exact marginalized CRLB. Do not label either as the perfect-known-perturbed-pose oracle bound. See `Reorientation sensitivity/Sensitivity_report.tex`.
- `rx_test_parameters` fixes the physical fixture for analytic tests independently of editable research defaults. Verify with `run_cambridge('test')`.

## TCOM equivalence and target coverage

- Start reading `LEER_PRIMERO_Resumen_proyecto.tex` (PDF in the root `build` directory). It indexes the specialized reports, the original fifteen experiments plus the three paper-PD experiments, and current limitations.
- `NLS` remains a backward-compatible alias for `NLS_joint`. `NLS_TCOM` uses the paper's normalized direction/scale objective with tangent-plane LM, followed by amplitude profiling and distance recovery from the same K measurements. The two objectives are related by an invertible optical-coordinate change on a shared full-visibility domain; do not claim identical solvers or the same cooperative K+1 protocol. GLS/WLS reproduce the paper's ratio/eigenvector principle, with receiver order replacing emitter order. Optional `reference_index=1` fixes the paper's reference; 0 selects maximum power.
- `Estimators/Estimators_derivation_TCOM.tex` contains detailed Spanish derivations, six pseudocodes, and first-order GLS caveats. Compile with the existing IEEEtran BibTeX workflow from `Estimators`.
- `p.design.coverage_threshold_cm=Inf` preserves finite regular coverage; a finite value such as 10 selects finite PEB <= 10 cm. The threshold never censors RMS or changes FOV/rank. Results preserve `regular_coverage`, `RegularCoverage_percent`, and the selected `coverage`, `Coverage_percent`, `CoverageThreshold_cm`. Legacy MAT plots without explicit threshold metadata retain regular-coverage labels.
- The eight original design experiments inherit the threshold from system parameters. Their separate feasibility targets (`target_peb_m`, full regular coverage, quantiles) remain explicit and unchanged. The historical full-design optimizer still minimizes full-domain RMS; it is not silently converted to a coverage optimizer.
- `Coverage target design/sim01_K5_tilt_coverage.m` fixes K=5, m_R=1.9 and a 10 cm coverage threshold, sweeps uniform-cone tilt on design and validation grids, and uses editable `orientation_std_deg` (STANDARD DEVIATION, squared before calling the variance-based pose bound). This bound is the joint RSS/pose-measurement nuisance CRLB, not unobserved-actuation marginal CRLB.
- Its absolute acceptance level (`minimum_coverage_percent=95`) is distinct from proximity to each grid's maximum (`near_peak_loss_pp=1`). Infeasible levels stay NaN. `grid_agreement.csv` records requirements on both grids; none certifies continuous-volume coverage. Monte Carlo checks use explicit full-visibility points, not an oracle mask or whole-room achieved coverage. Replot via `replot_K5_target_results`.
- At m_R=1.9 the half-response angle is near 46 degrees, but this is NOT a hard FOV cutoff. The current 46-degree FOV is retained as configured; verify the photodiode specification before drawing hardware conclusions.
- `Coverage target design/K5_tilt_report.tex` and the root overview use ordinary pdflatex passes (no bibliography). Their `build` folders must exist before compilation.

## Calibrated PD response models (Bastiaens 2020)

- The reference PDF is `CAMBRIDGE/papers/[PD REFERENCE] Impact of a Photodiode’s Angular Characteristics on RSS-Based VLP Accuracy.pdf`, DOI 10.1109/ACCESS.2020.2991298. Its equations (3), (5), (6), Table 1 and Section III-A2 define the implemented presets. These are rounded literature parameters, not new measurements of this hardware.
- `receiver.response_model` selects `cosine_power` (default and fallback for historical MAT files), `bastiaens_sq`, `bastiaens_sqapprox` or `bastiaens_exp`. Shared `rx_receiver_response` returns response and derivative with respect to incidence cosine; `rx_channel`, `rx_peb` and the pose-nuisance bound use the matching derivatives.
- `Receiver models/Bastiaens 2020/Parameters/bastiaens2020_parameters(base, device, family, outer_fov_deg, receiver_order)` preserves base power, area and noise. The optional fifth argument overrides the order of `cosine`/`cosine_mR`; empty uses the published order. `cosine_1` always uses order one. Paper device area/transimpedance are metadata, not silent gain multipliers. Non-cosine presets remove the irrelevant `m_R` field. Do not multiply another projected-area cosine into SQ/Exp.
- PDA100A2: cosine order 1.9, SQ psi_3dB=0.61 rad, Exp psi_half=0.80 rad and slope 2.39. PDA36A2: 0.98, 0.79 rad, 1.06 rad and 2.30. SQ's 3 dB reference is response 1/sqrt(2), NOT 1/2. Its natural zeros are 64.580/83.636 degrees, combined with any earlier external aperture. SQ is continuous at its natural zero but has a derivative kink; it does not eliminate all cutoffs.
- `pd_fit_estimate` implements general-response joint/profile NLS and NONLINEAR ratio GLS/WLS, with multistart and explicit ambiguity/failure diagnostics. `sqapprox_ls` is a special harmonic/constrained-algebraic estimator for SQapprox, a common cone and full visibility. It must not be used as an exact SQ estimator. Legacy `rx_estimate`, `rx_receiver_order` and cosine actuation-moment formulas reject paper presets.
- For a general response h(s), test the rank of [h,diag(h')*H*E], not just H. A finite local bound can coexist with global mirror ambiguities. Seed directions must be unit vectors; compute sums before MATLAB bracket concatenation to avoid accidentally splitting a vector expression.
- Dedicated scripts: `sim01_paper_PD_responses`, `sim02_paper_K5_PEB`, `sim03_paper_PD_estimators`. The first two now default to `families={'cosine_1','cosine','SQ'}`. `cosine_fov_deg` is the user-chosen PD half-angle cutoff for BOTH cosines; `outer_fov_deg` controls SQ/other paper profiles, in addition to their intrinsic zeros. Neither changes the LED half-power angle or derives a cutoff from the half-response angle. `m_R=[]` retains each device's published cosine order. Legacy saved five-model studies remain unchanged, including their wide-cosine controls; never relabel them as new three-model data.
- Legends come from actual saved receiver parameters, not a manually supplied list; model selection/reordering must carry the matching label, cutoff and PEB derivation. Angular plot axes are 0--90 degrees (with a tick at 90), independently of the computed mechanical sweep. Spatial x/y axes stay in metres. `plot_pd_K5` exports a map for every selected model and works without SQ. Derivative plots break across nonregular cutoffs even when the cutoff is between angular-grid nodes.
- `sim02_paper_K5_PEB` explicitly links `PEB_derivation.tex` for the nominal m_R=1 bound and the sensitivity report for uncertain normals. Its default `orientation_structure='independent'` means uncertain individual global PD normals with a known global reference frame, NOT an extra common attitude rotation and NOT exact normal knowledge. Plots use sigma_orient; the common_rotation alternative is labeled sigma_attitude. See the model report's guide for all axis definitions.
- Under independent isotropic normal errors, sigma_orient is the standard deviation of EACH of two Gaussian tangent coordinates. The small angular separation magnitude is Rayleigh, not a signed Gaussian: its RMS is sqrt(2)*sigma_orient and its 95th percentile is 2.4477*sigma_orient. Do not silently reinterpret the existing parameter as total angular RMS or attitude-control tracking error.
- `plot_pd_K5` includes a fixed dotted grey 10 cm reference on the conditional RMS-PEB axes only. This display guide does not modify coverage thresholds or imply that every point has PEB below 10 cm.
- The estimator experiment uses matched SQ as SYNTHETIC truth, not actual measured RSS. `replot_paper_PD` redraws the explicit saved MAT without calculations.
- Read `PD_K5_results.tex` first inside the paper folder; `PD_models_and_PEB.tex` covers critical reading and the general FIM; `PD_estimators.tex` contains derivations and pseudocodes. Compile from that folder with pdflatex, bibtex build/<basename>, and two pdflatex passes; all use `bastiaens2020_references.bib`.
- The article's SQapprox R2 text and Table 2 disagree slightly; no missing fit coefficients or measured curves were invented. Fresnel/cos(ax) presets are not supplied without an explicit, verified convention/parameter set. Exp tails above about 1.3 rad are not experimentally validated by assuming the formula continues.

## Scientific conventions

- Positions and normals are columns: receiver positions `3 x P`, commanded normals `3 x K`; optical means are `K x P`, position Jacobians `K x 3 x P`.
- Internal geometry is SI; field names identify degrees, square metres, watts, and optical per-sample noise variance in watts squared. FOV is a half-angle, distinct from LED half-power angle. No concentrator is assumed by default.
- `u=(t-r)/norm(t-r)` points from PD to LED, opposite to `n_d` in the earlier transmitter-steering manuscripts.
- Receiver orientations are known globally, the PD position is constant during a scan, and optical gain is calibrated. Do not silently treat a relative gimbal attitude or unknown transmitted power as known.
- Rank-deficient 3D bounds are `Inf`. Hard-FOV/emission boundary points are `NaN` with an explicit diagnostic. Never use a pseudoinverse to turn an unobservable coordinate into a finite PEB or silently omit outages from a full-volume score.
- Report conditional RMS and coverage separately. Design selection minimizes full-grid RMS with complete regular coverage. Dense-grid checks are not certificates of coverage on a continuous volume.
- Uniform-cone K sets are not nested. Distinguish fixed samples per orientation from fixed total samples. The individual-angle refinement is local, not globally optimal.
- `rx_position_gls` is a full-visibility reference estimator, not a general estimator for unknown FOV masks.
- The original paper grids and noise values are documented in `F_broadcast_Konly/paper/main.tex`; no MATLAB codebooks optimized for transmitter steering are reused as receiver-steering optima.
