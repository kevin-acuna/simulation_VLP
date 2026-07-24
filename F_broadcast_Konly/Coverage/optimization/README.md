# Coverage optimization (REAL / experiment-aligned parameters)

Independent copy of the broadcast (K-only) PEB optimization, kept separate from
`../../optimization/` so you can modify it freely.

## Difference vs `../../optimization/`
The original `optimize_PEB_Konly_parallel.m` **hardcodes** the old 45-deg setup
(`Pt=0.405`, `Phi_half=45`, large PD, `FOV=85`). This driver instead **loads the
real parameters** from `../system_params_coverage.m` (SFH4725S LED @ `Phi_half=36.7`,
BPX61 PD, `FOV=60`, `sigma2`, `N=1000`, room). That file is the single source of
truth, so the optimized codebooks are consistent with the coverage analysis.

## Objective (lexicographic: coverage + accuracy)
The GA minimizes
```
obj = (1 - coverage) + acc_norm/(N+1)
```
- `coverage` = fraction of (FOV-filtered) positions with `PEB_B <= PEB_QoS`.
- `acc_norm` = aggregate(`PEB_B` among covered)/`PEB_QoS` in [0,1], a strict
  tie-breaker (accuracy) that can never override a coverage difference (its
  weight `1/(N+1)` is below the coverage step `1/N`).
- Unlocalizable points (`PEB_B = Inf`) simply count as "not covered": they are
  penalized via the coverage term and are NEVER excluded from the denominator,
  and no arbitrary large PEB value is injected. This removes both failure modes
  of the old objective (excluding Inf -> shrink coverage; magic 50/100 caps).

Set `PEB_QoS` (default 0.05 m) and `optimization_metric` (the accuracy
aggregator among covered points: `mean`|`max`|`rms`|`percentile_90`) in the
CONFIG block. Each K also reports real metrics: coverage % and median/mean/P90
PEB among covered.

## Files
- `optimize_PEB_Konly_coverage.m` : GA driver (edit the CONFIG block).
- `PEB_Konly_objective.m`         : PEB_B objective (independent copy).
- `PEB_Konly_monitor.m`           : GA live-plot monitor (independent copy).
- `results/PEB_Konly_coverage/K_*`: per-K logs + `optimization_results.mat`.

## Run
```matlab
run('optimize_PEB_Konly_coverage.m')
```
Requires the Global Optimization and Parallel Computing toolboxes.

## Notes
- `FILTER_INFOV=true` drops receiver positions outside the PD FOV (unreachable
  regardless of LED tilt) so the objective is not diluted by a constant penalty.
- Each run prints a copy-paste line `orientations_DEBreal_K<K> = [...]`. Paste it
  into `../system_params_coverage.m` and reference it from a new preset (e.g.
  `'DEB_real'`) or replace the `DEB_45` values.
