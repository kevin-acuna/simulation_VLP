"""
Load global parameters for the noise effects experiment.
"""
def setup_parameters():
    """
    Returns:
      params (dict): Simulation parameters.
    """
    params = {}
    # Noise
    params['N0'] = 10**(-21.8)       # noise power spectral density
    params['signal_bandwidth'] = 30e6

    # Room dimensions
    params['room'] = {'L': 2.4,
                      'W': 2.4,
                      'H': 2.0}

    # Transmitter
    params['P_t'] = 0.405            # transmit power
    params['theta_half'] = 45        # LED half-angle (degrees)
    import math
    params['m_t'] = -math.log(2) / math.log(math.cos(math.radians(params['theta_half'])))
    params['coord_t'] = (0.0, 0.0, 0.0)

    # Receiver
    params['z_ref'] = 0.96           # receiver height above floor
    params['p'] = 4.8e-3             # PD width
    params['q'] = 5.5e-3             # PD height
    params['FOV'] = 85.0             # field of view (degrees)
    params['n_r'] = (0.0, 0.0, 1.0)   # receiver normal vector
    params['R_pd'] = 0.63            # PD responsivity

    # Reception plane grid
    params['testbed'] = (-1.2, 1.2, -1.2, 1.2)
    params['step'] = 0.1

    return params
