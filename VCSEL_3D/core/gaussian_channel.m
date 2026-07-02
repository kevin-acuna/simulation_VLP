function [mu, d, nd, cos_psi, phi] = gaussian_channel(R, nt_i, T, Pt, theta_div, A_det, Psi_FOV, nr)
% gaussian_channel - Noiseless received power for a single Gaussian VCSEL orientation
%
% Far-field fixed-emitted-power Gaussian beam model:
%   mu = [2*Pt*A_det/pi] * 1/(theta_div^2 * d^2) * exp(-2*(phi/theta_div)^2) * cos(psi)
%      = C/(theta_div^2 * d^2) * exp(-2*(phi/theta_div)^2) * cos(psi)
%
% with C = 2*Pt*A_det/pi (peak on-axis irradiance I0 = 2*Pt/(pi*w^2), w = d*theta_div).
% Ref.: Safi et al., "Q-Learning for 3D Coverage in VCSEL-based OWC", Eq. (8).
%
% INPUTS:
%   R         : 3x1 receiver position [x; y; z] (m)
%   nt_i      : 3x1 unit VCSEL orientation vector for this slot
%   T         : 3x1 transmitter position (m)
%   Pt        : transmitted optical power (W)
%   theta_div : VCSEL divergence half-angle (RADIANS)
%   A_det     : photodiode effective area (m^2)
%   Psi_FOV   : receiver field of view (RADIANS)
%   nr        : 3x1 receiver orientation (unit vector). Default [0;0;1].
%
% OUTPUTS:
%   mu      : received optical power (W). 0 if outside FOV or beam behind receiver.
%   d       : TX-RX distance (m)
%   nd      : 3x1 unit TX->RX direction
%   cos_psi : incidence cosine at receiver
%   phi     : beam angular offset (rad)

if nargin < 8 || isempty(nr)
    nr = [0; 0; 1];
end
R = R(:); nt_i = nt_i(:); T = T(:); nr = nr(:);

d_vec = R - T;
d = norm(d_vec);
if d < 1e-10
    mu = 0; nd = [0;0;-1]; cos_psi = 0; phi = 0; return;
end
nd = d_vec / d;

% Incidence at the receiver
cos_psi = -(nr' * nd);
psi = acos(min(1, max(-1, cos_psi)));

% Beam angular offset
Q_i = nt_i' * nd;                     % cos(phi)
phi = acos(min(1, max(-1, Q_i)));

% Gates: within FOV and beam pointing towards the receiver hemisphere
if cos_psi <= 0 || psi > Psi_FOV || Q_i <= 0
    mu = 0;
    return;
end

C_opt = 2 * Pt * A_det / pi;
R_G = exp(-2 * (phi / theta_div)^2);
mu = C_opt / (theta_div^2 * d^2) * R_G * cos_psi;
end
