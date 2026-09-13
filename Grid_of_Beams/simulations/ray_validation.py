import argparse
from dataclasses import replace
from pathlib import Path

import numpy as np

from optics import OpticalConfig, OpticalModel
from run_study import write_csv


def snell(directions, normals, ratio):
    cosine = np.einsum('ij,ij->i', directions, normals)
    discriminant = 1-ratio**2*(1-cosine**2)
    valid = (discriminant >= 0) & (cosine > 0)
    transmitted = ratio*directions + (np.sqrt(np.maximum(discriminant, 0))-ratio*cosine)[:, None]*normals
    return transmitted, valid


def trace_beam(config, channel, count=200000, seed=193):
    model = OpticalModel(config)
    radius = config.radii[0]
    rng = np.random.default_rng(seed)
    random = rng.normal(size=(count//2, 4))
    random = np.concatenate((random, -random))
    count = len(random)
    waist_xy = model.local_xy[channel] + config.waist/2*random[:, :2]
    slopes = config.wavelength/(2*np.pi*config.waist)*random[:, 2:]
    incoming = np.column_stack((slopes, np.ones(count)))
    incoming /= np.linalg.norm(incoming, axis=1)[:, None]
    entry = np.column_stack((waist_xy+config.array_lens_distance*slopes, np.full(count, config.array_lens_distance)))
    normal = np.broadcast_to([0., 0., 1.], incoming.shape)
    inside, valid = snell(incoming, normal, 1/config.index)
    valid &= np.sum(entry[:, :2]**2, axis=1) <= (config.diameter/2)**2
    center = np.array([0., 0., config.array_lens_distance+model.center_thicknesses[0]-radius])
    shifted = entry-center
    b = np.einsum('ij,ij->i', shifted, inside)
    discriminant = b*b-np.sum(shifted**2, axis=1)+radius**2
    valid &= discriminant >= 0
    distance = -b+np.sign(radius)*np.sqrt(np.maximum(discriminant, 0))
    exit_points = entry+distance[:, None]*inside
    valid &= (distance > 0) & (np.sum(exit_points[:, :2]**2, axis=1) <= (config.diameter/2)**2)
    normal = (exit_points-center)/radius
    output, refracted = snell(inside, normal, config.index)
    tir_fraction = float(np.mean(valid & ~refracted))
    valid &= refracted & (output[:, 2] > 0)
    target_distance = (3-exit_points[:, 2])/np.maximum(output[:, 2], 1e-12)
    intercepts = exit_points[valid] + target_distance[valid, None]*output[valid]
    xy = intercepts[:, :2]
    mean = xy.mean(axis=0)
    covariance = np.cov(xy, rowvar=False)
    widths = 2*np.sqrt(np.linalg.eigvalsh(covariance))
    v = model.local_directions[0][channel]
    origin = np.r_[model.local_xy[channel], config.array_lens_distance+model.thicknesses[0][channel]]
    s = (3-origin[2])/v[2]
    prediction = origin+s*v
    q = model.local_q[0][channel]+s
    w2 = config.wavelength/np.pi*abs(q)**2/q.imag
    predicted_covariance = w2/4*(np.eye(2)+np.outer(v[:2], v[:2])/v[2]**2)
    predicted_widths = 2*np.sqrt(np.linalg.eigvalsh(predicted_covariance))
    residual = xy-mean
    mahalanobis2 = np.einsum('ni,ij,nj->n', residual, np.linalg.inv(covariance), residual)
    return {
        'radius_mm': radius*1000, 'edge_thickness_mm': config.edge_thickness*1000,
        'channel_1based': channel+1, 'rays': count, 'transmitted_fraction': float(np.mean(valid)),
        'tir_fraction': tir_fraction, 'centroid_offset_mm': float(1000*np.linalg.norm(mean-prediction[:2])),
        'ray_width_minor_mm': float(widths[0]*1000), 'ray_width_major_mm': float(widths[1]*1000),
        'abcd_width_minor_mm': float(predicted_widths[0]*1000), 'abcd_width_major_mm': float(predicted_widths[1]*1000),
        'minor_width_ratio': float(widths[0]/predicted_widths[0]), 'major_width_ratio': float(widths[1]/predicted_widths[1]),
        'gaussian_fourth_moment_ratio': float(np.mean(mahalanobis2**2)/8),
    }


def run(output, count):
    output = Path(output)
    output.mkdir(exist_ok=True)
    configs = [OpticalConfig(radii=(r,)) for r in (.012, .015)]
    configs += [OpticalConfig(radii=(r,), edge_thickness=.006) for r in (-.010, -.011)]
    rows = [trace_beam(c, i, count=count) for c in configs for i in (12, 2, 0)]
    write_csv(output/'ray_validation.csv', rows)
    for row in rows:
        print(row, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='results')
    parser.add_argument('--rays', type=int, default=200000)
    args = parser.parse_args()
    run(args.output, args.rays)
