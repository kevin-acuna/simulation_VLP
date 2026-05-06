%% Run GLS, WLS, and NL-MLE Estimators for VLP — Direction-Finding Only (Monte Carlo, Parallel)
% Parallel version of run_DF_comparison_MC.m.
% Identical computation; the outer position loop runs as parfor to exploit
% all available CPU cores. Speedup is near-linear with number of workers.
%
% Key differences from the serial version:
%   - Parallel pool is started automatically
%   - Per-position timing arrays replace scalar accumulators (parfor constraint)
%   - Progress is reported via DataQueue (order-safe with parfor)
%   - rng per-worker streams are independent (results not bit-identical to
%     serial run but statistically equivalent)
%
% Author: Kevin Acuña

close all; clear variables; clc;
addpath('../core');

% =================================================
% HYPERPARAMETERS 
% =================================================
rng(42);
TEST_MODE    = false;     % true = fast coarse grid, false = full paper grid
M_trials     = 10;      % Monte Carlo trials per position
N_or         = 5;         % Number of orientations
save_files   = 0;         
receiver_mode = 'fixed';
error_metric = 'angular'; % 'angular' = acos(dot) | 'chordal' = ||n_hat - n||
PERMUTE_REF  = false;      % true = randomize ref for GLS/WLS (fair test vs *-Max)

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

n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = all_orientations{N_or-2}(2*i-1);
    rho_i   = all_orientations{N_or-2}(2*i);
    n_t(i,1) = sind(theta_i) * cosd(rho_i);
    n_t(i,2) = sind(theta_i) * sind(rho_i);
    n_t(i,3) = -cosd(theta_i);
end

%% 2. Generate Receiver Positions
if strcmp(receiver_mode, 'fixed')
    if TEST_MODE
        [X, Y, Z] = meshgrid(-1.5:0.5:1.5, -1.5:0.5:1.5, 0:0.6:1.2);
    else
        [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
    end
    X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
    N_pos = length(X_r);
    fprintf('Using %d fixed grid positions (testbed)\n', N_pos);
else
    N_pos = 100;
    X_r = -L/2 + L.*rand(1,N_pos);
    Y_r = -W/2 + W.*rand(1,N_pos);
    Z_r = Hmax*rand(1,N_pos);
    fprintf('Using %d random positions\n', N_pos);
end

param_r = {A_det, n_r, FOV};

%% 3. Monte Carlo Simulation Core (parallel over positions)
rmse_ang_WLS_pos  = zeros(N_pos, 1);
rmse_ang_WLSm_pos = zeros(N_pos, 1);
rmse_ang_GLS_pos  = zeros(N_pos, 1);
rmse_ang_GLSm_pos = zeros(N_pos, 1);
rmse_ang_NL_pos   = zeros(N_pos, 1);
rmse_cho_WLS_pos  = zeros(N_pos, 1);
rmse_cho_WLSm_pos = zeros(N_pos, 1);
rmse_cho_GLS_pos  = zeros(N_pos, 1);
rmse_cho_GLSm_pos = zeros(N_pos, 1);
rmse_cho_NL_pos   = zeros(N_pos, 1);
DEB_cho_pos       = zeros(N_pos, 1);
DEB_ang_pos       = zeros(N_pos, 1);

% Per-position timing arrays (scalar accumulators not allowed in parfor)
time_WLS_arr  = zeros(N_pos, 1);
time_WLSm_arr = zeros(N_pos, 1);
time_GLS_arr  = zeros(N_pos, 1);
time_GLSm_arr = zeros(N_pos, 1);
time_NL_arr   = zeros(N_pos, 1);

rad2deg_factor = 180 / pi;
options_nl = optimoptions('fmincon', 'Display', 'none', 'Algorithm', 'sqp');

%% Log setup — subdirectory named K{N_or}_DF_MC_{M_trials}
results_subdir = fullfile(fileparts(mfilename('fullpath')), 'results', ...
    sprintf('LAST', N_or, M_trials));
if ~exist(results_subdir, 'dir'), mkdir(results_subdir); end

log_filename = fullfile(results_subdir, ...
    sprintf('K%d_DF_MC_log_%s.txt', N_or, datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
diary(log_filename);

fprintf('%s\n', repmat('=', 1, 60));
fprintf('DIRECTION-FINDING MC SIMULATION LOG\n');
fprintf('%s\n', repmat('=', 1, 60));
fprintf('Date       : %s\n', datestr(now));
fprintf('K (N_or)   : %d\n', N_or);
fprintf('M_trials   : %d\n', M_trials);
fprintf('N_pos      : %d\n', N_pos);
fprintf('N_samples  : %d\n', N_samples);
fprintf('Metric     : %s\n', error_metric);
fprintf('TEST_MODE  : %d\n', TEST_MODE);
fprintf('Workers    : %d\n', pool.NumWorkers);
fprintf('%s\n\n', repmat('=', 1, 60));

% Progress reporting — anonymous callback receives position index directly
% (avoids nested-function scope issue when local functions are present)
fprintf('Running Monte Carlo Simulation (%d trials/pos) for %d positions...\n', M_trials, N_pos);
D = parallel.pool.DataQueue;
afterEach(D, @(pos) fprintf('  --> Completed position %d / %d\n', pos, N_pos));

parfor i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    R_real = [x; y; z];
    v_true = (R_real - T') / norm(R_real - T');

    % --- Clean channel powers once per position ---
    P_clean = zeros(1, N_or);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_clean(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
    end

    % --- Theoretical DEB ---
    deb_val = DEB_complete(R_real, n_t', T', P_t, m_t, A_det, ...
        deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples);
    if isreal(deb_val) && isfinite(deb_val)
        DEB_cho_pos(i_pos) = deb_val;
        DEB_ang_pos(i_pos) = deb_val * rad2deg_factor;
    else
        DEB_cho_pos(i_pos) = NaN;
        DEB_ang_pos(i_pos) = NaN;
    end

    % --- MC trials ---
    ang_WLS_mc  = zeros(M_trials, 1); cho_WLS_mc  = zeros(M_trials, 1);
    ang_WLSm_mc = zeros(M_trials, 1); cho_WLSm_mc = zeros(M_trials, 1);
    ang_GLS_mc  = zeros(M_trials, 1); cho_GLS_mc  = zeros(M_trials, 1);
    ang_GLSm_mc = zeros(M_trials, 1); cho_GLSm_mc = zeros(M_trials, 1);
    ang_NL_mc   = zeros(M_trials, 1); cho_NL_mc   = zeros(M_trials, 1);
    t_wls = 0; t_wlsm = 0; t_gls = 0; t_glsm = 0; t_nl = 0;

    for mc = 1:M_trials
        P_raw = repmat(P_clean, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);

        % Optional permutation so GLS/WLS ref (index 1) is arbitrary
        if PERMUTE_REF
            perm = randperm(N_or);
            n_t_ref  = n_t(perm, :);
            P_raw_ref = P_raw(:, perm);
        else
            n_t_ref  = n_t;
            P_raw_ref = P_raw;
        end

        % WLS (ref = index 1 of n_t_ref)
        t0 = tic;
        [d_hat_robust, ~, ~] = vlp_wls(n_t_ref', P_raw_ref, m_t);
        t_wls = t_wls + toc(t0);
        v_est_wls = d_hat_robust' / norm(d_hat_robust);
        ang_WLS_mc(mc) = acos(max(-1, min(1, v_true' * v_est_wls'))) * rad2deg_factor;
        cho_WLS_mc(mc) = norm(v_true - v_est_wls');

        % WLS-Max (adaptive ref = max-power orientation)
        t0 = tic;
        [d_hat_wlsm, ~, ~] = vlp_wls_max(n_t', P_raw, m_t);
        t_wlsm = t_wlsm + toc(t0);
        v_est_wlsm = d_hat_wlsm' / norm(d_hat_wlsm);
        ang_WLSm_mc(mc) = acos(max(-1, min(1, v_true' * v_est_wlsm'))) * rad2deg_factor;
        cho_WLSm_mc(mc) = norm(v_true - v_est_wlsm');

        % GLS (ref = index 1 of n_t_ref)
        t0 = tic;
        [d_hat_gls] = vlp_gls(n_t_ref', P_raw_ref, m_t, sigma2);
        t_gls = t_gls + toc(t0);
        v_est_gls = d_hat_gls' / norm(d_hat_gls);
        ang_GLS_mc(mc) = acos(max(-1, min(1, v_true' * v_est_gls'))) * rad2deg_factor;
        cho_GLS_mc(mc) = norm(v_true - v_est_gls');

        % GLS-Max (adaptive ref = max-power orientation)
        t0 = tic;
        [d_hat_glsm] = vlp_gls_max(n_t', P_raw, m_t, sigma2);
        t_glsm = t_glsm + toc(t0);
        v_est_glsm = d_hat_glsm' / norm(d_hat_glsm);
        ang_GLSm_mc(mc) = acos(max(-1, min(1, v_true' * v_est_glsm'))) * rad2deg_factor;
        cho_GLSm_mc(mc) = norm(v_true - v_est_glsm');

        % NL-MLE
        p_means = mean(P_raw, 1);
        max_p = max(p_means);
        if max_p <= 0; max_p = 1e-12; end
        p_target  = p_means / max_p;

        [~, max_idx] = max(p_target);
        best_n_t   = n_t(max_idx, :);
        x0_nl      = [best_n_t(1), best_n_t(2), best_n_t(3), 1.0];
        lb_nl      = [-1, -1, -1, 1e-3];
        ub_nl      = [ 1,  1,  0, 10];

        obj_fcn  = @(vars) mle_cost_function(vars, p_target, n_t, m_t);
        nonlcon  = @(vars) sphere_constraint(vars);

        t0 = tic;
        [sol, ~, ~] = fmincon(obj_fcn, x0_nl, [], [], [], [], lb_nl, ub_nl, nonlcon, options_nl);
        t_nl = t_nl + toc(t0);

        v_est_nl     = sol(1:3) / norm(sol(1:3));
        ang_NL_mc(mc) = acos(max(-1, min(1, v_true' * v_est_nl'))) * rad2deg_factor;
        cho_NL_mc(mc) = norm(v_true - v_est_nl');
    end

    % Per-position RMSE (both metrics)
    rmse_ang_WLS_pos(i_pos)  = sqrt(mean(ang_WLS_mc.^2));
    rmse_ang_WLSm_pos(i_pos) = sqrt(mean(ang_WLSm_mc.^2));
    rmse_ang_GLS_pos(i_pos)  = sqrt(mean(ang_GLS_mc.^2));
    rmse_ang_GLSm_pos(i_pos) = sqrt(mean(ang_GLSm_mc.^2));
    rmse_ang_NL_pos(i_pos)   = sqrt(mean(ang_NL_mc.^2));
    rmse_cho_WLS_pos(i_pos)  = sqrt(mean(cho_WLS_mc.^2));
    rmse_cho_WLSm_pos(i_pos) = sqrt(mean(cho_WLSm_mc.^2));
    rmse_cho_GLS_pos(i_pos)  = sqrt(mean(cho_GLS_mc.^2));
    rmse_cho_GLSm_pos(i_pos) = sqrt(mean(cho_GLSm_mc.^2));
    rmse_cho_NL_pos(i_pos)   = sqrt(mean(cho_NL_mc.^2));

    % Timing per position
    time_WLS_arr(i_pos)  = t_wls;
    time_WLSm_arr(i_pos) = t_wlsm;
    time_GLS_arr(i_pos)  = t_gls;
    time_GLSm_arr(i_pos) = t_glsm;
    time_NL_arr(i_pos)   = t_nl;

    % Send progress update every 10 positions (and first/last)
    if mod(i_pos, 10) == 0 || i_pos == 1 || i_pos == N_pos
        send(D, i_pos);
    end
end

% Aggregate timing
time_WLS   = sum(time_WLS_arr);
time_WLSm  = sum(time_WLSm_arr);
time_GLS   = sum(time_GLS_arr);
time_GLSm  = sum(time_GLSm_arr);
time_NL    = sum(time_NL_arr);
total_runs = N_pos * M_trials;

%% 4. Display Results (selected metric)
if strcmp(error_metric, 'angular')
    r_WLS = rmse_ang_WLS_pos; r_WLSm = rmse_ang_WLSm_pos;
    r_GLS = rmse_ang_GLS_pos; r_GLSm = rmse_ang_GLSm_pos;
    r_NL = rmse_ang_NL_pos;   r_DEB = DEB_ang_pos;
    unit_str = '°';
else
    r_WLS = rmse_cho_WLS_pos; r_WLSm = rmse_cho_WLSm_pos;
    r_GLS = rmse_cho_GLS_pos; r_GLSm = rmse_cho_GLSm_pos;
    r_NL = rmse_cho_NL_pos;   r_DEB = DEB_cho_pos;
    unit_str = '';
end

global_rmse_WLS  = sqrt(mean(r_WLS.^2));
global_rmse_WLSm = sqrt(mean(r_WLSm.^2));
global_rmse_GLS  = sqrt(mean(r_GLS.^2));
global_rmse_GLSm = sqrt(mean(r_GLSm.^2));
global_rmse_NL   = sqrt(mean(r_NL.^2));
global_rmse_DEB  = sqrt(nanmean(r_DEB.^2));

cdf90_WLS  = prctile(r_WLS, 90);
cdf90_WLSm = prctile(r_WLSm, 90);
cdf90_GLS  = prctile(r_GLS, 90);
cdf90_GLSm = prctile(r_GLSm, 90);
cdf90_NL   = prctile(r_NL, 90);
cdf90_DEB  = prctile(r_DEB(~isnan(r_DEB)), 90);

ape_WLS  = mean(r_WLS);  ape_WLSm = mean(r_WLSm);
ape_GLS  = mean(r_GLS);  ape_GLSm = mean(r_GLSm);
ape_NL   = mean(r_NL);   ape_DEB  = nanmean(r_DEB);

fprintf('\n========================================================\n');
fprintf(' DIRECTION-FINDING RESULTS (K=%d, %d MC trials/pos, metric=%s)\n', N_or, M_trials, error_metric);
fprintf('========================================================\n');
fprintf('%-10s %12s %12s %12s\n', 'Method', ['RMSE[' unit_str ']'], ['CDF90[' unit_str ']'], ['APE[' unit_str ']']);
fprintf('%-10s %12.4f %12.4f %12.4f\n', 'WLS',      global_rmse_WLS,  cdf90_WLS,  ape_WLS);
fprintf('%-10s %12.4f %12.4f %12.4f\n', 'WLS-Max',  global_rmse_WLSm, cdf90_WLSm, ape_WLSm);
fprintf('%-10s %12.4f %12.4f %12.4f\n', 'GLS',      global_rmse_GLS,  cdf90_GLS,  ape_GLS);
fprintf('%-10s %12.4f %12.4f %12.4f\n', 'GLS-Max',  global_rmse_GLSm, cdf90_GLSm, ape_GLSm);
fprintf('%-10s %12.4f %12.4f %12.4f\n', 'NL-MLE',   global_rmse_NL,   cdf90_NL,   ape_NL);
fprintf('%-10s %12.4f %12.4f %12.4f\n', 'DEB',      global_rmse_DEB,  cdf90_DEB,  ape_DEB);
fprintf('--------------------------------------------------------\n');
fprintf('PERMUTE_REF = %d\n', PERMUTE_REF);
fprintf('Latency -- WLS: %.4f ms | WLS-Max: %.4f ms | GLS: %.4f ms | GLS-Max: %.4f ms | NL-MLE: %.4f ms\n', ...
    (time_WLS/total_runs)*1000, (time_WLSm/total_runs)*1000, ...
    (time_GLS/total_runs)*1000, (time_GLSm/total_runs)*1000, (time_NL/total_runs)*1000);
if TEST_MODE
    fprintf('\n⚠ TEST_MODE=true. For paper results: TEST_MODE=false, M_trials≥100\n');
end

%% 5. Comparative CDF Plot (Spatial RMSE)
figure('Name', 'CDF of Spatial RMSE (Direction-Finding)', 'Position', [100, 100, 600, 500]);
hold on;

color_wls  = [0.8500, 0.3250, 0.0980];
color_wlsm = [1.0, 0.6, 0.2];
color_gls  = [0, 0.4470, 0.7410];
color_glsm = [0.3010, 0.7450, 0.9330];
color_nl   = [0.4940, 0.1840, 0.5560];
color_deb  = [0.4660, 0.6740, 0.1880];

[f, x] = ecdf(r_WLS);  stairs(x, f, '-',  'LineWidth', 1.5, 'Color', color_wls);
[f, x] = ecdf(r_WLSm); stairs(x, f, '--', 'LineWidth', 1.5, 'Color', color_wlsm);
[f, x] = ecdf(r_GLS);  stairs(x, f, '-',  'LineWidth', 1.5, 'Color', color_gls);
[f, x] = ecdf(r_GLSm); stairs(x, f, '--', 'LineWidth', 1.5, 'Color', color_glsm);
[f, x] = ecdf(r_NL);   stairs(x, f, '-',  'LineWidth', 1.5, 'Color', color_nl);
[f, x] = ecdf(r_DEB(~isnan(r_DEB))); stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_deb);

yline(0.9, '--', 'LineWidth', 0.8, 'Color', [0.5 0.5 0.5]);

xlabel('Spatial RMSE [degrees]', 'Interpreter', 'latex', 'FontSize', 12);
ylabel('Empirical CDF', 'Interpreter', 'latex', 'FontSize', 12);
legend(sprintf('WLS (K=%d)', N_or), sprintf('WLS-Max (K=%d)', N_or), ...
    sprintf('GLS (K=%d)', N_or), sprintf('GLS-Max (K=%d)', N_or), ...
    sprintf('NL-MLE (K=%d)', N_or), sprintf('Theoretical DEB (K=%d)', N_or), ...
    'Location', 'southeast', 'Interpreter', 'latex', 'FontSize', 11);
title(sprintf('CDF of Spatial RMSE (K=%d, %d MC trials)', N_or, M_trials), ...
    'Interpreter', 'latex', 'FontSize', 14);
grid minor

%% 6. Save
if save_files == 1
    save(fullfile(results_subdir, sprintf('K%d_DF_MC_results.mat', N_or)), ...
        'rmse_ang_WLS_pos', 'rmse_ang_WLSm_pos', 'rmse_ang_GLS_pos', 'rmse_ang_GLSm_pos', 'rmse_ang_NL_pos', ...
        'rmse_cho_WLS_pos', 'rmse_cho_WLSm_pos', 'rmse_cho_GLS_pos', 'rmse_cho_GLSm_pos', 'rmse_cho_NL_pos', ...
        'DEB_cho_pos', 'DEB_ang_pos', ...
        'time_WLS', 'time_WLSm', 'time_GLS', 'time_GLSm', 'time_NL', ...
        'N_or', 'M_trials', 'N_pos', 'N_samples', 'total_runs', 'PERMUTE_REF', ...
        'X_r', 'Y_r', 'Z_r', 'rad2deg_factor');
    fprintf('Saved .mat to: %s\n', results_subdir);
end

fprintf('\nLog saved to: %s\n', log_filename);
diary off;

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
    x = vars(1); y = vars(2); z = vars(3);
    c = [];
    ceq = x^2 + y^2 + z^2 - 1;
end
