"""
Simulate orientations scenario and compute 90%-CDF RMS error.
"""
import numpy as np
import math
from parameters.setup_parameters import setup_parameters
from optical_wireless.h_los import h_los
from utils.position_estimator import position_estimator
from visualization.visualize_results import visualize_results

def rmse_calculator(n_t_s, n_samples: int = 10000) -> float:
    """
    Run a noise-effect experiment for given transmitter orientations.

    Args:
        n_t_s: list of angles [theta1, rho1, theta2, rho2, ...]
        n_samples: number of noise samples to simulate per point
    Returns:
        cdf90_rms: rms error at 90% CDF
    """
    # get estimated and real positions
    x_est, y_est, x_real, y_real = position_estimator(n_t_s, n_samples)

    # compute RMS error grid
    err = np.sqrt((x_real - x_est)**2 + (y_real - y_est)**2)
    # 90th percentile (CDF) ignoring NaNs
    err_flat = err.flatten()
    err_flat = err_flat[~np.isnan(err_flat)]
    if err_flat.size == 0:
        cdf90 = np.nan
    else:
        cdf90 = np.percentile(err_flat, 90)

    # visualize results
    #visualize_results(n_t_s, x_real, y_real, x_est, y_est)
    return float(cdf90)
