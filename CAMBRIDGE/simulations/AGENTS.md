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
