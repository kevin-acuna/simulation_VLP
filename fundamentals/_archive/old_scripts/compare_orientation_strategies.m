function compare_orientation_strategies()
% compare_orientation_strategies - Compare different LED orientation strategies
%
% This function compares the PEB performance of different orientation strategies:
% 1. Optimized orientations (from GA)
% 2. Uniform angular distribution
% 3. Cardinal directions
% 4. Random orientations
%
% The comparison helps validate the optimization results and understand
% the impact of different orientation patterns on positioning accuracy.

clear; clc;

%% System parameters (same as optimization script)
system_params.T = [0; 0; 3];                    % LED position [m]
system_params.Pt = 1;                           % Transmitted power [W]
system_params.theta_half = deg2rad(60);         % Half-power angle [rad]
system_params.m = -log(2)/log(cos(system_params.theta_half)); % Lambertian order
system_params.A_det = 1e-4;                     % Photodiode area [m²]
system_params.Psi_FOV = deg2rad(90);            % Receiver FOV [rad]
system_params.sigma2 = 1e-12;                   % Noise variance [W²]
system_params.N = 100;                          % Samples per measurement

%% Test positions (subset for faster comparison)
x_range = -1.5:0.5:1.5;
y_range = -1.5:0.5:1.5;
z_heights = [0.8];

receiver_positions = [];
for z = z_heights
    for x = x_range
        for y = y_range
            if sqrt(x^2 + y^2) > 0.3 % Avoid positions too close to LED
                receiver_positions = [receiver_positions, [x; y; z]];
            end
        end
    end
end

fprintf('Comparing orientation strategies with %d test positions\n\n', size(receiver_positions, 2));

%% Test different numbers of orientations
K_values = [3, 4, 5];
strategies = {'optimized', 'uniform', 'cardinal', 'random'};
results_table = table();

for K = K_values
    fprintf('=== K = %d orientations ===\n', K);
    
    for s = 1:length(strategies)
        strategy = strategies{s};
        
        % Generate orientations based on strategy
        switch strategy
            case 'optimized'
                nt_set = load_optimized_orientations(K);
                if isempty(nt_set)
                    fprintf('  %s: No optimized data available\n', strategy);
                    continue;
                end
                
            case 'uniform'
                nt_set = generate_uniform_orientations(K);
                
            case 'cardinal'
                nt_set = generate_cardinal_orientations(K);
                
            case 'random'
                nt_set = generate_random_orientations(K);
        end
        
        % Calculate PEB for all test positions
        PEB_values = calculate_PEB_set(nt_set, receiver_positions, system_params);
        
        % Statistics
        mean_PEB = mean(PEB_values);
        std_PEB = std(PEB_values);
        max_PEB = max(PEB_values);
        p90_PEB = prctile(PEB_values, 90);
        
        fprintf('  %s: Mean=%.4f, Std=%.4f, Max=%.4f, P90=%.4f\n', ...
            strategy, mean_PEB, std_PEB, max_PEB, p90_PEB);
        
        % Store results
        new_row = table(K, {strategy}, mean_PEB, std_PEB, max_PEB, p90_PEB, ...
            'VariableNames', {'K', 'Strategy', 'Mean_PEB', 'Std_PEB', 'Max_PEB', 'P90_PEB'});
        results_table = [results_table; new_row];
    end
    fprintf('\n');
end

%% Create visualization
create_comparison_plots(results_table, K_values, strategies);

%% Save results
save('results/PEB_optimization/strategy_comparison.mat', 'results_table');
writetable(results_table, 'results/PEB_optimization/strategy_comparison.csv');

fprintf('Comparison complete. Results saved.\n');

end

%% Helper functions

function nt_set = load_optimized_orientations(K)
% Load optimized orientations from previous GA run
try
    filename = sprintf('results/PEB_optimization/K_%d/optimization_results.mat', K);
    if exist(filename, 'file')
        data = load(filename);
        
        % Convert angle representation to 3D unit vectors
        angles = data.result_data.optimal_angles;
        nt_set = zeros(3, K);
        
        for i = 1:K
            theta_deg = angles(2*i-1);
            rho_deg = angles(2*i);
            
            theta_rad = deg2rad(theta_deg);
            rho_rad = deg2rad(rho_deg);
            
            nt_set(:, i) = [
                sin(theta_rad) * cos(rho_rad);
                sin(theta_rad) * sin(rho_rad);
                -cos(theta_rad)
            ];
        end
    else
        nt_set = [];
    end
catch
    nt_set = [];
end
end

function nt_set = generate_uniform_orientations(K)
% Generate uniformly distributed orientations on lower hemisphere
nt_set = zeros(3, K);

for i = 1:K
    % Uniform azimuth distribution
    rho = 2 * pi * (i-1) / K;
    
    % Fixed elevation angle (45 degrees)
    theta = pi/4;
    
    nt_set(:, i) = [
        sin(theta) * cos(rho);
        sin(theta) * sin(rho);
        -cos(theta)
    ];
end
end

function nt_set = generate_cardinal_orientations(K)
% Generate orientations in cardinal directions with some tilt
nt_set = zeros(3, K);

% Cardinal directions: North, East, South, West, then diagonals
directions = [
    [0, 1];      % North
    [1, 0];      % East  
    [0, -1];     % South
    [-1, 0];     % West
    [1, 1]/sqrt(2);   % NE
    [1, -1]/sqrt(2);  % SE
    [-1, -1]/sqrt(2); % SW
    [-1, 1]/sqrt(2);  % NW
];

tilt_angle = pi/6; % 30 degree tilt

for i = 1:K
    if i <= size(directions, 1)
        dir = directions(i, :);
        nt_set(:, i) = [dir(1)*sin(tilt_angle); dir(2)*sin(tilt_angle); -cos(tilt_angle)];
    else
        % Additional orientations: vertical
        nt_set(:, i) = [0; 0; -1];
    end
end
end

function nt_set = generate_random_orientations(K)
% Generate random orientations on lower hemisphere
nt_set = zeros(3, K);

for i = 1:K
    % Random spherical coordinates
    theta = acos(rand()); % Uniform on hemisphere
    rho = 2 * pi * rand();
    
    nt_set(:, i) = [
        sin(theta) * cos(rho);
        sin(theta) * sin(rho);
        -cos(theta)
    ];
end
end

function PEB_values = calculate_PEB_set(nt_set, receiver_positions, system_params)
% Calculate PEB for a set of receiver positions
N_positions = size(receiver_positions, 2);
PEB_values = zeros(1, N_positions);

for i = 1:N_positions
    R = receiver_positions(:, i);
    
    try
        PEB_values(i) = PEB_complete(R, nt_set, system_params.T, ...
            system_params.Pt, system_params.m, system_params.A_det, ...
            system_params.theta_half, system_params.Psi_FOV, ...
            system_params.sigma2, system_params.N);
        
        if ~isfinite(PEB_values(i)) || PEB_values(i) > 10
            PEB_values(i) = 10; % Cap extreme values
        end
    catch
        PEB_values(i) = 10; % Penalty for failed calculations
    end
end
end

function create_comparison_plots(results_table, K_values, strategies)
% Create visualization of comparison results

% Create results directory if it doesn't exist
if ~exist('results/PEB_optimization', 'dir')
    mkdir('results/PEB_optimization');
end

% Plot 1: Mean PEB comparison
figure('Name', 'Strategy Comparison - Mean PEB', 'Position', [100 100 800 600]);

subplot(2, 2, 1);
for s = 1:length(strategies)
    strategy = strategies{s};
    strategy_data = results_table(strcmp(results_table.Strategy, strategy), :);
    if ~isempty(strategy_data)
        plot(strategy_data.K, strategy_data.Mean_PEB, 'o-', 'LineWidth', 2, ...
            'DisplayName', strategy, 'MarkerSize', 8);
        hold on;
    end
end
xlabel('Number of Orientations (K)');
ylabel('Mean PEB [m]');
title('Mean PEB Comparison');
legend('Location', 'best');
grid on;

subplot(2, 2, 2);
for s = 1:length(strategies)
    strategy = strategies{s};
    strategy_data = results_table(strcmp(results_table.Strategy, strategy), :);
    if ~isempty(strategy_data)
        plot(strategy_data.K, strategy_data.Max_PEB, 'o-', 'LineWidth', 2, ...
            'DisplayName', strategy, 'MarkerSize', 8);
        hold on;
    end
end
xlabel('Number of Orientations (K)');
ylabel('Max PEB [m]');
title('Maximum PEB Comparison');
legend('Location', 'best');
grid on;

subplot(2, 2, 3);
for s = 1:length(strategies)
    strategy = strategies{s};
    strategy_data = results_table(strcmp(results_table.Strategy, strategy), :);
    if ~isempty(strategy_data)
        plot(strategy_data.K, strategy_data.P90_PEB, 'o-', 'LineWidth', 2, ...
            'DisplayName', strategy, 'MarkerSize', 8);
        hold on;
    end
end
xlabel('Number of Orientations (K)');
ylabel('90th Percentile PEB [m]');
title('90th Percentile PEB Comparison');
legend('Location', 'best');
grid on;

subplot(2, 2, 4);
for s = 1:length(strategies)
    strategy = strategies{s};
    strategy_data = results_table(strcmp(results_table.Strategy, strategy), :);
    if ~isempty(strategy_data)
        plot(strategy_data.K, strategy_data.Std_PEB, 'o-', 'LineWidth', 2, ...
            'DisplayName', strategy, 'MarkerSize', 8);
        hold on;
    end
end
xlabel('Number of Orientations (K)');
ylabel('PEB Standard Deviation [m]');
title('PEB Variability Comparison');
legend('Location', 'best');
grid on;

sgtitle('LED Orientation Strategy Comparison');

% Save the figure
saveas(gcf, 'results/PEB_optimization/strategy_comparison.fig');
saveas(gcf, 'results/PEB_optimization/strategy_comparison.png');

end
