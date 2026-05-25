function d_hat = vlp_nls_lm(nt, Praw, m)
% VLP_NLS_LM  NLS direction estimator using lsqnonlin/Levenberg-Marquardt
%
% Solves the normalized-power NLS problem using lsqnonlin with
% Levenberg-Marquardt algorithm. Reparameterized in spherical coordinates
% (theta_d, phi_d, eta) so the unit-sphere constraint is satisfied by
% construction. Uses the Gauss-Newton Hessian approximation (J'J),
% which provides quadratic convergence for sum-of-squares objectives.
%
% Inputs:
%   nt   : 3×K  — LED orientation vectors (columns)
%   Praw : N×K  — raw power samples (rows = samples, cols = orientations)
%   m    : scalar, Lambertian order
%
% Output:
%   d_hat : 3×1 unit direction vector (Tx → Rx)

persistent opts_lm
if isempty(opts_lm)
    opts_lm = optimoptions('lsqnonlin', 'Display', 'none', ...
        'Algorithm', 'levenberg-marquardt', ...
        'StepTolerance', 1e-14, 'FunctionTolerance', 1e-14, ...
        'OptimalityTolerance', 1e-14, ...
        'MaxFunctionEvaluations', 5000, 'MaxIterations', 1000);
end

K = size(nt, 2);
nt_rows = nt';  % K×3

% 1. Normalized power targets
mu_hat = mean(Praw, 1);
max_mu = max(mu_hat);
if max_mu <= 0; max_mu = 1e-12; end
p_target = mu_hat / max_mu;

% 2. Initial guess in spherical coords
[~, idx] = max(p_target);
best_nt = nt_rows(idx, :);
theta0 = acos(max(-1, min(1, -best_nt(3))));
phi0   = atan2(best_nt(2), best_nt(1));
x0 = [theta0, phi0, 1.0];

% 3. Solve with lsqnonlin/LM (vector of residuals, not scalar cost)
res_fcn = @(vars) nls_residuals(vars, p_target, nt_rows, m);
[sol, ~, ~, ~] = lsqnonlin(res_fcn, x0, [], [], opts_lm);

% 4. Convert spherical → Cartesian unit vector
th = sol(1); ph = sol(2);
d_hat = [sin(th)*cos(ph); sin(th)*sin(ph); -cos(th)];  % 3×1 column

% Sign correction (towards receiver)
if dot(d_hat, nt(:,1)) < 0
    d_hat = -d_hat;
end
end

% --- Local: vector of residuals (K×1) ---
function r = nls_residuals(vars, p_target, nt_rows, m)
    theta_d = vars(1);
    phi_d   = vars(2);
    eta     = vars(3);
    v = [sin(theta_d)*cos(phi_d), sin(theta_d)*sin(phi_d), -cos(theta_d)];
    K = size(nt_rows, 1);
    r = zeros(K, 1);
    for i = 1:K
        Q = max(0, dot(nt_rows(i,:), v));
        r(i) = eta * Q^m - p_target(i);
    end
end
