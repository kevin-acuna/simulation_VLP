%% Latency Benchmark — GLS: Direction-Finding + 3D Positioning
% Measures vlp_gls() in isolation for DF, then the full 3D pipeline.
% No other estimator is called in this script.
%
% Design:
%   - Full testbed grid (same as paper) to get a representative sample
%   - JIT warm-up before timing (10 calls, discarded)
%   - M_BENCH independent timed calls per position (fresh noise each time)
%   - parfor outer loop: each worker measures its own subset of positions
%   - Results: mean, median, std, p5, p95 of per-call latency in microseconds
%
% Author: Kevin Acuña

close all; clear variables; clc;
addpath('../../core');

% =================================================
% HYPERPARAMETERS
% =================================================
N_or    = 5;       % Number of orientations (match paper K)
M_BENCH = 100;    % Timed calls per position
N_WARMUP = 10;     % Warm-up calls (discarded, force JIT compilation)

%% 0. Parallel Pool
if isempty(gcp('nocreate'))
    pool = parpool('local');
else
    pool = gcp;
end
fprintf('bench_GLS_DF — using %d workers\n\n', pool.NumWorkers);

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

%% 2. Positions (full testbed grid)
[X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);
fprintf('Positions : %d\n', N_pos);
fprintf('Trials/pos: %d\n', M_BENCH);
fprintf('Total calls: %d\n\n', N_pos * M_BENCH);

param_r = {A_det, n_r, FOV};

%% 3. Benchmark (parallel over positions)
t_df_arr  = zeros(N_pos, M_BENCH);   % DF only (seconds)
t_3d_arr  = zeros(N_pos, M_BENCH);   % DF + range recovery (seconds)

D = parallel.pool.DataQueue;
afterEach(D, @(pos) fprintf('  --> position %d / %d\n', pos, N_pos));

parfor i_pos = 1:N_pos
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
        P_w = repmat(P_clean, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);
        [d_w] = vlp_gls(n_t', P_w, m_t, sigma2);
        v_w = d_w' / norm(d_w);
        mean_pax_w = P_ax_clean + sqrt(sigma2)*randn();
        d_w2 = sqrt(P_t*(m_t+1)*A_det / (2*pi*mean_pax_w));
        tmp = T + v_w * d_w2; %#ok<NASGU>
    end

    % Timed calls
    t_df_pos  = zeros(1, M_BENCH);
    t_3d_pos  = zeros(1, M_BENCH);
    for mc = 1:M_BENCH
        % Pre-generate all random inputs (not timed)
        P_raw      = repmat(P_clean, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);
        P_ax_noisy = P_ax_clean + sqrt(sigma2) .* randn(1, N_samples);
        mean_P_ax  = mean(P_ax_noisy);

        % Timer 1: DF only
        t0 = tic;
        [d_hat] = vlp_gls(n_t', P_raw, m_t, sigma2);
        v_est = d_hat' / norm(d_hat);
        t_df_pos(mc) = toc(t0);

        % Timer 2: 3D extension (distance + position)
        t1 = tic;
        d_est  = sqrt(P_t*(m_t+1)*A_det / (2*pi*mean_P_ax));
        estPos = T + v_est * d_est; %#ok<NASGU>
        t_3d_pos(mc) = t_df_pos(mc) + toc(t1);
    end
    t_df_arr(i_pos, :) = t_df_pos;
    t_3d_arr(i_pos, :) = t_3d_pos;

    if mod(i_pos, 10) == 0 || i_pos == 1 || i_pos == N_pos
        send(D, i_pos);
    end
end

%% 4. Statistics
t_df_us  = t_df_arr(:)  * 1e6;
t_3d_us  = t_3d_arr(:)  * 1e6;

fprintf('\n========================================\n');
fprintf(' GLS LATENCY BENCHMARK (K=%d)\n', N_or);
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
fprintf('========================================\n');

%% 5. Save
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
save_path = fullfile(results_dir, sprintf('bench_GLS_K%d.mat', N_or));
save(save_path, 't_df_us', 't_3d_us', 'N_or', 'M_BENCH', 'N_pos', 'N_WARMUP');
fprintf('Saved: %s\n', save_path);
