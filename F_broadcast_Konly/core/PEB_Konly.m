function PEB = PEB_Konly(R, nt_orientations, T, Pt, m, A_det, Psi_FOV, sigma2, N, nr)
% PEB_Konly - Broadcast Position Error Bound (PEB_B)
%
% Computes the CRLB for 3D position estimation using ONLY the K steered-
% orientation measurements, without a cooperative beam-aligned measurement.
% This is the fundamental bound for the broadcast architecture.
%
% RELATION TO PEB_complete (cooperative PEB, PEB_C):
%   PEB_C uses: J_C = J_B + (N/sigma2) * grad_{K+1} * grad_{K+1}'
%   PEB_B uses: J_B = (N/sigma2) * sum_{i=1}^{K} grad_i * grad_i'
%   Since J_C = J_B + PSD, by Loewner ordering: PEB_C <= PEB_B (always).
%
% WHY THIS WORKS:
%   Each mu_i(r) depends on r through n_d(r), d(r), and cos_psi(r).
%   The gradient nabla_r mu_i captures sensitivity to all 3 components of r.
%   With K >= 3 non-coplanar orientations, J_B is rank 3 and 3D position
%   is identifiable from K measurements alone.
%
% NOTE: Unlike the DEB (n_r-independent), PEB_B depends on n_r because
%   absolute power information (not ratios) is needed for distance recovery.
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
%   PEB : scalar, broadcast position error bound PEB_B (m RMS)

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
% Check conditioning (scale-invariant)
% --- [SCALE-INVARIANT FIX] ------------------------------------------------
% Before, an ABSOLUTE determinant threshold was used (det_val < 1e-30). Since
% det(I) scales as (FIM magnitude)^3, that test was NOT invariant to the overall
% scaling of I_fisher (it could misfire for very small/large magnitudes). We now
% rely only on scale-invariant ratios: cond (and an rcond safeguard). A rank-
% deficient / ill-conditioned FIM -> Inf (position not identifiable).
% TO REVERT: uncomment the two (OLD) lines and delete the (NEW) block below.
% det_val = det(I_fisher);                                    % (OLD)
% if det_val < 1e-30 || cond_num > 1e14                       % (OLD)
cond_num = cond(I_fisher);                                     % (NEW)
if ~all(isfinite(I_fisher(:))) || cond_num > 1e14 || rcond(I_fisher) < 1e-14   % (NEW)
    PEB = Inf;
    return;
end
% --------------------------------------------------------------------------

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
