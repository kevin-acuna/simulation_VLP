%% Test Good Orientations - Find configurations that don't trigger penalties
% This script tests various orientation configurations to find ones that
% produce actual PEB calculations rather than penalties.

clear; clc;

fprintf('Testing Good Orientation Configurations\n');
fprintf('======================================\n\n');

%% System Parameters
system_params.T = [0; 0; 2];                    % LED position at 3m height [m]
system_params.Pt = 0.405;                       % Transmitted optical power [W]
system_params.theta_half = deg2rad(45);         % LED half-power angle [rad]
system_params.m = -log(2)/log(cos(system_params.theta_half)); % Lambertian order
system_params.A_det = (4.8e-3)*(5.5e-3);        % Photodiode effective area [m²]
system_params.Psi_FOV = deg2rad(85);            % Receiver field of view [rad]
system_params.sigma2 = (10^(-21.0))*(30e6);     % Noise variance per sample [W²]
system_params.N = 1000;                         % Number of samples per orientation
system_params.optimization_metric = 'rms';
system_params.penalize_extreme_angles = false;
system_params.debug_mode = false;               % Suppress warnings for cleaner output

% Test receiver position
R_test = [0.5; 0.5; 1.0];

%% Test different orientation configurations

configurations = {
    'Config 1: Moderate spread', [25, 0, 45, 90, 35, 180];
    'Config 2: Wide elevation spread', [10, 0, 30, 120, 60, 240];
    'Config 3: Symmetric distribution', [20, 60, 40, 180, 30, 300];
    'Config 4: Optimized-like', [18, 45, 42, 135, 28, 270];
    'Config 5: Conservative angles', [30, 0, 35, 120, 40, 240];
};

fprintf('Testing %d different configurations:\n\n', length(configurations));

for i = 1:length(configurations)
    config_name = configurations{i, 1};
    orientation_vector = configurations{i, 2};
    
    fprintf('%s\n', config_name);
    fprintf('%s\n', repmat('-', 1, length(config_name)));
    
    % Display the orientations
    K = length(orientation_vector) / 2;
    fprintf('Orientations (theta, rho):\n');
    for j = 1:K
        theta = orientation_vector(2*j-1);
        rho = orientation_vector(2*j);
        fprintf('  LED %d: θ=%.1f°, ρ=%.1f°\n', j, theta, rho);
    end
    
    try
        PEB_value = PEB_objective(orientation_vector, system_params, R_test);
        
        % Analyze the result
        if PEB_value == 30
            fprintf('Result: PEB = %.4f (COPLANARITY PENALTY)\n', PEB_value);
        elseif PEB_value >= 50
            fprintf('Result: PEB = %.4f (SIMILARITY/EXTREME PENALTY)\n', PEB_value);
        elseif PEB_value < 10
            fprintf('Result: PEB = %.4f ✓ GOOD CONFIGURATION\n', PEB_value);
        else
            fprintf('Result: PEB = %.4f (Valid calculation)\n', PEB_value);
        end
        
    catch ME
        fprintf('Result: ERROR - %s\n', ME.message);
    end
    
    fprintf('\n');
end

%% Summary
fprintf('%s\n', repmat('=', 1, 50));
fprintf('SUMMARY\n');
fprintf('%s\n', repmat('=', 1, 50));
fprintf('Look for configurations with PEB < 10 that are not penalty values.\n');
fprintf('These represent valid, well-distributed orientations.\n');
fprintf('Penalty values indicate:\n');
fprintf('  PEB = 30: Coplanarity detected\n');
fprintf('  PEB ≥ 50: Similarity or extreme angle penalties\n');
