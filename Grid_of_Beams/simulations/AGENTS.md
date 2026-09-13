# Optical positioning simulations

All development for this study belongs in this directory. Do not modify the source manuscript in the adjacent paper directory.

## Environment and verification

Verified with Python 3.12.8, NumPy 1.26.4, SciPy 1.14.0 and Matplotlib 3.9.0. The environment already supplies these packages.

Run from this directory:

- `python -m unittest discover -v`
- `python localize.py`
- `python design_sweep.py`
- `python run_study.py --scope tile --trials 300 --resolution 61`
- `python run_study.py --scope grid --trials 300 --resolution 61 --robustness`
- `python ray_validation.py`
- `python additional_checks.py`
- `python verify_results.py`
- `python plot_results.py`

For efficient numerical runs set `OPENBLAS_NUM_THREADS=1` and `OMP_NUM_THREADS=1` before starting Python. PowerShell syntax: `$env:OPENBLAS_NUM_THREADS = "1"`.

Use a different `--output` directory for quick experiments so reference results are preserved. Plotting takes `--results` rather than `--output`.

## Conventions

- Model parameters and coordinates use SI units. Receiver height is the global z coordinate, not the optical propagation distance.
- Channel order is lens state, tile, VCSEL. The central tile is index 4 in the nine-tile layout; local central VCSEL is index 12 (zero based).
- A single receiver PD has no CPC or ADR concentration gain. Its known upward normal gives the incidence factor `-normal @ beam_direction`.
- Preserve the coupling of curvature, surface thickness, Snell directions and ABCD q transformation. A focal sweep must not only change divergence.
- The paper omits numerical lens thickness; the edge thickness is an explicit simulation assumption.
- Distinguish positive-radius Kazemi optics from the exploratory signed-radius concave extension.
- Match final results to the estimator version: rerun both tile and grid studies after changing inference.
- Infinite information bounds must remain infinite (JSON null with metadata), not become zero through a pseudoinverse.
- Report the actual ROI, absolute-gain/orientation assumptions, noisy Monte Carlo errors and boundary failures. Optimizer convergence, a finite Jacobian rank and a local CRLB do not establish robust global localization.
- Ray validation shows substantial off-axis departures from the circular Gaussian model for R=+10 mm and the strong negative-radius designs. Do not present their matched-model millimetric errors as experimentally validated performance.
