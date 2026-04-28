%% Run GLS and WLS Estimators for VLP — Direction-Finding Only
% This script runs the GLS and WLS direction estimators, computes the 
% angular/chordal error of the estimated 3D unit vectors, compares them 
% against the theoretical DEB (Direction Error Bound), and saves results.
%
% Usage:
%   Set N_or (number of orientations) and save_files=1, then run.
%   Output .mat files go to estimators/results/
%
% Requires: core/ in path (vlp_gls.m, vlp_wls.m, OWC_LOS_channel.m, DEB_complete.m)
%
% Author: Kevin Acuña
% Date: 28/07/2025

close all; clear variables; clc;

% Add core functions to path
addpath('../core');

% =================================================
% HYPERPARAMETERS (only things that change per run)
% =================================================
rng(42);
N_or = 5;              % Number of orientations (change to 5 or 9)
save_files = 0;        % 1 = save .mat files to results/
receiver_mode = 'fixed'; % 'fixed' (testbed grid) or 'random'

%% 1. System Parameters (shared)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
system_params;         % Loads: P_t, theta_half, m_t, A_det, R_pd, FOV, n_r,
                       %        sigma2, C, L, W, Hmax, N_samples, step, stepH,
                       %        all_orientations, K_values, etc.
T = [0, 0, 2];         % LED position 

% Convert orientations to cartesian vectors
n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = all_orientations{N_or-2}(2*i-1);
    rho_i = all_orientations{N_or-2}(2*i);
    n_t(i,1) = sind(theta_i) * cosd(rho_i);
    n_t(i,2) = sind(theta_i) * sind(rho_i);
    n_t(i,3) = -cosd(theta_i);
end

%% 2. Generate Receiver Positions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if strcmp(receiver_mode, 'fixed')
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
    X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
    N_pos = length(X_r);
    fprintf('Using %d fixed grid positions (testbed)\n', N_pos);
else
    N_pos = 1000;
    X_r = -L/2 + L.*rand(1,N_pos);
    Y_r = -W/2 + W.*rand(1,N_pos);
    Z_r = Hmax*rand(1,N_pos);
    fprintf('Using %d random positions\n', N_pos);
end

param_r = {A_det, n_r, FOV};

%% 3. Simulation Core — Received Powers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
P_r = cell(N_pos, N_or);
P_r_noisy = cell(N_pos, N_or);
v_tr = zeros(N_pos, 3);
SNR_avg = [];

for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
        P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,N_samples));
        SNR_avg = [SNR_avg, ((R_pd*P_r{i_pos,i_dir})^2/(sigma2*R_pd^2))];
    end
end
fprintf('Average SNR: %.2f dB\n', 10*log10(mean(SNR_avg)));

%% 4. Direction Estimation (Stage 1 Only)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
v_tr_est_WLS = zeros(N_pos, 3);
v_tr_est_GLS = zeros(N_pos, 3);
time_WLS = []; time_GLS = [];

for i_pos = 1:N_pos
    P_raw = zeros(N_samples, N_or);
    for i_dir = 1:N_or
        P_raw(:, i_dir) = P_r_noisy{i_pos, i_dir};
    end

    % WLS
    tic;
    [d_hat_robust, ~, ~] = vlp_wls(n_t', P_raw, m_t);
    time_WLS = [time_WLS; toc];
    v_est = d_hat_robust';
    v_tr_est_WLS(i_pos,:) = v_est / norm(v_est); % Ensure perfect unit norm

    % GLS
    tic;
    [d_hat_gls] = vlp_gls(n_t', P_raw, m_t, sigma2);
    time_GLS = [time_GLS; toc];
    v_est = d_hat_gls';
    v_tr_est_GLS(i_pos,:) = v_est / norm(v_est); % Ensure perfect unit norm
end

%% 5. Error Calculation + DEB (In Degrees)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
errorAngWLS = zeros(N_pos, 1);
errorAngGLS = zeros(N_pos, 1);
errorAngDEB = zeros(1, N_pos);

rad2deg_factor = 180 / pi;

for i = 1:N_pos
    R_real = [X_r(i); Y_r(i); Z_r(i)];
    
    % True direction vector
    v_true = (R_real - T') / norm(R_real - T');
    
    % Empirical Errors: Chordal distance converted to degrees
    errorAngWLS(i) = norm(v_true - v_tr_est_WLS(i,:)') * rad2deg_factor;
    errorAngGLS(i) = norm(v_true - v_tr_est_GLS(i,:)') * rad2deg_factor;
    
    % Theoretical DEB: converted to degrees
    deb_val = DEB_complete(R_real, n_t', T', P_t, m_t, A_det, deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples);
    
    if isreal(deb_val) && isfinite(deb_val)
        errorAngDEB(i) = deb_val * rad2deg_factor;
    else
        errorAngDEB(i) = NaN;
    end
end

rmseWLS = sqrt(mean(errorAngWLS.^2));
rmseGLS = sqrt(mean(errorAngGLS.^2));
rmseDEB = sqrt(nanmean(errorAngDEB.^2));

%% 6. Display Results
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('\n==== DIRECTION-FINDING RESULTS K=%d ====\n', N_or);
fprintf('RMSE (deg)  — WLS: %.3f° | GLS: %.3f° | DEB: %.3f°\n', rmseWLS, rmseGLS, rmseDEB);
fprintf('CDF90 (deg) — WLS: %.3f° | GLS: %.3f° | DEB: %.3f°\n', prctile(errorAngWLS,90), prctile(errorAngGLS,90), prctile(errorAngDEB(~isnan(errorAngDEB)),90));
fprintf('Mean (deg)  — WLS: %.3f° | GLS: %.3f° | DEB: %.3f°\n', mean(errorAngWLS), mean(errorAngGLS), nanmean(errorAngDEB));
fprintf('Time per pos— WLS: %.4f ms | GLS: %.4f ms\n', median(time_WLS)*1000, median(time_GLS)*1000);

%% 7. Quick CDF Plot
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure;
hold on;
[f, x] = ecdf(errorAngGLS); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', [0, 0.4470, 0.7410]);
[f, x] = ecdf(errorAngWLS); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', [0.8500, 0.3250, 0.0980]);
[f, x] = ecdf(errorAngDEB(~isnan(errorAngDEB))); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', [0.4660, 0.6740, 0.1880]);
yline(0.9, '--', 'LineWidth', 0.4, 'Color', [0.5 0.5 0.5]);
xlim([0 5])
xlabel('Angular Error [degrees]', 'Interpreter', 'latex');
ylabel('CDF', 'Interpreter', 'latex');
legend(sprintf('GLS (K=%d)', N_or), sprintf('WLS (K=%d)', N_or), sprintf('DEB (K=%d)', N_or), 'Location', 'southeast', 'Interpreter', 'latex');
title(sprintf('CDF of Direction-Finding Error - K=%d', N_or), 'Interpreter', 'latex');
grid minor

%% 8. Save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if save_files == 1
    results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
    if ~exist(results_dir, 'dir'), mkdir(results_dir); end
    save(fullfile(results_dir, sprintf('K%d_DEB_fixed.mat', N_or)), 'errorAngDEB')
    save(fullfile(results_dir, sprintf('K%d_GLS_ang_fixed.mat', N_or)), 'errorAngGLS', 'time_GLS')
    save(fullfile(results_dir, sprintf('K%d_WLS_ang_fixed.mat', N_or)), 'errorAngWLS', 'time_WLS')
    fprintf('Saved to %s\n', results_dir);
end