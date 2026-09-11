# Cambridge MATLAB research project

## Scope

The fixed-LED / reorientable-PD study lives in `System`, `Bounds (3D)`, `Design of the Parameters (CRLB design)`, and `tests`. `digital_twin_ows` is a separate nested application; do not add its tree to the MATLAB path or modify it for this study. Preserve unrelated existing working-tree changes.

## Execution and verification

Verified with MATLAB R2026a on Windows. The numerical implementation uses base MATLAB (`pagesvd`, `pagemtimes`, `matlab.unittest`) and does not require Optimization, Statistics, or Parallel Computing toolboxes. `pagesvd` requires MATLAB R2021b or later; older releases have not been tested.

From the repository root in MATLAB:

```matlab
addpath('CAMBRIDGE');
run_cambridge('test');
results = run_cambridge('full');
```

`run_cambridge('quick')` is a coarse-grid integration check, not the publication-resolution design. Each design invocation creates a timestamped output directory. The returned `results.output_directory` locates CSV tables, the complete MAT dataset, and editable FIG/vector PDF/PNG figures. Tests create and clean up their own temporary artifacts.

All editable experiment inputs are in `System/Parameters/system_parameters.m`. A custom parameter struct can be supplied as `run_cambridge('full', p)`. `p.output.export_figures=false` runs calculations and table/MAT export without rendering figures. `p.output.visible='on'` shows figures during rendering; exported FIG files can be opened afterwards.

Compile the mathematical derivation from `Bounds (3D)/Position Error Bound` after ensuring the `build` directory exists:

```text
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=build PEB_derivation.tex
bibtex build/PEB_derivation
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=build PEB_derivation.tex
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=build PEB_derivation.tex
```

The derivation uses `PEB_references.bib` and the TeX Live `IEEEtran.bst` style. Run BibTeX from the source directory as above so it can locate the bibliography while writing its outputs into `build`.

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
