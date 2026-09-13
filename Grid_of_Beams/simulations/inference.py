from dataclasses import dataclass

import numpy as np
from scipy.optimize import least_squares

from optics import ReceiverNoise


def information_metrics(model, positions, noise=ReceiverNoise(), dimensions=3, gain_mode='known'):
    power, gradient = model.power_and_jacobian(positions)
    power = np.atleast_2d(power)
    gradient = gradient.reshape((-1, model.n_channels, 3))[..., :dimensions]
    sigma = noise.sigma(power)
    whitened = gradient/sigma[..., None]
    if gain_mode != 'known':
        groups = [np.ones(model.n_channels, dtype=bool)] if gain_mode == 'common' else [model.state_ids == k for k in np.unique(model.state_ids)]
        for mask in groups:
            g = power[:, mask]/sigma[:, mask]
            norm2 = np.sum(g*g, axis=1)
            j = whitened[:, mask, :]
            projection = np.einsum('ni,nij->nj', g, j)/np.maximum(norm2[:, None], 1e-300)
            whitened[:, mask, :] -= g[..., None]*projection[:, None, :]
    _, singular, vh = np.linalg.svd(whitened, full_matrices=False)
    valid = (singular[:, -1] > 1e-9*singular[:, 0]) & (singular[:, -1] > 1e-12)
    variance = np.sum(vh**2/np.maximum(singular[..., None]**2, 1e-300), axis=1)
    variance[~valid] = np.inf
    return {
        'peb': np.sqrt(np.sum(variance, axis=1)),
        'axis_std': np.sqrt(variance),
        'singular': singular,
        'rank': np.sum((singular > 1e-9*singular[:, :1]) & (singular > 1e-12), axis=1),
        'condition': singular[:, 0]/np.maximum(singular[:, -1], 1e-300),
        'visible_5sigma': np.sum(power > 5*sigma, axis=1),
        'max_power': power.max(axis=1),
    }


def cartesian_grid(bounds, counts, height=0.):
    axes = [np.linspace(lo, hi, count) for (lo, hi), count in zip(bounds, counts)]
    mesh = np.meshgrid(*axes, indexing='ij')
    points = np.column_stack([m.ravel() for m in mesh])
    if len(bounds) == 2:
        points = np.column_stack((points, np.full(len(points), height)))
    return points


@dataclass
class PositionFit:
    position: np.ndarray
    gain: float
    cost: float
    success: bool
    alternate_separation: float
    alternate_cost_gap: float
    evaluations: int


class PositionEstimator:
    def __init__(self, model, bounds, noise=ReceiverNoise(), height=0., gain_unknown=False, grid_counts=None, starts=5):
        self.model = model
        self.bounds = np.asarray(bounds, dtype=float)
        self.dimensions = len(bounds)
        self.height = height
        self.noise = noise
        self.gain_unknown = gain_unknown
        self.starts = starts
        if grid_counts is None:
            grid_counts = (35, 35) if self.dimensions == 2 else (31, 31, 9)
        self.grid = cartesian_grid(bounds, grid_counts, height)
        self.library = model.power_at(self.grid)
        self.library_square = self.library**2
        self.compressed_library = np.arcsinh(self.library/self.noise.sigma(0.))
        self.compressed_norm = np.sum(self.compressed_library**2, axis=1)

    def candidate_costs(self, measurement):
        y = np.asarray(measurement, dtype=float)
        sigma = self.noise.sigma(y)
        weights = 1/sigma**2
        aa = self.library_square @ weights
        ab = self.library @ (weights*y)
        gains = np.clip(ab/np.maximum(aa, 1e-300), .2, 5.) if self.gain_unknown else np.ones_like(aa)
        cost = gains*gains*aa-2*gains*ab+np.sum(y*y*weights)
        return np.maximum(cost, 0), gains, sigma

    def fit(self, measurement):
        y = np.asarray(measurement, dtype=float)
        if y.shape != (self.model.n_channels,) or not np.all(np.isfinite(y)):
            raise ValueError('Supply one finite, labelled power observation per channel.')
        costs, gains, sigma = self.candidate_costs(y)
        compressed = np.arcsinh(np.maximum(y, 0.)/self.noise.sigma(0.))
        compressed_cost = self.compressed_norm-2*self.compressed_library @ compressed
        order = np.column_stack((np.argsort(compressed_cost), np.argsort(costs))).ravel()
        seeds = []
        for idx in order:
            if not seeds or min(np.linalg.norm(self.grid[idx]-self.grid[j]) for j in seeds) >= .12:
                seeds.append(idx)
            if len(seeds) == self.starts:
                break
        lower, upper = self.bounds.T
        if self.gain_unknown:
            lower = np.r_[lower, np.log(.2)]
            upper = np.r_[upper, np.log(5.)]

        def evaluate(state, with_jac=False):
            position = state[:3] if self.dimensions == 3 else np.r_[state[:2], self.height]
            gain = np.exp(state[-1]) if self.gain_unknown else 1.
            power, jac = self.model.power_and_jacobian(position)
            if not with_jac:
                return (gain*power-y)/sigma
            jac = gain*jac[:, :self.dimensions]
            if self.gain_unknown:
                jac = np.column_stack((jac, gain*power))
            return jac/sigma[:, None]

        results = []
        for idx in seeds:
            initial = self.grid[idx, :self.dimensions]
            if self.gain_unknown:
                initial = np.r_[initial, np.log(gains[idx])]
            initial = np.clip(initial, lower+1e-9, upper-1e-9)
            result = least_squares(evaluate, initial, jac=lambda s: evaluate(s, True), bounds=(lower, upper),
                                   x_scale='jac', ftol=1e-10, xtol=1e-10, gtol=1e-8, max_nfev=180)
            results.append(result)
        results.sort(key=lambda r: r.cost)
        best = results[0]
        position = best.x[:3] if self.dimensions == 3 else np.r_[best.x[:2], self.height]
        different = [r for r in results[1:] if np.linalg.norm(r.x[:self.dimensions]-best.x[:self.dimensions]) > .1]
        gap = 2*(different[0].cost-best.cost) if different else np.inf
        separation = np.linalg.norm(different[0].x[:self.dimensions]-best.x[:self.dimensions]) if different else 0.
        return PositionFit(position, float(np.exp(best.x[-1])) if self.gain_unknown else 1., 2*best.cost,
                           bool(best.success), float(separation), float(gap), sum(r.nfev for r in results))
