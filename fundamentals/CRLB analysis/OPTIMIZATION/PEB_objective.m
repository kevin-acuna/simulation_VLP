function PEB_value = PEB_objective(orientation_vector, system_params, receiver_positions)
% PEB_objective - Objective function for genetic algorithm optimization
%
% This function calculates the Position Error Bound (PEB) for a given set
% of LED orientations and receiver positions. It serves as the objective
% function to be minimized by the genetic algorithm.
%
% INPUTS:
%   orientation_vector : 1×(2K) vector [theta1, rho1, theta2, rho2, ..., thetaK, rhoK]
%                       where theta is elevation angle (0-90°) and rho is azimuth (0-360°)
%   system_params     : struct with system parameters (T, Pt, m, A_det, etc.)
%   receiver_positions: 3×N matrix, each column is a receiver position [x; y; z]
%
% OUTPUT:
%   PEB_value         : scalar, average PEB across all receiver positions (to minimize)

%% Convert orientation vector to 3D unit vectors
K = length(orientation_vector) / 2; % Number of orientations
nt_orientations = zeros(3, K);

for i = 1:K
    theta_deg = orientation_vector(2*i-1); % Elevation angle in degrees
    rho_deg = orientation_vector(2*i);     % Azimuth angle in degrees
    
    % Convert to radians
    theta_rad = deg2rad(theta_deg);
    rho_rad = deg2rad(rho_deg);
    
    % Convert spherical coordinates to Cartesian (LED pointing downward)
    % Standard spherical coordinates: theta from z-axis, rho from x-axis
    nt_orientations(:, i) = [
        sin(theta_rad) * cos(rho_rad);   % x component
        sin(theta_rad) * sin(rho_rad);   % y component
        -cos(theta_rad)                  % z component (negative for downward)
    ];
end

%% Calculate PEB for each receiver position
N_positions = size(receiver_positions, 2);
PEB_values = zeros(1, N_positions);

for pos_idx = 1:N_positions
    R = receiver_positions(:, pos_idx);
    
    try
        % Calculate PEB using the complete function
        PEB_values(pos_idx) = PEB_complete(R, nt_orientations, ...
            system_params.T, system_params.Pt, system_params.m, ...
            system_params.A_det, system_params.theta_half, ...
            system_params.Psi_FOV, system_params.sigma2, system_params.N);
        
        % Handle infinite or very large PEB values
        if ~isfinite(PEB_values(pos_idx)) || PEB_values(pos_idx) > 100
            PEB_values(pos_idx) = 100; % Penalty for poor configurations
        end
        
    catch ME
        % If PEB calculation fails, assign penalty
        warning('PEB calculation failed for position [%.2f, %.2f, %.2f]: %s', ...
            R(1), R(2), R(3), ME.message);
        PEB_values(pos_idx) = 100; % Large penalty
    end
end

%% Calculate objective function value
% Use different aggregation strategies
switch system_params.optimization_metric
    case 'mean'
        PEB_value = mean(PEB_values);
    case 'max'
        PEB_value = max(PEB_values);
    case 'rms'
        PEB_value = sqrt(mean(PEB_values.^2));
    case 'percentile_90'
        PEB_value = prctile(PEB_values, 90);
    otherwise
        PEB_value = mean(PEB_values); % Default to mean
end

%% Add penalty for extreme orientations (optional)
if system_params.penalize_extreme_angles
    penalty = 0;
    for i = 1:K
        theta_deg = orientation_vector(2*i-1);
        % Penalize very vertical orientations (theta < 5°) or very tilted (theta > 85°)
        if theta_deg < 5
            penalty = penalty + (5 - theta_deg)^2 * 0.01;
        elseif theta_deg > 85
            penalty = penalty + (theta_deg - 85)^2 * 0.01;
        end
    end
    PEB_value = PEB_value + penalty;
end

end
