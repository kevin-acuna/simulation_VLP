%% run_nr_random_tilt_MC_parallel.m
% Evaluate DF estimator sensitivity to random receiver tilt.
%
% Models a realistic scenario where the receiver photodetector may be
% randomly tilted from vertical (manufacturing tolerance, user handling).
%
% Tilt model:
%   theta_tilt ~ truncated half-normal(0, sigma_tilt^2), max = theta_max
%   phi_tilt   ~ Uniform[0, 360°)
%
% Loop structure:
%   parfor over N_pos positions
%     for over N_random_tilt receiver orientations
%       for over M_trials Monte Carlo noise realizations
%
% For each position, we obtain:
%   - Per-tilt RMSE (N_random_tilt values per estimator)
%   - Aggregated RMSE (single value: RMS over all tilts × MC)
%   - Per-tilt DEB
%
% Uses two orientation sets (same as run_nr_robustness_MC_parallel.m):
%   GLS/WLS   → orientations_GLS_DF_K5_MC10
%   NL-MLE/DEB → orientations_DEB_K5
%
% Author: Kevin Acuña

close all; clear variables; clc;
addpath('../core');
addpath('../estimators');

% =================================================
% HYPERPARAMETERS
% =================================================
rng(42);
N_or           = 5;         % Number of LED orientations

TEST_MODE      = false;     % true = fast coarse grid
M_trials       = 100;      % Monte Carlo trials per (position, tilt)
N_random_tilt  = 20;        % Number of random tilt realizations per position
save_files     = 1;

% Random tilt distribution
sigma_tilt     = 10;        % Std dev of half-normal [deg] (tune spread)
theta_max_tilt = 30;        % Hard truncation limit [deg]

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

% Two orientation sets: GLS/WLS vs NL-MLE/DEB
or_gls_raw = orientations_GLS_DF_K5_MC10;  % for GLS and WLS
or_deb_raw = orientations_DEB_K5;           % for NL-MLE and DEB

n_t_gls = zeros(N_or, 3);
n_t_deb = zeros(N_or, 3);
for i = 1:N_or
    % GLS/WLS orientations
    theta_i = or_gls_raw(2*i-1);
    rho_i   = or_gls_raw(2*i);
    n_t_gls(i,1) = sind(theta_i) * cosd(rho_i);
    n_t_gls(i,2) = sind(theta_i) * sind(rho_i);
    n_t_gls(i,3) = -cosd(theta_i);
    % NL-MLE/DEB orientations
    theta_i = or_deb_raw(2*i-1);
    rho_i   = or_deb_raw(2*i);
    n_t_deb(i,1) = sind(theta_i) * cosd(rho_i);
    n_t_deb(i,2) = sind(theta_i) * sind(rho_i);
    n_t_deb(i,3) = -cosd(theta_i);
end

%% 2. Receiver Positions
if TEST_MODE
    [X, Y, Z] = meshgrid(-1.5:0.5:1.5, -1.5:0.5:1.5, 0:0.6:1.2);
else
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
end
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);
fprintf('Grid: %d positions\n', N_pos);

%% 3. Pre-generate random tilt samples (shared across all positions)
% theta: truncated half-normal on [0, theta_max_tilt]
% phi:   uniform on [0, 360)
tilt_samples    = zeros(N_random_tilt, 1);
azimuth_samples = zeros(N_random_tilt, 1);
for i = 1:N_random_tilt
    theta = abs(sigma_tilt * randn());
    while theta > theta_max_tilt
        theta = abs(sigma_tilt * randn());
    end
    tilt_samples(i)    = theta;
    azimuth_samples(i) = 360 * rand();
end

fprintf('Tilt samples: min=%.2f°, max=%.2f°, mean=%.2f°, median=%.2f°\n', ...
    min(tilt_samples), max(tilt_samples), mean(tilt_samples), median(tilt_samples));

%% 4. Results directory & log
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

log_filename = fullfile(results_dir, ...
    sprintf('nr_random_tilt_K%d_M%d_Ntilt%d_log_%s.txt', ...
    N_or, M_trials, N_random_tilt, datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
diary(log_filename);

fprintf('%s\n', repmat('=', 1, 65));
fprintf('RANDOM TILT SENSITIVITY EXPERIMENT LOG\n');
fprintf('%s\n', repmat('=', 1, 65));
fprintf('Date            : %s\n', datestr(now));
fprintf('K (N_or)        : %d\n', N_or);
fprintf('M_trials        : %d\n', M_trials);
fprintf('N_random_tilt   : %d\n', N_random_tilt);
fprintf('N_pos           : %d\n', N_pos);
fprintf('N_samples       : %d\n', N_samples);
fprintf('sigma2          : %.4e\n', sigma2);
fprintf('FOV             : %d deg\n', FOV);
fprintf('sigma_tilt      : %.1f deg\n', sigma_tilt);
fprintf('theta_max_tilt  : %.1f deg\n', theta_max_tilt);
fprintf('Workers         : %d\n', pool.NumWorkers);
fprintf('TEST_MODE       : %d\n', TEST_MODE);
fprintf('Total runs/pos  : %d (N_random_tilt x M_trials)\n', N_random_tilt * M_trials);
fprintf('Total runs      : %d\n', N_pos * N_random_tilt * M_trials);
fprintf('GLS/WLS ori     : orientations_GLS_DF_K5_MC10\n');
for ii = 1:N_or
    fprintf('                  LED%d: theta=%.2f deg, rho=%.2f deg\n', ...
        ii, or_gls_raw(2*ii-1), or_gls_raw(2*ii));
end
fprintf('NL/DEB  ori     : orientations_DEB_K5\n');
for ii = 1:N_or
    fprintf('                  LED%d: theta=%.2f deg, rho=%.2f deg\n', ...
        ii, or_deb_raw(2*ii-1), or_deb_raw(2*ii));
end
fprintf('\nTilt samples (first 10): %s\n', mat2str(tilt_samples(1:min(10,end))', 4));
fprintf('Azimuth samples (first 10): %s\n', mat2str(azimuth_samples(1:min(10,end))', 4));
fprintf('%s\n\n', repmat('=', 1, 65));

%% 5. Main simulation (parfor over positions)
rad2deg_factor = 180 / pi;
options_nl = optimoptions('fmincon', 'Display', 'none', 'Algorithm', 'sqp');

% Per-position × per-tilt RMSE matrices
rmse_GLS_all = zeros(N_pos, N_random_tilt);
rmse_WLS_all = zeros(N_pos, N_random_tilt);
rmse_NL_all  = zeros(N_pos, N_random_tilt);
DEB_ang_all  = zeros(N_pos, N_random_tilt);

% Per-position aggregated RMSE (over all tilts × MC)
rmse_GLS_agg = zeros(N_pos, 1);
rmse_WLS_agg = zeros(N_pos, 1);
rmse_NL_agg  = zeros(N_pos, 1);
DEB_ang_agg  = zeros(N_pos, 1);

% Per-position timing
time_WLS_arr = zeros(N_pos, 1);
time_GLS_arr = zeros(N_pos, 1);
time_NL_arr  = zeros(N_pos, 1);

% Also run baseline (tilt = 0) for direct comparison
rmse_GLS_baseline = zeros(N_pos, 1);
rmse_WLS_baseline = zeros(N_pos, 1);
rmse_NL_baseline  = zeros(N_pos, 1);
DEB_ang_baseline  = zeros(N_pos, 1);

% Progress
D = parallel.pool.DataQueue;
fprintf('Running random-tilt MC (%d tilts x %d trials/tilt, %d positions)...\n', ...
    N_random_tilt, M_trials, N_pos);
afterEach(D, @(pos) fprintf('  --> position %d / %d completed\n', pos, N_pos));

tic_total = tic;

parfor i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    R_real = [x; y; z];
    v_true = (R_real - T') / norm(R_real - T');

    % --- Per-tilt accumulators ---
    rt_rmse_GLS = zeros(N_random_tilt, 1);
    rt_rmse_WLS = zeros(N_random_tilt, 1);
    rt_rmse_NL  = zeros(N_random_tilt, 1);
    rt_DEB      = zeros(N_random_tilt, 1);
    t_wls = 0; t_gls = 0; t_nl = 0;

    for i_rt = 1:N_random_tilt
        theta_t = tilt_samples(i_rt);
        phi_t   = azimuth_samples(i_rt);

        % Build n_r for this random tilt
        n_r_t = [sind(theta_t)*cosd(phi_t), ...
                 sind(theta_t)*sind(phi_t), ...
                 cosd(theta_t)];
        param_r_t = {A_det, n_r_t, FOV};

        % Clean powers for each orientation set
        P_clean_gls = zeros(1, N_or);
        P_clean_deb = zeros(1, N_or);
        for i_dir = 1:N_or
            param_t_gls = {T, n_t_gls(i_dir,:), P_t, m_t};
            [~, P_clean_gls(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t_gls, param_r_t);
            param_t_deb = {T, n_t_deb(i_dir,:), P_t, m_t};
            [~, P_clean_deb(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t_deb, param_r_t);
        end

        % DEB with this tilt's n_r
        n_r_col = n_r_t(:);
        deb_val = DEB_complete_nr(R_real, n_t_deb', T', P_t, m_t, A_det, ...
            deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples, n_r_col);
        if isreal(deb_val) && isfinite(deb_val)
            rt_DEB(i_rt) = deb_val * rad2deg_factor;
        else
            rt_DEB(i_rt) = NaN;
        end

        % MC trials for this tilt
        ang_WLS_mc = zeros(M_trials, 1);
        ang_GLS_mc = zeros(M_trials, 1);
        ang_NL_mc  = zeros(M_trials, 1);

        for mc = 1:M_trials
            P_raw_gls = repmat(P_clean_gls, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);
            P_raw_deb = repmat(P_clean_deb, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);

            % WLS (GLS/WLS orientations)
            t0 = tic;
            [d_hat, ~, ~] = vlp_wls(n_t_gls', P_raw_gls, m_t);
            t_wls = t_wls + toc(t0);
            v_est = d_hat' / norm(d_hat);
            ang_WLS_mc(mc) = acos(max(-1, min(1, v_true' * v_est'))) * rad2deg_factor;

            % GLS (GLS/WLS orientations)
            t0 = tic;
            [d_hat] = vlp_gls(n_t_gls', P_raw_gls, m_t, sigma2);
            t_gls = t_gls + toc(t0);
            v_est = d_hat' / norm(d_hat);
            ang_GLS_mc(mc) = acos(max(-1, min(1, v_true' * v_est'))) * rad2deg_factor;

            % NL-MLE (DEB orientations)
            p_means = mean(P_raw_deb, 1);
            max_p = max(p_means); if max_p <= 0; max_p = 1e-12; end
            p_target = p_means / max_p;
            [~, max_idx] = max(p_target);
            best_n_t = n_t_deb(max_idx, :);
            x0_nl = [best_n_t(1), best_n_t(2), best_n_t(3), 1.0];
            lb_nl = [-1, -1, -1, 1e-3]; ub_nl = [1, 1, 0, 10];
            obj_fcn    = @(vars) mle_cost_function(vars, p_target, n_t_deb, m_t);
            nonlcon_fn = @(vars) sphere_constraint(vars);

            t0 = tic;
            [sol, ~, ~] = fmincon(obj_fcn, x0_nl, [], [], [], [], lb_nl, ub_nl, nonlcon_fn, options_nl);
            t_nl = t_nl + toc(t0);

            v_est_nl = sol(1:3) / norm(sol(1:3));
            ang_NL_mc(mc) = acos(max(-1, min(1, v_true' * v_est_nl'))) * rad2deg_factor;
        end

        % Per-tilt RMSE
        rt_rmse_GLS(i_rt) = sqrt(mean(ang_GLS_mc.^2));
        rt_rmse_WLS(i_rt) = sqrt(mean(ang_WLS_mc.^2));
        rt_rmse_NL(i_rt)  = sqrt(mean(ang_NL_mc.^2));
    end

    % === Baseline (tilt = 0) ===
    n_r_0 = [0, 0, 1];
    param_r_0 = {A_det, n_r_0, FOV};
    P_clean_gls_0 = zeros(1, N_or);
    P_clean_deb_0 = zeros(1, N_or);
    for i_dir = 1:N_or
        param_t_gls = {T, n_t_gls(i_dir,:), P_t, m_t};
        [~, P_clean_gls_0(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t_gls, param_r_0);
        param_t_deb = {T, n_t_deb(i_dir,:), P_t, m_t};
        [~, P_clean_deb_0(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t_deb, param_r_0);
    end
    deb_0 = DEB_complete_nr(R_real, n_t_deb', T', P_t, m_t, A_det, ...
        deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples, [0;0;1]);
    if isreal(deb_0) && isfinite(deb_0)
        DEB_ang_baseline(i_pos) = deb_0 * rad2deg_factor;
    else
        DEB_ang_baseline(i_pos) = NaN;
    end

    bl_WLS = zeros(M_trials, 1);
    bl_GLS = zeros(M_trials, 1);
    bl_NL  = zeros(M_trials, 1);
    for mc = 1:M_trials
        P_raw_gls = repmat(P_clean_gls_0, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);
        P_raw_deb = repmat(P_clean_deb_0, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);

        [d_hat, ~, ~] = vlp_wls(n_t_gls', P_raw_gls, m_t);
        v_est = d_hat' / norm(d_hat);
        bl_WLS(mc) = acos(max(-1, min(1, v_true' * v_est'))) * rad2deg_factor;

        [d_hat] = vlp_gls(n_t_gls', P_raw_gls, m_t, sigma2);
        v_est = d_hat' / norm(d_hat);
        bl_GLS(mc) = acos(max(-1, min(1, v_true' * v_est'))) * rad2deg_factor;

        p_means = mean(P_raw_deb, 1);
        max_p = max(p_means); if max_p <= 0; max_p = 1e-12; end
        p_target = p_means / max_p;
        [~, max_idx] = max(p_target);
        best_n_t = n_t_deb(max_idx, :);
        x0_nl = [best_n_t(1), best_n_t(2), best_n_t(3), 1.0];
        lb_nl = [-1, -1, -1, 1e-3]; ub_nl = [1, 1, 0, 10];
        obj_fcn    = @(vars) mle_cost_function(vars, p_target, n_t_deb, m_t);
        nonlcon_fn = @(vars) sphere_constraint(vars);
        [sol, ~, ~] = fmincon(obj_fcn, x0_nl, [], [], [], [], lb_nl, ub_nl, nonlcon_fn, options_nl);
        v_est_nl = sol(1:3) / norm(sol(1:3));
        bl_NL(mc) = acos(max(-1, min(1, v_true' * v_est_nl'))) * rad2deg_factor;
    end
    rmse_GLS_baseline(i_pos) = sqrt(mean(bl_GLS.^2));
    rmse_WLS_baseline(i_pos) = sqrt(mean(bl_WLS.^2));
    rmse_NL_baseline(i_pos)  = sqrt(mean(bl_NL.^2));

    % === Store results ===
    rmse_GLS_all(i_pos, :) = rt_rmse_GLS';
    rmse_WLS_all(i_pos, :) = rt_rmse_WLS';
    rmse_NL_all(i_pos, :)  = rt_rmse_NL';
    DEB_ang_all(i_pos, :)  = rt_DEB';

    % Aggregated RMSE: RMS across all tilts
    rmse_GLS_agg(i_pos) = sqrt(mean(rt_rmse_GLS.^2));
    rmse_WLS_agg(i_pos) = sqrt(mean(rt_rmse_WLS.^2));
    rmse_NL_agg(i_pos)  = sqrt(mean(rt_rmse_NL.^2));
    DEB_ang_agg(i_pos)  = sqrt(nanmean(rt_DEB.^2));

    % Timing
    time_WLS_arr(i_pos) = t_wls;
    time_GLS_arr(i_pos) = t_gls;
    time_NL_arr(i_pos)  = t_nl;

    % Progress (every 10 positions)
    if mod(i_pos, 10) == 0 || i_pos == 1 || i_pos == N_pos
        send(D, i_pos);
    end
end

elapsed_total = toc(tic_total);

%% 6. Aggregate timing
time_WLS = sum(time_WLS_arr);
time_GLS = sum(time_GLS_arr);
time_NL  = sum(time_NL_arr);
total_runs = N_pos * N_random_tilt * M_trials;

%% 7. Display results
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('RANDOM TILT SENSITIVITY RESULTS (K=%d, M=%d, N_tilt=%d)\n', N_or, M_trials, N_random_tilt);
fprintf('Tilt distribution: half-normal(sigma=%.1f deg), max=%.1f deg\n', sigma_tilt, theta_max_tilt);
fprintf('%s\n', repmat('=', 1, 70));

fprintf('\n--- AGGREGATED OVER RANDOM TILTS (per-position RMSE) ---\n');
fprintf('%-10s  %12s  %12s  %12s\n', 'Method', 'RMSE [°]', 'CDF90 [°]', 'Mean [°]');
fprintf('%s\n', repmat('-', 1, 50));
fprintf('%-10s  %12.4f  %12.4f  %12.4f\n', 'GLS',    sqrt(mean(rmse_GLS_agg.^2)), prctile(rmse_GLS_agg, 90), mean(rmse_GLS_agg));
fprintf('%-10s  %12.4f  %12.4f  %12.4f\n', 'WLS',    sqrt(mean(rmse_WLS_agg.^2)), prctile(rmse_WLS_agg, 90), mean(rmse_WLS_agg));
fprintf('%-10s  %12.4f  %12.4f  %12.4f\n', 'NL-MLE', sqrt(mean(rmse_NL_agg.^2)),  prctile(rmse_NL_agg, 90),  mean(rmse_NL_agg));
fprintf('%-10s  %12.4f  %12.4f  %12.4f\n', 'DEB',    sqrt(nanmean(DEB_ang_agg.^2)), prctile(DEB_ang_agg(~isnan(DEB_ang_agg)), 90), nanmean(DEB_ang_agg));
fprintf('%s\n', repmat('-', 1, 50));

fprintf('\n--- BASELINE (tilt = 0°) ---\n');
fprintf('%-10s  %12s  %12s  %12s\n', 'Method', 'RMSE [°]', 'CDF90 [°]', 'Mean [°]');
fprintf('%s\n', repmat('-', 1, 50));
fprintf('%-10s  %12.4f  %12.4f  %12.4f\n', 'GLS',    sqrt(mean(rmse_GLS_baseline.^2)), prctile(rmse_GLS_baseline, 90), mean(rmse_GLS_baseline));
fprintf('%-10s  %12.4f  %12.4f  %12.4f\n', 'WLS',    sqrt(mean(rmse_WLS_baseline.^2)), prctile(rmse_WLS_baseline, 90), mean(rmse_WLS_baseline));
fprintf('%-10s  %12.4f  %12.4f  %12.4f\n', 'NL-MLE', sqrt(mean(rmse_NL_baseline.^2)),  prctile(rmse_NL_baseline, 90),  mean(rmse_NL_baseline));
fprintf('%-10s  %12.4f  %12.4f  %12.4f\n', 'DEB',    sqrt(nanmean(DEB_ang_baseline.^2)), prctile(DEB_ang_baseline(~isnan(DEB_ang_baseline)), 90), nanmean(DEB_ang_baseline));
fprintf('%s\n', repmat('-', 1, 50));

fprintf('\n--- DEGRADATION (random tilt vs baseline) ---\n');
delta_GLS = sqrt(mean(rmse_GLS_agg.^2)) - sqrt(mean(rmse_GLS_baseline.^2));
delta_WLS = sqrt(mean(rmse_WLS_agg.^2)) - sqrt(mean(rmse_WLS_baseline.^2));
delta_NL  = sqrt(mean(rmse_NL_agg.^2))  - sqrt(mean(rmse_NL_baseline.^2));
delta_DEB = sqrt(nanmean(DEB_ang_agg.^2)) - sqrt(nanmean(DEB_ang_baseline.^2));
pct_GLS = 100 * delta_GLS / sqrt(mean(rmse_GLS_baseline.^2));
pct_WLS = 100 * delta_WLS / sqrt(mean(rmse_WLS_baseline.^2));
pct_NL  = 100 * delta_NL  / sqrt(mean(rmse_NL_baseline.^2));
pct_DEB = 100 * delta_DEB / sqrt(nanmean(DEB_ang_baseline.^2));
fprintf('  GLS  : %+.4f° (%+.2f%%)\n', delta_GLS, pct_GLS);
fprintf('  WLS  : %+.4f° (%+.2f%%)\n', delta_WLS, pct_WLS);
fprintf('  NL   : %+.4f° (%+.2f%%)\n', delta_NL,  pct_NL);
fprintf('  DEB  : %+.4f° (%+.2f%%)\n', delta_DEB, pct_DEB);
fprintf('%s\n', repmat('=', 1, 70));

fprintf('\nLatency — WLS: %.4f ms | GLS: %.4f ms | NL-MLE: %.4f ms\n', ...
    (time_WLS/total_runs)*1000, (time_GLS/total_runs)*1000, (time_NL/total_runs)*1000);
fprintf('Total elapsed: %.1f min (%.1f h)\n', elapsed_total/60, elapsed_total/3600);

if TEST_MODE
    fprintf('\nWARNING: TEST_MODE=true. For paper: TEST_MODE=false, M_trials>=100\n');
end

%% 8. Save (full workspace)
if save_files
    mat_file = fullfile(results_dir, ...
        sprintf('nr_random_tilt_K%d_M%d_Ntilt%d.mat', N_or, M_trials, N_random_tilt));
    save(mat_file);
    fprintf('\nFull workspace saved to: %s\n', mat_file);
end

fprintf('Log: %s\n', log_filename);
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
    c = [];
    ceq = vars(1)^2 + vars(2)^2 + vars(3)^2 - 1;
end
