import argparse
import json

import numpy as np

from inference import PositionEstimator, information_metrics
from optics import OpticalModel, ReceiverNoise
from run_study import clean_json, study_cases


def main():
    cases = {case.name: case for case in study_cases()}
    parser = argparse.ArgumentParser()
    parser.add_argument('--case', choices=cases, default='tile_baseline_core_3d')
    parser.add_argument('--powers', help='CSV file: one labelled power per channel, ordered state / tile / VCSEL.')
    parser.add_argument('--units', choices=['W', 'nW'], default='W')
    parser.add_argument('--position', nargs=3, type=float, default=[.213, -.147, .436])
    parser.add_argument('--seed', type=int, default=20260913)
    args = parser.parse_args()
    case = cases[args.case]
    model = OpticalModel(case.config)
    noise = ReceiverNoise(bandwidth=100*len(case.config.radii))
    truth = None
    if args.powers:
        observation = np.loadtxt(args.powers, delimiter=',').reshape(-1)
        if args.units == 'nW':
            observation *= 1e-9
    else:
        truth = np.array(args.position)
        if case.dimensions == 2:
            truth[2] = 0.
        mean = model.power_at(truth)
        observation = mean + noise.sigma(mean)*np.random.default_rng(args.seed).normal(size=mean.shape)
    bounds = [[-case.half_width, case.half_width]]*2 + ([[0., 1.]] if case.dimensions == 3 else [])
    estimator = PositionEstimator(model, bounds, noise, gain_unknown=case.gain_unknown,
                                  grid_counts=(51, 51, 9)[:case.dimensions] if case.config.tiles == 9 else None)
    fit = estimator.fit(observation)
    metrics = information_metrics(model, fit.position, noise, case.dimensions, 'common' if case.gain_unknown else 'known')
    output = {'case': args.case, 'measurements': model.n_channels, 'position_m': fit.position,
              'gain': fit.gain, 'weighted_squared_residual': fit.cost,
              'optimizer_converged': fit.success, 'local_peb_m': float(metrics['peb'][0]),
              'warning': 'Local bound and optimizer convergence do not certify global uniqueness or physical calibration.'}
    if truth is not None:
        output.update(truth_m=truth, error_m=float(np.linalg.norm(fit.position-truth)))
    print(json.dumps(clean_json(output), indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
