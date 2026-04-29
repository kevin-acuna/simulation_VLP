% optimize_GLS_DF_orientations_parallel.m
% GA optimization to find LED orientation sets that minimize the GLS
% direction-finding RMS angular error over a 3D testbed.
%
% Uses a simulation-based objective (GLS_DF_objective) that runs the GLS
% estimator (vlp_gls) and computes the RMS angular error [degrees].
%
% Author: Kevin Acuña

clear; clc; close all;
rng('default');

% Add core functions (vlp_gls, OWC_LOS_channel, etc.)
addpath('../core');

% ======================== CONFIGURATION ========================
K_orientations      = [5,9];   % Number of LED orientations to optimize
max_elevation_angle = 80;    % Max elevation angle for LED orientations [deg]
results_dir = 'results/GLS_DF_optimization';

L = 3; W = 3; Hmax = 1.2; step = 0.3;  % Testbed geometry [m]

M_MC = 10;               % Monte Carlo trials per position (higher = more accurate but slower)

% GA parameters
pop_size        = 300;
max_generations = 150;
% ===============================================================

%% ======================== PARALLEL SETUP ========================
fprintf('Setting up parallel computing pool...\n');
if isempty(gcp('nocreate'))
    pool = parpool('local');
    fprintf('Parallel pool created with %d workers.\n', pool.NumWorkers);
else
    pool = gcp;
    fprintf('Using existing parallel pool with %d workers.\n', pool.NumWorkers);
end

%% ======================== SYSTEM PARAMETERS ========================
system_params.T          = [0; 0; 2];
system_params.Pt         = 0.405;
system_params.theta_half = deg2rad(45);
system_params.m          = -log(2)/log(cos(system_params.theta_half));
system_params.A_det      = (4.8e-3)*(5.5e-3);
system_params.Psi_FOV    = deg2rad(85);
system_params.sigma2     = (10^(-21.0))*(30e6);
system_params.N          = 1000;
system_params.M_MC       = M_MC;
system_params.debug_mode = false;

%% ======================== TESTBED ========================
x_range   = -L/2 : step : L/2;
y_range   = -W/2 : step : W/2;
z_heights =     0 : step : Hmax;

receiver_positions = [];
for z = z_heights
    for x = x_range
        for y = y_range
            receiver_positions = [receiver_positions, [x; y; z]];
        end
    end
end

fprintf('Testbed: %d receiver positions\n', size(receiver_positions, 2));
fprintf('Range: X∈[%.1f,%.1f], Y∈[%.1f,%.1f], Z∈[%.1f,%.1f]\n', ...
    min(receiver_positions(1,:)), max(receiver_positions(1,:)), ...
    min(receiver_positions(2,:)), max(receiver_positions(2,:)), ...
    min(receiver_positions(3,:)), max(receiver_positions(3,:)));

%% ======================== OPTIMIZATION LOOP ========================
for k_idx = 1:length(K_orientations)
    K = K_orientations(k_idx);

    current_datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');

    k_results_dir = fullfile(results_dir, sprintf('K_%d', K));
    if ~exist(k_results_dir, 'dir'), mkdir(k_results_dir); end

    % Start diary log
    log_filename = fullfile(k_results_dir, sprintf('optimization_log_%s.txt', current_datetime));
    diary(log_filename);

    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('GLS DF ORIENTATION OPTIMIZATION LOG\n');
    fprintf('%s\n', repmat('=', 1, 60));
    fprintf('Date: %s\n', datestr(now));
    fprintf('K = %d orientations\n', K);
    fprintf('Testbed: %d positions\n', size(receiver_positions, 2));
    fprintf('Room: %.0fx%.0f m, H_max=%.1f m, step=%.2f m\n', L, W, Hmax, step);
    fprintf('LED: Pt=%.3f W, Φ½=%.0f°, m=%.2f\n', ...
        system_params.Pt, rad2deg(system_params.theta_half), system_params.m);
    fprintf('PD: A=%.2e m², FOV=%.0f°\n', system_params.A_det, rad2deg(system_params.Psi_FOV));
    fprintf('Noise: σ²=%.2e W², N=%d samples, M_MC=%d trials/pos\n', system_params.sigma2, system_params.N, system_params.M_MC);
    fprintf('GA: pop=%d, gen=%d, parallel=%d workers\n', pop_size, max_generations, pool.NumWorkers);
    fprintf('%s\n\n', repmat('=', 1, 60));

    %% GA Setup
    nvars = 2 * K;
    lb = zeros(1, nvars);
    ub = zeros(1, nvars);
    for i = 1:nvars
        if mod(i, 2) == 1   % odd indices = theta (elevation)
            lb(i) = 0;  ub(i) = max_elevation_angle;
        else                % even indices = rho (azimuth)
            lb(i) = 0;  ub(i) = 360;
        end
    end

    options = optimoptions('ga', ...
        'PopulationSize',    pop_size, ...
        'MaxGenerations',    max_generations, ...
        'CrossoverFraction', 0.8, ...
        'MutationFcn',       @mutationadaptfeasible, ...
        'Display',           'iter', ...
        'PlotFcn',           {@gaplotbestf}, ...
        'OutputFcn',         @GLS_DF_monitor, ...
        'UseParallel',       true, ...
        'UseVectorized',     false);

    objective_func = @(x) GLS_DF_objective(x, system_params, receiver_positions);

    %% Run GA
    fprintf('Starting GA optimization for GLS DF (K=%d)...\n', K);
    t_start = tic;
    [xOpt, fvalOpt, exitflag, output] = ga(objective_func, nvars, ...
        [], [], [], [], lb, ub, [], options);
    optimization_time = toc(t_start);

    %% Results
    fprintf('\n%s\n', repmat('-', 1, 50));
    fprintf('GLS DF OPTIMIZATION RESULTS FOR K = %d\n', K);
    fprintf('%s\n', repmat('-', 1, 50));
    fprintf('Execution time: %.2f seconds (%.1f min)\n', optimization_time, optimization_time/60);
    fprintf('Best RMS angular error: %.4f°\n', fvalOpt);
    fprintf('Exit flag: %d\n', exitflag);

    fprintf('\nOptimal LED orientations (GLS DF-optimized):\n');
    for i = 1:K
        theta_deg = xOpt(2*i-1);
        rho_deg   = xOpt(2*i);
        nt = [sind(theta_deg)*cosd(rho_deg), sind(theta_deg)*sind(rho_deg), -cosd(theta_deg)];
        fprintf('  LED %d: θ = %6.2f°, ρ = %6.2f° → n_t = [%6.3f, %6.3f, %6.3f]\n', ...
            i, theta_deg, rho_deg, nt(1), nt(2), nt(3));
    end

    % Save results
    save(fullfile(k_results_dir, 'optimization_results.mat'), ...
        'xOpt', 'fvalOpt', 'exitflag', 'output', 'optimization_time', ...
        'K', 'system_params', 'receiver_positions');

    % Print copy-paste ready orientation vector
    fprintf('\nOrientation vector (copy-paste ready):\n');
    fprintf('orientations_GLS_DF_K%d = [', K);
    for i = 1:length(xOpt)
        if i < length(xOpt)
            fprintf('%.2f,', xOpt(i));
        else
            fprintf('%.2f', xOpt(i));
        end
    end
    fprintf('];\n');

    % Save figures
    fig_ev = findobj('Type', 'figure', 'Name', 'GLS DF Optimization - Angle Evolution');
    if ~isempty(fig_ev)
        saveas(fig_ev, fullfile(k_results_dir, 'angle_evolution.fig'));
    end
    fig_3d = findobj('Type', 'figure', 'Name', 'GLS DF Optimization - 3D Orientations');
    if ~isempty(fig_3d)
        saveas(fig_3d, fullfile(k_results_dir, 'orientations_3d.fig'));
    end
    fig_ga = findobj('Type', 'figure', 'Name', 'Genetic Algorithm');
    if ~isempty(fig_ga)
        saveas(fig_ga, fullfile(k_results_dir, 'ga_convergence.fig'));
    end

    fprintf('\nOptimization completed at: %s\n', datestr(now));
    diary off;

    close all;
    pause(1);
end

%% Cleanup
fprintf('\nAll optimizations complete.\n');
if ~isempty(gcp('nocreate'))
    delete(gcp('nocreate'));
    fprintf('Parallel pool closed.\n');
end
