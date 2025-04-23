import numpy as np
import math
from parameters.setup_parameters import setup_parameters
from optical_wireless.h_los import h_los
from position_estimators.estimate_position import estimate_position

def position_estimator(n_t_s, n_samples: int = 10000):
    """
    Simulate orientations scenario:
    Builds orientation vectors, simulates received powers with noise,
    and estimates positions using WLS.

    Args:
        n_t_s: list of angles [theta1, rho1, ...]
        n_samples: number of noise samples per point
    Returns:
        x_est, y_est: estimated positions (Nx x Ny arrays)
        x_real, y_real: real grid coordinates (Nx x Ny arrays)
    """
    params = setup_parameters()
    # unpack parameters
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

    # setup grid
    xmin, xmax, ymin, ymax = testbed
    X_r = np.arange(xmin, xmax+step/2, step)
    Y_r = np.arange(ymin, ymax+step/2, step)
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
                noise = math.sqrt(sigma2) * np.random.randn(n_samples)
                s_r = (R_pd * P_los) + noise
                Pr_elec = np.mean(s_r**2)
                P_r[ix, iy, idx] = math.sqrt(Pr_elec) / R_pd
                SNR[ix, iy, idx] = 10 * math.log10((R_pd * P_los)**2 / sigma2 + 1e-12)

    # estimate positions
    x_est, y_est = estimate_position(P_r, np.array(orientations), m_t, method='WLS', SNR=SNR)
    return x_est, y_est, x_real, y_real
