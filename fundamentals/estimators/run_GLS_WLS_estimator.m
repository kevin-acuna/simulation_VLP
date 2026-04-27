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
% HYPERPARAMETERS
% =================================================
rng(42);
N_or = 5;          % Number of orientations (change to 5 or 9)
save_files = 0;    % 1 = save .mat files to results/

% Room dimensions
L = 3; W = 3; Hmax = 1.2;

% Grid parameters
step = 0.2;   % step in X,Y [m]
stepH = 0.2;  % step in Z [m]

% Receiver position mode: 'fixed' (testbed grid) or 'random' (1000 random)
receiver_mode = 'fixed';

% Filter imaginary values
filter_imaginary = false;

% =================================================
% ORIENTATIONS (optimized via GA)
% =================================================
orientations_K3=[35.40,140.13,33.31,36.38,29.58,262.70];
orientations_K4=[38.89,90.56,41.48,0.15,41.80,180.10,38.79,270.24];
orientations_K5=[0.10,211.14,50.55,89.96,50.66,179.99,50.37,359.93,50.59,269.96];
orientations_K6=[17.19,306.94,54.55,266.13,22.49,140.37,52.23,360.00,52.41,84.05,55.76,185.16];
orientations_K7=[58.91,355.65,53.77,170.74,27.75,43.75,5.36,305.88,54.35,96.46,35.10,220.04,54.78,278.61];
orientations_K8=[51.82,89.38,61.50,268.26,27.32,316.99,6.46,318.34,57.76,5.84,53.65,171.30,37.97,200.35,39.27,91.12];
orientations_K9=[0,28.15,56.92,178.69,36.54,266.83,33.86,182.29,42.20,78.36,53.07,97.46,57.91,359.73,37.07,355.08,58.23,272.07];
orientations_K10=[56.00,3.61,53.20,182.48,54.93,356.82,11.94,38.06,61.28,270.34,50.17,91.30,47.56,174.73,43.39,89.36,32.54,277.55,15.14,255.31];

all_orientations = {orientations_K3, orientations_K4, orientations_K5, orientations_K6, orientations_K7, orientations_K8, orientations_K9, orientations_K10};
K_values = [3, 4, 5, 6, 7, 8, 9, 10];

%% 1. System Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
N_samples = 1000;
theta_half = 45;
P_t = 0.405;
T = [0, 0, 2];
m_t = -log(2)./log(cosd(theta_half));

p = 4.8e-3; q = 5.5e-3;
N_det = 1;
A_det = p*q*N_det;
R_pd = 0.63;
FOV = 85;
n_r = [0, 0, 1];
sigma2 = 30e6*10^(-21.0);
C = -P_t*(m_t+1)*A_det/(2*pi);

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
