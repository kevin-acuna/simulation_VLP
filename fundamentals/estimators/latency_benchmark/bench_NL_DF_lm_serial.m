%% Latency Benchmark — NLS: fmincon/SQP vs lsqnonlin/LM (SERIAL)
% Benchmarks BOTH NLS solvers side-by-side for a fair latency comparison.
% Uses the core functions vlp_nls_fmincon.m and vlp_nls_lm.m.
%
% Design:
%   - Full testbed grid (same as paper)
%   - JIT warm-up before timing (10 calls per solver, discarded)
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
N_or     = 5;       % Number of orientations (match paper K)
M_BENCH  = 10;      % Timed calls per position
N_WARMUP = 10;      % Warm-up calls (discarded, force JIT compilation)

%% 1. System Parameters
system_params;
T = [0, 0, 2];

n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = orientations_DEB_K5(2*i-1);
    rho_i   = orientations_DEB_K5(2*i);
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
fprintf('Total calls: %d (per solver)\n\n', N_pos * M_BENCH);

param_r = {A_det, n_r, FOV};

%% 3. Benchmark (serial for loop)
t_fmincon_arr = zeros(N_pos, M_BENCH);
t_lm_arr      = zeros(N_pos, M_BENCH);

t_total = tic;
for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);

    % Clean DF powers (not timed)
    P_clean = zeros(1, N_or);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_clean(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
    end

    % JIT warm-up for BOTH solvers (not timed)
    for w = 1:N_WARMUP
        P_w = repmat(P_clean, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);
        vlp_nls_fmincon(n_t', P_w, m_t);
        vlp_nls_lm(n_t', P_w, m_t);
    end

    % Timed calls
    for mc = 1:M_BENCH
        % Pre-generate noise (not timed)
        P_raw = repmat(P_clean, N_samples, 1) + sqrt(sigma2) .* randn(N_samples, N_or);

        % A) fmincon/SQP
        t0 = tic;
        vlp_nls_fmincon(n_t', P_raw, m_t);
        t_fmincon_arr(i_pos, mc) = toc(t0);

        % B) lsqnonlin/LM
        t0 = tic;
        vlp_nls_lm(n_t', P_raw, m_t);
        t_lm_arr(i_pos, mc) = toc(t0);
    end

    if mod(i_pos, 10) == 0 || i_pos == 1 || i_pos == N_pos
        fprintf('  --> position %d / %d\n', i_pos, N_pos);
    end
end
fprintf('Total elapsed: %.1f s\n\n', toc(t_total));

%% 4. Statistics
t_fmincon_us = t_fmincon_arr(:) * 1e6;
t_lm_us      = t_lm_arr(:) * 1e6;

fprintf('\n================================================================\n');
fprintf(' NLS LATENCY COMPARISON (K=%d) — SERIAL\n', N_or);
fprintf('================================================================\n');
fprintf('%-30s %15s %15s\n', '', 'fmincon/SQP', 'lsqnonlin/LM');
fprintf('%-30s %15s %15s\n', '', '-----------', '------------');
fprintf('%-30s %12.2f us %12.2f us\n', 'Mean',    mean(t_fmincon_us),   mean(t_lm_us));
fprintf('%-30s %12.2f us %12.2f us\n', 'Median',  median(t_fmincon_us), median(t_lm_us));
fprintf('%-30s %12.2f us %12.2f us\n', 'Std',     std(t_fmincon_us),    std(t_lm_us));
fprintf('%-30s %12.2f us %12.2f us\n', 'p5',      prctile(t_fmincon_us,5),  prctile(t_lm_us,5));
fprintf('%-30s %12.2f us %12.2f us\n', 'p95',     prctile(t_fmincon_us,95), prctile(t_lm_us,95));
fprintf('%-30s %12.4f ms %12.4f ms\n', 'Mean [ms]', mean(t_fmincon_us)/1000, mean(t_lm_us)/1000);
fprintf('%-30s %12.4f ms %12.4f ms\n', 'Median [ms]', median(t_fmincon_us)/1000, median(t_lm_us)/1000);
fprintf('----------------------------------------------------------------\n');
fprintf('Speedup (fmincon/lm): %.2fx\n', mean(t_fmincon_us) / mean(t_lm_us));
fprintf('================================================================\n');

%% 5. Save
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
save_path = fullfile(results_dir, sprintf('bench_NL_comparison_K%d_serial.mat', N_or));
save(save_path, 't_fmincon_us', 't_lm_us', 'N_or', 'M_BENCH', 'N_pos', 'N_WARMUP');
fprintf('Saved: %s\n', save_path);
