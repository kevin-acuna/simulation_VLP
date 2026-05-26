function PEB = PEB_Konly(R, nt_orientations, T, Pt, m, A_det, Psi_FOV, sigma2, N, nr)
% PEB_Konly - Position Error Bound for K-only architecture (no K+1 measurement)
%
% Computes the CRLB for 3D position estimation using ONLY the K direction-
% finding measurements (no cooperative distance recovery measurement).
% This is the bound for the broadcast architecture (Proposal F).
%
% KEY DIFFERENCE vs PEB_complete:
%   - PEB_complete: J = sum_{i=1}^{K} grad_i*grad_i' + grad_{K+1}*grad_{K+1}'
%   - PEB_Konly:    J = sum_{i=1}^{K} grad_i*grad_i'  (NO distance measurement)
%
% The K-only bound depends on n_r (unlike DEB which is n_r-independent).
% This is because absolute power information is needed for distance recovery,
% and the absolute power depends on cos(psi) = -n_r . n_d.
%
% INPUTS:
%   R               : 3x1 vector, receiver position [x; y; z] (m)
%   nt_orientations : 3xK matrix, each column is a unit orientation vector
%   T               : 3x1 vector, transmitter position [0; 0; H] (m)
%   Pt              : scalar, transmitted optical power (W)
%   m               : scalar, Lambertian order
%   A_det           : scalar, effective area of photodiode (m^2)
%   Psi_FOV         : scalar, receiver field of view (radians)
%   sigma2          : scalar, noise variance per sample (W^2)
%   N               : scalar, number of samples per orientation
%   nr              : 3x1 vector, receiver orientation (unit vector)
%
% OUTPUT:
%   PEB : scalar, K-only Position Error Bound (m RMS)

%% Input validation
if nargin < 10
    nr = [0; 0; 1]; % Default: vertical receiver
end

K = size(nt_orientations, 2);

%% System geometry
d_vec = R - T;
d = norm(d_vec);
nd = d_vec / d;

% Optical constant
C_opt = (Pt * (m + 1) * A_det) / (2 * pi);

% Incidence angle
cos_psi = (nr' * (-d_vec)) / d;

% Check if receiver is within FOV
psi = acos(min(1, max(-1, cos_psi)));
if psi > Psi_FOV || cos_psi <= 0
    PEB = Inf;
    return;
end

%% Fisher Information Matrix (K orientations ONLY)
I_fisher = zeros(3, 3);

for i = 1:K
    nt_i = nt_orientations(:, i);
    
    % Irradiance angle cosine
    cos_phi_i = (nt_i' * d_vec) / d;
    
    % Skip if LED not pointing towards receiver
    if cos_phi_i <= 0
        continue;
    end
    
    % Gradient of mu_i(r) w.r.t. r (Eq. 22 of TCOM RV2)
    % nabla_r mu_i = (C/d^3) [m*cos^{m-1}(phi_i)*cos(psi)*n_{t,i}
    %                          - cos^m(phi_i)*n_r
    %                          - (m+3)*cos^m(phi_i)*cos(psi)*n_d]
    grad_mu_i = (C_opt / d^3) * (...
        m * cos_phi_i^(m-1) * cos_psi * nt_i - ...
        cos_phi_i^m * nr - ...
        (m + 3) * cos_phi_i^m * cos_psi * nd);
    
    % Accumulate FIM
    I_fisher = I_fisher + (N / sigma2) * (grad_mu_i * grad_mu_i');
end

%% Calculate PEB
% Check conditioning
det_val = det(I_fisher);
cond_num = cond(I_fisher);

if det_val < 1e-30 || cond_num > 1e14
    PEB = Inf;
    return;
end

try
    PEB = sqrt(trace(inv(I_fisher)));
catch
    PEB = Inf;
end

% Validate result
if ~isreal(PEB) || ~isfinite(PEB) || PEB < 0
    PEB = Inf;
end

end
