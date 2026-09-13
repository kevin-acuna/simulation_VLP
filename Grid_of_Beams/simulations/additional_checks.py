import argparse
from dataclasses import replace
from pathlib import Path

import numpy as np

from design_sweep import design_points, summarize
from optics import OpticalConfig, OpticalModel, ReceiverNoise
from ray_validation import trace_beam
from run_study import write_csv


def run(output):
    output = Path(output)
    output.mkdir(exist_ok=True)
    noise = ReceiverNoise()
    rows = []
    for states in ((.015,), (.015, .015), (.012, .015), (.015,)*8,
                   (.010, .011, .012, .013, .015, .017, .020, .025)):
        for mode in ('known', 'common', 'per_state'):
            model = OpticalModel(OpticalConfig(radii=states))
            for width in (.45, .6, 5/6):
                rows.append({'radii_mm': ','.join(str(r*1000) for r in states), 'K': len(states),
                             'half_width_m': width, 'gain_mode': mode,
                             **summarize(model, design_points(width), replace(noise, bandwidth=100*len(states)), gain_mode=mode)})
    write_csv(output/'diversity_controls.csv', rows)
    rows = []
    for tilt in (21., 24., 27., 30., 33.):
        for states in ((.015,), (.012, .015), (.010, .013), (.011, .015), (.010, .012, .015), (.010, .012, .015, .017)):
            model = OpticalModel(OpticalConfig(tiles=9, radii=states, tilt_deg=tilt))
            rows.append({'tilt_deg': tilt, 'radii_mm': ','.join(str(r*1000) for r in states), 'K': len(states),
                         **summarize(model, design_points(2.5, counts=(25, 25, 5)), replace(noise, bandwidth=100*len(states)))})
    write_csv(output/'grid_tilt_sweep.csv', rows)
    rows = []
    for bandwidth in (10., 100., 1000., 10000.):
        for area in (1e-7, 1e-6, 1e-5):
            for states, width in [((.015,), .45), ((.012, .015), .6)]:
                model = OpticalModel(OpticalConfig(radii=states, pd_area=area))
                n = replace(noise, bandwidth=bandwidth*len(states))
                rows.append({'bandwidth_hz_per_reference_pilot': bandwidth, 'pd_area_mm2': area*1e6,
                             'radii_mm': ','.join(str(r*1000) for r in states),
                             'tile_integration_seconds': 25/(2*bandwidth),
                             **summarize(model, design_points(width), n)})
    write_csv(output/'noise_area_tradeoff.csv', rows)
    rows = []
    for states, edge in [((.015,), .002), ((.012, .015), .002), ((-.010, -.011), .006)]:
        model = OpticalModel(OpticalConfig(radii=states, edge_thickness=edge))
        p1 = np.array([.21, -.14, .2])
        p2 = np.r_[p1[:2]*(3-.8)/(3-p1[2]), .8]
        first, second = model.power_at([p1, p2])
        sigma = replace(noise, bandwidth=100*len(states)).sigma(first)
        gain = np.sum(first*second/sigma**2)/np.sum(second**2/sigma**2)
        rows.append({'radii_mm': ','.join(str(r*1000) for r in states), 'separation_m': float(np.linalg.norm(p1-p2)),
                     'gain_on_second_position': float(gain),
                     'calibrated_distance_sigma': float(np.linalg.norm((first-second)/sigma)),
                     'free_gain_distance_sigma': float(np.linalg.norm((first-gain*second)/sigma))})
    write_csv(output/'radial_ambiguity.csv', rows)
    write_csv(output/'ray_validation_R10.csv', [trace_beam(OpticalConfig(radii=(.010,)), i) for i in (12, 2, 0)])
    print('Saved controls, tilt sweep, noise/area trade-off, radial ambiguity and R=10 mm ray check.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='results')
    run(parser.parse_args().output)
