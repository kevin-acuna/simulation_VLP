% optimize_PEB_Konly_coverage.m
% GA optimization of LED orientation sets that minimize the broadcast
% Position Error Bound (PEB_B) using ONLY the K steered-orientation
% measurements (no cooperative measurement), via core/PEB_Konly.m.
%
% *** INDEPENDENT COPY for the Coverage folder ***
% Unlike ../../optimization/optimize_PEB_Konly_parallel.m (which HARDCODES the
% old 45-deg setup: Pt=0.405, Phi_half=45, big PD, FOV=85), this driver LOADS
% the REAL, experiment-aligned parameters from ../system_params_coverage.m
% (SFH4725S LED @ Phi_half=36.7, BPX61 PD, FOV=60, etc.). Editing files in
% this folder does NOT affect the original optimization folder.
%
% Author: Cascade (for Kevin Acuna-Condori) -- Project F, Broadcast OWP

clear; clc; close all;
rng('default');

%% ======================== PATHS ========================
this_dir     = fileparts(mfilename('fullpath'));   % .../Coverage/optimization
coverage_dir = fileparts(this_dir);                % .../Coverage
project_root = fileparts(coverage_dir);            % .../F_broadcast_Konly
addpath(fullfile(project_root, 'core'));           % PEB_Konly
addpath(coverage_dir);                             % system_params_coverage.m
addpath(this_dir);                                 % objective + monitor (this folder)

%% ======================== CONFIGURATION ========================
K_orientations = [5,9];
PEB_QoS             = 0.1;     % coverage QoS: PEB_B <= this counts as covered [m]
optimization_metric = 'rms';    % ACCURACY aggregator among covered points
                                % (tie-breaker): 'mean'|'max'|'rms'|'percentile_90'
max_elevation_angle = 80;       % LED tilt upper bound [deg]
FILTER_INFOV        = true;     % exclude receiver positions outside the PD FOV
                                % (they are unreachable regardless of LED tilt,
                                %  so they only add a constant penalty)
% Testbed grid (defaults to the room defined in system_params_coverage.m)
testbed_step = 0.1;             % X,Y,Z spacing [m]

% GA parameters
pop_size        = 400;
max_generations = 400;

results_dir = fullfile(this_dir, 'results', 'PEB_Konly_coverage');
% ===============================================================

%% ======================== SYSTEM PARAMETERS (REAL) ========================
% Single source of truth: pull everything from the coverage-only params file.
system_params_coverage;   % defines theta_half, P_t, m_t, A_det, FOV, sigma2,
                          % N_samples, T, L, W, Hmax, n_r, R_pd, ...

system_params.T          = T(:);
system_params.Pt         = P_t;
system_params.theta_half = deg2rad(theta_half);
system_params.m          = m_t;
system_params.A_det      = A_det;
system_params.Psi_FOV    = deg2rad(FOV);
system_params.sigma2     = sigma2;
system_params.N          = N_samples;
system_params.nr         = n_r(:);
system_params.debug_mode = false;
system_params.optimization_metric = optimization_metric;
system_params.PEB_QoS    = PEB_QoS;

%% ======================== PARALLEL SETUP ========================
fprintf('Setting up parallel computing pool...\n');
if isempty(gcp('nocreate'))
    pool = parpool('local');
    fprintf('Parallel pool created with %d workers.\n', pool.NumWorkers);
else
    pool = gcp;
    fprintf('Using existing parallel pool with %d workers.\n', pool.NumWorkers);
end

%% ======================== TESTBED ========================
x_range   = -L/2:testbed_step:L/2;
y_range   = -W/2:testbed_step:W/2;
z_heights = 0:testbed_step:Hmax;

[Xg, Yg, Zg] = ndgrid(x_range, y_range, z_heights);
receiver_positions = [Xg(:)'; Yg(:)'; Zg(:)'];

if FILTER_INFOV
    dz    = system_params.T(3) - receiver_positions(3, :);
    dd    = sqrt((receiver_positions(1,:) - system_params.T(1)).^2 + ...
                 (receiver_positions(2,:) - system_params.T(2)).^2 + dz.^2);
    cpsi  = dz ./ dd;                          % nr assumed ~ [0;0;1]
    inFOV = (cpsi > 0) & (acos(min(1, max(-1, cpsi))) <= system_params.Psi_FOV);
    n_before = size(receiver_positions, 2);
    receiver_positions = receiver_positions(:, inFOV);
    fprintf('FOV filter: kept %d / %d positions (%.1f%% in-FOV, FOV=%.0f deg)\n', ...
        size(receiver_positions,2), n_before, 100*mean(inFOV), FOV);
end

fprintf('Testbed: %d receiver positions\n', size(receiver_positions, 2));
fprintf('Range: X in [%.1f,%.1f], Y in [%.1f,%.1f], Z in [%.1f,%.1f]\n', ...
    min(receiver_positions(1,:)), max(receiver_positions(1,:)), ...
    min(receiver_positions(2,:)), max(receiver_positions(2,:)), ...
    min(receiver_positions(3,:)), max(receiver_positions(3,:)));

%% ======================== OPTIMIZATION LOOP ========================
for k_idx = 1:length(K_orientations)
    K = K_orientations(k_idx);

    current_datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');

    k_results_dir = fullfile(results_dir, sprintf('K_%d', K));
    if ~exist(k_results_dir, 'dir'), mkdir(k_results_dir); end

    log_filename = fullfile(k_results_dir, sprintf('optimization_log_%s.txt', current_datetime));
    diary(log_filename);

    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('PEB_B ORIENTATION OPTIMIZATION LOG (Coverage / REAL params)\n');
    fprintf('%s\n', repmat('=', 1, 60));
    fprintf('Date: %s\n', datestr(now));
    fprintf('Metric: %s\n', system_params.optimization_metric);
    fprintf('K = %d orientations\n', K);
    fprintf('Testbed: %d positions (FOV-filtered=%d)\n', size(receiver_positions, 2), FILTER_INFOV);
    fprintf('Room: %.0fx%.0fx%.1f m^3\n', L, W, system_params.T(3));
    fprintf('LED: Pt=%.3f W, Phi_half=%.1f deg, m=%.2f\n', system_params.Pt, rad2deg(system_params.theta_half), system_params.m);
    fprintf('PD: A=%.2e m^2, FOV=%.0f deg\n', system_params.A_det, rad2deg(system_params.Psi_FOV));
    fprintf('Noise: sigma2=%.2e W^2, N=%d samples\n', system_params.sigma2, system_params.N);
    fprintf('GA: pop=%d, gen=%d, parallel=%d workers\n', pop_size, max_generations, pool.NumWorkers);
    fprintf('%s\n\n', repmat('=', 1, 60));

    %% GA Setup
    nvars = 2 * K;
    lb = zeros(1, nvars);
    ub = zeros(1, nvars);
    for i = 1:nvars
        if mod(i, 2) == 1
            lb(i) = 0;   ub(i) = max_elevation_angle;
        else
            lb(i) = 0;   ub(i) = 360;
        end
    end

    options = optimoptions('ga', ...
        'PopulationSize', pop_size, ...
        'MaxGenerations', max_generations, ...
        'CrossoverFraction', 0.8, ...
        'MutationFcn', @mutationadaptfeasible, ...
        'Display', 'iter', ...
        'PlotFcn', {@gaplotbestf}, ...
        'OutputFcn', @PEB_Konly_monitor, ...
        'UseParallel', true, ...
        'UseVectorized', false);

    objective_func = @(x) PEB_Konly_objective(x, system_params, receiver_positions);

    %% Run optimization
    fprintf('Starting GA optimization for PEB_B (K=%d)...\n', K);
    t_start = tic;

    [xOpt, fvalOpt, exitflag, output] = ga(objective_func, nvars, ...
        [], [], [], [], lb, ub, [], options);

    optimization_time = toc(t_start);

    %% Process results
    fprintf('\n%s\n', repmat('-', 1, 50));
    fprintf('PEB_B OPTIMIZATION RESULTS FOR K = %d\n', K);
    fprintf('%s\n', repmat('-', 1, 50));
    fprintf('Execution time: %.2f seconds (%.1f min)\n', optimization_time, optimization_time/60);
    fprintf('Best objective (lexicographic cov+acc): %.6f\n', fvalOpt);
    fprintf('Exit flag: %d\n', exitflag);

    % Physically meaningful metrics for the optimal solution
    nt_opt = zeros(3, K);
    for i = 1:K
        nt_opt(:, i) = [sind(xOpt(2*i-1))*cosd(xOpt(2*i)); ...
                        sind(xOpt(2*i-1))*sind(xOpt(2*i)); ...
                        -cosd(xOpt(2*i-1))];
    end
    peb_opt = inf(1, size(receiver_positions, 2));
    for j = 1:size(receiver_positions, 2)
        peb_opt(j) = PEB_Konly(receiver_positions(:, j), nt_opt, ...
            system_params.T, system_params.Pt, system_params.m, ...
            system_params.A_det, system_params.Psi_FOV, ...
            system_params.sigma2, system_params.N, system_params.nr);
    end
    cov_opt = mean(peb_opt <= system_params.PEB_QoS);
    covd    = peb_opt(peb_opt <= system_params.PEB_QoS);
    if isempty(covd), covd = NaN; end
    rms_covd = sqrt(mean(covd.^2));    % RMS among covered = the OPTIMIZED accuracy metric
    fprintf('Coverage (PEB_B<=%.1f cm): %.1f%% | among covered: RMS=%.2f cm, median=%.2f cm, mean=%.2f cm, P90=%.2f cm\n', ...
        system_params.PEB_QoS*100, 100*cov_opt, ...
        rms_covd*100, median(covd)*100, mean(covd)*100, prctile(covd, 90)*100);

    fprintf('\nOptimal LED orientations (PEB_B-optimized):\n');
    for i = 1:K
        theta_deg = xOpt(2*i-1);
        rho_deg   = xOpt(2*i);
        nt = [sind(theta_deg)*cosd(rho_deg), sind(theta_deg)*sind(rho_deg), -cosd(theta_deg)];
        fprintf('  LED %d: theta = %6.2f deg, rho = %6.2f deg -> n_t = [%6.3f, %6.3f, %6.3f]\n', ...
            i, theta_deg, rho_deg, nt(1), nt(2), nt(3));
    end

    results_filename = fullfile(k_results_dir, sprintf('optimization_results_%s.mat', current_datetime));
    save(results_filename, ...
        'xOpt', 'fvalOpt', 'exitflag', 'output', 'optimization_time', ...
        'K', 'system_params', 'receiver_positions');

    % Copy-paste-ready line for system_params_coverage.m
    fprintf('\nOrientation vector (copy-paste ready):\n');
    fprintf('orientations_DEBreal_K%d = [', K);
    for i = 1:length(xOpt)
        if i < length(xOpt)
            fprintf('%.2f,', xOpt(i));
        else
            fprintf('%.2f', xOpt(i));
        end
    end
    fprintf('];\n');

    fprintf('\nOptimization completed at: %s\n', datestr(now));
    diary off;
end

%% Cleanup
fprintf('\nAll optimizations complete.\n');
