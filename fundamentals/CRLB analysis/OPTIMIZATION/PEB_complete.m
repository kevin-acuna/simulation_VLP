function PEB = PEB_complete(R, nt_orientations, T, Pt, m, A_det, theta_half, Psi_FOV, sigma2, N)
% PEB_complete - Position Error Bound calculation for Single LED VLP system
%
% This function calculates the Cramér-Rao Lower Bound (CRLB) for position
% estimation in a Visible Light Positioning system with a single LED transmitter
% and photodiode receiver, following the theoretical framework described in
% the research paper.
%
% INPUTS:
%   R               : 3×1 vector, receiver position [x; y; z] (m)
%   nt_orientations : 3×K matrix, each column is a unit orientation vector n_t^(i)
%   T               : 3×1 vector, transmitter position [0; 0; H] (m)
%   Pt              : scalar, transmitted optical power (W)
%   m               : scalar, Lambertian order (calculated from LED half-power angle)
%   A_det           : scalar, effective area of photodiode (m²)
%   theta_half      : scalar, LED half-power angle (radians)
%   Psi_FOV         : scalar, receiver field of view (radians)
%   sigma2          : scalar, noise variance per sample (W²)
%   N               : scalar, number of samples per orientation
%
% OUTPUT:
%   PEB             : scalar, Position Error Bound (m RMS)
%
% THEORY:
% The system model considers K orientations for direction finding plus
% one distance recovery measurement. The Fisher Information Matrix (FIM)
% is calculated as the sum of contributions from all measurements.
%
% Author: Based on theoretical framework from VLP positioning research
% Date: 2025

%% Input validation
if size(R, 1) ~= 3 || size(R, 2) ~= 1
    error('R must be a 3×1 position vector');
end
if size(T, 1) ~= 3 || size(T, 2) ~= 1
    error('T must be a 3×1 position vector');
end
if size(nt_orientations, 1) ~= 3
    error('nt_orientations must be a 3×K matrix');
end

K = size(nt_orientations, 2); % Number of orientations

%% System parameters
% Receiver orientation (vertical upward)
nr = [0; 0; 1];

% Distance vector and its properties
d_vec = R - T;                    % Distance vector d = R - T
d = norm(d_vec);                  % Distance magnitude
nd = d_vec / d;                   % Unit direction vector

% Optical constant
C = (Pt * (m + 1) * A_det) / (2 * pi);

%% Initialize Fisher Information Matrix
I_fisher = zeros(3, 3);

%% Contribution from K orientations (direction finding)
for i = 1:K
    nt_i = nt_orientations(:, i);
    
    % Angle calculations
    cos_phi_i = (nt_i' * d_vec) / d;      % Irradiance angle cosine
    cos_psi = (nr' * (-d_vec)) / d;       % Incidence angle cosine
    
    % Check field of view constraint
    psi = acos(abs(cos_psi));
    if psi > Psi_FOV
        % Outside FOV, no contribution to FIM
        continue;
    end
    
    % Check if cos_phi_i is positive (LED pointing towards receiver)
    if cos_phi_i <= 0
        % LED not pointing towards receiver, no contribution
        continue;
    end
    
    % Calculate gradient of mu_i(R) according to equation in paper
    % ∇_R μ_i(R) = (C/d³)[m·cos^(m-1)(φ_i)·cos(ψ)·n_t^(i) - cos^m(φ_i)·n_r - (m+3)·cos^m(φ_i)·cos(ψ)·n_d]
    grad_mu_i = (C / d^3) * (...
        m * cos_phi_i^(m-1) * cos_psi * nt_i - ...
        cos_phi_i^m * nr - ...
        (m + 3) * cos_phi_i^m * cos_psi * nd);
    
    % Add contribution to Fisher Information Matrix
    I_fisher = I_fisher + (N / sigma2) * (grad_mu_i * grad_mu_i');
end

%% Contribution from distance recovery measurement
% Gradient of μ_{K+1}(R) = -2C/d³ · n_d
grad_mu_distance = -(2 * C / d^3) * nd;

% Add distance recovery contribution to FIM
I_fisher = I_fisher + (N / sigma2) * (grad_mu_distance * grad_mu_distance');

%% Calculate Position Error Bound
% PEB = sqrt(trace(I^(-1)))
if det(I_fisher) < eps
    warning('Fisher Information Matrix is singular or near-singular');
    PEB = Inf;
else
    PEB = sqrt(trace(inv(I_fisher)));
end

end


