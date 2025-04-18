import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

def visualize_results(n_t_s, x_real, y_real, x_est, y_est):
    """
    Plot Tx orientation vectors, real distribution of receivers, and estimated positions.

    Args:
        n_t_s: list of angles [theta1, rho1, theta2, rho2, ...]
        x_real, y_real: real grid coordinates (Nx x Ny arrays)
        x_est, y_est: estimated positions (Nx x Ny arrays)
    """
    n_pairs = len(n_t_s) // 2
    # Set up figure and 3D axes
    fig = plt.figure()
    ax = fig.add_subplot(111, projection='3d')
    # Colormap for orientation vectors
    cmap = plt.cm.get_cmap('tab10', n_pairs)
    # Plot orientation vectors
    for i in range(n_pairs):
        theta = n_t_s[2*i]
        rho = n_t_s[2*i+1]
        th = np.deg2rad(theta)
        rh = np.deg2rad(rho)
        x_u = np.sin(th) * np.cos(rh)
        y_u = np.sin(th) * np.sin(rh)
        z_u = -np.cos(th)
        ax.quiver(0, 0, 0, x_u, y_u, z_u,
                  length=1.0, normalize=True, color=cmap(i))
    # Scatter real receiver distribution at Z=0
    Z_real = np.zeros_like(x_real)
    ax.scatter(x_real.flatten(), y_real.flatten(), Z_real.flatten(),
               c='k', marker='o', s=10)
    # Scatter estimated positions at Z=0
    Z_est = np.zeros_like(x_est)
    ax.scatter(x_est.flatten(), y_est.flatten(), Z_est.flatten(),
               c='r', marker='x', s=10)
    # Axis settings
    ax.set_xlim([-1.2, 1.2])
    ax.set_ylim([-1.2, 1.2])
    ax.set_zlim([-2, 0])
    ax.set_xlabel('X (m)')
    ax.set_ylabel('Y (m)')
    ax.set_zlabel('Z (m)')
    ax.set_title('Position Estimation')
    # View from above (top-down)
    ax.view_init(elev=90, azim=-90)
    plt.show()
