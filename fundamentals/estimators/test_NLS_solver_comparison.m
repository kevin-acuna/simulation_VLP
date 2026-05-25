%% test_NLS_solver_comparison.m
% Quick A/B test: fmincon/SQP vs lsqnonlin/Levenberg-Marquardt for NLS
% at a single SNR point. Also computes GLS, WLS, DEB for reference.
%
% Change SNR_TEST_dB to test different SNR levels (e.g., 40, 50).
%
% Author: Kevin Acuña

close all; clear variables; clc;
addpath('../core');

% =================================================
% CONFIGURATION — change these to test
% =================================================
SNR_TEST_dB    = 14;       % <-- CHANGE THIS to test different SNR
M_trials       = 1000;     % MC trials per position
N_or           = 5;
SNR_nominal_dB = 14;

%% System Parameters
system_params;
T = [0, 0, 2];

% GLS/WLS orientations
n_t_lin = zeros(N_or, 3);
for i = 1:N_or
    theta_i = orientations_GLS_DF_K5_MC10(2*i-1);
    rho_i   = orientations_GLS_DF_K5_MC10(2*i);
    n_t_lin(i,1) = sind(theta_i) * cosd(rho_i);
    n_t_lin(i,2) = sind(theta_i) * sind(rho_i);
    n_t_lin(i,3) = -cosd(theta_i);
end

% NLS orientations
n_t_nl = zeros(N_or, 3);
for i = 1:N_or
    theta_i = orientations_DEB_K5(2*i-1);
    rho_i   = orientations_DEB_K5(2*i);
    n_t_nl(i,1) = sind(theta_i) * cosd(rho_i);
    n_t_nl(i,2) = sind(theta_i) * sind(rho_i);
    n_t_nl(i,3) = -cosd(theta_i);
end

%% Noise level for this SNR
sigma2_nominal = sigma2;
sigma2_0dB     = sigma2_nominal * 10^(SNR_nominal_dB / 10);
s2             = sigma2_0dB / 10^(SNR_TEST_dB / 10);

fprintf('SNR = %d dB | sigma2 = %.4e\n', SNR_TEST_dB, s2);

%% Testbed grid (coarse for speed)
step_grid = 0.8;
stepH_grid = 0.6;
[X, Y, Z] = meshgrid(-L/2:step_grid:L/2, -W/2:step_grid:W/2, 0:stepH_grid:Hmax);
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);
fprintf('Positions: %d | M_trials: %d\n\n', N_pos, M_trials);

param_r = {A_det, n_r, FOV};
rad2deg_factor = 180 / pi;

% Solvers are now in core: vlp_nls_fmincon.m and vlp_nls_lm.m

%% MC Simulation
ang_GLS  = zeros(N_pos, 1);
ang_WLS  = zeros(N_pos, 1);
ang_NLS_A = zeros(N_pos, 1);  % fmincon
ang_NLS_B = zeros(N_pos, 1);  % lsqnonlin
ang_DEB  = zeros(N_pos, 1);

fprintf('Running MC simulation...\n');
t0_total = tic;

for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    R_real = [x; y; z];
    v_true = (R_real - T') / norm(R_real - T');
    
    % Clean powers
    P_clean_lin = zeros(1, N_or);
    P_clean_nl  = zeros(1, N_or);
    for i_dir = 1:N_or
        param_t = {T, n_t_lin(i_dir,:), P_t, m_t};
        [~, P_clean_lin(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
        param_t = {T, n_t_nl(i_dir,:), P_t, m_t};
        [~, P_clean_nl(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
    end
    
    % DEB
    deb_val = DEB_complete(R_real, n_t_nl', T', P_t, m_t, A_det, ...
        deg2rad(theta_half), deg2rad(FOV), s2, N_samples);
    if isreal(deb_val) && isfinite(deb_val) && deb_val > 0
        ang_DEB(i_pos) = deb_val * rad2deg_factor;
    else
        ang_DEB(i_pos) = NaN;
    end
    
    % MC
    gls_mc = zeros(M_trials,1); wls_mc = zeros(M_trials,1);
    nlsA_mc = zeros(M_trials,1); nlsB_mc = zeros(M_trials,1);
    
    for mc = 1:M_trials
        P_raw_lin = repmat(P_clean_lin, N_samples, 1) + sqrt(s2) .* randn(N_samples, N_or);
        P_raw_nl  = repmat(P_clean_nl, N_samples, 1) + sqrt(s2) .* randn(N_samples, N_or);
        
        % GLS
        [d_hat] = vlp_gls(n_t_lin', P_raw_lin, m_t, s2);
        nrm = norm(d_hat); if nrm < 1e-12; nrm = 1e-12; end
        v_est = d_hat' / nrm;
        gls_mc(mc) = acos(max(-1, min(1, v_true' * v_est'))) * rad2deg_factor;
        
        % WLS
        [d_hat, ~, ~] = vlp_wls(n_t_lin', P_raw_lin, m_t);
        nrm = norm(d_hat); if nrm < 1e-12; nrm = 1e-12; end
        v_est = d_hat' / nrm;
        wls_mc(mc) = acos(max(-1, min(1, v_true' * v_est'))) * rad2deg_factor;
        
        % --- A) NLS via fmincon/SQP (current) ---
        d_hat_A = vlp_nls_fmincon(n_t_nl', P_raw_nl, m_t);
        v_est = d_hat_A' / norm(d_hat_A);
        nlsA_mc(mc) = acos(max(-1, min(1, v_true' * v_est'))) * rad2deg_factor;
        
        % --- B) NLS via lsqnonlin/LM (proposed) ---
        d_hat_B = vlp_nls_lm(n_t_nl', P_raw_nl, m_t);
        v_est = d_hat_B' / norm(d_hat_B);
        nlsB_mc(mc) = acos(max(-1, min(1, v_true' * v_est'))) * rad2deg_factor;
    end
    
    ang_GLS(i_pos)   = sqrt(mean(gls_mc.^2));
    ang_WLS(i_pos)   = sqrt(mean(wls_mc.^2));
    ang_NLS_A(i_pos) = sqrt(mean(nlsA_mc.^2));
    ang_NLS_B(i_pos) = sqrt(mean(nlsB_mc.^2));
    
    if mod(i_pos, 10) == 0 || i_pos == N_pos
        fprintf('  pos %d/%d\n', i_pos, N_pos);
    end
end

elapsed = toc(t0_total);

%% Results
rmse_GLS   = sqrt(mean(ang_GLS.^2));
rmse_WLS   = sqrt(mean(ang_WLS.^2));
rmse_NLS_A = sqrt(mean(ang_NLS_A.^2));
rmse_NLS_B = sqrt(mean(ang_NLS_B.^2));
rmse_DEB   = sqrt(nanmean(ang_DEB.^2));

fprintf('\n========================================================\n');
fprintf(' SOLVER COMPARISON @ SNR = %d dB (K=%d, %d MC, %d pos)\n', ...
    SNR_TEST_dB, N_or, M_trials, N_pos);
fprintf('========================================================\n');
fprintf('%-25s %12s %10s\n', 'Method', 'RMSE [deg]', 'Ratio/DEB');
fprintf('%-25s %12.6f %10s\n', 'DEB (bound)',         rmse_DEB,   '1.00');
fprintf('%-25s %12.6f %10.2f\n', 'GLS',               rmse_GLS,   rmse_GLS/rmse_DEB);
fprintf('%-25s %12.6f %10.2f\n', 'WLS',               rmse_WLS,   rmse_WLS/rmse_DEB);
fprintf('%-25s %12.6f %10.2f\n', 'NLS-A (fmincon/SQP)',  rmse_NLS_A, rmse_NLS_A/rmse_DEB);
fprintf('%-25s %12.6f %10.2f\n', 'NLS-B (lsqnonlin/LM)', rmse_NLS_B, rmse_NLS_B/rmse_DEB);
fprintf('--------------------------------------------------------\n');
fprintf('Improvement B vs A: %.1f%%\n', (1 - rmse_NLS_B/rmse_NLS_A)*100);
fprintf('Elapsed: %.1f s\n', elapsed);
fprintf('========================================================\n');

% NLS estimators are in core/vlp_nls_fmincon.m and core/vlp_nls_lm.m
