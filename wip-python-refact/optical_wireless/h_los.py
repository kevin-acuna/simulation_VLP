"""
Compute the line-of-sight gain between a transmitter and a receiver.
"""
import numpy as np

def h_los(param_t, i_t, param_r, x, y, z):
    """
    Compute LOS gain.
    Returns:
      h_los: float
      d_tr: float
      cos_phi: float
      cos_psi: float
    """
    coords, normals, ms = param_t
    T = np.array(coords[i_t])
    n_t = np.array(normals[i_t])
    m = ms[i_t]
    A_det, n_r, FOV = param_r
    R = np.array([x, y, z])
    d_tr = np.linalg.norm(R - T)
    v_tr = (R - T) / d_tr if d_tr != 0 else np.zeros(3)
    cos_phi = float(np.dot(n_t, v_tr))
    cos_psi = float(np.dot(n_r, -v_tr))
    psi_deg = np.degrees(np.arccos(np.clip(cos_psi, -1.0, 1.0)))
    if abs(psi_deg) <= FOV and cos_phi > 0:
        h_val = (m + 1) * A_det / (2 * np.pi * d_tr**2) * abs(cos_phi)**m * abs(cos_psi)
    else:
        h_val = 0.0
    return h_val, d_tr, cos_phi, cos_psi
