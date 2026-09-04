"""
Quick numerical checks for the [H] claims in plan_v1_formulacion_problema.md

  (1) Prop. 1: a static scan carries 3 DOF -> FIM over (x,y,z,yaw) is rank-deficient
      for ANY K and even with a tilted LED; FIM over (x,y,z) with known attitude is full rank
      iff the K body-frame normals are non-coplanar (K>=3).
  (2) Linear model mu = N w: ordinary LS attains the CRLB (efficient) for w; direction + amplitude.
  (3) LED-centred cone design: PEB(theta_c) from the exact FIM vs the closed-form approximation
      PEB^2 ~ d^2 sigma^2/(N K eta^2) [4/sin^2 + 1/(4 cos^2)]  ->  tan(theta_c*) = 2 (63.4 deg)
      and comparison with Wang's vertical 20-deg cone.

RX-steered model:  mu_j = (C/d^2) (n_t . n_d)^m  (R n_j^B . u),   u = -n_d = (t-r)/d
"""
import numpy as np

# ---------------- TCOM parameters ----------------
Pt, Phi_half, Adet = 0.405, np.deg2rad(45), 26.4e-6
m = -np.log(2) / np.log(np.cos(Phi_half))            # = 2
C = Pt * (m + 1) * Adet / (2 * np.pi)
sigma2, Nsamp = 3e-14, 1000
FOV = np.deg2rad(85)
H = 2.0
t = np.array([0.0, 0.0, H])

def Rz(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])

def Ry(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])

def sph(theta, phi):
    return np.array([np.sin(theta) * np.cos(phi), np.sin(theta) * np.sin(phi), np.cos(theta)])

def mu_vec(r, R, NB, n_t):
    d = r - t
    dn = np.linalg.norm(d)
    n_d = d / dn
    u = -n_d
    cosphi = max(n_t @ n_d, 0.0)
    cospsi = (R @ NB.T).T @ u                          # K values
    cospsi = np.where(cospsi >= np.cos(FOV), cospsi, 0.0)
    return C / dn**2 * cosphi**m * cospsi

def fim(param_fun, p0, h=1e-6):
    """Numerical FIM (N/sigma^2) J^T J with central differences."""
    p0 = np.asarray(p0, float)
    mu0 = param_fun(p0)
    J = np.zeros((mu0.size, p0.size))
    for k in range(p0.size):
        dp = np.zeros_like(p0); dp[k] = h
        J[:, k] = (param_fun(p0 + dp) - param_fun(p0 - dp)) / (2 * h)
    return Nsamp / sigma2 * J.T @ J

def report_rank(name, I):
    s = np.linalg.svd(I, compute_uv=False)
    print(f"  {name}: singular values (normalised) = {np.array2string(s / s[0], formatter={'float_kind': lambda x: f'{x:.2e}'})}")

rng = np.random.default_rng(1)

# ================= (1) Prop. 1 =================
print("\n=== (1) Prop. 1: information content of a static scan ===")
r_true = np.array([1.0, 0.8, 0.8])
n_t_vert = np.array([0, 0, -1.0])
n_t_tilt = Ry(np.deg2rad(15)) @ n_t_vert              # tilted LED (breaks axial symmetry)
for K in (4, 6, 12):
    NB = np.array([sph(rng.uniform(0, np.deg2rad(40)), rng.uniform(0, 2 * np.pi)) for _ in range(K)])
    for lab, n_t in (("vertical LED", n_t_vert), ("tilted LED 15deg", n_t_tilt)):
        f4 = lambda p: mu_vec(p[:3], Rz(p[3]), NB, n_t)          # unknown (x,y,z,yaw)
        f3 = lambda p: mu_vec(p, np.eye(3), NB, n_t)             # attitude known
        print(f" K={K}, {lab}")
        report_rank("FIM(x,y,z,yaw) [expect rank 3]", fim(f4, [*r_true, 0.3]))
        report_rank("FIM(x,y,z)     [expect rank 3]", fim(f3, r_true))
# coplanar counter-example: three normals with the same azimuth plane (phi=0 or pi) -> rank(N)=2
NB_cop = np.array([sph(np.deg2rad(0), 0), sph(np.deg2rad(20), 0), sph(np.deg2rad(20), np.pi)])
report_rank("K=3 coplanar normals, FIM(x,y,z) [expect rank 2]", fim(lambda p: mu_vec(p, np.eye(3), NB_cop, n_t_vert), r_true))

# ================= (2) Linear LS is efficient =================
print("\n=== (2) Linear LS  mu = N w  (BLUE / attains CRLB) ===")
K = 5
NB = np.array([sph(np.deg2rad(th), np.deg2rad(ph)) for th, ph in
               [(0, 0), (35, 0), (35, 90), (35, 180), (35, 270)]])
R = np.eye(3)
mu0 = mu_vec(r_true, R, NB, n_t_vert)
d_true = np.linalg.norm(r_true - t); u_true = (t - r_true) / d_true
eta_true = C * (n_t_vert @ (-u_true))**m / d_true**2
w_true = eta_true * u_true
M = 20000
noise = rng.normal(0, np.sqrt(sigma2 / Nsamp), size=(M, K))
W_hat = (np.linalg.pinv(NB) @ (mu0 + noise).T).T           # LS for each trial
cov_emp = np.cov(W_hat.T)
cov_crlb = sigma2 / Nsamp * np.linalg.inv(NB.T @ NB)
print(f"  ||w_hat mean - w_true|| / ||w|| = {np.linalg.norm(W_hat.mean(0) - w_true) / np.linalg.norm(w_true):.2e}  (bias)")
print(f"  tr(Cov_emp)/tr(CRLB_w) = {np.trace(cov_emp) / np.trace(cov_crlb):.3f}  (expect ~1)")
u_hat = W_hat / np.linalg.norm(W_hat, axis=1, keepdims=True)
ang = np.degrees(np.arccos(np.clip(u_hat @ u_true, -1, 1)))
print(f"  direction RMS error = {np.sqrt(np.mean(ang**2)):.3f} deg ; amplitude rel. RMS = {np.std(np.linalg.norm(W_hat,axis=1))/eta_true:.2e}")
# plug-in 3D position and comparison with PEB
cosphi_hat = -(n_t_vert @ u_hat.T)
d_hat = np.sqrt(C * cosphi_hat**m / np.linalg.norm(W_hat, axis=1))
r_hat = t[None, :] - d_hat[:, None] * u_hat
rmse3d = np.sqrt(np.mean(np.sum((r_hat - r_true)**2, axis=1)))
PEB = np.sqrt(np.trace(np.linalg.inv(fim(lambda p: mu_vec(p, R, NB, n_t_vert), r_true))))
print(f"  3D RMSE (plug-in LS) = {100*rmse3d:.3f} cm  vs  PEB = {100*PEB:.3f} cm   (ratio {rmse3d/PEB:.3f})")

# ================= (3) LED-centred cone rule =================
print("\n=== (3) LED-centred cone: exact PEB(theta_c) vs closed-form approximation ===")
def cone_normals(axis, theta_c, K):
    axis = axis / np.linalg.norm(axis)
    e1 = np.cross(axis, [0, 0, 1.0]);
    if np.linalg.norm(e1) < 1e-9: e1 = np.cross(axis, [1.0, 0, 0])
    e1 /= np.linalg.norm(e1); e2 = np.cross(axis, e1)
    return np.array([np.cos(theta_c) * axis + np.sin(theta_c) * (np.cos(a) * e1 + np.sin(a) * e2)
                     for a in np.arange(K) * 2 * np.pi / K])

def peb_at(r, NB, n_t=n_t_vert, R=np.eye(3)):
    I = fim(lambda p: mu_vec(p, R, NB, n_t), r)
    return np.sqrt(np.trace(np.linalg.inv(I)))

positions = [np.array([0.3, 0.2, 0.8]), np.array([1.0, 0.8, 0.8]), np.array([1.5, 1.5, 1.2])]
K = 4
thetas = np.deg2rad(np.arange(10, 81, 2.5))
for r in positions:
    d = np.linalg.norm(r - t); u = (t - r) / d
    eta = C * (n_t_vert @ (-u))**m / d**2
    peb_exact = np.array([peb_at(r, cone_normals(u, th, K)) for th in thetas])
    peb_approx = np.sqrt(d**2 * sigma2 / (Nsamp * K * eta**2) * (4 / np.sin(thetas)**2 + 1 / (4 * np.cos(thetas)**2)))
    i_ex, i_ap = np.argmin(peb_exact), np.argmin(peb_approx)
    # Wang-like design: vertical cone, 20 deg, K=4 at 0/90/180/270
    NB_wang = cone_normals(np.array([0, 0, 1.0]), np.deg2rad(20), 4)
    peb_wang = peb_at(r, NB_wang)
    # vertical cone with the same optimal angle (non-adaptive), may hit FOV
    NB_vert63 = cone_normals(np.array([0, 0, 1.0]), np.deg2rad(63.4), 4)
    peb_v63 = peb_at(r, NB_vert63)
    print(f" r={r}, d={d:.2f} m, LED zenith from RX = {np.degrees(np.arccos(-u@n_t_vert)):.1f} deg")
    print(f"   argmin exact PEB: theta_c = {np.degrees(thetas[i_ex]):.1f} deg -> {100*peb_exact[i_ex]:.3f} cm | "
          f"approx: {np.degrees(thetas[i_ap]):.1f} deg -> {100*peb_approx[i_ap]:.3f} cm")
    print(f"   exact PEB at 63.4 deg = {100*peb_exact[np.argmin(abs(thetas-np.deg2rad(62.5)))]:.3f} cm ; at 20 deg = {100*peb_exact[np.argmin(abs(thetas-np.deg2rad(20)))]:.3f} cm  (ratio {peb_exact[np.argmin(abs(thetas-np.deg2rad(20)))]/peb_exact[i_ex]:.2f})")
    print(f"   Wang vertical cone 20deg K=4: PEB = {100*peb_wang:.3f} cm ; vertical cone 63.4deg K=4: PEB = {100*peb_v63:.3f} cm (FOV dropouts possible)")

# ================= (4) RMS-PEB over the TCOM testbed (3x3x2 m, 1792 points) =================
print("\n=== (4) RMS-PEB over the TCOM testbed grid (compare: TCOM PEB_C 1.64 cm, Broadcast PEB_B 2.49 cm @K=5) ===")
xs = np.arange(-1.5, 1.5001, 0.2); zs = np.arange(0, 1.2001, 0.2)
grid = np.array([[x, y, z] for x in xs for y in xs for z in zs])
print(f"  grid points: {len(grid)}")

def rms_peb(design_fun, n_t=n_t_vert, label=""):
    vals = []
    for r in grid:
        NB = design_fun(r)
        I = fim(lambda p: mu_vec(p, np.eye(3), NB, n_t), r)
        try:
            v = np.trace(np.linalg.inv(I))
            vals.append(np.sqrt(v) if v > 0 and np.isfinite(v) else np.inf)
        except np.linalg.LinAlgError:
            vals.append(np.inf)
    vals = np.array(vals)
    ok = np.isfinite(vals)
    print(f"  {label:55s} RMS = {100*np.sqrt(np.mean(vals[ok]**2)):7.2f} cm | median = {100*np.median(vals[ok]):6.2f} cm | "
          f"P90 = {100*np.percentile(vals[ok],90):6.2f} cm | singular pts = {np.sum(~ok)}")
    return vals

def led_centred(theta_c, K):
    def f(r):
        u = (t - r); u /= np.linalg.norm(u)
        return cone_normals(u, theta_c, K)
    return f

def vertical_cone(theta_c, K, add_nadir=False):
    def f(r):
        NB = cone_normals(np.array([0, 0, 1.0]), theta_c, K)
        return np.vstack([NB, [[0, 0, 1.0]]]) if add_nadir else NB
    return f

for n_t, lab in ((n_t_vert, "LED vertical, m=2 (Phi1/2=45deg)"),):
    print(f" -- {lab} --")
    rms_peb(vertical_cone(np.deg2rad(20), 4), n_t, "Wang: vertical cone 20deg, K=4")
    rms_peb(vertical_cone(np.deg2rad(20), 4, add_nadir=True), n_t, "vertical cone 20deg + nadir, K=5")
    rms_peb(vertical_cone(np.deg2rad(40), 4, add_nadir=True), n_t, "vertical cone 40deg + nadir, K=5")
    rms_peb(led_centred(np.deg2rad(63.4), 4), n_t, "LED-centred cone 63.4deg, K=4 (adaptive)")
    rms_peb(led_centred(np.deg2rad(63.4), 5), n_t, "LED-centred cone 63.4deg, K=5 (adaptive)")
    rms_peb(led_centred(np.deg2rad(63.4), 9), n_t, "LED-centred cone 63.4deg, K=9 (adaptive)")

# wider LED (m=1) : does the fixed anchor pattern limit the edges?
m_backup = m
m = 1.0; C = Pt * (m + 1) * Adet / (2 * np.pi)
print(" -- LED vertical, m=1 (Phi1/2=60deg) --")
rms_peb(vertical_cone(np.deg2rad(20), 4), n_t_vert, "Wang: vertical cone 20deg, K=4")
rms_peb(led_centred(np.deg2rad(63.4), 5), n_t_vert, "LED-centred cone 63.4deg, K=5 (adaptive)")
m = m_backup; C = Pt * (m + 1) * Adet / (2 * np.pi)
