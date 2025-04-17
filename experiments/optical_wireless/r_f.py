"""
Compute gain between a wall reflector and the receiver.
"""
import numpy as np

def r_f(param_w, i_w, param_r, x, y, z):
    """
    Compute gain from wall reflector i_w to receiver at (x,y,z).
    """
    WR = np.array(param_w[0][i_w])
    n_w = np.array(param_w[1])
    L, W, H = param_w[3], param_w[4], param_w[5]
    A_det = param_r[0]
    n_r = param_r[1]
    FOV = param_r[2]
    R = np.array([x, y, z])
    d_wr = np.linalg.norm(R - WR)
    v_wr = (R - WR) / d_wr
    # determine cos_theta based on face
    normals = n_w
    # assume normals list aligned with positions
    # TODO: map WR to correct normal index
    cos_theta = np.dot(normals[0], v_wr)
    cos_psi = np.dot(n_r, -v_wr)
    if abs(np.degrees(np.arccos(cos_psi))) <= FOV:
        return A_det / (np.pi * d_wr**2) * abs(cos_theta) * abs(cos_psi)
    return 0.0
