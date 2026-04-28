function DEB_value = DEB_objective(orientation_vector, system_params, receiver_positions)
% DEB_objective - Objective function for GA optimization of DEB
%
% Calculates the Direction Error Bound (DEB) for a given set of LED
% orientations across all receiver positions. Minimized by the GA.
%
% INPUTS:
%   orientation_vector : 1x(2K) vector [theta1, rho1, ..., thetaK, rhoK] in degrees
%   system_params      : struct with T, Pt, m, A_det, theta_half, Psi_FOV, sigma2, N, etc.
%   receiver_positions : 3xN matrix, each column is [x; y; z]
%
% OUTPUT:
%   DEB_value : scalar, aggregated DEB metric across testbed (to minimize)

%% Convert orientation vector to 3D unit vectors
K = length(orientation_vector) / 2;
nt_orientations = zeros(3, K);

for i = 1:K
    theta_rad = deg2rad(orientation_vector(2*i-1));
    rho_rad   = deg2rad(orientation_vector(2*i));
    nt_orientations(:, i) = [sin(theta_rad)*cos(rho_rad); 
                              sin(theta_rad)*sin(rho_rad); 
                              -cos(theta_rad)];
end

%% Check for degenerate configurations
MIN_ANGLE_SEPARATION = 5; % degrees
for i = 1:K-1
    for j = i+1:K
        dot_product = max(min(dot(nt_orientations(:,i), nt_orientations(:,j)), 1), -1);
        angle_deg = rad2deg(acos(abs(dot_product)));
        if angle_deg < MIN_ANGLE_SEPARATION
            DEB_value = 50 + (MIN_ANGLE_SEPARATION - angle_deg) * 5;
            return;
        end
    end
end

if K >= 3 && rank(nt_orientations) < 3
    DEB_value = 30;
    return;
elseif K == 2 && norm(cross(nt_orientations(:,1), nt_orientations(:,2))) < 1e-6
    DEB_value = 50;
    return;
end

%% Calculate DEB for each receiver position
N_positions = size(receiver_positions, 2);
DEB_values = zeros(1, N_positions);

warning('off', 'all');
for pos_idx = 1:N_positions
    R = receiver_positions(:, pos_idx);
    try
        DEB_values(pos_idx) = DEB_complete(R, nt_orientations, ...
            system_params.T, system_params.Pt, system_params.m, ...
            system_params.A_det, system_params.theta_half, ...
            system_params.Psi_FOV, system_params.sigma2, system_params.N);
        
        if ~isfinite(DEB_values(pos_idx))
            DEB_values(pos_idx) = 100;
        elseif DEB_values(pos_idx) > 50
            DEB_values(pos_idx) = 50;
        elseif DEB_values(pos_idx) < 0
            DEB_values(pos_idx) = 100;
        end
    catch
        DEB_values(pos_idx) = 100;
    end
end
warning('on', 'all');

%% Aggregate metric
switch system_params.optimization_metric
    case 'mean'
        DEB_value = mean(DEB_values);
    case 'max'
        DEB_value = max(DEB_values);
    case 'rms'
        DEB_value = sqrt(mean(DEB_values.^2));
    case 'percentile_90'
        DEB_value = prctile(DEB_values, 90);
    otherwise
        DEB_value = sqrt(mean(DEB_values.^2));
end

end
