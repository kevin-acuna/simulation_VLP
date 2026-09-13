import argparse
from pathlib import Path

import numpy as np

from inference import PositionEstimator, information_metrics
from optics import OpticalModel, ReceiverNoise
from run_study import study_cases


def run(results, name):
    case = next(c for c in study_cases() if c.name == name)
    data = np.load(Path(results)/(name+'_trials.npz'))
    errors = np.linalg.norm(data['estimates']-data['truth'], axis=1)
    index = int(np.argmax(errors))
    truth = data['truth'][index]
    observation = data['measurements'][index]
    model = OpticalModel(case.config)
    noise = ReceiverNoise(bandwidth=100*len(case.config.radii))
    bounds = [[-case.half_width, case.half_width]]*2 + ([[0., 1.]] if case.dimensions == 3 else [])
    print('index', index, 'truth', truth, 'saved_estimate', data['estimates'][index], 'error', errors[index], flush=True)
    print('truth_information', information_metrics(model, truth, noise, case.dimensions)['peb'], flush=True)
    print('truth_weighted_residual', np.sum(((model.power_at(truth)-observation)/noise.sigma(observation))**2), flush=True)
    for grid, starts in [(51, 6), (51, 16), (81, 12)]:
        estimator = PositionEstimator(model, bounds, noise, grid_counts=(grid, grid, 9)[:case.dimensions], starts=starts)
        fit = estimator.fit(observation)
        print('grid', grid, 'starts', starts, 'fit', fit, 'error', np.linalg.norm(fit.position-truth), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--results', default='results')
    parser.add_argument('--case', default='grid_convex_core_2d')
    args = parser.parse_args()
    run(args.results, args.case)
