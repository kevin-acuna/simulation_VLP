function PEB = PEB_Gaussian(R, nt_orientations, T, Pt, theta_div, A_det, Psi_FOV, sigma2, N, nr)
% PEB_Gaussian - Position Error Bound for Gaussian VCSEL beam-steered OWP
%
% Computes the CRLB for 3D position estimation using K steered-orientation
% measurements from a single Gaussian VCSEL source with known n_r.
%
% CHANNEL MODEL:
%   mu_i(r) = [C / (theta_div^2 * d^2)] * exp(-2*(phi_i/theta_div)^2) * cos(psi)
%
%   where C = Pt * A_det / (2*pi), phi_i = arccos(n_{t,i} . n_d)
%
% GRADIENT (derived in analysis_PEB_Gaussian.md):
%   nabla_r mu_i = (mu_i / d) * [alpha_i*(n_{t,i} - Q_i*n_d) - n_r/cos(psi) - 3*n_d]
%
%   where alpha_i = 4*phi_i / (theta_div^2 * sin(phi_i))
%         (limit: alpha_i -> 4/theta_div^2 when phi_i -> 0)
%
% INPUTS:
%   R               : 3x1 vector, receiver position [x; y; z] (m)
%   nt_orientations : 3xK matrix, each column is a unit orientation vector
%   T               : 3x1 vector, transmitter position [0; 0; H] (m)
%   Pt              : scalar, transmitted optical power (W)
%   theta_div       : scalar, VCSEL divergence half-angle (RADIANS)
%   A_det           : scalar, effective area of photodiode (m^2)
%   Psi_FOV         : scalar, receiver field of view (RADIANS)
%   sigma2          : scalar, noise variance per sample (W^2)
%   N               : scalar, number of samples per orientation
%   nr              : 3x1 vector, receiver orientation (unit vector)
%
% OUTPUT:
%   PEB : scalar, position error bound (m RMS). Inf if outage.

%% Input defaults
if nargin < 10
    nr = [0; 0; 1];
end

R = R(:); T = T(:); nr = nr(:);
K = size(nt_orientations, 2);

%% Geometry
d_vec = R - T;
d = norm(d_vec);
if d < 1e-10
    PEB = Inf; return;
end
nd = d_vec / d;

% Radiometric constant (no (m+1) factor for Gaussian)
C_opt = Pt * A_det / (2*pi);

% Incidence angle
cos_psi = -(nr' * nd);  % cos(psi) = -n_r . n_d
psi = acos(min(1, max(-1, cos_psi)));

% Check FOV
if psi > Psi_FOV || cos_psi <= 0
    PEB = Inf; return;
end

% Amplitude parameter: eta = C * cos(psi) / (theta_div^2 * d^2)
eta = C_opt * cos_psi / (theta_div^2 * d^2);

%% Fisher Information Matrix
I_fisher = zeros(3, 3);

% Threshold for significant signal (exp(-2*(phi/theta_div)^2) > thr)
R_threshold = exp(-8);  % ~3.35e-4, corresponds to phi = 2*theta_div

for i = 1:K
    nt_i = nt_orientations(:, i);
    
    % Direction cosine
    Q_i = nt_i' * nd;  % cos(phi_i)
    
    % Skip if geometrically behind
    if Q_i <= 0
        continue;
    end
    
    % Beam angular offset
    Q_i_clamped = min(1, max(-1, Q_i));
    phi_i = acos(Q_i_clamped);  % radians
    
    % Gaussian pattern value
    R_G_i = exp(-2*(phi_i/theta_div)^2);
    
    % Skip if negligible signal
    if R_G_i < R_threshold
        continue;
    end
    
    % Mean power at this orientation
    mu_i = eta * R_G_i;
    
    % Angular sensitivity coefficient alpha_i
    % alpha_i = 4*phi_i / (theta_div^2 * sin(phi_i))
    % Limit: when phi_i -> 0, alpha_i -> 4/theta_div^2
    if phi_i < 1e-8
        alpha_i = 4 / theta_div^2;
    else
        sin_phi_i = sin(phi_i);
        if sin_phi_i < 1e-12
            alpha_i = 4 / theta_div^2;
        else
            alpha_i = 4 * phi_i / (theta_div^2 * sin_phi_i);
        end
    end
    
    % Gradient: nabla_r mu_i = (mu_i/d) * [alpha_i*(n_{t,i} - Q_i*n_d) - n_r/cos_psi - 3*n_d]
    grad_mu_i = (mu_i / d) * (...
        alpha_i * (nt_i - Q_i * nd) ...
        - nr / cos_psi ...
        - 3 * nd);
    
    % Accumulate FIM
    I_fisher = I_fisher + (N / sigma2) * (grad_mu_i * grad_mu_i');
end

%% Calculate PEB
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

% Validate
if ~isreal(PEB) || ~isfinite(PEB) || PEB < 0
    PEB = Inf;
end

end
