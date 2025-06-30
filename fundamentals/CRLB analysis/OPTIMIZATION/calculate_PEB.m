function PEB = calculate_PEB(R, nt_set, system_params)
% calculate_PEB - Simplified PEB calculation following the paper's notation
%
% This function implements the Position Error Bound calculation exactly as
% described in the theoretical framework, with simplified parameter handling.
%
% INPUTS:
%   R            : 3×1 vector, receiver position [x; y; z] (m)
%   nt_set       : 3×K matrix, set of K orientation vectors for the LED
%   system_params: struct with fields:
%                  .T         - 3×1 transmitter position [0; 0; H] (m)
%                  .Pt        - transmitted power (W)
%                  .m         - Lambertian order
%                  .A_det     - photodiode effective area (m²)
%                  .Psi_FOV   - receiver field of view (rad)
%                  .sigma2    - noise variance per sample (W²)
%                  .N         - number of samples per orientation
%
% OUTPUT:
%   PEB          : Position Error Bound (m RMS)
%
% MATHEMATICAL MODEL:
% Following the paper's equations:
% - K orientations for direction finding: P_r^(i) ~ N(μ_i(R), σ²/N)
% - 1 distance recovery measurement: μ* ~ N(C/d²(R), σ²/N)
% - Fisher Information Matrix: I(R) = (N/σ²) Σ[∇μ_i][∇μ_i]ᵀ
% - PEB = sqrt(trace(I⁻¹(R)))

%% Extract system parameters
T = system_params.T;
Pt = system_params.Pt;
m = system_params.m;
A_det = system_params.A_det;
Psi_FOV = system_params.Psi_FOV;
sigma2 = system_params.sigma2;
N = system_params.N;

K = size(nt_set, 2); % Number of orientations

%% System geometry
% Distance vector and properties
d_vec = R - T;                    % d = R - T
d = norm(d_vec);                  % ||d||
nd = d_vec / d;                   % unit direction vector

% Receiver normal (vertical)
nr = [0; 0; 1];

% Optical constant from equation (6)
C = (Pt * (m + 1) * A_det) / (2 * pi);

%% Fisher Information Matrix calculation
I_FIM = zeros(3, 3);

% Contribution from K orientations (Section 3.3, equation after (12))
for i = 1:K
    nt_i = nt_set(:, i);
    
    % Cosine calculations from equation (4)
    cos_phi_i = (nt_i' * d_vec) / d;     % cos φ_i = n_t^(i) · d / ||d||
    cos_psi = (nr' * (-d_vec)) / d;      % cos ψ = n_r · (-d) / ||d||
    
    % Field of view check
    if acos(abs(cos_psi)) > Psi_FOV || cos_phi_i <= 0
        continue; % Outside FOV or LED not pointing towards receiver
    end
    
    % Gradient calculation from equation in Section 3.3
    % ∇_R μ_i(R) = (C/d³)[m·cos^(m-1)φ_i·cosψ·n_t^(i) - cos^m φ_i·n_r - (m+3)·cos^m φ_i·cosψ·n_d]
    grad_mu_i = (C / d^3) * (...
        m * cos_phi_i^(m-1) * cos_psi * nt_i - ...
        cos_phi_i^m * nr - ...
        (m + 3) * cos_phi_i^m * cos_psi * nd);
    
    % Add to FIM (equation 12)
    I_FIM = I_FIM + (N / sigma2) * (grad_mu_i * grad_mu_i');
end

% Contribution from distance recovery measurement
% ∇_R μ_{K+1}(R) = -2C/d³ · n_d
grad_distance = -(2 * C / d^3) * nd;
I_FIM = I_FIM + (N / sigma2) * (grad_distance * grad_distance');

%% Position Error Bound calculation (equation 13)
if det(I_FIM) < eps
    warning('Singular Fisher Information Matrix - infinite PEB');
    PEB = Inf;
else
    PEB = sqrt(trace(inv(I_FIM)));
end

end