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
M_trials   = 10;         % Monte Carlo trials per position
K_sweep    = [5, 9];     % K values to compare in one CDF
save_files = false;
SAVE_FIGS  = true;       % Export figures in IEEE format (pdf/png/eps)

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

%% 2. Generate Receiver Positions
if TEST_MODE
    [X, Y, Z] = meshgrid(-1.5:0.5:1.5, -1.5:0.5:1.5, 0:0.6:1.2);
else
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
end
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);
param_r_ch = {A_det, n_r, FOV};

%% 3. Results directory and log
results_dir = fullfile(pwd, 'results', sprintf('broadcast_MC%d', M_trials));
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
log_file = fullfile(results_dir, sprintf('log_%s.txt', datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
diary(log_file);

fprintf('%s\n', repmat('=', 1, 60));
fprintf('BROADCAST 3D POSITIONING — MC SIMULATION\n');
fprintf('%s\n', repmat('=', 1, 60));
fprintf('Date       : %s\n', datestr(now));
fprintf('K_sweep    : [%s]\n', num2str(K_sweep));
fprintf('M_trials   : %d\n', M_trials);
fprintf('N_pos      : %d\n', N_pos);
fprintf('N_samples  : %d\n', N_samples);
fprintf('n_r        : [%.2f, %.2f, %.2f]\n', n_r(1), n_r(2), n_r(3));
fprintf('TEST_MODE  : %d\n', TEST_MODE);
fprintf('Workers    : %d\n', pool.NumWorkers);
fprintf('%s\n\n', repmat('=', 1, 60));

%% 4. Storage for all K values
nK = length(K_sweep);
cm = 100;

all_rmse_GLS = cell(nK, 1);
all_rmse_WLS = cell(nK, 1);
all_rmse_NLS = cell(nK, 1);
all_PEB_B    = cell(nK, 1);
all_time_GLS = zeros(nK, 1);
all_time_WLS = zeros(nK, 1);
all_time_NLS = zeros(nK, 1);

%% 5. Monte Carlo Core — loop over K values
for ik = 1:nK
    N_or = K_sweep(ik);
    K_idx = find(K_values == N_or);
    if isempty(K_idx)
        error('No DEB-optimized orientations available for K=%d', N_or);
    end
    nt = orient_to_vectors(all_orientations_DEB{K_idx});
    nt_rows = nt';

    rmse_GLS = zeros(N_pos, 1);
    rmse_WLS = zeros(N_pos, 1);
    rmse_NLS = zeros(N_pos, 1);
    PEB_B_arr = zeros(N_pos, 1);
    time_GLS_arr = zeros(N_pos, 1);
    time_WLS_arr = zeros(N_pos, 1);
    time_NLS_arr = zeros(N_pos, 1);

    fprintf('\n>>> K = %d (%d positions, %d MC trials)\n', N_or, N_pos, M_trials);
    D = parallel.pool.DataQueue;
    afterEach(D, @(pos) fprintf('  K=%d: position %d / %d\n', N_or, pos, N_pos));
    k_tic = tic;

    parfor i_pos = 1:N_pos
        x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
        R_real = [x; y; z];
        realPos = [x, y, z];

        P_clean = zeros(1, N_or);
        for i_dir = 1:N_or
            param_t = {T, nt_rows(i_dir,:), P_t, m_t};
            [~, P_clean(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r_ch);
        end

        peb_val = PEB_Konly(R_real, nt, T', P_t, m_t, A_det, deg2rad(FOV), sigma2, N_samples, n_r');
        if isreal(peb_val) && isfinite(peb_val)
            PEB_B_arr(i_pos) = peb_val;
        else
            PEB_B_arr(i_pos) = NaN;
        end

        err_GLS_mc = zeros(M_trials, 1);
        err_WLS_mc = zeros(M_trials, 1);
        err_NLS_mc = zeros(M_trials, 1);
        t_gls = 0; t_wls = 0; t_nls = 0;

        for mc = 1:M_trials
            P_raw = repmat(P_clean, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);
            mu_hat_mc = mean(P_raw, 1);

            t0 = tic;
            nd_gls = vlp_gls(nt, P_raw, m_t, sigma2);
            [d_gls, ~, ~] = broadcast_distance(nd_gls, nt, mu_hat_mc, m_t, C_opt, n_r');
            estPos = T + (nd_gls' * d_gls);
            t_gls = t_gls + toc(t0);
            err_GLS_mc(mc) = norm(realPos - estPos);

            t0 = tic;
            nd_wls = vlp_wls(nt, P_raw, m_t);
            [d_wls, ~, ~] = broadcast_distance(nd_wls, nt, mu_hat_mc, m_t, C_opt, n_r');
            estPos = T + (nd_wls' * d_wls);
            t_wls = t_wls + toc(t0);
            err_WLS_mc(mc) = norm(realPos - estPos);

            t0 = tic;
            nd_nls = vlp_nls_lm(nt, P_raw, m_t);
            [d_nls, ~, ~] = broadcast_distance(nd_nls, nt, mu_hat_mc, m_t, C_opt, n_r');
            estPos = T + (nd_nls' * d_nls);
            t_nls = t_nls + toc(t0);
            err_NLS_mc(mc) = norm(realPos - estPos);
        end

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

    % Store results for this K
    all_rmse_GLS{ik} = rmse_GLS;
    all_rmse_WLS{ik} = rmse_WLS;
    all_rmse_NLS{ik} = rmse_NLS;
    all_PEB_B{ik}    = PEB_B_arr;
    total_runs_k = N_pos * M_trials;
    all_time_GLS(ik) = (sum(time_GLS_arr)/total_runs_k)*1000;
    all_time_WLS(ik) = (sum(time_WLS_arr)/total_runs_k)*1000;
    all_time_NLS(ik) = (sum(time_NLS_arr)/total_runs_k)*1000;

    fprintf('  K=%d done in %.1f s\n', N_or, toc(k_tic));
end

%% 6. Print Results Table
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf(' BROADCAST 3D POSITIONING RESULTS (M=%d MC)\n', M_trials);
fprintf('%s\n', repmat('=', 1, 70));
fprintf('%-4s %-10s %10s %10s %10s %10s\n', 'K', 'Method', 'RMSE[cm]', 'CDF90[cm]', 'APE[cm]', 'Lat.[ms]');
fprintf('%s\n', repmat('-', 1, 70));
for ik = 1:nK
    K_i = K_sweep(ik);
    for method = {'GLS', 'WLS', 'NLS', 'PEB_B'}
        m_name = method{1};
        switch m_name
            case 'GLS',  vals = all_rmse_GLS{ik}; lat = all_time_GLS(ik);
            case 'WLS',  vals = all_rmse_WLS{ik}; lat = all_time_WLS(ik);
            case 'NLS',  vals = all_rmse_NLS{ik}; lat = all_time_NLS(ik);
            case 'PEB_B', vals = all_PEB_B{ik}; lat = NaN;
        end
        v = vals(isfinite(vals));
        fprintf('%-4d %-10s %10.2f %10.2f %10.2f', ...
            K_i, m_name, sqrt(mean(v.^2))*cm, prctile(v,90)*cm, mean(v)*cm);
        if isfinite(lat), fprintf(' %10.4f', lat); else, fprintf(' %10s', '-'); end
        fprintf('\n');
    end
    fprintf('%s\n', repmat('-', 1, 70));
end

if TEST_MODE
    fprintf('\nWARNING: TEST_MODE=true. For paper results use TEST_MODE=false.\n');
end

%% 7. CDF Figure — K=5 (solid) vs K=9 (dashed), explicit legend

c_gls = [0.00, 0.45, 0.74];
c_wls = [0.85, 0.33, 0.10];
c_nls = [0.49, 0.18, 0.56];
c_peb = [0.47, 0.67, 0.19];

figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w');
hold on;

% K=5 → solid (ik=1), K=9 → dashed (ik=2)
styles = {'-', '--'};
lw_base = 0.9;
leg_h = gobjects(0); leg_l = {};

for ik = 1:nK
    K_i = K_sweep(ik);
    ls = styles{ik};

    [f,x] = ecdf(all_rmse_GLS{ik}*cm);
    h = stairs(x, f, ls, 'LineWidth', lw_base, 'Color', c_gls);
    leg_h(end+1) = h; leg_l{end+1} = sprintf('GLS ($K{=}%d$)', K_i);

    [f,x] = ecdf(all_rmse_WLS{ik}*cm);
    h = stairs(x, f, ls, 'LineWidth', lw_base, 'Color', c_wls);
    leg_h(end+1) = h; leg_l{end+1} = sprintf('WLS ($K{=}%d$)', K_i);

    [f,x] = ecdf(all_rmse_NLS{ik}*cm);
    h = stairs(x, f, ls, 'LineWidth', lw_base+0.3, 'Color', c_nls);
    leg_h(end+1) = h; leg_l{end+1} = sprintf('NLS ($K{=}%d$)', K_i);

    v = all_PEB_B{ik}; v = v(isfinite(v));
    [f,x] = ecdf(v*cm);
    h = stairs(x, f, ls, 'LineWidth', lw_base, 'Color', c_peb);
    leg_h(end+1) = h; leg_l{end+1} = sprintf('$\\mathrm{PEB}_\\mathrm{B}$ ($K{=}%d$)', K_i);
end

yline(0.9, ':', 'LineWidth', 0.5, 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
xlabel('3D Positioning Error [cm]', 'Interpreter', 'latex', 'FontSize', 11);
ylabel('CDF', 'Interpreter', 'latex', 'FontSize', 11);
legend(leg_h, leg_l, 'Interpreter', 'latex', 'FontSize', 5.5, ...
    'Location', 'southeast', 'NumColumns', 2);
grid minor; box on;
set(gca, 'FontSize', 7, 'LineWidth', 0.5);
xlim([0 20])
if SAVE_FIGS
    exportgraphics(gcf, fullfile(results_dir, 'Fig05_CDF_broadcast.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(gcf, fullfile(results_dir, 'Fig05_CDF_broadcast.png'), 'Resolution',600,'BackgroundColor','white');
    exportgraphics(gcf, fullfile(results_dir, 'Fig05_CDF_broadcast.eps'), 'ContentType','vector','BackgroundColor','white');
    fprintf('CDF figure saved (pdf/png/eps)\n');
end

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
