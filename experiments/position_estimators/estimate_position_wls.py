import numpy as np

def estimate_position_wls(P: np.ndarray,
                          orientations: np.ndarray,
                          m: float,
                          SNR: np.ndarray,
                          z: float = -1.04) -> tuple:
    """
    Estimate (x,y) by weighted least squares for n>3 orientations.

    Args:
        P: np.ndarray shape (Nx, Ny, n) of received optical powers.
        orientations: np.ndarray shape (n,3) of unit vectors [a,b,c].
        m: Lambertian exponent.
        SNR: np.ndarray shape (Nx, Ny, n) of SNR values (dB) per measurement.
        z: receiver plane height (e.g., -1.04).
    Returns:
        x_est, y_est: np.ndarray shape (Nx, Ny) of estimated positions.
    """
    Nx, Ny, n = P.shape
    if n < 2:
        raise ValueError("WLS requires at least 2 orientations (n<2).")
    # orientation components
    n_tx = orientations[:, 0]
    n_ty = orientations[:, 1]
    n_tz = orientations[:, 2]

    x_est = np.full((Nx, Ny), np.nan)
    y_est = np.full((Nx, Ny), np.nan)

    ref = 0
    for ix in range(Nx):
        for iy in range(Ny):
            p_vec = P[ix, iy, :]
            snr_vec = SNR[ix, iy, :]
            P_ref = p_vec[ref]
            if P_ref <= 0:
                # skip when reference power is non-positive
                continue
            ratio = (p_vec / P_ref) ** (1.0 / m)
            A_rows = []
            B_rows = []
            W = []
            for i in range(n):
                if i == ref:
                    continue
                alpha_x = n_tx[i] - ratio[i] * n_tx[ref]
                alpha_y = n_ty[i] - ratio[i] * n_ty[ref]
                alpha_z = n_tz[i] - ratio[i] * n_tz[ref]
                A_rows.append([alpha_x, alpha_y])
                B_rows.append(-alpha_z * z)
                # weight from SNR (convert dB to linear)
                snr_linear = 10.0 ** (snr_vec[i] / 10.0)
                w_i = min(max(snr_linear, 0.001), 1000)
                W.append(w_i)
            A = np.array(A_rows)
            B = np.array(B_rows)
            W = np.array(W)
            if A.shape[0] < 2 or np.linalg.matrix_rank(A) < 2:
                continue
            # normalize weights
            W_norm = W / np.max(W)
            W_norm = np.maximum(W_norm, 1e-6)
            W_sqrt = np.sqrt(W_norm)
            # apply weights
            A_w = (W_sqrt[:, np.newaxis] * A)
            B_w = W_sqrt * B
            # solve weighted LS
            try:
                x_y, *_ = np.linalg.lstsq(A_w, B_w, rcond=None)
            except Exception:
                x_y = np.linalg.pinv(A_w).dot(B_w)
            # fallback if nan/inf
            if np.any(np.isnan(x_y)) or np.any(np.isinf(x_y)):
                x_y = np.linalg.pinv(A_w).dot(B_w)
            if np.all(np.abs(x_y) <= 10):
                x_est[ix, iy] = x_y[0]
                y_est[ix, iy] = x_y[1]
    return x_est, y_est
