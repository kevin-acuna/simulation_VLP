%% Simple PEB Objective Test
% Test PEB_objective.m with one specific orientation set
% Based on system parameters from optimize_PEB_orientations.m

clear; clc;

fprintf('Simple PEB Objective Test\n');
fprintf('=========================\n\n');

%% System Parameters (same as optimize_PEB_orientations.m)
system_params.T = [0; 0; 2];                    % LED position at 2m height [m]
system_params.Pt = 0.405;                       % Transmitted optical power [W]
system_params.theta_half = deg2rad(45);         % LED half-power angle [rad]
system_params.m = -log(2)/log(cos(system_params.theta_half)); % Lambertian order
system_params.A_det = (4.8e-3)*(5.5e-3);        % Photodiode effective area [m²]
system_params.Psi_FOV = deg2rad(85);            % Receiver field of view [rad]
system_params.N = 1000;                         % Number of samples per orientation
system_params.optimization_metric = 'rms';      % RMS metric for PEB aggregation
system_params.penalize_extreme_angles = false;  % No extreme angle penalties
system_params.debug_mode = false;               % No debug warnings

%R_pd= 0.63;
R_pd = 1;
system_params.sigma2 = (10^(-20.0))*(30e6)/(R_pd^2)     % Noise variance per sample [W²]

%% Test Receiver Positions (same as optimize_PEB_orientations.m)
% Define receiver positions for testing (3D testbed)
x_range = -1.2:0.1:1.2;
y_range = -1.2:0.1:1.2;
z_heights = 0.0:0.1:1.2; % Different receiver heights

receiver_positions = [];
for z = z_heights
    for x = x_range
        for y = y_range
            receiver_positions = [receiver_positions, [x; y; z]];
        end
    end
end



%%
fprintf('System Configuration:\n');
fprintf('- LED position: [%.1f, %.1f, %.1f] m\n', system_params.T);
fprintf('- Number of test positions: %d\n', size(receiver_positions, 2));
fprintf('- Position range: X ∈ [%.1f, %.1f], Y ∈ [%.1f, %.1f], Z ∈ [%.1f, %.1f]\n', ...
    min(receiver_positions(1,:)), max(receiver_positions(1,:)), ...
    min(receiver_positions(2,:)), max(receiver_positions(2,:)), ...
    min(receiver_positions(3,:)), max(receiver_positions(3,:)));
fprintf('- Optimization metric: %s\n\n', system_params.optimization_metric);

%% CONFIGURE YOUR ORIENTATION SET HERE
% Define your orientation set [elevation1, azimuth1, elevation2, azimuth2, ...]
% Example with 5 orientations (K=5):
%orientation_set = [25, 30, 40, 120, 35, 210, 45, 300, 20, 60];
orientation_set = [0.0, 0.0, 45.0, 90.0, 45.0, 0.0, 45.0, 180.0, 45.0, 270.0]

% Display the configuration
K = length(orientation_set) / 2;
fprintf('Testing Orientation Set (K = %d):\n', K);
for j = 1:K
    theta = orientation_set(2*j-1);
    rho = orientation_set(2*j);
    fprintf('  LED %d: θ = %.1f°, ρ = %.1f°\n', j, theta, rho);
end
fprintf('\n');

%% Test the Objective Function
fprintf('Computing PEB...\n');
tic;
PEB_result = PEB_objective(orientation_set, system_params, receiver_positions);
computation_time = toc;

%% Display Results
fprintf('\n');
fprintf('RESULTS:\n');
fprintf('========\n');
fprintf('PEB Result (RMS): %.6f m\n', PEB_result);
fprintf('Computation Time: %.3f seconds\n', computation_time);

