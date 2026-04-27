%% PEB Analysis vs Noise Level
% This script analyzes how PEB changes with different noise levels (sigma2)
% for different sets of LED orientations (K=3,4,5).
%
% Author: Kevin Acuña
% Date: July 2025

clear; clc; close all;

% Create results directory with the same name as this file
script_name = 'analyze_PEB_vs_noise';
results_dir = fullfile(pwd, script_name);
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

%% ======================== CONFIGURATION ========================

SNR_dB = -30:5:30;
SNR_lin = 10.^(SNR_dB/10);

sigma2_base = (10^(-21.0))*(30e6)*2.466*10; %Para 10dB : 2.466
sigma2_values = sigma2_base*(1./SNR_lin);
% sigma2_values = sigma2_base:sigma2_base:10*sigma2_base; % Multiply by bandwidth (30e6)

% Define sets of orientations for different K values
% Format: [theta1, rho1, theta2, rho2, ...] where theta is elevation and rho is azimuth
orientations_K3=[35.40,140.13,33.31,36.38,29.58,262.70];
orientations_K4=[38.89,90.56,41.48,0.15,41.80,180.10,38.79,270.24];
orientations_K5=[50.55,89.96,50.66,179.99,50.37,359.93,0.10,211.14,50.59,269.96];
orientations_K6=[17.19,306.94,54.55,266.13,22.49,140.37,52.23,360.00,52.41,84.05,55.76,185.16];
orientations_K7=[58.91,355.65,53.77,170.74,27.75,43.75,5.36,305.88,54.35,96.46,35.10,220.04,54.78,278.61];
orientations_K8=[51.82,89.38,61.50,268.26,27.32,316.99,6.46,318.34,57.76,5.84,53.65,171.30,37.97,200.35,39.27,91.12];
orientations_K9=[56.92,178.69,36.54,266.83,33.86,182.29,2.51,28.15,42.20,78.36,53.07,97.46,57.91,359.73,37.07,355.08,58.23,272.07];
% orientations_K10=[56.00,3.61,53.20,182.48,54.93,356.82,11.94,38.06,61.28,270.34,50.17,91.30,47.56,174.73,43.39,89.36,32.54,277.55,15.14,255.31];

% Store all orientation sets in a cell array
all_orientations = {orientations_K3, orientations_K4, orientations_K5, orientations_K6, orientations_K7, orientations_K8, orientations_K9};
K_values = [3, 4, 5, 6, 7, 8, 9];

%% ======================== SYSTEM PARAMETERS ========================
% (Same as in optimize_PEB_orientations.m)

system_params = struct();
system_params.T = [0; 0; 2];                    % LED position at 2m height [m]
system_params.Pt = 0.405;                       % Transmitted optical power [W]
system_params.theta_half = deg2rad(45);         % LED half-power angle [rad]
system_params.m = -log(2)/log(cos(system_params.theta_half)); % Lambertian order
system_params.A_det = (4.8e-3)*(5.5e-3);        % Photodiode effective area [m²]
system_params.Psi_FOV = deg2rad(85);            % Receiver field of view [rad]
system_params.N = 1000;                         % Number of samples per orientation
system_params.optimization_metric = 'percentile_90';      
system_params.penalize_extreme_angles = false;  % No extreme angle penalties
system_params.debug_mode = false;               % No debug warnings

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

fprintf('\nCalculating PEB for different noise levels and orientations...\n');

% Initialize results matrix: rows=noise levels, columns=K values
peb_results = zeros(length(sigma2_values), length(K_values));

% Create a log file
% current_datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
% log_filename = fullfile(results_dir, sprintf('PEB_vs_noise_analysis_%s.txt', current_datetime));
% diary(log_filename);
% fprintf('Log file started: %s\n', log_filename);
% fprintf('Date and time: %s\n\n', datestr(now));

% Loop through each noise level
for i = 1:length(sigma2_values)
    sigma2 = sigma2_values(i);
    fprintf('Processing noise level %.2e W²...\n', sigma2);
    
    % Update system parameters with current sigma2
    system_params.sigma2 = sigma2;
    
    % Loop through each K value
    for j = 1:length(K_values)
        K = K_values(j);
        orientation_vector = all_orientations{j};
        
        tic;
        % Calculate PEB using the PEB_objective function
        peb = PEB_objective(orientation_vector, system_params, receiver_positions);
        calc_time = toc;
        
        % Store the result
        peb_results(i, j) = peb;
        
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

% Plot styles for different K values
markers = {'o-', 's-', 'd-'};

colors       = [0.0000 0.4470 0.7410 ;... 
                0.8500 0.3250 0.0980 ;...
                0.9290 0.6940 0.1250 ;...
                0.4940 0.1840 0.5560 ;...
                0.4660 0.6740 0.1880 ;...
                0.3010 0.7450 0.9330 ;...
                0.6350 0.0780 0.1840 ;...
                0.0000 0.4470 0.7410 ;...
                0.8500 0.3250 0.0980 ;...
                0.9290 0.6940 0.1250];

legend_entries = cell(1, length(K_values));

% Create a single plot for all K values
hold on;

% Loop through each K value to add to the single plot
for j = 1:length(K_values)
    K = K_values(j);
    
    % Plot PEB vs noise level for this K value (with linear axes)
    plot(SNR_dB, peb_results(:, j)*100, markers{min(j,length(markers))}, 'Color', colors(j,:), ...
        'LineWidth', 1, 'MarkerSize', 5);
    
    legend_entries{j} = sprintf('K=%d', K);
end
% set( gca, 'YScale', 'log' );

% Add labels, title, grid, and legend
xlabel('$\mathrm{SNR\,\,[dB]}$', 'FontSize', 14,'interpreter', 'latex');
ylabel('$\mathrm{PEB_{90\%}\,[cm]}$', 'FontSize', 14, 'interpreter', 'latex');
grid on;
legend(legend_entries, 'Location', 'best', 'FontSize', 12,'Interpreter','latex');

% Set specific X-axis limits to start from first sigma2 and end at last sigma2
xlim([SNR_dB(1), SNR_dB(end)]);
ylim([1e-1 1e3])

% Format the axes for better readability
ax = gca;
ax.FontSize = 14;
ax.GridLineStyle = ':';
ax.GridAlpha = 0.3;
ax.TickLabelInterpreter="latex";

set(gca, 'YScale', 'log')
box on
ax.LineWidth = 1;

hold off;

% Save the figure to the results directory
% saveas(fig, fullfile(results_dir, sprintf('PEB_vs_noise_analysis_%s.fig', current_datetime)));
% saveas(fig, fullfile(results_dir, sprintf('PEB_vs_noise_analysis_%s.png', current_datetime)));
%%

figure(1);
set(gcf, 'Color', 'white');
print(fullfile(results_dir, 'PEB_vs_SNR.png'), '-dpng', '-r300');
fprintf('Analysis complete. Figure saved in %s\n', results_dir);
