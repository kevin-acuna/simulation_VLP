%% Run GLS, WLS, and NL-MLE — Full 3D Positioning (Direction + Distance Recovery)
% Compares all estimators for 3D position estimation against the PEB.
% Each estimator: (1) estimates direction, (2) beamsteered distance recovery.
%
% Author: Kevin Acuña

close all; clear variables; clc;
addpath('../core');

% =================================================
% HYPERPARAMETERS
% =================================================
rng(41);
N_or = 5;               % Number of orientations (5 or 9)
save_files = 0;
receiver_mode = 'fixed';

%% 1. System Parameters
system_params;
T = [0, 0, 2];

% Convert orientations to cartesian vectors (PEB-optimized for GLS/WLS)
n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = all_orientations{N_or-2}(2*i-1);
    rho_i = all_orientations{N_or-2}(2*i);
    n_t(i,1) = sind(theta_i) * cosd(rho_i);
    n_t(i,2) = sind(theta_i) * sind(rho_i);
    n_t(i,3) = -cosd(theta_i);
end

%% 2. Generate Receiver Positions
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

%% 3. Generate Received Powers
P_r_noisy = cell(N_pos, N_or);
P_r_noisy_mean = zeros(N_pos, N_or);
v_tr = zeros(N_pos, 3);

fprintf('Generating received powers...\n');
for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r_clean, v_tr(i_pos,:), ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
        noisy_samples = P_r_clean + sqrt(sigma2).*randn(1, N_samples);
        P_r_noisy{i_pos, i_dir} = noisy_samples;
        P_r_noisy_mean(i_pos, i_dir) = mean(noisy_samples);
    end
end

%% 4. Direction Estimation + Distance Recovery
estPosWLS = zeros(N_pos, 3);
estPosGLS = zeros(N_pos, 3);
estPosNL  = zeros(N_pos, 3);
time_WLS = []; time_GLS = []; time_NL = [];

options_nl = optimoptions('fmincon', 'Display', 'none', 'Algorithm', 'sqp');

fprintf('Running estimators (WLS, GLS, NL-MLE + Distance Recovery)...\n');
for i_pos = 1:N_pos
    if mod(i_pos, 100) == 0 || i_pos == 1 || i_pos == N_pos
        fprintf('  --> Position %d / %d\n', i_pos, N_pos);
    end
    
    x_real = X_r(i_pos); y_real = Y_r(i_pos); z_real = Z_r(i_pos);
    
    P_raw = zeros(N_samples, N_or);
    for i_dir = 1:N_or
        P_raw(:, i_dir) = P_r_noisy{i_pos, i_dir}';
    end

    % ----- WLS: Direction + Distance Recovery -----
    tic;
    [d_hat, ~, ~] = vlp_wls(n_t', P_raw, m_t);
    v_est = d_hat' / norm(d_hat);
    % Beamsteered distance recovery
    param_t_ax = {T, v_est, P_t, m_t};
    param_r_ax = {A_det, -v_est, FOV};
    [~, P_ax, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_ax, param_r_ax);
    P_ax_noisy = P_ax + sqrt(sigma2).*randn(1, N_samples);
    d_est = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_ax_noisy)));
    estPosWLS(i_pos,:) = T + v_est .* d_est;
    time_WLS = [time_WLS; toc];

    % ----- GLS: Direction + Distance Recovery -----
    tic;
    [d_hat] = vlp_gls(n_t', P_raw, m_t, sigma2);
    v_est = d_hat' / norm(d_hat);
    param_t_ax = {T, v_est, P_t, m_t};
    param_r_ax = {A_det, -v_est, FOV};
    [~, P_ax, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_ax, param_r_ax);
    P_ax_noisy = P_ax + sqrt(sigma2).*randn(1, N_samples);
    d_est = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_ax_noisy)));
    estPosGLS(i_pos,:) = T + v_est .* d_est;
    time_GLS = [time_GLS; toc];

    % ----- NL-MLE: Direction + Distance Recovery -----
    tic;
    p_means = P_r_noisy_mean(i_pos, :);
    max_p = max(p_means); if max_p <= 0; max_p = 1e-12; end
    p_target = p_means / max_p;
    [~, max_idx] = max(p_target);
    best_n_t = n_t(max_idx, :);
    x0 = [best_n_t(1), best_n_t(2), best_n_t(3), 1.0];
    lb = [-1, -1, -1, 1e-3]; ub = [1, 1, 0, 10];
    obj_fcn = @(vars) mle_cost_function(vars, p_target, n_t, m_t);
    nonlcon = @(vars) sphere_constraint(vars);
    [sol, ~, ~] = fmincon(obj_fcn, x0, [], [], [], [], lb, ub, nonlcon, options_nl);
    v_est = sol(1:3) / norm(sol(1:3));
    % Beamsteered distance recovery (same as WLS/GLS)
    param_t_ax = {T, v_est, P_t, m_t};
    param_r_ax = {A_det, -v_est, FOV};
    [~, P_ax, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_ax, param_r_ax);
    P_ax_noisy = P_ax + sqrt(sigma2).*randn(1, N_samples);
    d_est = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_ax_noisy)));
    estPosNL(i_pos,:) = T + v_est .* d_est;
    time_NL = [time_NL; toc];
end

%% 5. Error Calculation + PEB
realPos = [X_r; Y_r; Z_r]';

errorNormWLS = zeros(N_pos, 1);
errorNormGLS = zeros(N_pos, 1);
errorNormNL  = zeros(N_pos, 1);
errorNormPEB = zeros(1, N_pos);

for i = 1:N_pos
    errorNormWLS(i) = norm(realPos(i,:) - estPosWLS(i,:));
    errorNormGLS(i) = norm(realPos(i,:) - estPosGLS(i,:));
    errorNormNL(i)  = norm(realPos(i,:) - estPosNL(i,:));
    
    R_real = [X_r(i); Y_r(i); Z_r(i)];
    peb_val = PEB_complete(R_real, n_t', T', P_t, m_t, A_det, deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples);
    if isreal(peb_val) && isfinite(peb_val)
        errorNormPEB(i) = peb_val;
    else
        errorNormPEB(i) = NaN;
    end
end

rmseWLS = sqrt(mean(errorNormWLS.^2));
rmseGLS = sqrt(mean(errorNormGLS.^2));
rmseNL  = sqrt(mean(errorNormNL.^2));
rmsePEB = sqrt(nanmean(errorNormPEB.^2));

%% 6. Display Results
fprintf('\n========================================================\n');
fprintf(' 3D POSITIONING RESULTS (K=%d)\n', N_or);
fprintf('========================================================\n');
fprintf('%-10s %10s %10s %10s\n', 'Method', 'RMSE[cm]', 'CDF90[cm]', 'APE[cm]');
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'GLS',    rmseGLS*100, prctile(errorNormGLS,90)*100, mean(errorNormGLS)*100);
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'WLS',    rmseWLS*100, prctile(errorNormWLS,90)*100, mean(errorNormWLS)*100);
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'NL-MLE', rmseNL*100,  prctile(errorNormNL,90)*100,  mean(errorNormNL)*100);
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'PEB',    rmsePEB*100, prctile(errorNormPEB(~isnan(errorNormPEB)),90)*100, nanmean(errorNormPEB)*100);
fprintf('--------------------------------------------------------\n');
fprintf('Latency — WLS: %.4f ms | GLS: %.4f ms | NL-MLE: %.4f ms\n', ...
    median(time_WLS)*1000, median(time_GLS)*1000, median(time_NL)*1000);

%% 7. CDF Plot
figure('Position', [100, 100, 600, 500]);
hold on;
factor = 100;

color_gls = [0, 0.4470, 0.7410];
color_wls = [0.8500, 0.3250, 0.0980];
color_nl  = [0.4940, 0.1840, 0.5560];
color_peb = [0.4660, 0.6740, 0.1880];

[f, x] = ecdf(errorNormGLS*factor); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_gls);
[f, x] = ecdf(errorNormWLS*factor); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_wls);
[f, x] = ecdf(errorNormNL*factor);  stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_nl);
[f, x] = ecdf(errorNormPEB(~isnan(errorNormPEB))*factor); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_peb);

yline(0.9, '--', 'LineWidth', 0.4, 'Color', [0.5 0.5 0.5]);
xlabel('3D Positioning Error [cm]', 'Interpreter', 'latex');
ylabel('CDF', 'Interpreter', 'latex');
legend(sprintf('GLS (K=%d)', N_or), sprintf('WLS (K=%d)', N_or), ...
       sprintf('NL-MLE (K=%d)', N_or), sprintf('PEB (K=%d)', N_or), ...
       'Location', 'southeast', 'Interpreter', 'latex');
title(sprintf('CDF of 3D Position Error — K=%d', N_or), 'Interpreter', 'latex');
xlim([0 14]);
grid minor;

%% 8. Save
if save_files == 1
    results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
    if ~exist(results_dir, 'dir'), mkdir(results_dir); end
    save(fullfile(results_dir, sprintf('K%d_3D_comparison.mat', N_or)), ...
        'errorNormWLS', 'errorNormGLS', 'errorNormNL', 'errorNormPEB', ...
        'time_WLS', 'time_GLS', 'time_NL', ...
        'N_or', 'N_pos', 'X_r', 'Y_r', 'Z_r');
    fprintf('Saved to %s\n', results_dir);
end

% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================
function F = mle_cost_function(vars, p_target, n_t, m_t)
    v = vars(1:3)';
    eta = vars(4);
    F = 0;
    for i = 1:size(n_t, 1)
        Q_pos = max(0, dot(n_t(i,:), v));
        F = F + (eta * Q_pos^m_t - p_target(i))^2;
    end
end

function [c, ceq] = sphere_constraint(vars)
    c = [];
    ceq = vars(1)^2 + vars(2)^2 + vars(3)^2 - 1;
end
