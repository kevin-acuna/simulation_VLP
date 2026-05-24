%% Latency Benchmark — NL-MLE: Direction-Finding + 3D Positioning (SERIAL)
% Identical logic to bench_NL_DF.m but WITHOUT parfor.
% Purpose: verify that parallel execution does not alter timing results.
%
% Design:
%   - Full testbed grid (same as paper) to get a representative sample
%   - JIT warm-up before timing (10 calls, discarded)
%   - M_BENCH independent timed calls per position (fresh noise each time)
%   - Standard for loop — single-threaded, reproducible
%   - Results: mean, median, std, p5, p95 of per-call latency in microseconds
%
% Author: Kevin Acuña

close all; clear variables; clc;
addpath('../../core');

% =================================================
% HYPERPARAMETERS
% =================================================
N_or    = 5;       % Number of orientations (match paper K)
M_BENCH = 10;     % Timed calls per position (fewer since NL is slow)
N_WARMUP = 10;    % Warm-up calls (discarded, force JIT compilation)

%% 1. System Parameters
system_params;
T = [0, 0, 2];

n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = all_orientations_NL_DEB{N_or-2}(2*i-1);
    rho_i   = all_orientations_NL_DEB{N_or-2}(2*i);
    n_t(i,1) = sind(theta_i) * cosd(rho_i);
    n_t(i,2) = sind(theta_i) * sind(rho_i);
    n_t(i,3) = -cosd(theta_i);
end

%% 2. Positions (full testbed grid)
[X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);
fprintf('Positions : %d\n', N_pos);
fprintf('Trials/pos: %d\n', M_BENCH);
fprintf('Total calls: %d\n\n', N_pos * M_BENCH);

param_r = {A_det, n_r, FOV};
options_nl = optimoptions('fmincon', 'Display', 'none', 'Algorithm', 'sqp', 'MaxIterations', 400);
lb_nl = [-1, -1, -1, 1e-3];
ub_nl = [ 1,  1,  0, 10];

%% 3. Benchmark (serial for loop)
t_df_arr   = zeros(N_pos, M_BENCH);   % DF only (seconds)
t_3d_arr   = zeros(N_pos, M_BENCH);   % DF + range recovery (seconds)
iter_arr   = zeros(N_pos, M_BENCH);   % fmincon iteration count (diagnostic)

t_total = tic;
for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);

    % Clean DF powers (not timed)
    P_clean = zeros(1, N_or);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_clean(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
    end

    % Clean axial power using true direction as proxy (not timed)
    R_real   = [x; y; z];
    v_true   = ((R_real - T') / norm(R_real - T'))';
    param_tax = {T, v_true, P_t, m_t};
    param_rax = {A_det, -v_true, FOV};
    [~, P_ax_clean, ~, ~] = OWC_LOS_channel(x, y, z, param_tax, param_rax);

    % JIT warm-up (not timed)
    for w = 1:N_WARMUP
        P_w  = repmat(P_clean, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);
        p_means_w = mean(P_w, 1);
        max_p_w   = max(p_means_w); if max_p_w <= 0; max_p_w = 1e-12; end
        p_tgt_w   = p_means_w / max_p_w;
        [~, mx_w] = max(p_tgt_w);
        x0_w = [n_t(mx_w,1), n_t(mx_w,2), n_t(mx_w,3), 1.0];
        obj_w = @(v) nl_cost(v, p_tgt_w, n_t, m_t);
        nc_w  = @(v) sph_con(v);
        sol_w = fmincon(obj_w, x0_w, [], [], [], [], lb_nl, ub_nl, nc_w, options_nl);
        v_w   = sol_w(1:3) / norm(sol_w(1:3));
        mean_pax_w = P_ax_clean + sqrt(sigma2)*randn();
        d_w2  = sqrt(P_t*(m_t+1)*A_det / (2*pi*mean_pax_w));
        tmp   = T + v_w * d_w2; %#ok<NASGU>
    end

    % Timed calls
    t_df_pos  = zeros(1, M_BENCH);
    t_3d_pos  = zeros(1, M_BENCH);
    for mc = 1:M_BENCH
        % Pre-generate all random inputs (not timed)
        P_raw      = repmat(P_clean, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);
        P_ax_noisy = P_ax_clean + sqrt(sigma2) .* randn(1, N_samples);
        mean_P_ax  = mean(P_ax_noisy);

        % Timer 1: full NL-MLE DF pipeline (mean preprocessing included for fair comparison)
        t0 = tic;
        p_means = mean(P_raw, 1);
        max_p   = max(p_means); if max_p <= 0; max_p = 1e-12; end
        p_tgt   = p_means / max_p;
        [~, mx] = max(p_tgt);
        x0_nl   = [n_t(mx,1), n_t(mx,2), n_t(mx,3), 1.0];
        obj_fcn = @(v) nl_cost(v, p_tgt, n_t, m_t);
        nonlcon = @(v) sph_con(v);
        [sol, ~, ~, output_nl] = fmincon(obj_fcn, x0_nl, [], [], [], [], lb_nl, ub_nl, nonlcon, options_nl);
        v_est   = sol(1:3) / norm(sol(1:3));
        t_df_pos(mc) = toc(t0);
        iter_arr(i_pos, mc) = output_nl.iterations;

        % Timer 2: 3D extension (distance + position)
        t1 = tic;
        d_est  = sqrt(P_t*(m_t+1)*A_det / (2*pi*mean_P_ax));
        estPos = T + v_est * d_est; %#ok<NASGU>
        t_3d_pos(mc) = t_df_pos(mc) + toc(t1);
    end
    t_df_arr(i_pos, :) = t_df_pos;
    t_3d_arr(i_pos, :) = t_3d_pos;
    % iter_arr already filled above

    if mod(i_pos, 10) == 0 || i_pos == 1 || i_pos == N_pos
        fprintf('  --> position %d / %d\n', i_pos, N_pos);
    end
end
fprintf('Total elapsed: %.1f s\n\n', toc(t_total));

%% 4. Statistics
t_df_us  = t_df_arr(:)  * 1e6;
t_3d_us  = t_3d_arr(:)  * 1e6;

fprintf('\n========================================\n');
fprintf(' NL-MLE LATENCY BENCHMARK (K=%d) — SERIAL\n', N_or);
fprintf('========================================\n');
fprintf('--- Direction-Finding (DF) ---\n');
fprintf('Mean          : %.2f us\n', mean(t_df_us));
fprintf('Median        : %.2f us\n', median(t_df_us));
fprintf('Std           : %.2f us\n', std(t_df_us));
fprintf('p5 / p95      : %.2f / %.2f us\n', prctile(t_df_us,5), prctile(t_df_us,95));
fprintf('Mean [ms]     : %.4f ms\n', mean(t_df_us)/1000);
fprintf('--- 3D Pipeline (DF + range) ---\n');
fprintf('Mean          : %.2f us\n', mean(t_3d_us));
fprintf('Median        : %.2f us\n', median(t_3d_us));
fprintf('Std           : %.2f us\n', std(t_3d_us));
fprintf('p5 / p95      : %.2f / %.2f us\n', prctile(t_3d_us,5), prctile(t_3d_us,95));
fprintf('Mean [ms]     : %.4f ms\n', mean(t_3d_us)/1000);
fprintf('--- fmincon Iterations (diagnostic) ---\n');
fprintf('Mean iter     : %.1f\n', mean(iter_arr(:)));
fprintf('Median iter   : %.1f\n', median(iter_arr(:)));
fprintf('p5 / p95 iter : %.0f / %.0f\n', prctile(iter_arr(:),5), prctile(iter_arr(:),95));
fprintf('Max iter      : %d\n', max(iter_arr(:)));
fprintf('========================================\n');

%% 5. Save
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
save_path = fullfile(results_dir, sprintf('bench_NL_K%d_serial.mat', N_or));
save(save_path, 't_df_us', 't_3d_us', 'iter_arr', 'N_or', 'M_BENCH', 'N_pos', 'N_WARMUP');
fprintf('Saved: %s\n', save_path);

% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================
function F = nl_cost(vars, p_target, n_t, m_t)
    v   = vars(1:3)';
    eta = vars(4);
    F   = 0;
    for i = 1:size(n_t, 1)
        Q = max(0, dot(n_t(i,:), v));
        F = F + (eta * Q^m_t - p_target(i))^2;
    end
end

function [c, ceq] = sph_con(vars)
    c   = [];
    ceq = vars(1)^2 + vars(2)^2 + vars(3)^2 - 1;
end
