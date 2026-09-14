# MATLAB optical positioning study

This study belongs entirely in `Grid_of_Beams/simulation_MATLAB`. Preserve the sibling `simulations` Python directory and the source manuscript. Python preservation is checked against the delivered SHA-256 snapshot.

## Environment and entry points

Verified with MATLAB R2026a and Optimization Toolbox (`lsqnonlin`). No Statistics or Parallel Computing Toolbox is required. `pagesvd` is used. TeX Live provides `pdflatex` for the report.

From the repository root in MATLAB:

```matlab
addpath('Grid_of_Beams/simulation_MATLAB');
gob_paths;
run_gob('test');
run_gob('demo');
r = run_gob('quick');
r = run_gob('full');
run_gob('verify');
run_gob('plots');
compilar_informe;
```

`demo_localizacion.m` is a workspace-oriented debugging script. `gob_localize` accepts a labelled power vector or CSV in watts. New runs create timestamped result directories and reject existing output directories. `resultados/ultimo_completo.mat` points to the last complete reference run; quick outputs are not publication-resolution results.

For batch runs, `matlab -singleCompThread -batch "..."` avoids unnecessary BLAS thread overhead. Root-level `gob_paths` adds only this study's code folders, not unrelated projects.

## Scientific and implementation conventions

- SI internally. Positions and directions are `3 x N`; observations `M x N`; Jacobians `M x 3 x N`.
- Channel order: state, tile, VCSEL. MATLAB central tile is 5 and central VCSEL is 13.
- One PD, no CPC/ADR gain. Known upward normal gives incidence `-normal' * direction`.
- Curvature changes surface thickness, Snell direction and ABCD q together. Do not implement tuning by varying only divergence.
- Distinguish convex Kazemi optics from the exploratory concave extension. Strong negative radii and R=+10 mm show important off-axis discrepancies in ray validation.
- The numerical lens edge thickness is an explicit assumption because the manuscript does not supply it.
- Rank-deficient position bounds are Inf. Mean-only frozen-covariance information is not the exact CRLB of the heteroscedastic model.
- Monte Carlo uses MATLAB `mt19937ar`, not Python PCG64. Native sample statistics need not match Python exactly. Deterministic references are in `referencias/python_reference.mat`; Python is only needed to regenerate that optional migration fixture.
- Use `gob_grid` for endpoint conventions: MATLAB `linspace(a,b,1)` otherwise returns b, unlike NumPy. A 2D map must be at z=0, not z=1.
- Use `gob_read_table` when reading experiment CSV files: numeric-looking lists such as `12,15` must remain strings rather than thousands-separated numbers.
- Preserve negative noisy pilot estimates in the residual. Clipping is only used for noise weighting and compressed seed selection.
- `gob_verify_results` checks statistics against saved trials, optical means, map coordinates and Python preservation. `gob_rebuild_maps` regenerates information maps without changing Monte Carlo measurements/estimates.
- Report actual ROI, calibration assumptions, boundary failures and physical-model limitations. Solver convergence and local rank do not prove global uniqueness.

## Report

The source is `informe/INFORME.tex`, split into seven chapters. `run_gob('report')` regenerates tables and macros from the verified full MATLAB results. `compilar_informe` calls the report generator and runs pdflatex three times. Final PDF: `informe/compilado/INFORME.pdf`. Figures are saved in PNG, vector PDF and editable FIG.
