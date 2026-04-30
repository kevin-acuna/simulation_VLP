%% run_nr_robustness_MC_parallel.m
% Sweep receiver tilt angles to demonstrate n_r-agnosticism of ratio-based
% DF estimators (GLS, WLS, NL-MLE).
%
% For each tilt angle theta_tilt:
%   - Set n_r = [sin(theta_tilt)cos(phi), sin(theta_tilt)sin(phi), cos(theta_tilt)]
%   - Run DF Monte Carlo (M trials) over the 3D position grid (parfor)
%   - Compute DEB with the actual n_r (via DEB_complete_nr)
%
% The key claim (Proposition 1):
%   GLS/WLS/NL-MLE use only power RATIOS P_k/P_j.
%   The common factor alpha(n_r, d) cancels in all ratios.
%   Therefore, these estimators do NOT require n_r as input.
%   However, n_r affects the absolute SNR, which in turn affects
%   the noise level in the estimated ratios. The DEB, computed from
%   absolute powers, explicitly depends on n_r.
%
% Outer loop: tilt angles (sequential)
% Inner loop: positions (parfor)
% Saves a struct array with per-tilt results.
%
% Author: Kevin Acuña

close all; clear variables; clc;
addpath('../core');
addpath('../estimators');

% =================================================
% HYPERPARAMETERS
% =================================================
rng(42);
TEST_MODE    = false;     % true = fast coarse grid
M_trials     = 1000;      % Monte Carlo trials per position
N_or         = 5;         % Number of LED orientations
save_files   = 1;

% Receiver tilt sweep
tilt_angles  = 0:2:20;  % degrees
phi_tilt     = 0;                          % fixed azimuth [deg]

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

%% 2. Receiver Positions (shared across all tilts)
if TEST_MODE
    [X, Y, Z] = meshgrid(-1.5:0.5:1.5, -1.5:0.5:1.5, 0:0.6:1.2);
else
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
end
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);
fprintf('Grid: %d positions\n', N_pos);

%% 3. Results directory & log
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

log_filename = fullfile(results_dir, ...
    sprintf('nr_robustness_K%d_M%d_log_%s.txt', N_or, M_trials, datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
diary(log_filename);

fprintf('%s\n', repmat('=', 1, 60));
fprintf('n_r ROBUSTNESS EXPERIMENT LOG\n');
fprintf('%s\n', repmat('=', 1, 60));
fprintf('Date         : %s\n', datestr(now));
fprintf('K (N_or)     : %d\n', N_or);
fprintf('M_trials     : %d\n', M_trials);
fprintf('N_pos        : %d\n', N_pos);
fprintf('N_samples    : %d\n', N_samples);
fprintf('sigma2       : %.4e\n', sigma2);
fprintf('FOV          : %d deg\n', FOV);
fprintf('Tilt angles  : %s deg\n', mat2str(tilt_angles));
fprintf('Phi_tilt     : %d deg\n', phi_tilt);
fprintf('Workers      : %d\n', pool.NumWorkers);
fprintf('TEST_MODE    : %d\n', TEST_MODE);
fprintf('GLS/WLS ori  : orientations_GLS_DF_K5_MC10\n');
for ii = 1:N_or
    fprintf('               LED%d: theta=%.2f deg, rho=%.2f deg\n', ...
        ii, or_gls_raw(2*ii-1), or_gls_raw(2*ii));
end
fprintf('NL/DEB  ori  : orientations_DEB_K5\n');
for ii = 1:N_or
    fprintf('               LED%d: theta=%.2f deg, rho=%.2f deg\n', ...
        ii, or_deb_raw(2*ii-1), or_deb_raw(2*ii));
end
fprintf('%s\n\n', repmat('=', 1, 60));

%% 4. Main sweep over tilt angles
N_tilts = length(tilt_angles);
rad2deg_factor = 180 / pi;
options_nl = optimoptions('fmincon', 'Display', 'none', 'Algorithm', 'sqp');

% Pre-allocate struct array
all_results = struct();

for i_tilt = 1:N_tilts
    theta_t = tilt_angles(i_tilt);

    % Build n_r for this tilt
    n_r_tilt = [sind(theta_t)*cosd(phi_tilt), ...
                sind(theta_t)*sind(phi_tilt), ...
                cosd(theta_t)];
    param_r_tilt = {A_det, n_r_tilt, FOV};

    fprintf('\n%s\n', repmat('-', 1, 60));
    fprintf('TILT %d/%d: theta_tilt = %d deg, n_r = [%.4f, %.4f, %.4f]\n', ...
        i_tilt, N_tilts, theta_t, n_r_tilt(1), n_r_tilt(2), n_r_tilt(3));
    fprintf('%s\n', repmat('-', 1, 60));

    % Per-position arrays
    rmse_ang_WLS = zeros(N_pos, 1);
    rmse_ang_GLS = zeros(N_pos, 1);
    rmse_ang_NL  = zeros(N_pos, 1);
    DEB_ang      = zeros(N_pos, 1);
    coverage     = true(N_pos, 1);
    time_WLS_arr = zeros(N_pos, 1);
    time_GLS_arr = zeros(N_pos, 1);
    time_NL_arr  = zeros(N_pos, 1);

    % Progress queue
    D = parallel.pool.DataQueue;
    afterEach(D, @(pos) fprintf('  --> tilt=%d°: position %d / %d\n', theta_t, pos, N_pos));

    tic_tilt = tic;

    parfor i_pos = 1:N_pos
        x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
        R_real = [x; y; z];
        v_true = (R_real - T') / norm(R_real - T');

        % --- Clean channel powers (separate for each orientation set) ---
        P_clean_gls = zeros(1, N_or);
        P_clean_deb = zeros(1, N_or);
        for i_dir = 1:N_or
            param_t_gls = {T, n_t_gls(i_dir,:), P_t, m_t};
            [~, P_clean_gls(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t_gls, param_r_tilt);
            param_t_deb = {T, n_t_deb(i_dir,:), P_t, m_t};
            [~, P_clean_deb(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t_deb, param_r_tilt);
        end

        % --- DEB with actual n_r (uses DEB orientations) ---
        n_r_col = n_r_tilt(:);
        deb_val = DEB_complete_nr(R_real, n_t_deb', T', P_t, m_t, A_det, ...
            deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples, n_r_col);
        if isreal(deb_val) && isfinite(deb_val)
            DEB_ang(i_pos) = deb_val * rad2deg_factor;
        else
            DEB_ang(i_pos) = NaN;
        end

        % Coverage flag — informational only, all positions are simulated
        if any(P_clean_gls <= 0) || any(P_clean_deb <= 0)
            coverage(i_pos) = false;
        end

        % --- MC trials ---
        ang_WLS_mc = zeros(M_trials, 1);
        ang_GLS_mc = zeros(M_trials, 1);
        ang_NL_mc  = zeros(M_trials, 1);
        t_wls = 0; t_gls = 0; t_nl = 0;

        for mc = 1:M_trials
            % Noisy powers — separate for each orientation set
            P_raw_gls = repmat(P_clean_gls, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);
            P_raw_deb = repmat(P_clean_deb, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);

            % WLS (uses GLS/WLS orientations)
            t0 = tic;
            [d_hat, ~, ~] = vlp_wls(n_t_gls', P_raw_gls, m_t);
            t_wls = t_wls + toc(t0);
            v_est = d_hat' / norm(d_hat);
            ang_WLS_mc(mc) = acos(max(-1, min(1, v_true' * v_est'))) * rad2deg_factor;

            % GLS (uses GLS/WLS orientations)
            t0 = tic;
            [d_hat] = vlp_gls(n_t_gls', P_raw_gls, m_t, sigma2);
            t_gls = t_gls + toc(t0);
            v_est = d_hat' / norm(d_hat);
            ang_GLS_mc(mc) = acos(max(-1, min(1, v_true' * v_est'))) * rad2deg_factor;

            % NL-MLE (uses DEB orientations)
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

        % Per-position RMSE
        rmse_ang_WLS(i_pos) = sqrt(mean(ang_WLS_mc.^2));
        rmse_ang_GLS(i_pos) = sqrt(mean(ang_GLS_mc.^2));
        rmse_ang_NL(i_pos)  = sqrt(mean(ang_NL_mc.^2));

        % Timing
        time_WLS_arr(i_pos) = t_wls;
        time_GLS_arr(i_pos) = t_gls;
        time_NL_arr(i_pos)  = t_nl;

        % Progress
        if mod(i_pos, 50) == 0 || i_pos == 1 || i_pos == N_pos
            send(D, i_pos);
        end
    end

    elapsed = toc(tic_tilt);

    % Store in struct
    all_results(i_tilt).theta_tilt   = theta_t;
    all_results(i_tilt).phi_tilt     = phi_tilt;
    all_results(i_tilt).n_r          = n_r_tilt;
    all_results(i_tilt).rmse_ang_GLS = rmse_ang_GLS;
    all_results(i_tilt).rmse_ang_WLS = rmse_ang_WLS;
    all_results(i_tilt).rmse_ang_NL  = rmse_ang_NL;
    all_results(i_tilt).DEB_ang      = DEB_ang;
    all_results(i_tilt).coverage     = coverage;
    all_results(i_tilt).time_WLS     = sum(time_WLS_arr);
    all_results(i_tilt).time_GLS     = sum(time_GLS_arr);
    all_results(i_tilt).time_NL      = sum(time_NL_arr);
    all_results(i_tilt).elapsed_s    = elapsed;

    % Quick summary for this tilt (all positions)
    n_valid = sum(coverage);
    fprintf('  Coverage  : %d / %d positions (%.1f%%)  [informational]\n', n_valid, N_pos, 100*n_valid/N_pos);
    fprintf('  GLS  RMSE : %.4f deg  (all positions)\n', sqrt(nanmean(rmse_ang_GLS.^2)));
    fprintf('  WLS  RMSE : %.4f deg\n', sqrt(nanmean(rmse_ang_WLS.^2)));
    fprintf('  NL   RMSE : %.4f deg\n', sqrt(nanmean(rmse_ang_NL.^2)));
    fprintf('  DEB  RMSE : %.4f deg\n', sqrt(nanmean(DEB_ang.^2)));
    fprintf('  Elapsed   : %.1f s\n', elapsed);
end

%% 5. Coverage statistics (informational)
common_cov = true(N_pos, 1);
for i_tilt = 1:N_tilts
    common_cov = common_cov & all_results(i_tilt).coverage;
end
n_common = sum(common_cov);
fprintf('\n%s\n', repmat('=', 1, 60));
fprintf('Coverage info: %d / %d positions fully illuminated across all tilts (%.1f%%)\n', ...
    n_common, N_pos, 100*n_common/N_pos);
fprintf('%s\n', repmat('=', 1, 60));

% Final metrics over ALL positions
fprintf('\nRESULTS OVER ALL %d POSITIONS\n', N_pos);
fprintf('%-12s  %-10s  %-10s  %-10s  %-10s\n', 'Tilt [deg]', 'GLS [°]', 'WLS [°]', 'NL [°]', 'DEB [°]');
fprintf('%s\n', repmat('-', 1, 60));
for i_tilt = 1:N_tilts
    g = all_results(i_tilt).rmse_ang_GLS;
    w = all_results(i_tilt).rmse_ang_WLS;
    n = all_results(i_tilt).rmse_ang_NL;
    d = all_results(i_tilt).DEB_ang;
    fprintf('%-12d  %-10.4f  %-10.4f  %-10.4f  %-10.4f\n', ...
        all_results(i_tilt).theta_tilt, ...
        sqrt(nanmean(g.^2)), sqrt(nanmean(w.^2)), sqrt(nanmean(n.^2)), sqrt(nanmean(d.^2)));
end
fprintf('%s\n', repmat('=', 1, 60));

%% 6. Save
if save_files
    mat_file = fullfile(results_dir, sprintf('nr_robustness_K%d_M%d.mat', N_or, M_trials));
    save(mat_file, ...
        'all_results', 'tilt_angles', 'phi_tilt', 'common_cov', ...
        'N_or', 'M_trials', 'N_pos', 'N_samples', 'sigma2', 'FOV', ...
        'X_r', 'Y_r', 'Z_r', 'n_t_gls', 'n_t_deb', 'T', ...
        'or_gls_raw', 'or_deb_raw');
    fprintf('\nResults saved to: %s\n', mat_file);
end

fprintf('\nTotal experiment time: %.1f min\n', sum([all_results.elapsed_s])/60);
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
