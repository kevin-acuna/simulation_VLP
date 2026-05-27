%% sim05_MC_broadcast.m — Monte Carlo: Broadcast 3D Positioning (Parallel)
%
% Full 3D positioning using ONLY K measurements (no cooperative K+1).
% Pipeline per trial:
%   1. Generate K noisy powers from the Lambertian channel
%   2. Direction finding: GLS / WLS / NLS (from fundamentals/core)
%   3. Broadcast distance recovery: eta_hat + d_hat (from core/broadcast_distance)
%   4. Position: r_hat = t + d_hat * nd_hat
%
% Compared against PEB_B (broadcast PEB, no K+1 contribution).
%
% Author: Kevin Acuna-Condori
% Date: 27 May 2026
% Project: Proposal F — Broadcast K-only OWP

close all; clear; clc;

%% Add paths
addpath(fullfile(pwd, '..\core'));
addpath(fullfile(fileparts(pwd), '..\','fundamentals', 'core'));

% =========================================================================
% HYPERPARAMETERS
% =========================================================================
rng(42);
TEST_MODE  = false;      % true = coarse grid for debugging
M_trials   = 10;       % Monte Carlo trials per position
N_or       = 5;          % Number of orientations (K)
save_files = false;

%% 0. Parallel Pool
fprintf('Setting up parallel pool...\n');
if isempty(gcp('nocreate'))
    pool = parpool('local');
else
    pool = gcp;
end
fprintf('Using %d parallel workers.\n\n', pool.NumWorkers);

%% 1. System Parameters
system_params_F;
%n_r = [0, sind(20), cosd(20)];
% Select orientation set for chosen K
K_idx = find(K_values == N_or);
if isempty(K_idx)
    error('No DEB-optimized orientations available for K=%d', N_or);
end
orient_deg = all_orientations_DEB{K_idx};
nt = orient_to_vectors(orient_deg);  % 3 x K

% Also build Kx3 format for estimator functions
nt_rows = nt';  % K x 3

%% 2. Generate Receiver Positions
if TEST_MODE
    [X, Y, Z] = meshgrid(-1.5:0.5:1.5, -1.5:0.5:1.5, 0:0.6:1.2);
else
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
end
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);
fprintf('Testbed: %d positions, K=%d, M=%d trials\n', N_pos, N_or, M_trials);

param_r_ch = {A_det, n_r, FOV};  % For OWC_LOS_channel

%% 3. Preallocate
rmse_GLS = zeros(N_pos, 1);
rmse_WLS = zeros(N_pos, 1);
rmse_NLS = zeros(N_pos, 1);
PEB_B_arr = zeros(N_pos, 1);

time_GLS_arr = zeros(N_pos, 1);
time_WLS_arr = zeros(N_pos, 1);
time_NLS_arr = zeros(N_pos, 1);

%% 4. Results directory and log
results_dir = fullfile(pwd, 'results', sprintf('broadcast_K%d_MC%d', N_or, M_trials));
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

log_file = fullfile(results_dir, sprintf('log_%s.txt', datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
diary(log_file);

fprintf('%s\n', repmat('=', 1, 60));
fprintf('BROADCAST 3D POSITIONING — MC SIMULATION\n');
fprintf('%s\n', repmat('=', 1, 60));
fprintf('Date       : %s\n', datestr(now));
fprintf('K          : %d\n', N_or);
fprintf('M_trials   : %d\n', M_trials);
fprintf('N_pos      : %d\n', N_pos);
fprintf('N_samples  : %d\n', N_samples);
fprintf('n_r        : [%.2f, %.2f, %.2f]\n', n_r(1), n_r(2), n_r(3));
fprintf('TEST_MODE  : %d\n', TEST_MODE);
fprintf('Workers    : %d\n', pool.NumWorkers);
fprintf('%s\n\n', repmat('=', 1, 60));

%% 5. Monte Carlo Core (parallel over positions)
D = parallel.pool.DataQueue;
afterEach(D, @(pos) fprintf('  --> Completed position %d / %d\n', pos, N_pos));

fprintf('Running broadcast MC...\n');
total_tic = tic;

parfor i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    R_real = [x; y; z];
    realPos = [x, y, z];

    % --- Clean channel powers (K orientations, no K+1) ---
    P_clean = zeros(1, N_or);
    for i_dir = 1:N_or
        param_t = {T, nt_rows(i_dir,:), P_t, m_t};
        [~, P_clean(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r_ch);
    end

    % --- Broadcast PEB (deterministic, once per position) ---
    peb_val = PEB_Konly(R_real, nt, T', P_t, m_t, A_det, deg2rad(FOV), sigma2, N_samples, n_r');
    if isreal(peb_val) && isfinite(peb_val)
        PEB_B_arr(i_pos) = peb_val;
    else
        PEB_B_arr(i_pos) = NaN;
    end

    % --- MC trials ---
    err_GLS_mc = zeros(M_trials, 1);
    err_WLS_mc = zeros(M_trials, 1);
    err_NLS_mc = zeros(M_trials, 1);
    t_gls = 0; t_wls = 0; t_nls = 0;

    for mc = 1:M_trials
        % Noisy K powers (same noise for all estimators)
        P_raw = repmat(P_clean, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);
        mu_hat_mc = mean(P_raw, 1);

        % ===== GLS =====
        t0 = tic;
        nd_gls = vlp_gls(nt, P_raw, m_t, sigma2);
        [d_gls, ~, ~] = broadcast_distance(nd_gls, nt, mu_hat_mc, m_t, C_opt, n_r');
        estPos = T + (nd_gls' * d_gls);
        t_gls = t_gls + toc(t0);
        err_GLS_mc(mc) = norm(realPos - estPos);

        % ===== WLS =====
        t0 = tic;
        nd_wls = vlp_wls(nt, P_raw, m_t);
        [d_wls, ~, ~] = broadcast_distance(nd_wls, nt, mu_hat_mc, m_t, C_opt, n_r');
        estPos = T + (nd_wls' * d_wls);
        t_wls = t_wls + toc(t0);
        err_WLS_mc(mc) = norm(realPos - estPos);

        % ===== NLS (Levenberg-Marquardt) =====
        t0 = tic;
        nd_nls = vlp_nls_lm(nt, P_raw, m_t);
        [d_nls, ~, ~] = broadcast_distance(nd_nls, nt, mu_hat_mc, m_t, C_opt, n_r');
        estPos = T + (nd_nls' * d_nls);
        t_nls = t_nls + toc(t0);
        err_NLS_mc(mc) = norm(realPos - estPos);
    end

    % Per-position RMSE
    rmse_GLS(i_pos) = sqrt(mean(err_GLS_mc.^2));
    rmse_WLS(i_pos) = sqrt(mean(err_WLS_mc.^2));
    rmse_NLS(i_pos) = sqrt(mean(err_NLS_mc.^2));

    time_GLS_arr(i_pos) = t_gls;
    time_WLS_arr(i_pos) = t_wls;
    time_NLS_arr(i_pos) = t_nls;

    if mod(i_pos, 10) == 0 || i_pos == 1 || i_pos == N_pos
        send(D, i_pos);
    end
end

total_time = toc(total_tic);
total_runs = N_pos * M_trials;

%% 6. Aggregate Results
cm = 100;

global_rmse_GLS = sqrt(mean(rmse_GLS.^2));
global_rmse_WLS = sqrt(mean(rmse_WLS.^2));
global_rmse_NLS = sqrt(mean(rmse_NLS.^2));
global_rmse_PEB = sqrt(nanmean(PEB_B_arr.^2));

cdf90_GLS = prctile(rmse_GLS, 90);
cdf90_WLS = prctile(rmse_WLS, 90);
cdf90_NLS = prctile(rmse_NLS, 90);
cdf90_PEB = prctile(PEB_B_arr(~isnan(PEB_B_arr)), 90);

ape_GLS = mean(rmse_GLS);
ape_WLS = mean(rmse_WLS);
ape_NLS = mean(rmse_NLS);
ape_PEB = nanmean(PEB_B_arr);

fprintf('\n%s\n', repmat('=', 1, 60));
fprintf(' BROADCAST 3D POSITIONING RESULTS (K=%d, %d MC)\n', N_or, M_trials);
fprintf('%s\n', repmat('=', 1, 60));
fprintf('%-10s %10s %10s %10s\n', 'Method', 'RMSE[cm]', 'CDF90[cm]', 'APE[cm]');
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'GLS', global_rmse_GLS*cm, cdf90_GLS*cm, ape_GLS*cm);
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'WLS', global_rmse_WLS*cm, cdf90_WLS*cm, ape_WLS*cm);
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'NLS', global_rmse_NLS*cm, cdf90_NLS*cm, ape_NLS*cm);
fprintf('%-10s %10.2f %10.2f %10.2f\n', 'PEB_B', global_rmse_PEB*cm, cdf90_PEB*cm, ape_PEB*cm);
fprintf('%s\n', repmat('-', 1, 60));
fprintf('Latency — GLS: %.4f ms | WLS: %.4f ms | NLS: %.4f ms\n', ...
    (sum(time_GLS_arr)/total_runs)*1000, ...
    (sum(time_WLS_arr)/total_runs)*1000, ...
    (sum(time_NLS_arr)/total_runs)*1000);
fprintf('Total wall time: %.1f s (%.1f min)\n', total_time, total_time/60);

if TEST_MODE
    fprintf('\nWARNING: TEST_MODE=true. For paper results use TEST_MODE=false.\n');
end

%% 7. Figures

c_gls = [0.00, 0.45, 0.74];
c_wls = [0.85, 0.33, 0.10];
c_nls = [0.49, 0.18, 0.56];
c_peb = [0.47, 0.67, 0.19];

% ---- (a) CDF of 3D positioning error ----
figure('Name', 'Broadcast 3D Positioning', 'Position', [50, 100, 1200, 480]);

subplot(1, 2, 1);
hold on;
[f,x] = ecdf(rmse_GLS*cm); stairs(x, f, '-',  'LineWidth', 1.8, 'Color', c_gls);
[f,x] = ecdf(rmse_WLS*cm); stairs(x, f, '-',  'LineWidth', 1.8, 'Color', c_wls);
[f,x] = ecdf(rmse_NLS*cm); stairs(x, f, '-',  'LineWidth', 1.8, 'Color', c_nls);
[f,x] = ecdf(PEB_B_arr(~isnan(PEB_B_arr))*cm); stairs(x, f, '--', 'LineWidth', 1.8, 'Color', c_peb);
yline(0.9, ':', 'LineWidth', 0.5, 'Color', [0.5 0.5 0.5]);
xlabel('3D Positioning Error [cm]', 'Interpreter', 'latex');
ylabel('CDF', 'Interpreter', 'latex');
legend(sprintf('GLS ($K{=}%d$)', N_or), ...
       sprintf('WLS ($K{=}%d$)', N_or), ...
       sprintf('NLS ($K{=}%d$)', N_or), ...
       sprintf('$\\mathrm{PEB}_\\mathrm{B}$ ($K{=}%d$)', N_or), ...
       'Location', 'southeast', 'Interpreter', 'latex', 'FontSize', 8);
title('(a) CDF of 3D positioning error', 'Interpreter', 'latex');
grid minor; box on;

% ---- (b) Scatter: per-position RMSE vs PEB_B ----
subplot(1, 2, 2);
hold on;
valid_idx = isfinite(PEB_B_arr) & PEB_B_arr > 0;

scatter(PEB_B_arr(valid_idx)*cm, rmse_GLS(valid_idx)*cm, 8, c_gls, 'filled', 'MarkerFaceAlpha', 0.3);
scatter(PEB_B_arr(valid_idx)*cm, rmse_WLS(valid_idx)*cm, 8, c_wls, 'filled', 'MarkerFaceAlpha', 0.3);
scatter(PEB_B_arr(valid_idx)*cm, rmse_NLS(valid_idx)*cm, 12, c_nls, 'filled', 'MarkerFaceAlpha', 0.4);

% Diagonal (RMSE = PEB_B → perfectly efficient)
ax_max = max(max(rmse_GLS(valid_idx)*cm), max(PEB_B_arr(valid_idx)*cm)) * 1.05;
plot([0, ax_max], [0, ax_max], 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');

xlabel('$\mathrm{PEB}_\mathrm{B}$ [cm]', 'Interpreter', 'latex');
ylabel('Per-position RMSE [cm]', 'Interpreter', 'latex');
legend('GLS', 'WLS', 'NLS', 'Location', 'northwest', 'Interpreter', 'latex', 'FontSize', 8);
title('(b) Estimator RMSE vs $\mathrm{PEB}_\mathrm{B}$', 'Interpreter', 'latex');
axis equal; grid on; box on;
xlim([0, ax_max]); ylim([0, ax_max]);

% Annotation: diagonal = efficient
text(ax_max*0.55, ax_max*0.45, '$\mathrm{RMSE} = \mathrm{PEB}_\mathrm{B}$', ...
    'Interpreter', 'latex', 'FontSize', 9, 'Color', [0.4 0.4 0.4], 'Rotation', 45);

sgtitle(sprintf('Broadcast 3D Positioning ($K{=}%d$, $M{=}%d$, $\\mathbf{n}_r{=}[0,0,1]^T$)', ...
    N_or, M_trials), 'Interpreter', 'latex', 'FontSize', 12);

saveas(gcf, fullfile(results_dir, 'Fig05_CDF_and_scatter.png'));
saveas(gcf, fullfile(results_dir, 'Fig05_CDF_and_scatter.fig'));

%% 8. Save
if save_files
    save(fullfile(results_dir, sprintf('broadcast_K%d_MC%d_results.mat', N_or, M_trials)), ...
        'rmse_GLS', 'rmse_WLS', 'rmse_NLS', 'PEB_B_arr', ...
        'time_GLS_arr', 'time_WLS_arr', 'time_NLS_arr', ...
        'N_or', 'M_trials', 'N_pos', 'N_samples', 'total_runs', ...
        'X_r', 'Y_r', 'Z_r', 'total_time');
    fprintf('Results saved to: %s\n', results_dir);
end

diary off;
