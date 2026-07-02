%% validate_gradient_Gaussian.m — Finite-difference validation of the Gaussian gradient
%
% Independently verifies the analytic gradient used inside core/PEB_Gaussian.m:
%
%   grad_r mu_i = (mu_i/d) * [ alpha_i*(n_t,i - Q_i*n_d) - n_r/cos(psi) - 3*n_d ]
%   alpha_i     = 4*phi_i / (theta_div^2 * sin(phi_i))
%
% against a central finite-difference gradient of mu_i computed from the raw
% channel model (core/gaussian_channel.m). Also cross-checks the PEB against a
% brute-force FIM assembled from the finite-difference gradients.
%
% Run from VCSEL_3D/simulations/. Prints max relative errors; PASS if < 1e-4.
%
% Author: Kevin Acuna-Condori
% Project: VCSEL Gaussian OWP

clear; clc;

%% Paths + params
project_root = fileparts(pwd);
addpath(fullfile(project_root, 'core'));
system_params_VCSEL;

nr = n_r(:);
Psi_FOV = deg2rad(FOV);
Tc = T(:);

%% Test configurations (positions x divergence angles)
test_positions = [ ...
    0.4,  0.3, 0.8;   ...
   -0.9,  0.6, 0.0;   ...
    1.2, -1.1, 1.2;   ...
    0.0,  0.0, 1.0];       % near-boresight case
theta_div_list = deg2rad([5, 10, 20, 30]);
h = 1e-7;                                  % finite-difference step [m]

fprintf('%s\n', repmat('=', 1, 68));
fprintf(' GAUSSIAN GRADIENT / PEB VALIDATION (central finite differences)\n');
fprintf('%s\n', repmat('=', 1, 68));

max_grad_err = 0;
max_peb_err  = 0;

for it = 1:numel(theta_div_list)
    theta_div = theta_div_list(it);

    % A representative codebook for this divergence
    K = 9;
    nt = generate_codebook(K, theta_cap, 'sunflower');

    for ip = 1:size(test_positions, 1)
        R = test_positions(ip, :)';

        % ---- Analytic gradient per orientation + brute-force FIM ----
        I_fisher_fd = zeros(3);
        for i = 1:K
            g_an = analytic_grad(R, nt(:, i), Tc, P_t, theta_div, A_det, Psi_FOV, nr);

            % Central finite-difference gradient of mu_i
            g_fd = zeros(3, 1);
            for k = 1:3
                Rp = R; Rp(k) = Rp(k) + h;
                Rm = R; Rm(k) = Rm(k) - h;
                mu_p = gaussian_channel(Rp, nt(:, i), Tc, P_t, theta_div, A_det, Psi_FOV, nr);
                mu_m = gaussian_channel(Rm, nt(:, i), Tc, P_t, theta_div, A_det, Psi_FOV, nr);
                g_fd(k) = (mu_p - mu_m) / (2*h);
            end

            % Compare only when the orientation is active (mu>0)
            mu0 = gaussian_channel(R, nt(:, i), Tc, P_t, theta_div, A_det, Psi_FOV, nr);
            if mu0 > 0
                rel = norm(g_an - g_fd) / max(norm(g_fd), 1e-30);
                max_grad_err = max(max_grad_err, rel);
                I_fisher_fd = I_fisher_fd + (N_samples/sigma2) * (g_fd * g_fd');
            end
        end

        % ---- PEB: analytic (PEB_Gaussian) vs brute-force FD FIM ----
        % Only judged in the well-conditioned (covered) regime: an ill-conditioned
        % FIM (PEB of metres) is physically an outage and finite differencing there
        % is meaningless.
        peb_an = PEB_Gaussian(R, nt, Tc, P_t, theta_div, A_det, Psi_FOV, sigma2, N_samples, nr);
        well_cond = rank(I_fisher_fd) == 3 && cond(I_fisher_fd) < 1e10;
        if well_cond && isfinite(peb_an) && peb_an < 5
            peb_fd = sqrt(trace(inv(I_fisher_fd)));
            rel_peb = abs(peb_an - peb_fd) / max(peb_fd, 1e-30);
            max_peb_err = max(max_peb_err, rel_peb);
            fprintf('theta=%2.0f deg  R=[%5.1f %5.1f %4.1f]  PEB_an=%7.2f cm  PEB_fd=%7.2f cm  relPEB=%.2e\n', ...
                rad2deg(theta_div), R(1), R(2), R(3), 100*peb_an, 100*peb_fd, rel_peb);
        else
            fprintf('theta=%2.0f deg  R=[%5.1f %5.1f %4.1f]  (uncovered / ill-conditioned FIM; skipped)\n', ...
                rad2deg(theta_div), R(1), R(2), R(3));
        end
    end
end

fprintf('%s\n', repmat('-', 1, 68));
fprintf('Max relative gradient error : %.3e\n', max_grad_err);
fprintf('Max relative PEB error      : %.3e\n', max_peb_err);
tol = 1e-4;
if max_grad_err < tol && max_peb_err < tol
    fprintf('RESULT: PASS (both errors < %.0e)\n', tol);
else
    fprintf('RESULT: CHECK — an error exceeds %.0e\n', tol);
end
fprintf('%s\n', repmat('=', 1, 68));

%% --- Local: analytic gradient (mirrors PEB_Gaussian.m) ---
function g = analytic_grad(R, nt_i, T, Pt, theta_div, A_det, Psi_FOV, nr)
    d_vec = R - T; d = norm(d_vec); nd = d_vec / d;
    C_opt = 2 * Pt * A_det / pi;
    cos_psi = -(nr' * nd);
    psi = acos(min(1, max(-1, cos_psi)));
    Q_i = nt_i' * nd;
    if cos_psi <= 0 || psi > Psi_FOV || Q_i <= 0
        g = zeros(3, 1); return;
    end
    phi_i = acos(min(1, max(-1, Q_i)));
    R_G = exp(-2 * (phi_i/theta_div)^2);
    mu_i = C_opt * cos_psi / (theta_div^2 * d^2) * R_G;
    if phi_i < 1e-8
        alpha_i = 4 / theta_div^2;
    else
        alpha_i = 4 * phi_i / (theta_div^2 * sin(phi_i));
    end
    g = (mu_i / d) * (alpha_i * (nt_i - Q_i*nd) - nr/cos_psi - 3*nd);
end
