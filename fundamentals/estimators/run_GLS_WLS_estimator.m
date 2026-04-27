%% Run GLS and WLS Estimators for VLP — Data Generation
% This script runs the GLS and WLS direction estimators, computes 3D
% position estimates via beamsteered distance recovery, calculates errors
% and CRLB, and saves results as .mat files for use by figure scripts.
%
% Usage:
%   Set N_or (number of orientations) and save_files=1, then run.
%   Output .mat files go to estimators/results/
%
% Requires: core/ in path (vlp_gls.m, vlp_wls.m, OWC_LOS_channel.m, PEB_complete.m)
%
% Author: Kevin Acuña
% Date: 28/07/2025
% Split from FigCompare3D_WLS_GLS.m — simulation part only

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
T = [0, 0, 2];        % LED position (GLS/WLS uses T at ceiling)

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

%% 3. Simulation Core — Received Powers + Estimation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
P_r = cell(N_pos, N_or);
P_r_noisy = cell(N_pos, N_or);
v_tr = zeros(N_pos, 3);
d_tr = zeros(N_pos, 1);
estPosWLS = zeros(N_pos, 3);
estPosGLS = zeros(N_pos, 3);
time_WLS = []; time_GLS = [];
SNR_avg = [];

for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), d_tr(i_pos,1)] = OWC_LOS_channel(x, y, z, param_t, param_r);
        P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,N_samples));
        SNR_avg = [SNR_avg, ((R_pd*P_r{i_pos,i_dir})^2/(sigma2*R_pd^2))];
    end
end
fprintf('Average SNR: %.2f dB\n', 10*log10(mean(SNR_avg)));

%% 4. Position Estimation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i_pos = 1:N_pos
    x_real = X_r(i_pos); y_real = Y_r(i_pos); z_real = Z_r(i_pos);
    
    P_raw = zeros(N_samples, N_or);
    for i_dir = 1:N_or
        P_raw(:, i_dir) = P_r_noisy{i_pos, i_dir};
    end

    % WLS
    tic;
    [d_hat_robust, ~, ~] = vlp_wls(n_t', P_raw, m_t);
    time_WLS = [time_WLS; toc];
    v_tr_est_WLS = d_hat_robust';
    param_t_axis = {T, v_tr_est_WLS, P_t, m_t};
    param_r_axis = {A_det, -v_tr_est_WLS, FOV};
    [~, P_r_axis_WLS, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
    P_r_axis_noisy_WLS = (P_r_axis_WLS + sqrt(sigma2).*randn(1,N_samples));
    d_tr_est_WLS = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_WLS)));
    estPosWLS(i_pos,:) = T + (v_tr_est_WLS.*d_tr_est_WLS);

    % GLS
    tic;
    [d_hat_gls] = vlp_gls(n_t', P_raw, m_t, sigma2);
    time_GLS = [time_GLS; toc];
    v_tr_est_GLS = d_hat_gls';
    param_t_axis = {T, v_tr_est_GLS, P_t, m_t};
    param_r_axis = {A_det, -v_tr_est_GLS, FOV};
    [~, P_r_axis_GLS, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
    P_r_axis_noisy_GLS = P_r_axis_GLS + sqrt(sigma2).*randn(1,N_samples);
    d_tr_est_GLS = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_GLS)));
    estPosGLS(i_pos,:) = T + (v_tr_est_GLS.*d_tr_est_GLS);
end

%% 5. Error Calculation + CRLB
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
realPos = [X_r; Y_r; Z_r]';

% WLS errors
errorNormWLS = zeros(N_pos, 1);
for i = 1:N_pos
    errorNormWLS(i) = norm(realPos(i,:) - estPosWLS(i,:));
end
filtered_errorNormWLS = errorNormWLS;
rmseWLS = sqrt(mean(filtered_errorNormWLS.^2));

% GLS errors
errorNormGLS = zeros(N_pos, 1);
for i = 1:N_pos
    errorNormGLS(i) = norm(realPos(i,:) - estPosGLS(i,:));
end
filtered_errorNormGLS = errorNormGLS;
rmseGLS = sqrt(mean(filtered_errorNormGLS.^2));

% CRLB (PEB)
errorNormCRLB = zeros(1, N_pos);
for i = 1:N_pos
    R_real = [X_r(i); Y_r(i); Z_r(i)];
    peb_value = PEB_complete(R_real, n_t', T', P_t, m_t, A_det, deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples);
    if isreal(peb_value) && isfinite(peb_value)
        errorNormCRLB(i) = peb_value;
    else
        errorNormCRLB(i) = NaN;
    end
end
rmseCRLB = sqrt(nanmean(errorNormCRLB.^2));

%% 6. Display Results
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('\n==== RESULTS K=%d ====\n', N_or);
fprintf('RMSE  — WLS: %.2f cm | GLS: %.2f cm | PEB: %.2f cm\n', rmseWLS*100, rmseGLS*100, rmseCRLB*100);
fprintf('CDF90 — WLS: %.2f cm | GLS: %.2f cm | PEB: %.2f cm\n', prctile(filtered_errorNormWLS,90)*100, prctile(filtered_errorNormGLS,90)*100, prctile(errorNormCRLB(~isnan(errorNormCRLB)),90)*100);
fprintf('APE   — WLS: %.2f cm | GLS: %.2f cm | PEB: %.2f cm\n', mean(filtered_errorNormWLS)*100, mean(filtered_errorNormGLS)*100, nanmean(errorNormCRLB)*100);
fprintf('Time  — WLS: %.4f ms | GLS: %.4f ms\n', median(time_WLS)*1000, median(time_GLS)*1000);

%% 7. Quick CDF Plot
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure;
hold on;
factor = 100; % convert m to cm
[f, x] = ecdf(filtered_errorNormGLS*factor); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', [0, 0.4470, 0.7410]);
[f, x] = ecdf(filtered_errorNormWLS*factor); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', [0.8500, 0.3250, 0.0980]);
[f, x] = ecdf(errorNormCRLB(~isnan(errorNormCRLB))*factor); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', [0.4660, 0.6740, 0.1880]);
yline(0.9, '--', 'LineWidth', 0.4, 'Color', [0.5 0.5 0.5]);
xlabel('Positioning Error [cm]', 'Interpreter', 'latex');
ylabel('CDF', 'Interpreter', 'latex');
legend(sprintf('GLS (K=%d)', N_or), sprintf('WLS (K=%d)', N_or), sprintf('PEB (K=%d)', N_or), 'Location', 'southeast', 'Interpreter', 'latex');
title(sprintf('CDF of 3D Position Error - K=%d', N_or), 'Interpreter', 'latex');
xlim([0 14]);
grid minor

%% 8. Save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if save_files == 1
    results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
    if ~exist(results_dir, 'dir'), mkdir(results_dir); end
    save(fullfile(results_dir, sprintf('K%d_CRLB_fixed.mat', N_or)), 'errorNormCRLB')
    save(fullfile(results_dir, sprintf('K%d_GLS_fixed.mat', N_or)), 'filtered_errorNormGLS', 'time_GLS')
    save(fullfile(results_dir, sprintf('K%d_WLS_fixed.mat', N_or)), 'filtered_errorNormWLS', 'time_WLS')
    fprintf('Saved to %s\n', results_dir);
end
