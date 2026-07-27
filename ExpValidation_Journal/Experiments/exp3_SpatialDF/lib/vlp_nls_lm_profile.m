function d_hat = vlp_nls_lm_profile(nt, Praw, Rfun)
% VLP_NLS_LM_PROFILE  NLS-LM direction estimator using a MEASURED beam profile.
%
%   d_hat = vlp_nls_lm_profile(nt, Praw, Rfun)
%
% Same normalized-power NLS problem as fundamentals/core/vlp_nls_lm.m, but the
% Lambertian term cos^m(theta) = Q^m is replaced by an empirical radiation
% profile Rfun(theta) obtained from the sub0 axis sweep (df_load_profile).
% Reparameterized in spherical coords (theta_d, phi_d, eta) so the unit-sphere
% constraint holds by construction; solved with lsqnonlin / Levenberg-Marquardt.
%
% Inputs:
%   nt    : 3xK   LED orientation vectors (columns)
%   Praw  : NxK   raw power samples (rows = samples, cols = orientations)
%   Rfun  : function handle, Rfun(theta_rad) -> normalized radiance in [0,1]
%
% Output:
%   d_hat : 3x1 unit direction vector (Tx -> Rx)

persistent opts_lm
if isempty(opts_lm)
    opts_lm = optimoptions('lsqnonlin', 'Display', 'none', ...
        'Algorithm', 'levenberg-marquardt', ...
        'StepTolerance', 1e-14, 'FunctionTolerance', 1e-14, ...
        'OptimalityTolerance', 1e-14, ...
        'MaxFunctionEvaluations', 5000, 'MaxIterations', 1000);
end

nt_rows = nt';   % Kx3

% 1. Normalized power targets
mu_hat = mean(Praw, 1);
max_mu = max(mu_hat);
if max_mu <= 0, max_mu = 1e-12; end
p_target = mu_hat / max_mu;

% 2. Initial guess in spherical coords (brightest orientation)
[~, idx] = max(p_target);
best_nt = nt_rows(idx, :);
theta0 = acos(max(-1, min(1, -best_nt(3))));
phi0   = atan2(best_nt(2), best_nt(1));
x0 = [theta0, phi0, 1.0];

% 3. Solve with lsqnonlin / LM (vector residual)
res_fcn = @(vars) nls_residuals_profile(vars, p_target, nt_rows, Rfun);
sol = lsqnonlin(res_fcn, x0, [], [], opts_lm);

% 4. Spherical -> Cartesian unit vector
th = sol(1); ph = sol(2);
d_hat = [sin(th)*cos(ph); sin(th)*sin(ph); -cos(th)];

% Sign correction (towards receiver)
if dot(d_hat, nt(:,1)) < 0
    d_hat = -d_hat;
end
end

% --- Local: vector of residuals (Kx1) using the measured profile ---
function r = nls_residuals_profile(vars, p_target, nt_rows, Rfun)
    theta_d = vars(1);
    phi_d   = vars(2);
    eta     = vars(3);
    v = [sin(theta_d)*cos(phi_d), sin(theta_d)*sin(phi_d), -cos(theta_d)];
    K = size(nt_rows, 1);
    r = zeros(K, 1);
    for i = 1:K
        Q  = max(0, dot(nt_rows(i,:), v));
        th = acos(min(1, Q));
        r(i) = eta * Rfun(th) - p_target(i);
    end
end
