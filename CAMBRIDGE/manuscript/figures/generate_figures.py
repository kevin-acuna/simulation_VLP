from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Rectangle
from matplotlib import font_manager

OUT = Path(__file__).resolve().parent
font_manager.findfont('Times New Roman', fallback_to_default=False)
plt.rcParams.update({
    'font.family': 'Times New Roman', 'font.size': 9,
    'mathtext.fontset': 'stix', 'pdf.fonttype': 42, 'ps.fonttype': 42,
    'axes.linewidth': 0.6, 'savefig.facecolor': 'white',
})
INK = '#252A30'
GRAY = '#8B929A'
BLUE = '#23678A'
ORANGE = '#B05B32'
LIGHT = '#E9EDF0'

az, el = np.deg2rad([-50, 18])
view = np.array([np.cos(el)*np.cos(az), np.cos(el)*np.sin(az), np.sin(el)])
right = np.array([-np.sin(az), np.cos(az), 0])
up = np.cross(view, right)
PROJ = np.stack([right, up])
assert np.allclose(PROJ @ PROJ.T, np.eye(2))


def project(points):
    return np.asarray(points) @ PROJ.T


def line3(ax, points, **kwargs):
    p = project(points)
    return ax.plot(p[:, 0], p[:, 1], **kwargs)


def arrow(ax, a, b, color=INK, width=1.0, scale=8, style='-|>', zorder=5):
    ax.annotate('', xy=b, xytext=a, arrowprops=dict(
        arrowstyle=style, color=color, lw=width, mutation_scale=scale,
        shrinkA=0, shrinkB=0), zorder=zorder)


def arrow3(ax, origin, direction, length=1, color=INK, width=1.0):
    arrow(ax, project(origin), project(origin + length*direction), color, width)


def text3(ax, point, text, offset=(0, 0), **kwargs):
    p = project(point) + offset
    return ax.text(*p, text, color=kwargs.pop('color', INK), **kwargs)


def spherical_arc(ax, origin, a, b, radius, label, offset=(0, 0), color=INK):
    a, b = np.asarray(a), np.asarray(b)
    assert np.isclose(np.linalg.norm(a), 1) and np.isclose(np.linalg.norm(b), 1)
    angle = np.arccos(np.clip(a @ b, -1, 1))
    t = np.linspace(0, 1, 90)
    curve = (np.sin((1-t)*angle)[:, None]*a + np.sin(t*angle)[:, None]*b)/np.sin(angle)
    line3(ax, origin + radius*curve, color=color, lw=0.85, zorder=6)
    text3(ax, origin + radius*curve[len(t)//2], label, offset=offset, color=color, fontsize=10)


def finish(fig, name):
    fig.savefig(OUT / (name + '.pdf'), bbox_inches='tight', pad_inches=0.035)
    fig.savefig(OUT / (name + '.png'), dpi=350, bbox_inches='tight', pad_inches=0.035)
    plt.close(fig)


def geometry():
    fig = plt.figure(figsize=(7.16, 3.30))
    ax = fig.add_axes([0.02, 0.075, 0.51, 0.88])
    ax2 = fig.add_axes([0.59, 0.15, 0.39, 0.78])
    ez = np.array([0., 0., 1.])
    nt = -ez
    transmitter = np.array([0., 0., 2.8])
    receiver = np.array([0.8, 0.25, 0.75])
    u = transmitter - receiver
    u /= np.linalg.norm(u)
    theta = np.deg2rad(25)
    alpha = np.deg2rad(np.arange(5)*72)
    normals = np.column_stack([np.sin(theta)*np.cos(alpha), np.sin(theta)*np.sin(alpha), np.full(5, np.cos(theta))])
    n = normals[1]
    assert np.allclose(np.linalg.norm(normals, axis=1), 1)
    assert np.allclose(normals[:, 2], np.cos(theta))
    corners = np.array([[-1.25, -1.25, 0], [1.25, -1.25, 0], [1.25, 1.25, 0], [-1.25, 1.25, 0]])
    for height in [0, 2.8]:
        ring = corners + height*ez
        ax.add_patch(Polygon(project(ring), facecolor='#F5F6F7', edgecolor=GRAY, lw=0.6, zorder=0))
        line3(ax, np.vstack([ring, ring[0]]), color=GRAY, lw=0.6, zorder=1)
    for j in [2, 3]:
        line3(ax, [corners[j], corners[j] + 2.8*ez], color=GRAY, lw=0.6, zorder=1)
    origin = corners[0] + np.array([0.16, 0.16, 0])
    for direction, label, offset in [(np.array([1., 0, 0]), '$x$', (0.03, -0.04)),
                                     (np.array([0., 1, 0]), '$y$', (0.02, 0)),
                                     (ez, '$z$', (-0.05, 0.02))]:
        arrow3(ax, origin, direction, 0.49, width=0.75)
        text3(ax, origin + 0.52*direction, label, offset)
    led = project(transmitter)
    ax.add_patch(Rectangle(led + [-0.12, -0.035], 0.24, 0.07, facecolor='white', edgecolor=INK, lw=1.1, zorder=8))
    ax.text(led[0], led[1]+0.17, r'Fixed LED: $\mathbf{t}$', ha='center', fontsize=9.5)
    arrow3(ax, transmitter, nt, 0.69, width=1.1)
    text3(ax, transmitter + 0.59*nt, r'$\mathbf{n}_t$', (-0.24, -0.02))
    line3(ax, [transmitter, receiver], color=BLUE, lw=0.95, ls=(0, (3.5, 2)), zorder=3)
    distance = np.linalg.norm(transmitter-receiver)
    arrow3(ax, receiver + 0.28*distance*u, u, 0.40*distance, BLUE, 1.4)
    text3(ax, receiver + 0.55*distance*u, r'$\mathbf{u}$', (-0.22, -0.03), color=BLUE, fontsize=11)
    text3(ax, receiver + 0.66*distance*u, '$d$', (0.15, 0.0), color=BLUE, fontsize=10)
    spherical_arc(ax, transmitter, nt, -u, 0.45, r'$\phi$', (0.09, -0.025))
    for ni in normals:
        line3(ax, [receiver, receiver + 0.58*ni], color=GRAY, lw=0.7, ls='--', zorder=2)
    e1 = np.cross(n, ez); e1 /= np.linalg.norm(e1)
    e2 = np.cross(n, e1)
    plate = receiver + 0.16*np.array([-e1-e2, e1-e2, e1+e2, -e1+e2])
    ax.add_patch(Polygon(project(plate), facecolor=LIGHT, edgecolor=INK, lw=0.9, zorder=7))
    ax.scatter(*project(receiver), s=14, color=INK, zorder=9)
    arrow3(ax, receiver, n, 0.86, ORANGE, 1.25)
    text3(ax, receiver + 0.88*n, r'$\mathbf{n}_i$', (0.055, -0.01), color=ORANGE, fontsize=10)
    ax.text(*(project(receiver) + [0.21, -0.15]), r'PD: $\mathbf{r}=[x,y,z]^{\mathsf{T}}$', fontsize=9)
    ax.text(*(project(receiver) + [0.19, -0.33]), 'Same optical center for every hold', fontsize=8)
    line3(ax, [receiver, receiver*np.array([1, 1, 0])], color=GRAY, lw=0.65, ls=':')
    ax.set_xlim(-1.98, 2.05); ax.set_ylim(-0.70, 3.24)
    ax.set_aspect('equal'); ax.axis('off')
    fig.text(0.07, 0.035, '(a) Spatial geometry and fixed source', fontsize=9)
    zero = np.zeros(3)
    length = 1.34
    ring_alpha = np.linspace(0, 2*np.pi, 240)
    ring = length*np.column_stack([np.sin(theta)*np.cos(ring_alpha), np.sin(theta)*np.sin(ring_alpha), np.full_like(ring_alpha, np.cos(theta))])
    line3(ax2, ring, color=GRAY, lw=0.85, ls='--')
    for direction, label, offset in [(np.array([1., 0, 0]), r'$\mathbf{e}_x$', (0.01, -0.07)),
                                     (np.array([0., 1, 0]), r'$\mathbf{e}_y$', (0.02, 0.0)),
                                     (ez, r'$\mathbf{e}_z$', (-0.08, 0.04))]:
        length_axis = 1.59 if direction[2] else 1.11
        arrow3(ax2, zero, direction, length_axis, INK, 0.8)
        text3(ax2, length_axis*direction, label, offset, fontsize=9)
    for j, ni in enumerate(normals):
        if j != 1:
            arrow3(ax2, zero, ni, length, GRAY, 0.75)
            ax2.scatter(*project(length*ni), color=GRAY, s=9, zorder=5)
    arrow3(ax2, zero, n, length, ORANGE, 1.4)
    text3(ax2, length*n, r'$\mathbf{n}_i$', (0.055, 0.055), color=ORANGE, fontsize=11)
    arrow3(ax2, zero, u, 1.53, BLUE, 1.3)
    text3(ax2, 1.53*u, r'$\mathbf{u}$', (-0.16, 0.02), color=BLUE, fontsize=11)
    projection_n = length*n*np.array([1, 1, 0])
    line3(ax2, [length*n, projection_n, zero], color=ORANGE, lw=0.7, ls=':')
    spherical_arc(ax2, zero, ez, n, 0.60, r'$\theta_i$', (0.04, 0.015), ORANGE)
    spherical_arc(ax2, zero, n, u, 1.04, r'$\psi_i$', (-0.19, -0.01), BLUE)
    xy = np.array([n[0], n[1], 0]); xy /= np.linalg.norm(xy)
    spherical_arc(ax2, zero, np.array([1., 0, 0]), xy, 0.42, r'$\alpha_i$', (0.035, -0.095))
    ax2.scatter(0, 0, s=14, color=INK, zorder=9)
    ax2.text(-0.13, -0.10, r'$\mathbf{r}$', fontsize=10)
    ax2.set_xlim(-0.88, 1.17); ax2.set_ylim(-0.45, 1.74)
    ax2.set_aspect('equal'); ax2.axis('off')
    fig.text(0.605, 0.035, '(b) Orientation coordinates at the PD', fontsize=9)
    finish(fig, 'fig01_geometry')


def block(ax, x, y, width, height, text, face='white', edge=INK, fontsize=8.5):
    ax.add_patch(Rectangle((x, y), width, height, facecolor=face, edgecolor=edge, lw=0.75))
    ax.text(x+width/2, y+height/2, text, ha='center', va='center', fontsize=fontsize, color=INK)


def acquisition():
    fig, ax = plt.subplots(figsize=(7.16, 2.35))
    fig.subplots_adjust(left=0.015, right=0.985, bottom=0.035, top=0.975)
    ax.set_xlim(-0.025, 1.06); ax.set_ylim(-0.03, 1.08); ax.axis('off')
    ax.text(-0.017, 0.99, '(a)', fontsize=9)
    block(ax, 0.055, 0.95, 0.93, 0.10,
          r'Fixed during the scan: $\mathbf{t}$, $\mathbf{n}_t$, $P_t$, and PD optical center $\mathbf{r}$', face='#F7F8F9')
    starts = [0.145, 0.375, 0.775]
    labels = ['1', '2', 'K']
    widths = [0.16, 0.16, 0.16]
    for start, width, label in zip(starts, widths, labels):
        block(ax, start-0.067, 0.71, 0.067, 0.16, '', LIGHT, GRAY)
        block(ax, start, 0.71, width, 0.16, '', '#F3F8FB', BLUE)
        ax.text(start+width/2, 0.825, r'$\mathbf{n}_{'+label+'}$', ha='center', va='center', color=ORANGE)
        for t in np.linspace(start+0.025, start+width-0.025, 5):
            ax.plot([t, t], [0.727, 0.754], color=BLUE, lw=0.9)
        ax.text(start+width/2, 0.672, r'$N_{'+label+'}$ observations', ha='center', va='center', fontsize=8)
    ax.text(0.624, 0.79, r'$\cdots$', ha='center', fontsize=16)
    arrow(ax, [0.055, 0.90], [1.00, 0.90], width=0.75, scale=7)
    ax.text(1.015, 0.90, '$t$', va='center')
    ax.text(0.13, 0.566, 'Move / settle: discarded', fontsize=8, color='#565C63')
    arrow(ax, [0.13, 0.605], [0.111, 0.705], GRAY, 0.7, 5)
    ax.text(0.68, 0.566, r'Only completed stable holds enter $\bar{\mathbf{P}}_r$', ha='center', fontsize=8)
    ax.plot([0.055, 0.99], [0.50, 0.50], color=LIGHT, lw=0.8)
    ax.text(-0.017, 0.37, '(b)', fontsize=9)
    ax.text(0.038, 0.358, 'Voltage', ha='center', va='center', fontsize=8)
    arrow(ax, [0.085, 0.355], [0.13, 0.355], width=0.8)
    block(ax, 0.13, 0.265, 0.205, 0.18, 'Offset / gain\ncalibration')
    arrow(ax, [0.335, 0.355], [0.43, 0.355], width=0.8)
    ax.text(0.382, 0.389, r'$P_{r,i,k}$', ha='center', va='bottom')
    block(ax, 0.43, 0.265, 0.14, 0.18, 'Per-hold\naveraging')
    arrow(ax, [0.57, 0.355], [0.755, 0.355], width=0.8)
    ax.text(0.66, 0.384, r'$\bar{\mathbf{P}}_r\in\mathbb{R}^K$', ha='center', va='bottom')
    block(ax, 0.755, 0.265, 0.175, 0.18, '3-D position\nestimation', '#F3F8FB', BLUE)
    arrow(ax, [0.93, 0.355], [1.00, 0.355], BLUE, 1.0)
    ax.text(1.015, 0.355, r'$\hat{\mathbf{r}}$', va='center', color=BLUE, fontsize=11)
    ax.text(0.232, 0.156, 'Calibration data', ha='center', va='center', fontsize=8)
    arrow(ax, [0.232, 0.20], [0.232, 0.26], width=0.7, scale=6)
    block(ax, 0.43, 0.012, 0.305, 0.14, 'Receiver orientation vectors\nin the global frame', '#FAF6F3', ORANGE, fontsize=8)
    arrow(ax, [0.735, 0.081], [0.842, 0.081], ORANGE, 0.8, 6)
    arrow(ax, [0.842, 0.081], [0.842, 0.26], ORANGE, 0.8, 6)
    ax.text(0.957, 0.161, 'Optical model', ha='center', fontsize=8)
    arrow(ax, [0.955, 0.195], [0.91, 0.26], GRAY, 0.7, 6)
    finish(fig, 'fig02_acquisition')


if __name__ == '__main__':
    acquisition()
    print('Generated the acquisition figure as vector PDF and PNG in', OUT)
