import argparse
import csv
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LogNorm
from matplotlib.patches import Ellipse

from optics import OpticalConfig, OpticalModel


LABELS = {
    'tile_baseline_core': 'Convexa K=1, zona central',
    'tile_baseline_ninth': 'Convexa K=1, noveno completo',
    'tile_convex_core': 'Convexa K=2, zona ampliada',
    'tile_diverging_ninth': 'Concava K=2, noveno completo (ideal)',
    'grid_baseline_full': 'Kazemi K=1, 5 x 5 m',
    'grid_convex_core': 'Convexa K=2, 3.6 x 3.6 m',
    'grid_convex_full': 'Convexa K=2, 5 x 5 m',
    'grid_diverging_full': 'Concava K=2, 5 x 5 m (ideal)',
    'grid_convex_retilted_full': 'Convexa K=3, 27 grados, 5 x 5 m (ideal)',
}


def save(fig, directory, name):
    fig.savefig(directory/(name+'.png'), dpi=180, bbox_inches='tight')
    fig.savefig(directory/(name+'.pdf'), bbox_inches='tight')
    plt.close(fig)


def optics_figure(directory):
    fig, axes = plt.subplots(1, 3, figsize=(13, 4), constrained_layout=True)
    for ax, radii, edge, title in zip(axes, [(.015,), (.012, .015), (-.010, -.011)], [.002, .002, .006],
                                     ['Kazemi, R = 15 mm', 'Convexa, R = 12 / 15 mm', 'Concava, R = -10 / -11 mm']):
        model = OpticalModel(OpticalConfig(radii=radii, edge_thickness=edge))
        centers = model.footprint_centers()
        for i, center in enumerate(centers):
            v = model.directions[i]
            s = np.dot(center-model.origins[i], v)
            q = model.q[i]+s
            w2 = model.config.wavelength/np.pi*abs(q)**2/q.imag
            covariance = w2*(np.eye(2)+np.outer(v[:2], v[:2])/v[2]**2)
            eigen, vectors = np.linalg.eigh(covariance)
            angle = np.rad2deg(np.arctan2(vectors[1, 1], vectors[0, 1]))
            color = ['tab:blue', 'tab:orange'][model.state_ids[i]]
            ax.add_patch(Ellipse(center[:2], 2*np.sqrt(eigen[1]), 2*np.sqrt(eigen[0]), angle=angle,
                                 facecolor='none', edgecolor=color, lw=.7, alpha=.75))
            ax.plot(*center[:2], '.', color=color, ms=2)
        ax.set(xlim=(-1.25, 1.25), ylim=(-1.25, 1.25), xlabel='x [m]', ylabel='y [m]', title=title, aspect='equal')
        ax.plot([-.8333, .8333, .8333, -.8333, -.8333], [-.8333, -.8333, .8333, .8333, -.8333], 'k--', lw=.8)
    fig.suptitle('Huellas a z=0: contorno 1/e^2, modelo Snell + ABCD')
    save(fig, directory, 'optical_footprints')


def maps(results, directory):
    cases = ['tile_baseline_ninth_3d', 'tile_convex_core_3d', 'tile_diverging_ninth_3d',
             'grid_baseline_full_3d', 'grid_convex_core_3d', 'grid_diverging_full_3d']
    fig, axes = plt.subplots(2, 3, figsize=(13, 8), constrained_layout=True)
    for ax, case in zip(axes.ravel(), cases):
        path = results/(case+'_map.npz')
        if not path.exists():
            ax.set_visible(False)
            continue
        data = np.load(path)
        p = data['points']
        mask = np.isclose(p[:, 2], 0.)
        n = round(np.sqrt(mask.sum()))
        x, y = p[mask, 0].reshape(n, n), p[mask, 1].reshape(n, n)
        peb = data['peb'][mask].reshape(n, n)
        image = ax.pcolormesh(x, y, np.minimum(peb, 10), norm=LogNorm(1e-3, 1), cmap='viridis', shading='auto')
        if peb.min() < .1 < peb.max():
            ax.contour(x, y, peb, [.1], colors='white', linewidths=.7)
        ax.set(xlabel='x [m]', ylabel='y [m]', title=LABELS[case[:-3]], aspect='equal')
    fig.colorbar(image, ax=axes.ravel().tolist(), label='PEB 3D [m], ganancia calibrada; blanco = 10 cm', extend='both', shrink=.8)
    save(fig, directory, 'position_information_maps')


def cdf_figure(results, directory, prefix):
    fig, axes = plt.subplots(1, 2, figsize=(12, 4), constrained_layout=True)
    keys = [key for key in LABELS if key.startswith(prefix)]
    for dim, ax in zip((2, 3), axes):
        for index, key in enumerate(keys):
            path = results/(key+f'_{dim}d_trials.npz')
            if not path.exists():
                continue
            data = np.load(path)
            count = int(data['random_trial_count'])
            errors = np.sort(np.linalg.norm(data['truth'][:count]-data['estimates'][:count], axis=1))
            ax.semilogx(np.maximum(errors, 1e-7), np.arange(1, count+1)/count, color=f'C{index}', label=LABELS[key])
        ax.axvline(.01, color='grey', ls=':', lw=.8)
        ax.axvline(.1, color='grey', ls='--', lw=.8)
        ax.set(xlabel='Error euclideo [m]', ylabel='CDF empirica', title=f'Estimacion {dim}D', ylim=(0, 1.01), xlim=(1e-5, 10 if prefix == 'grid' else 3))
        ax.grid(True, alpha=.2)
        ax.legend(fontsize=7, loc='lower right')
    save(fig, directory, prefix+'_error_cdf')


def gain_figure(results, directory):
    fig, ax = plt.subplots(figsize=(8, 4), constrained_layout=True)
    for index, base in enumerate(('tile_baseline_core_3d', 'tile_diverging_ninth_3d', 'grid_diverging_full_3d')):
        for suffix, style in [('', '-'), ('_unknown_gain', '--')]:
            path = results/(base+suffix+'_trials.npz')
            if not path.exists():
                continue
            data = np.load(path)
            n = int(data['random_trial_count'])
            error = np.sort(np.linalg.norm(data['truth'][:n]-data['estimates'][:n], axis=1))
            ax.semilogx(np.maximum(error, 1e-7), np.arange(1, n+1)/n, style, color=f'C{index}',
                        label=base.replace('_3d', '')+(' gain libre' if suffix else ' calibrado'))
    ax.set(xlabel='Error 3D [m]', ylabel='CDF empirica', xlim=(1e-4, 3), ylim=(0, 1.01))
    ax.legend(fontsize=7)
    ax.grid(True, alpha=.2)
    save(fig, directory, 'unknown_gain_failure')


def robustness_figure(results, directory):
    path = results/'robustness.csv'
    if not path.exists():
        return
    with path.open(encoding='utf-8') as stream:
        rows = list(csv.DictReader(stream))
    cases = list(dict.fromkeys(r['case'] for r in rows))
    labels = list(dict.fromkeys(r['perturbation'] for r in rows))
    fig, ax = plt.subplots(figsize=(12, 5), constrained_layout=True)
    for j, case in enumerate(cases):
        values = [float(r['p95_m']) for r in rows if r['case'] == case]
        ax.bar(np.arange(len(labels))+.2*(j-1.5), values, width=.18, label=case)
    ax.set(yscale='log', ylabel='Percentil 95 error 3D [m]', xticks=np.arange(len(labels)))
    ax.set_xticklabels(labels, rotation=25, ha='right', fontsize=8)
    ax.legend(fontsize=7)
    ax.axhline(.1, color='grey', ls='--')
    save(fig, directory, 'calibration_sensitivity')


def ray_figure(results, directory):
    path = results/'ray_validation.csv'
    if not path.exists():
        return
    with path.open(encoding='utf-8') as stream:
        rows = list(csv.DictReader(stream))
    fig, axes = plt.subplots(1, 2, figsize=(12, 4), constrained_layout=True)
    labels = [f"R={r['radius_mm']}\ni={r['channel_1based']}" for r in rows]
    axes[0].bar(np.arange(len(rows))-.15, [float(r['minor_width_ratio']) for r in rows], .3, label='Eje menor')
    axes[0].bar(np.arange(len(rows))+.15, [float(r['major_width_ratio']) for r in rows], .3, label='Eje mayor')
    axes[0].axhline(1., color='black', lw=.8)
    axes[0].set(ylabel='Radio trazado / radio ABCD', xticks=np.arange(len(rows)))
    axes[0].set_xticklabels(labels, fontsize=6)
    axes[0].legend()
    axes[1].bar(np.arange(len(rows)), [float(r['centroid_offset_mm']) for r in rows])
    axes[1].set(ylabel='Desplazamiento centroide [mm]', xticks=np.arange(len(rows)))
    axes[1].set_xticklabels(labels, fontsize=6)
    save(fig, directory, 'ray_model_crosscheck')


def run(results):
    results = Path(results)
    directory = results/'figures'
    directory.mkdir(exist_ok=True)
    plt.rcParams.update({'font.size': 9, 'axes.spines.top': False, 'axes.spines.right': False})
    optics_figure(directory)
    maps(results, directory)
    cdf_figure(results, directory, 'tile')
    cdf_figure(results, directory, 'grid')
    gain_figure(results, directory)
    robustness_figure(results, directory)
    ray_figure(results, directory)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--results', default='results')
    run(parser.parse_args().results)
