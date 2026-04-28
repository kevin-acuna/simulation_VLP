%% Run GLS, WLS, and NL-MLE — Full 3D Positioning Monte Carlo
% Monte Carlo version of run_3D_comparison.m
% M trials per position -> per-position RMSE -> spatial CDF
% Saves both metrics for post-processing flexibility.
%
% Author: Kevin Acuña

close all; clear variables; clc;
addpath('../core');

% =================================================
% HYPERPARAMETERS
% =================================================
rng(42);
TEST_MODE = false;       % true: coarse grid for fast testing
M_trials = 100;         % Monte Carlo trials per position
N_or = 5;
save_files = 1;
receiver_mode = 'fixed';

%% 1. System Parameters
system_params;
T = [0, 0, 2];

n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = all_orientations{N_or-2}(2*i-1);
    rho_i = all_orientations{N_or-2}(2*i);
    n_t(i,1) = sind(theta_i) * cosd(rho_i);
    n_t(i,2) = sind(theta_i) * sind(rho_i);
    n_t(i,3) = -cosd(theta_i);
end

%% 2. Receiver Positions
if strcmp(receiver_mode, 'fixed')
    if TEST_MODE
        [X, Y, Z] = meshgrid(-1.5:0.5:1.5, -1.5:0.5:1.5, 0:0.6:1.2);
    else
        [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
    end
    X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
    N_pos = length(X_r);
    fprintf('Using %d fixed positions\n', N_pos);
else
    N_pos = 100;
    X_r = -L/2 + L.*rand(1,N_pos);
    Y_r = -W/2 + W.*rand(1,N_pos);
    Z_r = Hmax*rand(1,N_pos);
    fprintf('Using %d random positions\n', N_pos);
end

param_r = {A_det, n_r, FOV};

%% 3. Monte Carlo Core
rmse_3D_WLS_pos = zeros(N_pos, 1);
rmse_3D_GLS_pos = zeros(N_pos, 1);
rmse_3D_NL_pos  = zeros(N_pos, 1);
PEB_pos         = zeros(N_pos, 1);

time_WLS = 0; time_GLS = 0; time_NL = 0;
options_nl = optimoptions('fmincon', 'Display', 'none', 'Algorithm', 'sqp');

fprintf('Running 3D MC (%d trials/pos, %d positions)...\n', M_trials, N_pos);

for i_pos = 1:N_pos
    if mod(i_pos, 10) == 0 || i_pos == 1 || i_pos == N_pos
        fprintf('  --> Position %d / %d\n', i_pos, N_pos);
    end
    
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    x_real = x; y_real = y; z_real = z;
    R_real = [x; y; z];
    realPos_i = [x, y, z];
    
    % Clean powers (once per position)
    P_clean = zeros(1, N_or);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_clean(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
    end
    
    % PEB (deterministic, once per position)
    peb_val = PEB_complete(R_real, n_t', T', P_t, m_t, A_det, deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples);
    if isreal(peb_val) && isfinite(peb_val)
        PEB_pos(i_pos) = peb_val;
    else
        PEB_pos(i_pos) = NaN;
    end
    
    err_WLS_mc = zeros(M_trials, 1);
    err_GLS_mc = zeros(M_trials, 1);
    err_NL_mc  = zeros(M_trials, 1);
    
    for mc = 1:M_trials
        % Generate noisy powers for DF stage
        P_raw = repmat(P_clean, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);
        
        % ----- WLS -----
        tic;
        [d_hat, ~, ~] = vlp_wls(n_t', P_raw, m_t);
        v_est = d_hat' / norm(d_hat);
        param_t_ax = {T, v_est, P_t, m_t};
        param_r_ax = {A_det, -v_est, FOV};
        [~, P_ax, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_ax, param_r_ax);
        P_ax_noisy = P_ax + sqrt(sigma2).*randn(1, N_samples);
        d_est = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_ax_noisy)));
        estPos = T + v_est .* d_est;
        time_WLS = time_WLS + toc;
        err_WLS_mc(mc) = norm(realPos_i - estPos);
        
        % ----- GLS -----
        tic;
        [d_hat] = vlp_gls(n_t', P_raw, m_t, sigma2);
        v_est = d_hat' / norm(d_hat);
        param_t_ax = {T, v_est, P_t, m_t};
        param_r_ax = {A_det, -v_est, FOV};
        [~, P_ax, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_ax, param_r_ax);
        P_ax_noisy = P_ax + sqrt(sigma2).*randn(1, N_samples);
        d_est = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_ax_noisy)));
        estPos = T + v_est .* d_est;
        time_GLS = time_GLS + toc;
        err_GLS_mc(mc) = norm(realPos_i - estPos);
        
        % ----- NL-MLE -----
        tic;
        p_means = mean(P_raw, 1);
        max_p = max(p_means); if max_p <= 0; max_p = 1e-12; end
        p_target = p_means / max_p;
        [~, max_idx] = max(p_target);
        best_n_t = n_t(max_idx, :);
        x0 = [best_n_t(1), best_n_t(2), best_n_t(3), 1.0];
        lb = [-1, -1, -1, 1e-3]; ub = [1, 1, 0, 10];
        obj_fcn = @(vars) mle_cost_function(vars, p_target, n_t, m_t);
        nonlcon_fn = @(vars) sphere_constraint(vars);
        [sol, ~, ~] = fmincon(obj_fcn, x0, [], [], [], [], lb, ub, nonlcon_fn, options_nl);
        v_est = sol(1:3) / norm(sol(1:3));
        param_t_ax = {T, v_est, P_t, m_t};
        param_r_ax = {A_det, -v_est, FOV};
        [~, P_ax, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_ax, param_r_ax);
        P_ax_noisy = P_ax + sqrt(sigma2).*randn(1, N_samples);
        d_est = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_ax_noisy)));
        estPos = T + v_est .* d_est;
        time_NL = time_NL + toc;
        err_NL_mc(mc) = norm(realPos_i - estPos);
    end
    
    rmse_3D_WLS_pos(i_pos) = sqrt(mean(err_WLS_mc.^2));
    rmse_3D_GLS_pos(i_pos) = sqrt(mean(err_GLS_mc.^2));
    rmse_3D_NL_pos(i_pos)  = sqrt(mean(err_NL_mc.^2));
end

total_runs = N_pos * M_trials;

%% 4. Display Results
factor = 100; % m to cm

global_rmse_WLS = sqrt(mean(rmse_3D_WLS_pos.^2));
global_rmse_GLS = sqrt(mean(rmse_3D_GLS_pos.^2));
global_rmse_NL  = sqrt(mean(rmse_3D_NL_pos.^2));
global_rmse_PEB = sqrt(nanmean(PEB_pos.^2));

cdf90_WLS = prctile(rmse_3D_WLS_pos, 90);
cdf90_GLS = prctile(rmse_3D_GLS_pos, 90);
cdf90_NL  = prctile(rmse_3D_NL_pos, 90);
cdf90_PEB = prctile(PEB_pos(~isnan(PEB_pos)), 90);

ape_WLS = mean(rmse_3D_WLS_pos);
ape_GLS = mean(rmse_3D_GLS_pos);
ape_NL  = mean(rmse_3D_NL_pos);
ape_PEB = nanmean(PEB_pos);

fprintf('\n========================================================\n');
fprintf(' 3D POSITIONING RESULTS (K=%d, %d MC trials/pos)\n', N_or, M_trials);
fprintf('========================================================\n');
fprintf('%-10s %10s %10s %10s\n', 'Method', 'RMSE[cm]', 'CDF90[cm]', 'APE[cm]');
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'GLS',    global_rmse_GLS*factor, cdf90_GLS*factor, ape_GLS*factor);
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'WLS',    global_rmse_WLS*factor, cdf90_WLS*factor, ape_WLS*factor);
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'NL-MLE', global_rmse_NL*factor,  cdf90_NL*factor,  ape_NL*factor);
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'PEB',    global_rmse_PEB*factor, cdf90_PEB*factor, ape_PEB*factor);
fprintf('--------------------------------------------------------\n');
fprintf('Latency — WLS: %.4f ms | GLS: %.4f ms | NL-MLE: %.4f ms\n', ...
    (time_WLS/total_runs)*1000, (time_GLS/total_runs)*1000, (time_NL/total_runs)*1000);
if TEST_MODE
    fprintf('\nWARNING: TEST_MODE=true. For paper: TEST_MODE=false, M_trials>=100\n');
end

%% 5. CDF Plot
figure('Position', [100, 100, 600, 500]);
hold on;

color_gls = [0, 0.4470, 0.7410];
color_wls = [0.8500, 0.3250, 0.0980];
color_nl  = [0.4940, 0.1840, 0.5560];
color_peb = [0.4660, 0.6740, 0.1880];

[f, x] = ecdf(rmse_3D_GLS_pos*factor); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_gls);
[f, x] = ecdf(rmse_3D_WLS_pos*factor); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_wls);
[f, x] = ecdf(rmse_3D_NL_pos*factor);  stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_nl);
[f, x] = ecdf(PEB_pos(~isnan(PEB_pos))*factor); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_peb);

yline(0.9, '--', 'LineWidth', 0.4, 'Color', [0.5 0.5 0.5]);
xlabel('3D Positioning Error [cm]', 'Interpreter', 'latex');
ylabel('CDF', 'Interpreter', 'latex');
legend(sprintf('GLS (K=%d)', N_or), sprintf('WLS (K=%d)', N_or), ...
       sprintf('NL-MLE (K=%d)', N_or), sprintf('PEB (K=%d)', N_or), ...
       'Location', 'southeast', 'Interpreter', 'latex');
title(sprintf('CDF of 3D Position Error (K=%d, %d MC)', N_or, M_trials), 'Interpreter', 'latex');
xlim([0 14]);
grid minor;

%% 6. Save
if save_files == 1
    results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
    if ~exist(results_dir, 'dir'), mkdir(results_dir); end
    save(fullfile(results_dir, sprintf('K%d_3D_MC_results.mat', N_or)), ...
        'rmse_3D_WLS_pos', 'rmse_3D_GLS_pos', 'rmse_3D_NL_pos', 'PEB_pos', ...
        'time_WLS', 'time_GLS', 'time_NL', ...
        'N_or', 'M_trials', 'N_pos', 'N_samples', 'total_runs', ...
        'X_r', 'Y_r', 'Z_r');
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
