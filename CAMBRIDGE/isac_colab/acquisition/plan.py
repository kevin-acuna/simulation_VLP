"""Measurement plan: sites (gantry X, Y, Z) x K MTRS orientations x repeated captures.

Route (same as the database acquisition tool):
  - Z levels outermost; within a level a serpentine XY grid (rows along X, Y direction alternating), and the XY
    route is reversed on every Z level.
  - At every site the K angles theta_k = (offset + 360 k / K) mod 360 are measured in increasing angle, and in
    decreasing angle at the next site: no return turns, and in LinearRange the PD cable never winds up.
  - N captures are taken at every pose (rep = 0 .. N-1) without moving in between.
"""


def grid_sites(x_mm, y_mm, z_mm, serpentine=True):
    """[(x, y, z)] of an X x Y x Z grid in route order."""
    sites, reverse = [], False
    for z in z_mm:
        level = []
        for ix, x in enumerate(x_mm):
            ys = list(y_mm)[::-1] if serpentine and ix % 2 else list(y_mm)
            level += [(float(x), float(y), float(z)) for y in ys]
        sites += level[::-1] if serpentine and reverse else level
        reverse = not reverse
    return sites


def orientation_angles(k_orientations, offset_deg):
    """theta_k = (offset + 360 k / K) mod 360, k = 0 .. K-1."""
    k = max(int(k_orientations), 1)
    return [round((offset_deg + 360.0 * i / k) % 360.0, 6) % 360.0 for i in range(k)]


def make_plan(sites, angles, n_captures=1, tilt_deg=0.0, alternate=True):
    """List of measurements: index, site_id (1-based), k (index in `angles`), rep, xyz, angle, tilt, new_site,
    new_pose (False for the repeated captures of a pose)."""
    ascending = sorted(range(len(angles)), key=lambda i: angles[i])
    plan = []
    for s, xyz in enumerate(sites):
        order = ascending[::-1] if alternate and s % 2 else ascending
        for j, k in enumerate(order):
            for rep in range(int(n_captures)):
                plan.append(dict(index=len(plan), site_id=s + 1, k=k, rep=rep, xyz=tuple(xyz),
                                 angle=float(angles[k]), tilt=float(tilt_deg), new_site=j == 0 and rep == 0,
                                 new_pose=rep == 0))
    return plan


def check_plan(plan, tb):
    """Problems of the plan against the gantry workspace and the MTRS limits (empty if valid)."""
    problems = []
    for m in plan:
        if m["new_pose"]:
            problems += [f"site {m['site_id']}: {p}" for p in tb.check_pose(m["xyz"], m["angle"], m["tilt"])]
    return list(dict.fromkeys(problems))


def plan_label(sites, angles, n_captures, grid=None):
    """Short description for the session folder name, e.g. 'grid5x5x1_K5' or 'sites12_K5x2'."""
    where = f"grid{len(grid[0])}x{len(grid[1])}x{len(grid[2])}" if grid else f"sites{len(sites)}"
    return f"{where}_K{len(angles)}" + (f"x{int(n_captures)}" if int(n_captures) > 1 else "")
