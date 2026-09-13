import argparse
import csv
import json
from pathlib import Path

import numpy as np
from numpy.testing import assert_allclose

from optics import OpticalModel
from run_study import error_summary, study_cases


def verify(results):
    results = Path(results)
    rows = {}
    for scope in ('tile', 'grid'):
        with (results/f'summary_{scope}.csv').open(encoding='utf-8') as stream:
            rows.update({r['case']: r for r in csv.DictReader(stream)})
        manifest = json.loads((results/f'manifest_{scope}.json').read_text(encoding='utf-8'))
        assert manifest['random_trials_per_case'] == 300
        assert manifest['grid_resolution'] == 61
        assert manifest['seed'] == 20260912
    assert set(rows) == {case.name for case in study_cases()}
    total = 0
    for case in study_cases():
        row = rows[case.name]
        data = np.load(results/(case.name+'_trials.npz'))
        model = OpticalModel(case.config)
        count = int(data['random_trial_count'])
        assert count == 300
        assert data['measurements'].shape == (count+(9 if case.dimensions == 2 else 27), model.n_channels)
        assert np.all(np.isfinite(data['measurements']))
        assert np.all(np.isfinite(data['estimates']))
        summary = error_summary(data['truth'][:count], data['estimates'][:count])
        for key, value in summary.items():
            assert_allclose(float(row[key]), value, rtol=1e-10, atol=1e-14)
        gain = 1.08 if case.gain_unknown else 1.
        assert_allclose(gain*model.power_at(data['truth'][:3]), data['noiseless_mean'][:3], rtol=1e-12, atol=1e-20)
        grid = np.load(results/(case.name+'_map.npz'))
        expected = 61*61*(5 if case.dimensions == 3 else 1)
        assert len(grid['points']) == expected
        assert len(grid['peb']) == expected
        assert not np.any(np.isnan(grid['peb']))
        assert np.all(grid['peb'] > 0)
        assert np.all(grid['rank'] <= case.dimensions)
        total += count
    for required in ('robustness.csv', 'ray_validation.csv', 'ray_validation_R10.csv',
                     'diversity_controls.csv', 'design_sweep.csv', 'grid_tilt_sweep.csv',
                     'noise_area_tradeoff.csv', 'radial_ambiguity.csv'):
        assert (results/required).is_file(), required
    print(f'Verified {len(rows)} cases, {total} random localization trials, boundaries, saved observations, maps and summaries.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--results', default='results')
    verify(parser.parse_args().results)
