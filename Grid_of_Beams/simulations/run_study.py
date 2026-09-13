import argparse
import csv
import json
import platform
from dataclasses import asdict, dataclass, replace
from pathlib import Path

import matplotlib
import numpy as np
import scipy

from design_sweep import finite_quantile
from inference import PositionEstimator, cartesian_grid, information_metrics
from optics import OpticalConfig, OpticalModel, ReceiverNoise


@dataclass(frozen=True)
class Case:
    name: str
    config: OpticalConfig
    half_width: float
    dimensions: int = 3
    frustum: bool = True
    gain_unknown: bool = False


def study_cases():
    baseline = OpticalConfig()
    convex = replace(baseline, radii=(.012, .015))
    diverging = replace(baseline, radii=(-.010, -.011), edge_thickness=.006)
    cases = []
    for name, config, width in [('tile_baseline_core', baseline, .45),
                                ('tile_baseline_ninth', baseline, 5/6),
                                ('tile_convex_core', convex, .6),
                                ('tile_diverging_ninth', diverging, 5/6),
                                ('grid_baseline_full', replace(baseline, tiles=9), 2.5),
                                ('grid_convex_core', replace(convex, tiles=9), 1.8),
                                ('grid_diverging_full', replace(diverging, tiles=9), 2.5),
                                ('grid_convex_retilted_full', replace(baseline, tiles=9, tilt_deg=27., radii=(.010, .012, .015)), 2.5)]:
        for dim in (2, 3):
            cases.append(Case(f'{name}_{dim}d', config, width, dim))
    cases += [Case('tile_convex_ninth_3d', convex, 5/6),
              Case('tile_scan8_ninth_3d', replace(baseline, radii=(.010, .011, .012, .013, .015, .017, .020, .025)), 5/6),
              Case('tile_diverging_single_3d', replace(diverging, radii=(-.010,)), 5/6),
              Case('grid_convex_full_3d', replace(convex, tiles=9), 2.5),
              Case('tile_diverging_prism_3d', diverging, 5/6, frustum=False),
              Case('grid_diverging_prism_3d', replace(diverging, tiles=9), 2.5, frustum=False)]
    cases += [replace(c, name=c.name+'_unknown_gain', gain_unknown=True) for c in cases
              if c.name in ('tile_baseline_core_3d', 'tile_diverging_ninth_3d', 'grid_diverging_full_3d')]
    return cases


def sample_positions(case, count, rng):
    points = np.zeros((count, 3))
    points[:, :2] = rng.uniform(-case.half_width, case.half_width, (count, 2))
    if case.dimensions == 3:
        u = rng.uniform(size=count)
        points[:, 2] = 3-(27-19*u)**(1/3) if case.frustum else u
        if case.frustum:
            points[:, :2] *= (3-points[:, 2:3])/3
    return points


def boundary_positions(case):
    heights = [0., .5, 1.] if case.dimensions == 3 else [0.]
    points = np.array([[x*case.half_width, y*case.half_width, z] for z in heights
                       for x in (-1, 0, 1) for y in (-1, 0, 1)], dtype=float)
    if case.frustum:
        points[:, :2] *= (3-points[:, 2:3])/3
    return points


def metric_grid(case, resolution):
    heights = 5 if case.dimensions == 3 else 1
    points = cartesian_grid([[-case.half_width, case.half_width]]*2 + [[0., 1.]], (resolution, resolution, heights))
    if case.frustum:
        points[:, :2] *= (3-points[:, 2:3])/3
    return points


def batched_metrics(model, points, noise, dimensions, gain_mode):
    pieces = [information_metrics(model, chunk, noise, dimensions, gain_mode) for chunk in np.array_split(points, max(1, int(np.ceil(len(points)/512))))]
    return {key: np.concatenate([p[key] for p in pieces]) for key in pieces[0]}


def error_summary(truth, estimates):
    delta = estimates-truth
    error = np.linalg.norm(delta, axis=1)
    count = len(error)
    failures = int(np.count_nonzero(error > .1))
    phat = failures/count
    z = 1.95996398454
    denominator = 1+z*z/count
    center = (phat+z*z/(2*count))/denominator
    radius = z*np.sqrt(phat*(1-phat)/count+z*z/(4*count*count))/denominator
    return {
        'count': count, 'median_m': float(np.median(error)), 'p95_m': float(np.quantile(error, .95)),
        'max_m': float(error.max()), 'rmse_m': float(np.sqrt(np.mean(error**2))),
        'rmse_x_m': float(np.sqrt(np.mean(delta[:, 0]**2))),
        'rmse_y_m': float(np.sqrt(np.mean(delta[:, 1]**2))),
        'rmse_z_m': float(np.sqrt(np.mean(delta[:, 2]**2))),
        'fraction_error_1cm': float(np.mean(error < .01)),
        'fraction_error_10cm': float(np.mean(error < .1)),
        'failure_10cm_wilson95_low': float(max(0, center-radius)),
        'failure_10cm_wilson95_high': float(min(1, center+radius)),
    }


def write_csv(path, rows):
    with Path(path).open('w', encoding='utf-8', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def clean_json(value):
    if isinstance(value, dict):
        return {k: clean_json(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [clean_json(v) for v in value]
    if isinstance(value, np.ndarray):
        return clean_json(value.tolist())
    if isinstance(value, (float, np.floating)) and not np.isfinite(value):
        return None
    if isinstance(value, np.generic):
        return value.item()
    return value


def run_case(case, output, trials, resolution, seed):
    model = OpticalModel(case.config)
    noise = ReceiverNoise(bandwidth=100*len(case.config.radii))
    gain_mode = 'common' if case.gain_unknown else 'known'
    points = metric_grid(case, resolution)
    metrics = batched_metrics(model, points, noise, case.dimensions, gain_mode)
    np.savez_compressed(output/(case.name+'_map.npz'), points=points, **metrics)
    bounds = [[-case.half_width, case.half_width]]*2 + ([[0., 1.]] if case.dimensions == 3 else [])
    counts = (51, 51, 9)[:case.dimensions] if case.config.tiles == 9 else (35, 35, 9)[:case.dimensions]
    estimator = PositionEstimator(model, bounds, noise, gain_unknown=case.gain_unknown, grid_counts=counts, starts=6)
    rng = np.random.default_rng(seed)
    truth = sample_positions(case, trials, rng)
    boundary = boundary_positions(case)
    all_truth = np.vstack((truth, boundary))
    true_gain = 1.08 if case.gain_unknown else 1.
    mean = true_gain*model.power_at(all_truth)
    measurements = mean + noise.sigma(mean)*rng.normal(size=mean.shape)
    fits = [estimator.fit(y) for y in measurements]
    estimates = np.array([f.position for f in fits])
    np.savez_compressed(output/(case.name+'_trials.npz'), truth=all_truth, estimates=estimates,
                        measurements=measurements, noiseless_mean=mean, gains=[f.gain for f in fits],
                        optimizer_success=[f.success for f in fits], cost=[f.cost for f in fits],
                        alternate_gap=[f.alternate_cost_gap for f in fits],
                        alternate_separation=[f.alternate_separation for f in fits],
                        random_trial_count=trials)
    summary = {'case': case.name, 'tiles': case.config.tiles, 'K': len(case.config.radii),
               'dimensions': case.dimensions, 'half_width_floor_m': case.half_width,
               'region': 'frustum' if case.frustum else 'prism', 'gain': gain_mode,
               'pilot_integration_seconds': .125*case.config.tiles,
               'grid_count': len(points), 'grid_peb_median_m': finite_quantile(metrics['peb'], .5),
               'grid_peb_p95_m': finite_quantile(metrics['peb'], .95), 'grid_peb_max_m': float(metrics['peb'].max()),
               'grid_fraction_peb_10cm': float(np.mean(metrics['peb'] < .1)),
               'grid_fraction_full_rank': float(np.mean(metrics['rank'] == case.dimensions)),
               'grid_minimum_visible_5sigma': int(metrics['visible_5sigma'].min()),
               **error_summary(truth, estimates[:trials]),
               'boundary_p95_m': float(np.quantile(np.linalg.norm(estimates[trials:]-boundary, axis=1), .95)),
               'boundary_max_m': float(np.linalg.norm(estimates[trials:]-boundary, axis=1).max()),
               'optimizer_success_fraction': float(np.mean([f.success for f in fits])),
               'alternative_gap_below9_fraction': float(np.mean([f.alternate_cost_gap < 9 for f in fits]))}
    audit_truth = sample_positions(case, min(24, trials), np.random.default_rng(seed+9000))
    audit_estimates = np.array([estimator.fit(model.power_at(p)).position for p in audit_truth])
    summary['noiseless_audit_max_error_m'] = float(np.linalg.norm(audit_truth-audit_estimates, axis=1).max())
    far_distances = []
    for p in audit_truth:
        costs, _, _ = estimator.candidate_costs(model.power_at(p))
        far = np.linalg.norm(estimator.grid-p, axis=1) >= .1
        far_distances.append(float(np.sqrt(costs[far].min())))
    summary['sampled_far_fingerprint_min_sigma'] = min(far_distances)
    print(case.name, {k: round(summary[k], 5) for k in ('median_m', 'p95_m', 'rmse_m', 'fraction_error_10cm', 'boundary_max_m')}, flush=True)
    return summary, {'case': asdict(case), 'noise': asdict(noise), 'optics': model.diagnostics(), 'seed': seed,
                     'fingerprint_far_sigma': far_distances}


def robustness(output, trials, seed):
    selected = [c for c in study_cases() if c.name in ('tile_baseline_core_3d', 'tile_convex_core_3d', 'tile_diverging_ninth_3d', 'grid_diverging_full_3d')]
    rows, arrays = [], {}
    for case in selected:
        rng = np.random.default_rng(seed)
        model = OpticalModel(case.config)
        noise = ReceiverNoise(bandwidth=100*len(case.config.radii))
        bounds = [[-case.half_width, case.half_width]]*2 + [[0., 1.]]
        estimator = PositionEstimator(model, bounds, noise, starts=5, grid_counts=(45, 45, 9) if case.config.tiles == 9 else (31, 31, 9))
        truth = sample_positions(case, trials, rng)
        mean = model.power_at(truth)
        perturbations = {'matched': mean, 'global_gain_plus2pct': 1.02*mean,
                         'vcsel_calibration_1pct': mean*(1+.01*np.tile(rng.normal(size=25*case.config.tiles), len(case.config.radii))),
                         'residual_background_0p1nW': mean+1e-10,
                         'pd_tilt_3deg': model.power_at(truth, normal=[np.sin(np.deg2rad(3)), 0, np.cos(np.deg2rad(3))])}
        for magnitude in (.001, .01):
            actual = OpticalModel(replace(case.config, radii=tuple(r*(1+magnitude) for r in case.config.radii)))
            perturbations[f'curvature_error_{100*magnitude:g}pct'] = actual.power_at(truth)
        perturbations['edge_thickness_plus0p1mm'] = OpticalModel(replace(case.config, edge_thickness=case.config.edge_thickness+.0001)).power_at(truth)
        errors = rng.normal(size=mean.shape)
        for label, actual in perturbations.items():
            observations = actual+noise.sigma(actual)*errors
            estimated = np.array([estimator.fit(y).position for y in observations])
            rows.append({'case': case.name, 'perturbation': label, **error_summary(truth, estimated)})
            arrays[case.name+'_'+label] = estimated-truth
        print('robustness', case.name, flush=True)
    write_csv(output/'robustness.csv', rows)
    np.savez_compressed(output/'robustness_errors.npz', **arrays)
    return rows


def run(output, trials, resolution, seed, scope, run_robustness):
    output = Path(output)
    output.mkdir(exist_ok=True)
    cases = [c for c in study_cases() if scope == 'all' or c.name.startswith(scope)]
    summaries, manifests = [], []
    for case in cases:
        summary, manifest = run_case(case, output, trials, resolution, seed)
        summaries.append(summary)
        manifests.append(manifest)
        write_csv(output/f'summary_{scope}.csv', summaries)
    metadata = {'seed': seed, 'random_trials_per_case': trials, 'grid_resolution': resolution,
                'python': platform.python_version(), 'numpy': np.__version__, 'scipy': scipy.__version__,
                'matplotlib': matplotlib.__version__, 'cases': manifests,
                'nonfinite_json_values': 'null means an unbounded or numerically unidentifiable result; never zero'}
    if run_robustness:
        metadata['robustness'] = robustness(output, max(40, trials//3), seed+3000)
    (output/f'manifest_{scope}.json').write_text(json.dumps(clean_json(metadata), indent=2, allow_nan=False), encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='results')
    parser.add_argument('--trials', type=int, default=300)
    parser.add_argument('--resolution', type=int, default=61)
    parser.add_argument('--seed', type=int, default=20260912)
    parser.add_argument('--scope', choices=['all', 'tile', 'grid'], default='all')
    parser.add_argument('--robustness', action='store_true')
    args = parser.parse_args()
    run(args.output, args.trials, args.resolution, args.seed, args.scope, args.robustness)
