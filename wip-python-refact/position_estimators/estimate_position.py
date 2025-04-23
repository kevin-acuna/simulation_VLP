"""
Estimate position from measured power matrix P.
"""
import numpy as np
from .deterministic3_orientation import deterministic3_orientation
from .estimate_position_ls import estimate_position_ls
from .estimate_position_wls import estimate_position_wls

def estimate_position(P: np.ndarray,
                      orientations: np.ndarray,
                      m: float,
                      method: str = 'LS',
                      SNR: np.ndarray = None,
                      z: float = -1.04) -> tuple:
    """
    Estimate positions based on received power P.
    """
    n = P.shape[2]
    if n == 3:
        return deterministic3_orientation(P, orientations, m)
    elif n > 3:
        method = method.upper()
        if method == 'LS':
            return estimate_position_ls(P, orientations, m, z=z)
        elif method == 'WLS':
            if SNR is None:
                print("Warning: SNR not provided, using LS")
                return estimate_position_ls(P, orientations, m, z=z)
            return estimate_position_wls(P, orientations, m, SNR, z=z)
        else:
            raise ValueError(f"Unknown method {method}")
    else:
        raise ValueError("Not enough orientations (n<2)")
