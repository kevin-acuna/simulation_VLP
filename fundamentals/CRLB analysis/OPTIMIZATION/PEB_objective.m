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

%% Check for degenerate configurations
% 1. Check for nearly identical orientations
MIN_ANGLE_SEPARATION = 10; % degrees
for i = 1:K-1
    for j = i+1:K
        % Calculate angle between orientations
        dot_product = dot(nt_orientations(:,i), nt_orientations(:,j));
        angle_deg = rad2deg(acos(abs(dot_product)));
        
        if angle_deg < MIN_ANGLE_SEPARATION
            % Orientations too similar, add penalty
            PEB_value = 50 + (MIN_ANGLE_SEPARATION - angle_deg) * 5;
            return;
        end
    end
end

% 2. Check for coplanar orientations (all in same plane)
if K >= 3
    % Find two non-parallel vectors to define a plane
    v1 = nt_orientations(:,1);
    plane_found = false;
    normal = [];
    
    for j = 2:K
        v2 = nt_orientations(:,j);
        cross_prod = cross(v1, v2);
        
        if norm(cross_prod) > 1e-6  % Vectors not parallel
            normal = cross_prod / norm(cross_prod);
            plane_found = true;
            break;
        end
    end
    
    if plane_found
        % Check if all other orientations lie in the same plane
        coplanar_count = 2; % v1 and v2 are already in the plane
        
        for i = 1:K
            if i == 1 || i == j
                continue; % Skip the vectors used to define the plane
            end
            
            % Calculate distance from vector to plane
            % Distance = |dot(vector, normal)| where normal is unit vector
            distance_to_plane = abs(dot(nt_orientations(:,i), normal));
            
            if distance_to_plane < 0.2  % Threshold for coplanarity (more lenient)
                coplanar_count = coplanar_count + 1;
            end
        end
        
        % If most orientations are coplanar, apply penalty
        if coplanar_count >= K-1  % Allow one orientation to be out of plane
            % All or most orientations are coplanar, add penalty
            PEB_value = 30;
            return;
        end
    else
        % All vectors are parallel (very bad configuration)
        PEB_value = 50;
        return;
    end
end

%% Calculate PEB for each receiver position
N_positions = size(receiver_positions, 2);
PEB_values = zeros(1, N_positions);

% Suppress warnings during optimization to avoid cluttering output
warning_state = warning('query', 'all');
warning('off', 'all');

for pos_idx = 1:N_positions
    R = receiver_positions(:, pos_idx);
    
    try
        % Calculate PEB using the complete function
        PEB_values(pos_idx) = PEB_complete(R, nt_orientations, ...
            system_params.T, system_params.Pt, system_params.m, ...
            system_params.A_det, system_params.theta_half, ...
            system_params.Psi_FOV, system_params.sigma2, system_params.N);
        
        % Handle infinite or very large PEB values
        if ~isfinite(PEB_values(pos_idx))
            PEB_values(pos_idx) = 100; % Penalty for poor configurations
        elseif PEB_values(pos_idx) > 50  % Reduced threshold
            PEB_values(pos_idx) = 50;   % Cap very large values
        elseif PEB_values(pos_idx) < 0   % Should not happen, but safety check
            PEB_values(pos_idx) = 100;
        end
        
    catch ME
        % If PEB calculation fails, assign penalty
        % Only show warning in debug mode
        if system_params.debug_mode
            fprintf('PEB calculation failed for position [%.2f, %.2f, %.2f]: %s\n', ...
                R(1), R(2), R(3), ME.message);
        end
        PEB_values(pos_idx) = 100; % Large penalty
    end
end

% Restore warning state
warning(warning_state);

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
