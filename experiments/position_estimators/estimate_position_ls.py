import numpy as np

def estimate_position_ls(P: np.ndarray,
                         orientations: np.ndarray,
                         m: float,
                         z: float = -1.04) -> tuple:
    """
    Estimate (x,y) by least squares for n>3 orientations.

    Args:
        P: np.ndarray shape (Nx, Ny, n) of received optical powers.
        orientations: np.ndarray shape (n,3) of unit vectors [a,b,c].
        m: Lambertian exponent.
        z: receiver plane height (e.g., -1.04).
    Returns:
        x_est, y_est: np.ndarray shape (Nx, Ny) of estimated positions.
    """
    Nx, Ny, n = P.shape
    if n < 2:
        raise ValueError("LS requires at least 2 orientations (n<2).")
    ref = 0
    n_tx = orientations[:, 0]
    n_ty = orientations[:, 1]
    n_tz = orientations[:, 2]

    x_est = np.full((Nx, Ny), np.nan)
    y_est = np.full((Nx, Ny), np.nan)

    for ix in range(Nx):
        for iy in range(Ny):
            p_vec = P[ix, iy, :]
            P_ref = p_vec[ref]
            if P_ref <= 0:
                continue
            ratio = (p_vec / P_ref) ** (1.0 / m)
            A = []
            B = []
            for i in range(n):
                if i == ref:
                    continue
                alpha_x = n_tx[i] - ratio[i] * n_tx[ref]
                alpha_y = n_ty[i] - ratio[i] * n_ty[ref]
                alpha_z = n_tz[i] - ratio[i] * n_tz[ref]
                A.append([alpha_x, alpha_y])
                B.append(-alpha_z * z)
            A = np.array(A)
            B = np.array(B)
            if A.shape[0] < 2 or np.linalg.matrix_rank(A) < 2:
                continue
            x_y, *_ = np.linalg.lstsq(A, B, rcond=None)
            x_est[ix, iy] = x_y[0]
            y_est[ix, iy] = x_y[1]
    return x_est, y_est
