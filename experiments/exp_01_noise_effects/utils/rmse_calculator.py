"""
Simulate orientations scenario and compute 90%-CDF RMS error.
"""
import numpy as np
import math
from parameters.setup_parameters import setup_parameters
from optical_wireless.h_los import h_los
from position_estimators.estimate_position import estimate_position
# from visualization.visualize_results import visualize_results  # optional

def rmse_calculator(n_t_s, n_samples: int = 10000) -> float:
    """
    Run a noise-effect experiment for given transmitter orientations.

    Args:
        n_t_s: list of angles [theta1, rho1, theta2, rho2, ...]
        n_samples: number of noise samples to simulate per point
    Returns:
        cdf90_rms: rms error at 90% CDF
    """
    params = setup_parameters()
    # unpack
    P_t = params['P_t']
    m_t = params['m_t']
    coord_t = params['coord_t']
    z_ref = params['z_ref']
    p = params['p']
    q = params['q']
    FOV = params['FOV']
    n_r = np.array(params['n_r'])
    R_pd = params['R_pd']
    N0 = params['N0']
    BW = params['signal_bandwidth']
    testbed = params['testbed']  # (xmin, xmax, ymin, ymax)
    step = params['step']

    # build orientation vectors
    n_pairs = len(n_t_s) // 2
    orientations = []
    for i in range(n_pairs):
        theta, rho = n_t_s[2*i], n_t_s[2*i+1]
        th = math.radians(theta)
        rh = math.radians(rho)
        orientations.append((math.sin(th)*math.cos(rh),
                              math.sin(th)*math.sin(rh),
                              -math.cos(th)))
    # prepare channel params
    coords = [coord_t] * n_pairs
    normals = orientations
    ms = [m_t] * n_pairs
    param_t = (coords, normals, ms)
    A_det = p * q
    param_r = (A_det, n_r, FOV)

    # grid
    xmin, xmax, ymin, ymax = testbed
    X_r = np.arange(xmin, xmax+step/2, step)
    Y_r = np.arange(ymin, ymax+step/2, step)
    # ensure shapes (Nx, Ny)
    x_real, y_real = np.meshgrid(X_r, Y_r, indexing='ij')
    z = z_ref - params['room']['H']
    Nx, Ny = x_real.shape

    # simulate powers and SNR
    P_r = np.zeros((Nx, Ny, n_pairs))
    SNR = np.zeros_like(P_r)
    sigma2 = N0 * BW
    for idx in range(n_pairs):
        for ix in range(Nx):
            for iy in range(Ny):
                x, y = X_r[ix], Y_r[iy]
                h_val, _, _, _ = h_los(param_t, idx, param_r, x, y, z)
                P_los = h_val * P_t
                # noise simulation
                noise = math.sqrt(sigma2) * np.random.randn(n_samples)
                s_r = (R_pd * P_los) + noise
                Pr_elec = np.mean(s_r**2)
                P_r[ix, iy, idx] = math.sqrt(Pr_elec) / R_pd
                # SNR (linear->dB)
                SNR[ix, iy, idx] = 10 * math.log10((R_pd * P_los)**2 / sigma2 + 1e-12)

    # estimate positions
    x_est, y_est = estimate_position(P_r, np.array(orientations), m_t,
                                     method='WLS', SNR=SNR)

    # compute RMS error grid
    err = np.sqrt((x_real - x_est)**2 + (y_real - y_est)**2)
    # 90th percentile (CDF)
    cdf90 = np.percentile(err.flatten(), 90)

    # optional: visualize
    # visualize_results(n_t_s, x_real, y_real, x_est, y_est)
    return float(cdf90)
