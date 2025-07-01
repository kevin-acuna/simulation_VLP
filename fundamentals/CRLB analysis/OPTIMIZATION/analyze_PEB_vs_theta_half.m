%% PEB Analysis vs LED Half-Angle (theta_half)
% This script analyzes how PEB changes with different LED half-angles
% for different sets of LED orientations (K=3 to K=9).
%
% Author: Kevin Acuña
% Date: July 2025

clear; clc; close all;

% Create results directory with the same name as this file
script_name = 'analyze_PEB_vs_theta_half';
results_dir = fullfile(pwd, script_name);
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

%% ======================== CONFIGURATION ========================

% Fix the noise level (sigma2)
sigma2_base = (10^(-21.0))*(30e6);

% Define the theta_half values to test (in degrees)
theta_half_deg = [30, 45, 60];

% Define sets of orientations for different K values
% Format: [theta1, rho1, theta2, rho2, ...] where theta is elevation and rho is azimuth

% Configurations
orientations_K3 = [36.93, 56.20, 35.42, 176.85, 33.39, 296.52];
orientations_K4 = [36.87, 17.59, 41.59, 198.61, 42.40, 108.42, 39.37, 293.57];
orientations_K5 = [57.57, 87.79, 57.71, 358.55, 57.17, 177.68, 0.48, 294.81, 55.72, 268.14];
orientations_K6 = [53.23, 179.80, 58.97, 355.37, 48.42, 97.78, 49.58, 268.13, 19.80, 252.81, 25.95, 39.19];
orientations_K7 = [27.60, 355.20, 49.75, 182.12, 51.74, 280.40, 39.06, 251.04, 58.92, 352.88, 16.73, 71.81, 42.72, 104.45];
orientations_K8 = [32.76, 218.19, 28.47, 61.48, 51.87, 178.18, 35.72, 25.47, 51.63, 338.81, 57.74, 273.57, 49.66, 106.23, 18.14, 243.22];
orientations_K9 = [64.05, 261.27, 60.74, 358.44, 57.22, 187.22, 26.09, 251.86, 63.10, 175.67, 11.75, 76.79, 44.54, 119.76, 58.20, 85.09, 25.17, 304.81];

% Store all orientation sets in a cell array
all_orientations = {orientations_K3, orientations_K4, orientations_K5, orientations_K6, orientations_K7, orientations_K8, orientations_K9};
K_values = [3, 4, 5, 6, 7, 8, 9];

%% ======================== SYSTEM PARAMETERS ========================
% (Same as in optimize_PEB_orientations.m, except for theta_half which will vary)

system_params = struct();
system_params.T = [0; 0; 2];                    % LED position at 2m height [m]
system_params.Pt = 0.405;                       % Transmitted optical power [W]
% theta_half will be set in the loop
system_params.A_det = (4.8e-3)*(5.5e-3);        % Photodiode effective area [m²]
system_params.Psi_FOV = deg2rad(85);            % Receiver field of view [rad]
system_params.N = 1000;                         % Number of samples per orientation
system_params.optimization_metric = 'percentile_90';
system_params.penalize_extreme_angles = false;  % No extreme angle penalties
system_params.debug_mode = false;               % No debug warnings
system_params.sigma2 = sigma2_base;             % Fixed noise value

%% ======================== TEST ENVIRONMENT ========================

L = 3; W = 3; Hmax = 1.2; step = 0.2;
x_range = -L/2:step:L/2;
y_range = -W/2:step:W/2;
z_heights = 0:step:Hmax; % Different receiver heights

receiver_positions = [];
for z = z_heights
    for x = x_range
        for y = y_range
            receiver_positions = [receiver_positions, [x; y; z]];
        end
    end
end

fprintf('Testing with %d receiver positions\n', size(receiver_positions, 2));
fprintf('Position range: X ∈ [%.1f, %.1f], Y ∈ [%.1f, %.1f], Z ∈ [%.1f, %.1f]\n', ...
    min(receiver_positions(1,:)), max(receiver_positions(1,:)), ...
    min(receiver_positions(2,:)), max(receiver_positions(2,:)), ...
    min(receiver_positions(3,:)), max(receiver_positions(3,:)));

%% ======================== PEB CALCULATION ========================

fprintf('\nCalculating PEB for different theta_half values and orientations...\n');

% Initialize results matrix: rows=K values, columns=theta_half values
peb_results = zeros(length(K_values), length(theta_half_deg));

% Create a log file
current_datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
log_filename = fullfile(results_dir, sprintf('PEB_vs_theta_half_%s.txt', current_datetime));
diary(log_filename);
fprintf('Log file started: %s\n', log_filename);
fprintf('Date and time: %s\n\n', datestr(now));

% Loop through each theta_half value
for i = 1:length(theta_half_deg)
    theta_half = theta_half_deg(i);
    fprintf('Processing theta_half = %d°...\n', theta_half);
    
    % Update system parameters with current theta_half
    system_params.theta_half = deg2rad(theta_half);
    system_params.m = -log(2)/log(cos(system_params.theta_half)); % Update Lambertian order
    
    % Loop through each K value
    for j = 1:length(K_values)
        K = K_values(j);
        orientation_vector = all_orientations{j};
        
        tic;
        % Calculate PEB using the PEB_objective function
        peb = PEB_objective(orientation_vector, system_params, receiver_positions);
        calc_time = toc;
        
        % Store the result
        peb_results(j, i) = peb;
        
        fprintf('  K=%d: PEB = %.6f m (calculated in %.2f seconds)\n', K, peb, calc_time);
    end
    fprintf('\n');
end

% Close the log file
fprintf('Analysis completed at: %s\n', datestr(now));
fprintf('Log file saved in: %s\n', results_dir);
diary off;

%% ======================== PLOTTING ========================
close all

% Create the figure
fig = figure('Position', [100, 100, 800, 600]);

% Plot styles for different theta_half values
markers = {'o-', 's-', 'd-'};
colors = [
    0.0000, 0.4470, 0.7410; % Blue
    0.8500, 0.3250, 0.0980; % Orange/Red
    0.4660, 0.6740, 0.1880  % Green
];

legend_entries = cell(1, length(theta_half_deg));

% Create a single plot for all theta_half values
hold on;

% Loop through each theta_half value
for i = 1:length(theta_half_deg)
    theta_half = theta_half_deg(i);
    
    % Plot PEB vs K for this theta_half value
    plot(K_values, peb_results(:, i)*100, markers{min(i,length(markers))}, 'Color', colors(i,:), ...
        'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'w');
    
    % Create legend entry
    legend_entries{i} = sprintf('\\theta_{1/2} = %d°', theta_half);
end

% Add labels, title, grid, and legend
xlabel('Number of Orientations (K)', 'FontSize', 12,'interpreter', 'latex');
ylabel('Overal PEB error $\mathrm{PEB_{90\%}}$(cm)', 'FontSize', 12,'interpreter', 'latex');
grid on;
legend(legend_entries, 'Location', 'northeast', 'FontSize', 11);
axis([3,9,0,10])

% Format the axes for better readability
ax = gca;
ax.FontSize = 11;
ax.TickLabelInterpreter="latex"
ax.GridLineStyle = ':';
ax.GridAlpha = 0.3;

hold off;

% Save the figure to the results directory
saveas(fig, fullfile(results_dir, sprintf('PEB_vs_theta_half_%s.fig', current_datetime)));
saveas(fig, fullfile(results_dir, sprintf('PEB_vs_theta_half_%s.png', current_datetime)));

fprintf('Analysis complete. Figure saved in %s\n', results_dir);
