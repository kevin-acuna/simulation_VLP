"""
Optical wireless channel computations.
"""
import numpy as np
from .h_los import h_los
from .t_f import t_f
from .r_f import r_f
from .h_f import h_f

def optical_wireless_channel(param_t, i_t, param_w, param_r, x, y, z,
                              bounce_order_decomposition=False, bounce_order=1):
    """
    Compute LOS and NLOS gains of optical channel.

    Returns:
      channel_gain_los, channel_gain_nlos, bounce_order_gain list.
    """
    # Line-of-sight component
    channel_gain_los, _, _, _ = h_los(param_t, i_t, param_r, x, y, z)

    # TODO: implement NLOS using reflectors and bounce orders
    channel_gain_nlos = 0.0
    bounce_order_gain = [0.0] * bounce_order

    return channel_gain_los, channel_gain_nlos, bounce_order_gain
