% optimize_PEB_orientations.m
% Genetic Algorithm optimization of LED orientations to minimize Position Error Bound (PEB)
% 
% This script optimizes the set of LED orientations for a Single LED VLP system
% using the theoretical CRLB framework to minimize positioning errors.
%
% Based on the theoretical work on Position Error Bound for VLP systems
% Author: Kevin Acuña
% Date: 2025

clear; clc; close all;

% ======================== PARALLEL SETUP ========================
% Setup parallel pool with 4 cores for acceleration
fprintf('Setting up parallel computing pool...\n');
if isempty(gcp('nocreate'))
    % Create parallel pool with 4 workers
    pool = parpool('local', 4);
    fprintf('Parallel pool created with %d workers.\n', pool.NumWorkers);
else
    pool = gcp;
    fprintf('Using existing parallel pool with %d workers.\n', pool.NumWorkers);
end

% Get current date/time for log filename
current_datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');

%% ======================== CONFIGURATION ========================

% Random seed for reproducibility
rng('default');

% Number of LED orientations to optimize
K_orientations = [5]; % Test different numbers of orientations

% Create results directory
results_dir = 'test_optimization_K5/PEB_optimization';
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

% Create and start log file
log_filename = fullfile(results_dir, sprintf('optimization_log_%s.txt', current_datetime));
diary(log_filename);
fprintf('Log file started: %s\n', log_filename);
fprintf('Date and time: %s\n\n', datestr(now));

%% ======================== SYSTEM PARAMETERS ========================

% LED transmitter parameters
system_params.T = [0; 0; 2];                    % LED position at 3m height [m]
system_params.Pt = 0.405;                       % Transmitted optical power [W]
system_params.theta_half = deg2rad(45);         % LED half-power angle [rad]
system_params.m = -log(2)/log(cos(system_params.theta_half)); % Lambertian order
system_params.A_det = (4.8e-3)*(5.5e-3);        % Photodiode effective area [m²]
system_params.Psi_FOV = deg2rad(85);            % Receiver field of view [rad]

% Noise and sampling parameters
system_params.sigma2 = (10^(-21.0))*(30e6);     % Noise variance per sample [W²]
system_params.N = 1000;                         % Number of samples per orientation

% Optimization parameters
system_params.optimization_metric = 'percentile_90';     % 'mean', 'max', 'rms', 'percentile_90'
system_params.penalize_extreme_angles = false;   % Penalize very vertical/horizontal orientations
system_params.debug_mode = false;               % Set to true to show detailed warnings

%% ======================== TEST SCENARIO ========================

% Define receiver positions for testing (3D testbed)
% Create a grid of positions at different heights

L = 2; W = 2; Hmax = 1.2;
step = 0.2; 

x_range = -L/2:step:L/2;
y_range = -W/2:step:W/2;
z_heights = 0:step:Hmax; % Different receiver heights

receiver_positions = [];
for z = z_heights
    for x = x_range
        for y = y_range
            % Skip positions too close to the LED (directly underneath)
            % if sqrt(x^2 + y^2) > 0.3
                receiver_positions = [receiver_positions, [x; y; z]];
            % end
        end
    end
end

fprintf('Testing with %d receiver positions\n', size(receiver_positions, 2));
fprintf('Position range: X ∈ [%.1f, %.1f], Y ∈ [%.1f, %.1f], Z ∈ [%.1f, %.1f]\n', ...
    min(receiver_positions(1,:)), max(receiver_positions(1,:)), ...
    min(receiver_positions(2,:)), max(receiver_positions(2,:)), ...
    min(receiver_positions(3,:)), max(receiver_positions(3,:)));

%% ======================== OPTIMIZATION LOOP ========================

optimization_results = struct();

for k_idx = 1:length(K_orientations)
    K = K_orientations(k_idx);
    
    fprintf('\n' + string(repmat('=', 1, 60)) + '\n');
    fprintf('OPTIMIZING FOR K = %d ORIENTATIONS\n', K);
    fprintf(string(repmat('=', 1, 60)) + '\n');
    
    % Create subdirectory for this K value
    k_results_dir = fullfile(results_dir, sprintf('K_%d', K));
    if ~exist(k_results_dir, 'dir')
        mkdir(k_results_dir);
    end
    
    %% GA Setup
    tic;
    
    % Number of decision variables (2 per orientation: theta and rho)
    nvars = 2 * K; % [theta1, rho1, theta2, rho2, ..., thetaK, rhoK]
    
    % Variable bounds
    lb = zeros(1, nvars);
    ub = zeros(1, nvars);
    
    for i = 1:nvars
        if mod(i, 2) == 1 % Odd indices are theta values (elevation)
            lb(i) = 0;   % Minimum elevation angle [degrees]
            ub(i) = 80;  % Maximum elevation angle [degrees]
        else % Even indices are rho values (azimuth)
            lb(i) = 0;   % Minimum azimuth angle [degrees]
            ub(i) = 360; % Maximum azimuth angle [degrees]
        end
    end
    
    % Linear constraints (none)
    A = []; b = [];
    Aeq = []; beq = [];
    nonlcon = [];
    
    % GA options
%     options = optimoptions('ga', ...
%         'PopulationSize', 200, ...
%         'MaxGenerations', 200, ...
%         'CrossoverFraction', 0.8, ...
%         'MutationFcn', @mutationadaptfeasible, ...
%         'Display', 'iter', ...
%         'PlotFcn', {@gaplotbestf}, ...
%         'OutputFcn', @PEB_monitor, ...
%         'UseParallel', false); % Set to true if Parallel Computing Toolbox available
    
    % Optimized GA options for parallel execution
    options = optimoptions('ga', ...
        'PopulationSize', 300, ...
        'MaxGenerations', 100, ...
        'CrossoverFraction', 0.8, ...
        'MutationFcn', @mutationadaptfeasible, ...
        'Display', 'iter', ...
        'PlotFcn', {@gaplotbestf}, ...
        'OutputFcn', @PEB_monitor, ...
        'UseParallel', true, ...             % ENABLED for 4-core acceleration
        'UseVectorized', false);             % Optimized for parallel objective function calls

    % Create objective function handle
    objective_func = @(x) PEB_objective(x, system_params, receiver_positions);
    
    %% Run optimization
    fprintf('Starting GA optimization with parallel processing...\n');
    fprintf('Population size: %d, Max generations: %d\n', ...
        options.PopulationSize, options.MaxGenerations);
    fprintf('Using %d parallel workers for acceleration\n', pool.NumWorkers);
    
    % Start timing
    parallel_start_time = tic;
    [xOpt, fvalOpt, exitflag, output] = ga(objective_func, nvars, ...
        A, b, Aeq, beq, lb, ub, nonlcon, options);
    
    optimization_time = toc(parallel_start_time);
    
    %% Process and save results
    fprintf('\n' + string(repmat('-', 1, 50)) + '\n');
    fprintf('OPTIMIZATION RESULTS FOR K = %d\n', K);
    fprintf(string(repmat('-', 1, 50)) + '\n');
    fprintf('Execution time: %.2f seconds\n', optimization_time);
    fprintf('Best PEB achieved: %.6f m\n', fvalOpt);
    fprintf('Exit flag: %d\n', exitflag);
    
    % Display optimal orientations
    fprintf('\nOptimal LED orientations:\n');
    optimal_orientations = zeros(3, K);
    for i = 1:K
        theta_deg = xOpt(2*i-1);
        rho_deg = xOpt(2*i);
        
        % Convert to 3D unit vector for verification
        theta_rad = deg2rad(theta_deg);
        rho_rad = deg2rad(rho_deg);
        optimal_orientations(:, i) = [
            sin(theta_rad) * cos(rho_rad);
            sin(theta_rad) * sin(rho_rad);
            -cos(theta_rad)
        ];
        
        fprintf('  LED %d: θ = %6.2f°, ρ = %6.2f° → n_t = [%6.3f, %6.3f, %6.3f]\n', ...
            i, theta_deg, rho_deg, optimal_orientations(1,i), optimal_orientations(2,i), optimal_orientations(3,i));
    end
    
    %% Save results
    result_data = struct();
    result_data.K = K;
    result_data.optimal_angles = xOpt;
    result_data.optimal_orientations_3D = optimal_orientations;
    result_data.best_PEB = fvalOpt;
    result_data.optimization_time = optimization_time;
    result_data.exitflag = exitflag;
    result_data.output = output;
    result_data.system_params = system_params;
    result_data.receiver_positions = receiver_positions;
    
    % Save to .mat file
    save(fullfile(k_results_dir, 'optimization_results.mat'), 'result_data');
    
    % Save figures
    fig_evolution = findobj('Type', 'figure', 'Name', 'PEB Optimization - Angle Evolution');
    if ~isempty(fig_evolution)
        figure(fig_evolution);
        saveas(fig_evolution, fullfile(k_results_dir, 'angle_evolution.fig'));
        saveas(fig_evolution, fullfile(k_results_dir, 'angle_evolution.png'));
    end
    
    fig_3d = findobj('Type', 'figure', 'Name', 'PEB Optimization - 3D Orientations');
    if ~isempty(fig_3d)
        figure(fig_3d);
        saveas(fig_3d, fullfile(k_results_dir, 'orientations_3d.fig'));
        saveas(fig_3d, fullfile(k_results_dir, 'orientations_3d.png'));
    end
    
    fig_ga = findobj('Type', 'figure', 'Name', 'Genetic Algorithm');
    if ~isempty(fig_ga)
        figure(fig_ga);
        saveas(fig_ga, fullfile(k_results_dir, 'ga_convergence.fig'));
        saveas(fig_ga, fullfile(k_results_dir, 'ga_convergence.png'));
    end
    
    % Store in overall results
    optimization_results.(sprintf('K_%d', K)) = result_data;
    
    % Clean up for next iteration
    %close all;
    pause(1); % Brief pause to ensure proper cleanup
end

% Close the log file
fprintf('\nOptimization completed at: %s\n', datestr(now));
fprintf('Log file saved to: %s\n', log_filename);
diary off;

% ======================== PARALLEL CLEANUP ========================
% Clean up parallel pool
fprintf('\nCleaning up parallel computing resources...\n');
if ~isempty(gcp('nocreate'))
    delete(gcp('nocreate'));
    fprintf('Parallel pool closed successfully.\n');
end

