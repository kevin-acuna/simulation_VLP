function rms_ang_deg = GLS_DF_objective(orientation_vector, system_params, receiver_positions)
% GLS_DF_OBJECTIVE  Objective function for GA optimization of LED orientations
%                   using the GLS direction-finding estimator.
%
% Simulates the GLS direction estimator over a testbed and returns the RMS
% angular error in degrees. Designed to be minimized by a genetic algorithm.
%
% INPUTS:
%   orientation_vector : 1×(2K) vector [theta1,rho1,...,thetaK,rhoK] in degrees
%   system_params      : struct with fields T, Pt, m, A_det, Psi_FOV, sigma2, N
%   receiver_positions : 3×N_pos matrix, each column is [x; y; z]
%
% OUTPUT:
%   rms_ang_deg : scalar, RMS angular error [degrees] across testbed (to minimize)

% Add core functions to path if not already available
if ~exist('OWC_LOS_channel', 'file') || ~exist('vlp_gls', 'file')
    addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'core'));
end

try
    K = length(orientation_vector) / 2;

    %% Convert orientation vector to 3D unit vectors (K×3)
    n_t = zeros(K, 3);
    for i = 1:K
        theta_rad = deg2rad(orientation_vector(2*i-1));
        rho_rad   = deg2rad(orientation_vector(2*i));
        n_t(i,:) = [sin(theta_rad)*cos(rho_rad), ...
                    sin(theta_rad)*sin(rho_rad), ...
                    -cos(theta_rad)];
    end

    %% Degeneracy check — penalize near-parallel orientations
    MIN_ANGLE_SEP = 5; % degrees
    for i = 1:K-1
        for j = i+1:K
            cos_ang   = max(-1, min(1, dot(n_t(i,:), n_t(j,:))));
            angle_deg = rad2deg(acos(abs(cos_ang)));
            if angle_deg < MIN_ANGLE_SEP
                rms_ang_deg = 50 + (MIN_ANGLE_SEP - angle_deg) * 5;
                return;
            end
        end
    end

    if K >= 3 && rank(n_t') < 3
        rms_ang_deg = 30;
        return;
    elseif K == 2 && norm(cross(n_t(1,:), n_t(2,:))) < 1e-6
        rms_ang_deg = 50;
        return;
    end

    %% Extract system parameters
    T_col   = system_params.T;              % 3×1 column vector (LED position)
    T_row   = T_col';                       % 1×3 row for OWC_LOS_channel
    P_t     = system_params.Pt;
    m_t     = system_params.m;
    A_det   = system_params.A_det;
    FOV     = rad2deg(system_params.Psi_FOV);
    sigma2  = system_params.sigma2;
    N_samp  = system_params.N;

    n_r     = [0, 0, 1];
    param_r = {A_det, n_r, FOV};

    N_pos      = size(receiver_positions, 2);
    ang_errors = zeros(N_pos, 1);  % per-position spatial RMSE [deg]

    % Number of Monte Carlo trials per position (default = 1 → single noise draw)
    if isfield(system_params, 'M_MC')
        M_MC = system_params.M_MC;
    else
        M_MC = 1;
    end

    %% Simulate channel + GLS estimator for each receiver position
    warning('off', 'all');
    for i_pos = 1:N_pos
        x = receiver_positions(1, i_pos);
        y = receiver_positions(2, i_pos);
        z = receiver_positions(3, i_pos);

        % Compute clean channel powers ONCE per position
        P_clean = zeros(1, K);
        for i_dir = 1:K
            param_t = {T_row, n_t(i_dir,:), P_t, m_t};
            [~, P_r_clean, ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
            P_clean(i_dir) = P_r_clean;
        end

        % True unit direction from LED to receiver
        R      = receiver_positions(:, i_pos);      % 3×1
        v_true = (R - T_col) / norm(R - T_col);    % 3×1

        % Monte Carlo trials: add independent noise each trial
        ang_mc = zeros(M_MC, 1);
        for mc = 1:M_MC
            P_raw = repmat(P_clean, N_samp, 1) + sqrt(sigma2) * randn(N_samp, K);

            % GLS direction estimator  (n_t' is 3×K)
            try
                d_hat = vlp_gls(n_t', P_raw, m_t, sigma2);  % 3×1, normalized
                d_hat = d_hat / norm(d_hat);
                ang_mc(mc) = acos(max(-1, min(1, v_true' * d_hat))) * (180/pi);
            catch
                ang_mc(mc) = 90;  % Maximum penalty for failed estimation
            end
        end

        % Per-position spatial RMSE across MC trials
        ang_errors(i_pos) = sqrt(mean(ang_mc.^2));
    end
    warning('on', 'all');

    %% Global RMS of per-position spatial RMSEs [degrees]
    rms_ang_deg = sqrt(mean(ang_errors.^2));

catch ME
    if isfield(system_params, 'debug_mode') && system_params.debug_mode
        warning('GLS_DF_objective error: %s', ME.message);
    end
    rms_ang_deg = 90;
end

end
