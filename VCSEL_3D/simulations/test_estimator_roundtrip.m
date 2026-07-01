%% test_estimator_roundtrip.m — Smoke/regression test for the Gaussian pipeline
%
% Verifies that the two-stage broadcast estimator
%   gaussian_channel -> vlp_nls_gaussian (direction) -> broadcast_distance_Gaussian
% recovers the true 3D position, and that the Monte-Carlo RMSE approaches the
% analytic PEB (PEB_Gaussian) at high sample count.
%
% Author: Kevin Acuna-Condori
% Project: VCSEL Gaussian OWP

clear; clc;
rng(7);

project_root = fileparts(pwd);
addpath(fullfile(project_root, 'core'));
system_params_VCSEL;

Psi_FOV = deg2rad(FOV);
nr = n_r(:);
C_opt = 2 * P_t * A_det / pi;

% --- Configuration in a well-covered regime ---
theta_div = deg2rad(20);
K  = 15;
nt = generate_codebook(K, theta_cap, 'sunflower');
R_true = [0.4; -0.3; 0.8];
M = 3000;

% --- Clean powers ---
mu_clean = zeros(1, K);
for i = 1:K
    mu_clean(i) = gaussian_channel(R_true, nt(:,i), T, P_t, theta_div, A_det, Psi_FOV, nr);
end
fprintf('Active orientations (mu>0): %d / %d\n', nnz(mu_clean > 0), K);

% --- Noiseless recovery (sanity) ---
nd0 = vlp_nls_gaussian(nt, mu_clean, theta_div);
d0  = broadcast_distance_Gaussian(nd0, nt, mu_clean, theta_div, C_opt, nr);
r0  = T(:) + d0 * nd0;
fprintf('Noiseless position error: %.4f cm\n', 100*norm(r0 - R_true));

% --- Monte-Carlo under noise ---
err = zeros(M,1);
for mc = 1:M
    Praw = repmat(mu_clean, N_samples, 1) + sqrt(sigma2)*randn(N_samples, K);
    mu_hat = mean(Praw, 1);
    nd = vlp_nls_gaussian(nt, Praw, theta_div);
    d  = broadcast_distance_Gaussian(nd, nt, mu_hat, theta_div, C_opt, nr);
    if isnan(d), err(mc) = NaN; continue; end
    r_hat = T(:) + d*nd;
    err(mc) = norm(r_hat - R_true);
end
err = err(isfinite(err));

rmse = sqrt(mean(err.^2));
peb  = PEB_Gaussian(R_true, nt, T, P_t, theta_div, A_det, Psi_FOV, sigma2, N_samples, nr);

fprintf('\n=== Round-trip (theta=%d deg, K=%d, N=%d, M=%d trials) ===\n', ...
    rad2deg(theta_div), K, N_samples, numel(err));
fprintf('MC RMSE : %.2f cm\n', 100*rmse);
fprintf('PEB     : %.2f cm\n', 100*peb);
fprintf('RMSE/PEB: %.2f  (near 1 => estimator efficient)\n', rmse/peb);

if 100*norm(r0 - R_true) < 1e-3 && rmse/peb < 3
    fprintf('RESULT: PASS\n');
else
    fprintf('RESULT: CHECK\n');
end
