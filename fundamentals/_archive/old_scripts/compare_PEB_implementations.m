%% Compare PEB Implementations
% This script compares the results between PEB_complete.m and previous_PEB.m
% to verify if both implementations give the same results.

clear; clc;

fprintf('Comparing PEB Implementations\n');
fprintf('============================\n\n');

%% Test Parameters
% System parameters (matching both implementations)
T = [0; 0; 2];                          % LED position at 2m height [m]
Pt = 0.405;                             % Transmitted optical power [W]
theta_half = deg2rad(45);               % LED half-power angle [rad]
m = -log(2)/log(cos(theta_half));       % Lambertian order
A_det = (4.8e-3)*(5.5e-3);              % Photodiode effective area [m²]
Psi_FOV = deg2rad(85);                  % Receiver field of view [rad]
sigma2 = (10^(-21.0))*(30e6);           % Noise variance per sample [W²]
N = 1000;                               % Number of samples per orientation
Nb = 1000;                              % Number of samples for beam-steered (previous_PEB)

% Optical constant K for previous_PEB
K_constant = Pt * (m + 1) * A_det / (2 * pi);

%% Test Cases
test_cases = {
    'Case 1: Close receiver', [0.2; 0.2; 1.0];
    'Case 2: Medium distance', [0.5; 0.5; 1.0];
    'Case 3: Far receiver', [1.0; 1.0; 0.5];
    'Case 4: Edge case', [1.5; 0.3; 0.8];
    'Case 5: High receiver', [0.3; 0.3; 1.8];
};

% Test orientations (3 orientations for K=4)
orientations_deg = [20, 0, 40, 120, 30, 240, 50, 80];  % theta, rho pairs
K = length(orientations_deg) / 2;

% Convert to 3D unit vectors
nt_orientations = zeros(3, K);
for i = 1:K
    theta = deg2rad(orientations_deg(2*i-1));
    rho = deg2rad(orientations_deg(2*i));
    
    nt_orientations(:,i) = [
        sin(theta) * cos(rho);
        sin(theta) * sin(rho);
        -cos(theta)
    ];
end

fprintf('Test orientations:\n');
for i = 1:K
    fprintf('  LED %d: θ=%.1f°, ρ=%.1f° → [%.3f, %.3f, %.3f]\n', ...
        i, orientations_deg(2*i-1), orientations_deg(2*i), nt_orientations(:,i));
end
fprintf('\n');

%% Run Comparisons
fprintf('%-25s %-15s %-15s %-15s %-10s\n', 'Test Case', 'PEB_complete', 'previous_PEB', 'Difference', 'Match?');
fprintf('%s\n', repmat('-', 1, 80));

results = [];

for i = 1:length(test_cases)
    case_name = test_cases{i, 1};
    R = test_cases{i, 2};
    
    try
        % Call PEB_complete (new implementation)
        PEB_new = PEB_complete(R, nt_orientations, T, Pt, m, A_det, ...
                              theta_half, Psi_FOV, sigma2, N);
        
        % Call previous_PEB (old implementation)
        % Note: previous_PEB uses different parameter order and includes beam-steering
        PEB_old = previous_PEB(R, nt_orientations, T, m, K_constant, ...
                              sigma2, N, Nb);
        
        % Calculate difference
        if isfinite(PEB_new) && isfinite(PEB_old)
            diff_abs = abs(PEB_new - PEB_old);
            diff_rel = diff_abs / min(PEB_new, PEB_old) * 100; % Relative difference in %
            
            % Check if they match (within 5% tolerance)
            match = diff_rel < 5.0;
            if match
                match_str = '✓';
            else
                match_str = '✗';
            end
            
            fprintf('%-25s %-15.6f %-15.6f %-15.6f %-10s\n', ...
                case_name, PEB_new, PEB_old, diff_abs, match_str);
            
            results = [results; PEB_new, PEB_old, diff_abs, diff_rel, match];
        else
            % Handle infinite or invalid results
            if isinf(PEB_new) && isinf(PEB_old)
                match_str = '✓ (both Inf)';
            else
                match_str = '✗ (one Inf)';
            end
            
            fprintf('%-25s %-15s %-15s %-15s %-10s\n', ...
                case_name, num2str(PEB_new), num2str(PEB_old), 'N/A', match_str);
        end
        
    catch ME
        fprintf('%-25s %-15s %-15s %-15s %-10s\n', ...
            case_name, 'ERROR', 'ERROR', ME.message(1:min(15,end)), '✗');
    end
end

%% Analysis Summary
fprintf('\n%s\n', repmat('=', 1, 80));
fprintf('COMPARISON SUMMARY\n');
fprintf('%s\n', repmat('=', 1, 80));

if ~isempty(results)
    finite_results = results(isfinite(results(:,1)) & isfinite(results(:,2)), :);
    
    if ~isempty(finite_results)
        fprintf('Valid comparisons: %d/%d\n', size(finite_results,1), length(test_cases));
        fprintf('Average PEB_complete: %.6f m\n', mean(finite_results(:,1)));
        fprintf('Average previous_PEB: %.6f m\n', mean(finite_results(:,2)));
        fprintf('Average absolute difference: %.6f m\n', mean(finite_results(:,3)));
        fprintf('Average relative difference: %.2f%%\n', mean(finite_results(:,4)));
        fprintf('Matches within 5%% tolerance: %d/%d\n', sum(finite_results(:,5)), size(finite_results,1));
        
        if all(finite_results(:,5))
            fprintf('\n✓ IMPLEMENTATIONS MATCH: Both functions produce similar results\n');
        else
            fprintf('\n⚠ IMPLEMENTATIONS DIFFER: Significant differences detected\n');
        end
    else
        fprintf('No valid finite results to compare\n');
    end
else
    fprintf('No results to analyze\n');
end

%% Key Differences Analysis
fprintf('\n%s\n', repmat('-', 1, 80));
fprintf('KEY DIFFERENCES BETWEEN IMPLEMENTATIONS:\n');
fprintf('%s\n', repmat('-', 1, 80));
fprintf('1. PEB_complete: Uses K orientations + 1 distance recovery\n');
fprintf('2. previous_PEB: Uses n orientations + 1 beam-steered orientation\n');
fprintf('3. Parameter differences:\n');
fprintf('   - PEB_complete: Individual parameters (Pt, A_det, etc.)\n');
fprintf('   - previous_PEB: Combined constant K = Pt*(m+1)*A_det/(2π)\n');
fprintf('4. Beam-steering:\n');
fprintf('   - PEB_complete: Distance recovery with fixed measurement\n');
fprintf('   - previous_PEB: Beam-steered orientation pointing toward receiver\n');
fprintf('\nIf results differ significantly, it may be due to:\n');
fprintf('- Different beam-steering vs distance recovery approaches\n');
fprintf('- Different handling of the additional measurement\n');
fprintf('- Numerical implementation differences\n');
