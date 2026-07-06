%% optimize_codebook_GA.m — GA design of localization-oriented VCSEL codebooks
%
% For each (theta_div, K), searches beam orientations that MINIMIZE the
% coverage-accuracy fitness (PEB_Gaussian_objective): effective P90 PEB with an
% outage penalty. Produces the "optimized" codebooks used by sim06 to beat the
% sunflower/rings/random/dense baselines (paper_plan §6, Fig. 6).
%
% Heavy compute: uses the Parallel Computing Toolbox if available. Reduce
% pop_size/max_generations or the (theta,K) lists for a quick run.
%
% Author: Kevin Acuna-Condori
% Project: VCSEL Gaussian OWP (target IEEE TWC)

clear; clc; close all;
rng('default');

%% Paths + base params
project_root = fileparts(pwd);
addpath(fullfile(project_root, 'core'));
addpath(fullfile(project_root, 'simulations'));
system_params_VCSEL;

% =========================== CONFIGURATION ===========================
theta_div_opt_deg = [10, 15, 20];      % divergences to optimize [deg]
K_opt             = [7, 9, 13, 19];    % codebook sizes (overhead) to optimize
metric            = 'mean';            % GA fitness aggregate. 'mean' gives gradient
                                       % even at low coverage; 'p90' saturates at the
                                       % penalty until coverage is high. (P90 is still
                                       % reported per codebook by sim06.)
PEB_penalty       = 2.0;               % outage clamp [m]
max_tilt_deg      = 70;                % beams may tilt up to this from nadir
step_opt          = 0.30;              % testbed grid for optimization [m] (coarser=faster)
pop_size          = 150;
max_generations   = 120;
results_dir       = fullfile(pwd, 'results');
% =====================================================================

if ~exist(results_dir, 'dir'), mkdir(results_dir); end

%% Parallel pool (optional)
use_parallel = false;
if ~isempty(ver('parallel'))
    try
        if isempty(gcp('nocreate')), parpool('local'); end
        use_parallel = true;
    catch
        use_parallel = false;
    end
end
fprintf('Parallel: %d\n', use_parallel);

%% System params struct for the objective
sp = struct('T', T, 'Pt', P_t, 'A_det', A_det, 'Psi_FOV', deg2rad(FOV), ...
    'sigma2', sigma2, 'N', N_samples, 'nr', n_r, ...
    'SNR_min_dB', SNR_min_dB, 'PEB_max_cov', PEB_max_cov, ...
    'PEB_penalty', PEB_penalty, 'metric', metric, 'min_sep_deg', 3);

%% Testbed
[X, Y, Z] = meshgrid(-L/2:step_opt:L/2, -W/2:step_opt:W/2, 0:step_opt:Hmax);
positions = [X(:), Y(:), Z(:)]';
fprintf('Testbed for optimization: %d positions\n', size(positions, 2));

%% Storage
nT = numel(theta_div_opt_deg); nK = numel(K_opt);
OPT = struct('theta_deg', {}, 'K', {}, 'nt', {}, 'fitness', {}, ...
    'coverage', {}, 'p90_peb', {}, 'mean_peb', {}, 'xOpt', {});

%% Optimization loop
for it = 1:nT
    theta_deg = theta_div_opt_deg(it);
    sp.theta_div = deg2rad(theta_deg);

    for ik = 1:nK
        K = K_opt(ik);
        nvars = 2*K;

        lb = zeros(1, nvars); ub = zeros(1, nvars);
        lb(1:2:end) = 0;   ub(1:2:end) = max_tilt_deg;   % theta
        lb(2:2:end) = 0;   ub(2:2:end) = 360;            % rho

        options = optimoptions('ga', ...
            'PopulationSize', pop_size, ...
            'MaxGenerations', max_generations, ...
            'CrossoverFraction', 0.8, ...
            'MutationFcn', @mutationadaptfeasible, ...
            'Display', 'iter', ...
            'UseParallel', use_parallel, ...
            'UseVectorized', false);

        obj = @(x) PEB_Gaussian_objective(x, sp, positions);

        fprintf('\n=== GA: theta_div=%d deg, K=%d (%d vars) ===\n', theta_deg, K, nvars);
        t0 = tic;
        [xOpt, fval] = ga(obj, nvars, [], [], [], [], lb, ub, [], options);
        fprintf('  done in %.1f s | fitness=%.2f cm\n', toc(t0), 100*fval);

        % Rebuild optimal codebook + full evaluation
        nt_opt = zeros(3, K);
        for i = 1:K
            t = deg2rad(xOpt(2*i-1)); r = deg2rad(xOpt(2*i));
            nt_opt(:, i) = [sin(t)*cos(r); sin(t)*sin(r); -cos(t)];
        end
        params = struct('T', T, 'Pt', P_t, 'A_det', A_det, 'Psi_FOV', deg2rad(FOV), ...
            'sigma2', sigma2, 'N', N_samples, 'nr', n_r, ...
            'SNR_min_dB', SNR_min_dB, 'PEB_max_cov', PEB_max_cov);
        res = evaluate_codebook(nt_opt, sp.theta_div, positions, params);

        e = numel(OPT) + 1;
        OPT(e).theta_deg = theta_deg;   OPT(e).K = K;
        OPT(e).nt = nt_opt;             OPT(e).fitness = fval;
        OPT(e).coverage = res.coverage; OPT(e).p90_peb = res.p90_peb;
        OPT(e).mean_peb = res.mean_peb; OPT(e).xOpt = xOpt;

        fprintf('  coverage=%.1f%%  P90 PEB=%.2f cm  mean PEB=%.2f cm\n', ...
            100*res.coverage, 100*res.p90_peb, 100*res.mean_peb);

        save(fullfile(results_dir, 'opt_codebooks.mat'), 'OPT', 'sp', 'metric', ...
            'theta_div_opt_deg', 'K_opt', 'max_tilt_deg', 'step_opt');
    end
end

fprintf('\nAll optimizations complete. Saved to %s\n', ...
    fullfile(results_dir, 'opt_codebooks.mat'));
