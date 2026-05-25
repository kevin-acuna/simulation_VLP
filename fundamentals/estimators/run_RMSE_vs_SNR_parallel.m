%% run_RMSE_vs_SNR_parallel.m
% IEEE TCOM — RMSE of estimators (GLS, WLS, NLS) vs SNR
% Responds to R2-C11 ("performance via SNR should also be provided") and
% R3-C6 ("analyze the impact of different ambient light power levels").
%
% For each SNR point, runs a full Monte Carlo simulation over the 3D testbed
% and computes:
%   (a) Angular RMSE [°] for Direction Finding stage (GLS, WLS, NLS)
%   (b) Position RMSE [cm] for full 3D positioning (GLS, WLS, NLS)
%
% Orientation sets (K=5):
%   - GLS/WLS: orientations_GLS_DF_K5_MC10
%   - NLS:     orientations_DEB_K5
%
% Uses the same estimator implementations as run_DF_comparison_MC_parallel.m
% and run_3D_comparison_MC_parallel.m but sweeps sigma² across SNR values.
%
% Output: .mat file with all results + log, for subsequent plotting with
%         plot_RMSE_vs_SNR.m
%
% Author: Kevin Acuña

close all; clear variables; clc;
addpath('../core');

% =================================================
% HYPERPARAMETERS
% =================================================
rng(42);
TEST_MODE    = false;      % true = fast test (coarse grid, few trials)
M_trials     = 1000;        % Monte Carlo trials per position per SNR
N_or         = 5;          % Number of orientations (K=5, main operating point)
save_files   = 1;

% SNR sweep: the nominal sigma2 from system_params.m corresponds to ~14 dB.
% We define sigma2(SNR) = sigma2_0dB / 10^(SNR/10), where sigma2_0dB is the
% noise at SNR=0 dB, calibrated so that sigma2_nominal → 14 dB.
SNR_nominal_dB = 14;       % SNR corresponding to sigma2 in system_params.m
SNR_dB         = 0:5:50;   % 11 SNR points [dB]

if TEST_MODE
    M_trials = 50;
    SNR_dB   = [0, 14, 30, 50];
end

%% 0. Parallel Pool Setup
fprintf('Setting up parallel pool...\n');
if isempty(gcp('nocreate'))
    pool = parpool('local');
else
    pool = gcp;
end
fprintf('Using %d parallel workers.\n\n', pool.NumWorkers);

%% 1. System Parameters
system_params;
T = [0, 0, 2];

% Build orientation matrices for K=5
% GLS/WLS use orientations_GLS_DF_K5_MC10
n_t_lin = zeros(N_or, 3);
for i = 1:N_or
    theta_i = orientations_GLS_DF_K5_MC10(2*i-1);
    rho_i   = orientations_GLS_DF_K5_MC10(2*i);
    n_t_lin(i,1) = sind(theta_i) * cosd(rho_i);
    n_t_lin(i,2) = sind(theta_i) * sind(rho_i);
    n_t_lin(i,3) = -cosd(theta_i);
end

% NLS uses orientations_DEB_K5
n_t_nl = zeros(N_or, 3);
for i = 1:N_or
    theta_i = orientations_DEB_K5(2*i-1);
    rho_i   = orientations_DEB_K5(2*i);
    n_t_nl(i,1) = sind(theta_i) * cosd(rho_i);
    n_t_nl(i,2) = sind(theta_i) * sind(rho_i);
    n_t_nl(i,3) = -cosd(theta_i);
end

%% 2. Generate Receiver Positions (testbed grid)
if TEST_MODE
    [X, Y, Z] = meshgrid(-1.5:0.5:1.5, -1.5:0.5:1.5, 0:0.6:1.2);
else
    step_grid = 0.3;  % coarser than paper grid (0.2) for tractable sweep
    stepH_grid = 0.3;
    [X, Y, Z] = meshgrid(-L/2:step_grid:L/2, -W/2:step_grid:W/2, 0:stepH_grid:Hmax);
end
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);

param_r = {A_det, n_r, FOV};

%% 3. SNR sweep setup
% sigma2 from system_params.m is the noise at the nominal operating point (14 dB).
% Calibrate: sigma2_0dB = sigma2_nominal * 10^(SNR_nominal/10)
sigma2_nominal = sigma2;
sigma2_0dB     = sigma2_nominal * 10^(SNR_nominal_dB / 10);  % noise at 0 dB
sigma2_vec     = sigma2_0dB ./ 10.^(SNR_dB / 10);
nSNR           = numel(SNR_dB);

% Pre-allocate results arrays
% Direction-Finding RMSE [degrees]
rmse_DF_GLS = zeros(nSNR, 1);
rmse_DF_WLS = zeros(nSNR, 1);
rmse_DF_NLS = zeros(nSNR, 1);
rmse_DEB    = zeros(nSNR, 1);

% 3D Positioning RMSE [meters]
rmse_3D_GLS = zeros(nSNR, 1);
rmse_3D_WLS = zeros(nSNR, 1);
rmse_3D_NLS = zeros(nSNR, 1);
rmse_PEB    = zeros(nSNR, 1);

% CDF-90 arrays
cdf90_DF_GLS = zeros(nSNR, 1);
cdf90_DF_WLS = zeros(nSNR, 1);
cdf90_DF_NLS = zeros(nSNR, 1);
cdf90_3D_GLS = zeros(nSNR, 1);
cdf90_3D_WLS = zeros(nSNR, 1);
cdf90_3D_NLS = zeros(nSNR, 1);

% Timing per SNR point
time_per_SNR = zeros(nSNR, 1);

%% Log setup
results_subdir = fullfile(fileparts(mfilename('fullpath')), 'results', ...
    sprintf('K%d_RMSE_vs_SNR', N_or));
if ~exist(results_subdir, 'dir'), mkdir(results_subdir); end

log_filename = fullfile(results_subdir, ...
    sprintf('K%d_RMSE_vs_SNR_log_%s.txt', N_or, datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
diary(log_filename);

fprintf('%s\n', repmat('=', 1, 70));
fprintf(' RMSE vs SNR SIMULATION LOG\n');
fprintf('%s\n', repmat('=', 1, 70));
fprintf('Date       : %s\n', datestr(now));
fprintf('K (N_or)   : %d\n', N_or);
fprintf('M_trials   : %d\n', M_trials);
fprintf('N_pos      : %d\n', N_pos);
fprintf('N_samples  : %d\n', N_samples);
fprintf('SNR range  : [%d, %d] dB, step %d dB (%d points)\n', SNR_dB(1), SNR_dB(end), SNR_dB(2)-SNR_dB(1), nSNR);
fprintf('SNR_nominal: %d dB (sigma2 = %.4e W^2)\n', SNR_nominal_dB, sigma2_nominal);
fprintf('sigma2_0dB : %.4e W^2\n', sigma2_0dB);
fprintf('TEST_MODE  : %d\n', TEST_MODE);
fprintf('Workers    : %d\n', pool.NumWorkers);
fprintf('%s\n\n', repmat('=', 1, 70));

rad2deg_factor = 180 / pi;

%% 4. Main SNR Sweep Loop
total_t0 = tic;

for i_snr = 1:nSNR
    s2 = sigma2_vec(i_snr);
    fprintf('\n--- SNR = %+.0f dB (sigma2 = %.4e) ---\n', SNR_dB(i_snr), s2);
    snr_t0 = tic;
    
    % Per-position results for this SNR
    ang_GLS_pos = zeros(N_pos, 1);
    ang_WLS_pos = zeros(N_pos, 1);
    ang_NLS_pos = zeros(N_pos, 1);
    deb_pos     = zeros(N_pos, 1);
    
    pos_GLS_pos = zeros(N_pos, 1);
    pos_WLS_pos = zeros(N_pos, 1);
    pos_NLS_pos = zeros(N_pos, 1);
    peb_pos     = zeros(N_pos, 1);
    
    % Progress
    D = parallel.pool.DataQueue;
    afterEach(D, @(msg) fprintf('  [SNR=%+.0f dB] pos %d/%d\n', SNR_dB(i_snr), msg, N_pos));
    
    parfor i_pos = 1:N_pos
        x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
        R_real = [x; y; z];
        realPos_i = [x, y, z];
        v_true = (R_real - T') / norm(R_real - T');
        
        % --- Clean channel powers (GLS/WLS orientations) ---
        P_clean_lin = zeros(1, N_or);
        for i_dir = 1:N_or
            param_t = {T, n_t_lin(i_dir,:), P_t, m_t};
            [~, P_clean_lin(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
        end
        
        % --- Clean channel powers (NLS orientations) ---
        P_clean_nl = zeros(1, N_or);
        for i_dir = 1:N_or
            param_t = {T, n_t_nl(i_dir,:), P_t, m_t};
            [~, P_clean_nl(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
        end
        
        % --- Theoretical Bounds (DEB and PEB with NLS orientations) ---
        deb_val = DEB_complete(R_real, n_t_nl', T', P_t, m_t, A_det, ...
            deg2rad(theta_half), deg2rad(FOV), s2, N_samples);
        peb_val = PEB_complete(R_real, n_t_nl', T', P_t, m_t, A_det, ...
            deg2rad(theta_half), deg2rad(FOV), s2, N_samples);
        if isreal(deb_val) && isfinite(deb_val) && deb_val > 0
            deb_pos(i_pos) = deb_val * rad2deg_factor;
        else
            deb_pos(i_pos) = NaN;
        end
        if isreal(peb_val) && isfinite(peb_val) && peb_val > 0
            peb_pos(i_pos) = peb_val;
        else
            peb_pos(i_pos) = NaN;
        end
        
        % --- MC Trials ---
        ang_GLS_mc = zeros(M_trials, 1);
        ang_WLS_mc = zeros(M_trials, 1);
        ang_NLS_mc = zeros(M_trials, 1);
        pos_GLS_mc = zeros(M_trials, 1);
        pos_WLS_mc = zeros(M_trials, 1);
        pos_NLS_mc = zeros(M_trials, 1);
        
        d_max = 5;  % max plausible distance [m] (room diagonal ≈ 2.9 m)
        for mc = 1:M_trials
            % Noisy powers (DF stage) — separate for linear and NLS
            P_raw_lin = repmat(P_clean_lin, N_samples, 1) + sqrt(s2) .* randn(N_samples, N_or);
            P_raw_nl  = repmat(P_clean_nl, N_samples, 1) + sqrt(s2) .* randn(N_samples, N_or);
            
            % ===== GLS =====
            [d_hat_gls] = vlp_gls(n_t_lin', P_raw_lin, m_t, s2);
            nrm_gls = norm(d_hat_gls);
            if nrm_gls < 1e-12; nrm_gls = 1e-12; end
            v_est_gls = d_hat_gls' / nrm_gls;
            ang_GLS_mc(mc) = acos(max(-1, min(1, v_true' * v_est_gls'))) * rad2deg_factor;
            % 3D: distance recovery
            param_t_ax = {T, v_est_gls, P_t, m_t};
            param_r_ax = {A_det, -v_est_gls, FOV};
            [~, P_ax, ~, ~] = OWC_LOS_channel(x, y, z, param_t_ax, param_r_ax);
            P_ax_noisy = P_ax + sqrt(s2) .* randn(1, N_samples);
            P_ax_mean = max(mean(P_ax_noisy), 1e-20);
            d_est = min(sqrt(P_t*(m_t+1)*A_det / (2*pi*P_ax_mean)), d_max);
            estPos_gls = T + v_est_gls .* d_est;
            pos_GLS_mc(mc) = norm(realPos_i - estPos_gls);
            
            % ===== WLS =====
            [d_hat_wls, ~, ~] = vlp_wls(n_t_lin', P_raw_lin, m_t);
            nrm_wls = norm(d_hat_wls);
            if nrm_wls < 1e-12; nrm_wls = 1e-12; end
            v_est_wls = d_hat_wls' / nrm_wls;
            ang_WLS_mc(mc) = acos(max(-1, min(1, v_true' * v_est_wls'))) * rad2deg_factor;
            % 3D: distance recovery
            param_t_ax = {T, v_est_wls, P_t, m_t};
            param_r_ax = {A_det, -v_est_wls, FOV};
            [~, P_ax, ~, ~] = OWC_LOS_channel(x, y, z, param_t_ax, param_r_ax);
            P_ax_noisy = P_ax + sqrt(s2) .* randn(1, N_samples);
            P_ax_mean = max(mean(P_ax_noisy), 1e-20);
            d_est = min(sqrt(P_t*(m_t+1)*A_det / (2*pi*P_ax_mean)), d_max);
            estPos_wls = T + v_est_wls .* d_est;
            pos_WLS_mc(mc) = norm(realPos_i - estPos_wls);
            
            % ===== NLS (lsqnonlin/LM via core function) =====
            d_hat_nl = vlp_nls_lm(n_t_nl', P_raw_nl, m_t);
            v_est_nl = d_hat_nl' / norm(d_hat_nl);
            ang_NLS_mc(mc) = acos(max(-1, min(1, v_true' * v_est_nl'))) * rad2deg_factor;
            % 3D: distance recovery
            param_t_ax = {T, v_est_nl, P_t, m_t};
            param_r_ax = {A_det, -v_est_nl, FOV};
            [~, P_ax, ~, ~] = OWC_LOS_channel(x, y, z, param_t_ax, param_r_ax);
            P_ax_noisy = P_ax + sqrt(s2) .* randn(1, N_samples);
            P_ax_mean = max(mean(P_ax_noisy), 1e-20);
            d_est = min(sqrt(P_t*(m_t+1)*A_det / (2*pi*P_ax_mean)), d_max);
            estPos_nl = T + v_est_nl .* d_est;
            pos_NLS_mc(mc) = norm(realPos_i - estPos_nl);
        end
        
        % Per-position RMSE
        ang_GLS_pos(i_pos) = sqrt(mean(ang_GLS_mc.^2));
        ang_WLS_pos(i_pos) = sqrt(mean(ang_WLS_mc.^2));
        ang_NLS_pos(i_pos) = sqrt(mean(ang_NLS_mc.^2));
        pos_GLS_pos(i_pos) = sqrt(mean(pos_GLS_mc.^2));
        pos_WLS_pos(i_pos) = sqrt(mean(pos_WLS_mc.^2));
        pos_NLS_pos(i_pos) = sqrt(mean(pos_NLS_mc.^2));
        
        % Progress (every 20 positions)
        if mod(i_pos, 20) == 0 || i_pos == N_pos
            send(D, i_pos);
        end
    end
    
    % Aggregate: global RMS of per-position RMSE
    rmse_DF_GLS(i_snr) = sqrt(mean(ang_GLS_pos.^2));
    rmse_DF_WLS(i_snr) = sqrt(mean(ang_WLS_pos.^2));
    rmse_DF_NLS(i_snr) = sqrt(mean(ang_NLS_pos.^2));
    rmse_DEB(i_snr)    = sqrt(nanmean(deb_pos.^2));
    
    rmse_3D_GLS(i_snr) = sqrt(mean(pos_GLS_pos.^2));
    rmse_3D_WLS(i_snr) = sqrt(mean(pos_WLS_pos.^2));
    rmse_3D_NLS(i_snr) = sqrt(mean(pos_NLS_pos.^2));
    rmse_PEB(i_snr)    = sqrt(nanmean(peb_pos.^2));
    
    % CDF-90
    cdf90_DF_GLS(i_snr) = prctile(ang_GLS_pos, 90);
    cdf90_DF_WLS(i_snr) = prctile(ang_WLS_pos, 90);
    cdf90_DF_NLS(i_snr) = prctile(ang_NLS_pos, 90);
    cdf90_3D_GLS(i_snr) = prctile(pos_GLS_pos, 90);
    cdf90_3D_WLS(i_snr) = prctile(pos_WLS_pos, 90);
    cdf90_3D_NLS(i_snr) = prctile(pos_NLS_pos, 90);
    
    time_per_SNR(i_snr) = toc(snr_t0);
    
    fprintf('  Elapsed: %.1f s (%.2f s/pos, %.4f s/trial)\n', ...
        time_per_SNR(i_snr), time_per_SNR(i_snr)/N_pos, time_per_SNR(i_snr)/(N_pos*M_trials));
    fprintf('  DF RMSE  [deg] — GLS: %.3f | WLS: %.3f | NLS: %.3f | DEB: %.3f\n', ...
        rmse_DF_GLS(i_snr), rmse_DF_WLS(i_snr), rmse_DF_NLS(i_snr), rmse_DEB(i_snr));
    fprintf('  3D RMSE  [cm]  — GLS: %.2f | WLS: %.2f | NLS: %.2f | PEB: %.2f\n', ...
        rmse_3D_GLS(i_snr)*100, rmse_3D_WLS(i_snr)*100, rmse_3D_NLS(i_snr)*100, rmse_PEB(i_snr)*100);
    
    % Estimated remaining time
    avg_time_per_snr = mean(time_per_SNR(1:i_snr));
    remaining_snr = nSNR - i_snr;
    fprintf('  Avg time/SNR: %.1f s | Remaining: ~%.1f min (%d SNR points left)\n', ...
        avg_time_per_snr, remaining_snr*avg_time_per_snr/60, remaining_snr);
    
    % Intermediate save after each SNR point (protection against crashes)
    save(fullfile(results_subdir, 'workspace_partial.mat'));
end

total_time = toc(total_t0);

%% 5. Summary Table
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf(' SUMMARY: RMSE vs SNR (K=%d, %d MC trials/pos, %d positions)\n', N_or, M_trials, N_pos);
fprintf('%s\n', repmat('=', 1, 70));
fprintf('\n--- Direction Finding RMSE [degrees] ---\n');
fprintf('%-8s %10s %10s %10s %10s\n', 'SNR[dB]', 'GLS', 'WLS', 'NLS', 'DEB');
for i = 1:nSNR
    fprintf('%-8.0f %10.4f %10.4f %10.4f %10.4f\n', ...
        SNR_dB(i), rmse_DF_GLS(i), rmse_DF_WLS(i), rmse_DF_NLS(i), rmse_DEB(i));
end

fprintf('\n--- 3D Positioning RMSE [cm] ---\n');
fprintf('%-8s %10s %10s %10s %10s\n', 'SNR[dB]', 'GLS', 'WLS', 'NLS', 'PEB');
for i = 1:nSNR
    fprintf('%-8.0f %10.2f %10.2f %10.2f %10.2f\n', ...
        SNR_dB(i), rmse_3D_GLS(i)*100, rmse_3D_WLS(i)*100, rmse_3D_NLS(i)*100, rmse_PEB(i)*100);
end

fprintf('\nTotal computation time: %.1f min\n', total_time/60);

fprintf('\n--- Timing per SNR point ---\n');
fprintf('%-8s %12s %12s %14s\n', 'SNR[dB]', 'Time[s]', 'Time/pos[s]', 'Time/trial[ms]');
for i = 1:nSNR
    fprintf('%-8.0f %12.1f %12.3f %14.4f\n', ...
        SNR_dB(i), time_per_SNR(i), time_per_SNR(i)/N_pos, time_per_SNR(i)/(N_pos*M_trials)*1000);
end
fprintf('%-8s %12.1f %12.3f %14.4f\n', ...
    'AVG', mean(time_per_SNR), mean(time_per_SNR)/N_pos, mean(time_per_SNR)/(N_pos*M_trials)*1000);
fprintf('%s\n', repmat('=', 1, 70));

%% 6. Save Results
if save_files
    matfile = fullfile(results_subdir, ...
        sprintf('K%d_RMSE_vs_SNR_%s.mat', N_or, datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
    save(matfile, ...
        'SNR_dB', 'sigma2_vec', 'sigma2_nominal', 'sigma2_0dB', 'SNR_nominal_dB', 'nSNR', ...
        'rmse_DF_GLS', 'rmse_DF_WLS', 'rmse_DF_NLS', 'rmse_DEB', ...
        'rmse_3D_GLS', 'rmse_3D_WLS', 'rmse_3D_NLS', 'rmse_PEB', ...
        'cdf90_DF_GLS', 'cdf90_DF_WLS', 'cdf90_DF_NLS', ...
        'cdf90_3D_GLS', 'cdf90_3D_WLS', 'cdf90_3D_NLS', ...
        'time_per_SNR', ...
        'N_or', 'M_trials', 'N_pos', 'N_samples', 'total_time');
    fprintf('\nResults saved to: %s\n', matfile);
end

% Save full workspace (backup)
save(fullfile(results_subdir, 'workspace_full.mat'));
fprintf('Full workspace saved to: %s\n', fullfile(results_subdir, 'workspace_full.mat'));

fprintf('\nLog saved to: %s\n', log_filename);
diary off;

% NLS estimator is in core/vlp_nls_lm.m (lsqnonlin/Levenberg-Marquardt)
