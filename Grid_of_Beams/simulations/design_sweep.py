import argparse
import csv
import itertools
import json
from dataclasses import asdict, replace
from pathlib import Path

import numpy as np

from inference import cartesian_grid, information_metrics
from optics import OpticalConfig, OpticalModel, ReceiverNoise


def finite_quantile(values, q):
    return float(np.sort(np.asarray(values))[min(len(values)-1, int(q*(len(values)-1)))])


def design_points(half_width, counts=(17, 17, 5), frustum=True, tiles=1):
    points = cartesian_grid([[-half_width, half_width], [-half_width, half_width], [0., 1.]], counts)
    if frustum:
        points[:, :2] *= (3-points[:, 2:3])/3
    return points


def summarize(model, points, noise, dimensions=3, gain_mode='known'):
    metrics = information_metrics(model, points, noise, dimensions, gain_mode)
    peb = metrics['peb']
    return {
        'peb_median_m': finite_quantile(peb, .5),
        'peb_p95_m': finite_quantile(peb, .95),
        'peb_max_m': float(np.max(peb)),
        'fraction_peb_1cm': float(np.mean(peb < .01)),
        'fraction_peb_10cm': float(np.mean(peb < .1)),
        'fraction_full_rank': float(np.mean(metrics['rank'] == dimensions)),
        'minimum_visible_5sigma': int(metrics['visible_5sigma'].min()),
    }


def run(output):
    output = Path(output)
    output.mkdir(exist_ok=True)
    regions = {'tile_core': design_points(.6), 'tile_ninth': design_points(5/6),
               'tile_prism': design_points(5/6, frustum=False)}
    rows = []
    configs = []
    for pitch in (.0015, .002, .00225, .0025):
        valid = []
        for radius in (.010, .011, .012, .013, .015, .017, .020, .025):
            config = OpticalConfig(pitch=pitch, radii=(radius,))
            try:
                OpticalModel(config)
                valid.append(radius)
            except ValueError:
                continue
        for states in [(r,) for r in valid] + list(itertools.combinations(valid, 2)) + [tuple(valid)]:
            configs.append((f'pitch{1000*pitch:g}', replace(config, radii=states)))
    for label, changed in [('short_gap', {'array_lens_distance': .001}),
                           ('waist3um', {'waist': 3e-6}),
                           ('waist2um', {'waist': 2e-6}),
                           ('large_array', {'pitch': .004, 'diameter': .028, 'tile_spacing': .030})]:
        candidates = (.013, .015, .020, .025) if label != 'large_array' else (.020, .022, .025, .030)
        for states in [(r,) for r in candidates]+list(itertools.combinations(candidates, 2)):
            configs.append((label, OpticalConfig(radii=states, **changed)))
    for label, config in configs:
        try:
            model = OpticalModel(config)
        except ValueError:
            continue
        noise = ReceiverNoise(bandwidth=100*len(config.radii))
        for region, points in regions.items():
            summary = summarize(model, points, noise)
            row = {'variant': label, 'region': region, 'pitch_mm': config.pitch*1000,
                   'radii_mm': ','.join(f'{1000*r:g}' for r in config.radii), 'K': len(config.radii),
                   **summary, 'config_json': json.dumps(asdict(config))}
            rows.append(row)
    with (output/'design_sweep.csv').open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    for region in regions:
        candidates = [r for r in rows if r['region'] == region]
        candidates.sort(key=lambda r: (-r['fraction_peb_10cm'], r['K'], r['peb_p95_m']))
        print('\nREGION', region, flush=True)
        for row in candidates[:12]:
            print({k: v for k, v in row.items() if k != 'config_json'}, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='results')
    run(parser.parse_args().output)
