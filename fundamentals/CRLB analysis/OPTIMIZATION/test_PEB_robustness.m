%% Test PEB Robustness - Verify fixes for singular matrix issues
% This script tests the improved PEB calculation with various problematic
% configurations to ensure robust handling of singular matrices.

clear; clc; close all;

fprintf('Testing PEB Robustness Improvements\n');
fprintf('==================================\n\n');

%% System Parameters (same as main optimization)
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
system_params.optimization_metric = 'rms';     % 'mean', 'max', 'rms', 'percentile_90'
system_params.penalize_extreme_angles = false;   % Penalize very vertical/horizontal orientations
system_params.debug_mode = true;               % Set to true to show detailed warnings

% Test receiver position
R_test = [0.5; 0.5; 1.0];

%% Test Case 1: Nearly identical orientations (should trigger penalty)
fprintf('Test 1: Nearly identical orientations\n');
fprintf('-------------------------------------\n');
orientation_vector_1 = [30, 0, 31, 5, 32, 10];  % Very similar theta values
try
    PEB_1 = PEB_objective(orientation_vector_1, system_params, R_test);
    fprintf('PEB with similar orientations: %.4f\n', PEB_1);
    if PEB_1 >= 50
        fprintf('✓ Penalty correctly applied for similar orientations\n');
    else
        fprintf('⚠ Warning: Expected penalty not applied\n');
    end
catch ME
    fprintf('✗ Error in Test 1: %s\n', ME.message);
end

%% Test Case 2: Coplanar orientations (should trigger penalty)
fprintf('\nTest 2: Coplanar orientations\n');
fprintf('-----------------------------\n');
% Create orientations that are truly coplanar (all in XY plane)
orientation_vector_2 = [90, 0, 90, 90, 90, 180];  % All horizontal (theta=90°)
try
    PEB_2 = PEB_objective(orientation_vector_2, system_params, R_test);
    fprintf('PEB with coplanar orientations: %.4f\n', PEB_2);
    if PEB_2 >= 30
        fprintf('✓ Penalty correctly applied for coplanar orientations\n');
    else
        fprintf('⚠ Warning: Expected penalty not applied\n');
    end
catch ME
    fprintf('✗ Error in Test 2: %s\n', ME.message);
end

%% Test Case 3: Good diverse orientations (should work normally)
fprintf('\nTest 3: Well-distributed orientations\n');
fprintf('------------------------------------\n');
% Use orientations that are well-separated in both elevation and azimuth
% and avoid coplanarity
orientation_vector_3 = [15, 0, 35, 120, 55, 240];  % Different elevations, spread azimuth
try
    PEB_3 = PEB_objective(orientation_vector_3, system_params, R_test);
    fprintf('PEB with good orientations: %.4f\n', PEB_3);
    
    % Check if it's a penalty value (30 or 50 indicate penalties)
    if PEB_3 == 30
        fprintf('⚠ Coplanarity penalty applied (orientations may still be too similar)\n');
    elseif PEB_3 == 50 || PEB_3 >= 85
        fprintf('⚠ High penalty applied (orientations problematic)\n');
    elseif PEB_3 < 10 && isfinite(PEB_3)
        fprintf('✓ Good orientations produce reasonable PEB\n');
    else
        fprintf('⚠ PEB value: %.4f (may indicate suboptimal but valid configuration)\n', PEB_3);
    end
catch ME
    fprintf('✗ Error in Test 3: %s\n', ME.message);
end

%% Test Case 4: Extreme orientations (should be handled)
fprintf('\nTest 4: Extreme orientations\n');
fprintf('---------------------------\n');
orientation_vector_4 = [1, 0, 89, 90, 2, 180];  % Very vertical and horizontal
try
    PEB_4 = PEB_objective(orientation_vector_4, system_params, R_test);
    fprintf('PEB with extreme orientations: %.4f\n', PEB_4);
    if isfinite(PEB_4)
        fprintf('✓ Extreme orientations handled without crashing\n');
    else
        fprintf('⚠ Warning: Infinite PEB for extreme orientations\n');
    end
catch ME
    fprintf('✗ Error in Test 4: %s\n', ME.message);
end

%% Test Case 5: Direct PEB_complete test with problematic configuration
fprintf('\nTest 5: Direct PEB_complete test\n');
fprintf('-------------------------------\n');
% Create orientations that might cause singular matrix (correct format: 3×K)
nt_problem = [
    0.1,  0.11, 0.12;     % x components
    0.1,  0.11, 0.12;     % y components  
    -0.99, -0.98, -0.97   % z components (nearly vertical)
];

try
    PEB_direct = PEB_complete(R_test, nt_problem, system_params.T, ...
        system_params.Pt, system_params.m, system_params.A_det, ...
        system_params.theta_half, system_params.Psi_FOV, ...
        system_params.sigma2, system_params.N);
    
    fprintf('Direct PEB calculation: %.4f\n', PEB_direct);
    if isfinite(PEB_direct)
        fprintf('✓ Singular matrix handled successfully\n');
    else
        fprintf('⚠ Infinite PEB returned (expected for bad configuration)\n');
    end
catch ME
    fprintf('✗ Error in direct PEB test: %s\n', ME.message);
end

%% Summary
fprintf('\n' + string(repmat('=', 1, 50)) + '\n');
fprintf('ROBUSTNESS TEST SUMMARY\n');
fprintf(string(repmat('=', 1, 50)) + '\n');
fprintf('The improved PEB calculation should now:\n');
fprintf('1. Detect and penalize similar orientations\n');
fprintf('2. Detect and penalize coplanar configurations\n');
fprintf('3. Handle singular matrices with regularization\n');
fprintf('4. Suppress excessive warnings during optimization\n');
fprintf('5. Return finite penalty values instead of crashing\n');
fprintf('\nIf all tests show ✓ or expected ⚠, the fixes are working correctly.\n');
