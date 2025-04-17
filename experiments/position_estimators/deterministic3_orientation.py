"""
Deterministic position estimator for exactly 3 orientations based on closed-form solution.
"""
import numpy as np

def deterministic3_orientation(P: np.ndarray,
                                orientations: np.ndarray,
                                m: float) -> tuple:
    """
    Estimate (x,y) positions assuming 3 transmitter orientations without noise.

    Parameters:
      P: 3D array shape (Nx, Ny, 3) of received optical powers.
      orientations: array shape (3, 3), each row is unit vector [a, b, c].
      m: Lambertian exponent.

    Returns:
      x_est, y_est: 2D arrays shape (Nx, Ny) of estimated positions.
    """
    # Extract orientation components
    a = orientations[:, 0]
    b = orientations[:, 1]
    c = orientations[:, 2]

    # Indices for closed-form (i, j, k, l) zero-based
    i, j, k, l = 0, 1, 0, 2

    # Received power slices
    P1 = P[:, :, i]
    P2 = P[:, :, j]
    P3 = P[:, :, l]

    # Compute ratios
    K_ij = (P1 / P2) ** (1.0 / m)
    K_kl = (P1 / P3) ** (1.0 / m)

    # Receiver plane height (example, adjust as needed)
    z = -1.04

    # Closed-form estimation
    num_x = (K_kl * b[l] - b[k]) * (c[i] - K_ij * c[j]) - (K_ij * b[j] - b[i]) * (c[k] - c[l] * K_kl)
    den_x = (K_kl * b[l] - b[k]) * (K_ij * a[j] - a[i]) - (K_ij * b[j] - b[i]) * (K_kl * a[l] - a[k])
    x_est = z * num_x / den_x

    num_y = (K_kl * a[l] - a[k]) * (c[i] - K_ij * c[j]) - (K_ij * a[j] - a[i]) * (c[k] - c[l] * K_kl)
    den_y = (K_kl * a[l] - a[k]) * (K_ij * b[j] - b[i]) - (K_ij * a[j] - a[i]) * (K_kl * b[l] - b[k])
    y_est = z * num_y / den_y

    return x_est, y_est
