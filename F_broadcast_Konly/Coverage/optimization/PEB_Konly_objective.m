function PEB_value = PEB_Konly_objective(orientation_vector, system_params, receiver_positions)
% PEB_Konly_objective - Objective function for GA optimization of PEB_B
%
% Calculates the broadcast Position Error Bound (PEB_B) for a given set
% of LED orientations across all receiver positions. Minimized by the GA.
%
% INPUTS:
%   orientation_vector : 1x(2K) vector [theta1, rho1, ..., thetaK, rhoK] in degrees
%   system_params      : struct with T, Pt, m, A_det, Psi_FOV, sigma2, N, nr
%   receiver_positions : 3xN matrix, each column is [x; y; z]
%
% OUTPUT:
%   PEB_value : scalar objective to MINIMIZE. Lexicographic coverage+accuracy:
%       PEB_value = (1 - coverage) + acc_norm/(N+1)
%     where coverage = fraction of positions with PEB_B <= QoS, and
%     acc_norm = aggregate(PEB_B among covered)/QoS in [0,1] is a strict
%     tie-breaker (accuracy) that never overrides a coverage difference.
%     Unlocalizable points (PEB_B = Inf) simply count as "not covered": they
%     are penalised via the coverage term and never excluded from the
%     denominator, and NO arbitrary large PEB value is injected.
%
% NOTE: This is an INDEPENDENT copy for the Coverage optimization. Editing it
% here does NOT affect ../../optimization/PEB_Konly_objective.m.

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

%% QoS threshold for the coverage term (m)
if isfield(system_params, 'PEB_QoS')
    QoS = system_params.PEB_QoS;
else
    QoS = 0.05;   % default: same order as the coverage analysis QoS
end

%% Check for degenerate configurations (penalty >> normal max ~1)
MIN_ANGLE_SEPARATION = 5; % degrees
for i = 1:K-1
    for j = i+1:K
        dot_product = max(min(dot(nt_orientations(:,i), nt_orientations(:,j)), 1), -1);
        angle_deg = rad2deg(acos(abs(dot_product)));
        if angle_deg < MIN_ANGLE_SEPARATION
            PEB_value = 10 + (MIN_ANGLE_SEPARATION - angle_deg);
            return;
        end
    end
end

if K >= 3 && rank(nt_orientations) < 3
    PEB_value = 10;
    return;
elseif K == 2 && norm(cross(nt_orientations(:,1), nt_orientations(:,2))) < 1e-6
    PEB_value = 10;
    return;
end

%% Calculate PEB_B for each receiver position
% Inf / invalid PEB is kept as Inf (=> "not covered"); NO arbitrary cap.
N_positions = size(receiver_positions, 2);
PEB_values = inf(1, N_positions);

warning('off', 'all');
for pos_idx = 1:N_positions
    R = receiver_positions(:, pos_idx);
    try
        p = PEB_Konly(R, nt_orientations, ...
            system_params.T, system_params.Pt, system_params.m, ...
            system_params.A_det, system_params.Psi_FOV, ...
            system_params.sigma2, system_params.N, system_params.nr);
        if isfinite(p) && p > 0
            PEB_values(pos_idx) = p;   % else leave as Inf (not covered)
        end
    catch
        % leave as Inf (not covered)
    end
end
warning('on', 'all');

%% Lexicographic objective: coverage first, accuracy as tie-breaker
covered  = PEB_values <= QoS;          % Inf -> false (not covered)
coverage = mean(covered);

if isfield(system_params, 'optimization_metric')
    acc_metric = system_params.optimization_metric;
else
    acc_metric = 'mean';               % robust default if field is absent
end

if any(covered)
    pv = PEB_values(covered);          % all finite and <= QoS
    switch acc_metric
        case 'max'
            acc = max(pv);
        case 'rms'
            acc = sqrt(mean(pv.^2));
        case 'percentile_90'
            acc = prctile(pv, 90);
        otherwise                       % 'mean'
            acc = mean(pv);
    end
    acc_norm = min(acc / QoS, 1);      % in [0,1]
else
    acc_norm = 1;                       % nothing covered -> worst accuracy
end

% Coverage step is 1/N; accuracy weight 1/(N+1) < 1/N guarantees that any
% coverage gain strictly dominates the accuracy refinement (true lexicographic).
PEB_value = (1 - coverage) + acc_norm / (N_positions + 1);

end
