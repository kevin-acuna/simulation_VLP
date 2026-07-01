function nd_hat = vlp_nls_gaussian(nt, Praw, theta_div)
% VLP_NLS_GAUSSIAN  Pattern-aware NLS direction finder for a Gaussian VCSEL
%
% Estimates the TX->RX direction n_d from K steered-orientation power samples,
% using the correct Gaussian radiation pattern R_G(phi) = exp(-2*(phi/theta_div)^2).
% Analogous to fundamentals/core/vlp_nls_lm.m but with the Gaussian pattern
% instead of the Lambertian cos^m(phi).
%
% The direction is reparameterized in spherical coordinates (theta_d, phi_d) so
% the unit-norm constraint holds by construction; the amplitude eta is a free
% scalar. Solved with lsqnonlin / Levenberg-Marquardt (Gauss-Newton Hessian).
%
% INPUTS:
%   nt        : 3xK  LED orientation vectors (columns, unit)
%   Praw      : NxK  raw power samples (rows = samples, cols = orientations)
%               (a 1xK row of averaged powers is also accepted)
%   theta_div : scalar, VCSEL divergence half-angle (RADIANS)
%
% OUTPUT:
%   nd_hat    : 3x1 unit direction vector (Tx -> Rx)

persistent opts_lm
if isempty(opts_lm)
    opts_lm = optimoptions('lsqnonlin', 'Display', 'none', ...
        'Algorithm', 'levenberg-marquardt', ...
        'StepTolerance', 1e-14, 'FunctionTolerance', 1e-14, ...
        'OptimalityTolerance', 1e-14, ...
        'MaxFunctionEvaluations', 5000, 'MaxIterations', 1000);
end

nt_rows = nt';                        % Kx3

% 1. Averaged, peak-normalized power targets
if size(Praw, 1) > 1
    mu_hat = mean(Praw, 1);
else
    mu_hat = Praw(:)';
end
max_mu = max(mu_hat);
if max_mu <= 0; max_mu = 1e-12; end
p_target = mu_hat / max_mu;

% 2. Initial guess: the orientation with the largest response points closest to n_d
[~, idx] = max(p_target);
best_nt = nt_rows(idx, :);
theta0 = acos(max(-1, min(1, -best_nt(3))));
phi0   = atan2(best_nt(2), best_nt(1));
x0 = [theta0, phi0, 1.0];

% 3. Solve
res_fcn = @(vars) nls_residuals_gauss(vars, p_target, nt_rows, theta_div);
sol = lsqnonlin(res_fcn, x0, [], [], opts_lm);

% 4. Spherical -> Cartesian
th = sol(1); ph = sol(2);
nd_hat = [sin(th)*cos(ph); sin(th)*sin(ph); -cos(th)];

% 5. Sign coherence (towards receiver)
if dot(nd_hat, nt(:,1)) < 0
    nd_hat = -nd_hat;
end
end

% --- Local: residual vector (Kx1) ---
function r = nls_residuals_gauss(vars, p_target, nt_rows, theta_div)
    theta_d = vars(1);
    phi_d   = vars(2);
    eta     = vars(3);
    v = [sin(theta_d)*cos(phi_d), sin(theta_d)*sin(phi_d), -cos(theta_d)];
    K = size(nt_rows, 1);
    r = zeros(K, 1);
    for i = 1:K
        Q = dot(nt_rows(i,:), v);
        if Q <= 0
            R_G = 0;
        else
            phi = acos(min(1, Q));
            R_G = exp(-2 * (phi / theta_div)^2);
        end
        r(i) = eta * R_G - p_target(i);
    end
end
