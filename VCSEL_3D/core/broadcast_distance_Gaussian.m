function [d_hat, eta_hat] = broadcast_distance_Gaussian(nd_hat, nt, mu_hat, theta_div, C_opt, nr)
% BROADCAST_DISTANCE_GAUSSIAN  Distance recovery for the Gaussian VCSEL broadcast pipeline
%
% Given the estimated direction n_d and the K measured (averaged) powers, recover
% the TX-RX distance assuming the receiver orientation n_r is known (IMU).
%
% Observation model:  mu_i = eta * R_G(phi_i),   R_G(phi) = exp(-2*(phi/theta_div)^2)
% with amplitude       eta  = C_opt * cos(psi) / (theta_div^2 * d^2),  cos(psi) = -n_r . n_d
%
% Steps:
%   1. Recompute Q_i = n_t,i . n_d_hat, phi_i, and the model response R_i = R_G(phi_i)
%   2. Profiled-amplitude LS (MLE for eta given the direction):
%        eta_hat = sum_i mu_hat_i * R_i / sum_i R_i^2
%   3. cos(psi_hat) = -n_r . n_d_hat
%   4. Invert the amplitude:  d_hat = sqrt( C_opt * cos(psi_hat) / (theta_div^2 * eta_hat) )
%
% Mirrors fundamentals/core/broadcast_distance.m (Lambertian) for the Gaussian pattern.
%
% INPUTS:
%   nd_hat    : 3x1 estimated unit direction (Tx -> Rx)
%   nt        : 3xK LED orientation vectors (columns)
%   mu_hat    : 1xK measured averaged powers (W)
%   theta_div : scalar, divergence half-angle (RADIANS)
%   C_opt     : radiometric constant = 2*Pt*A_det/pi
%   nr        : 3x1 receiver orientation (unit). Default [0;0;1].
%
% OUTPUTS:
%   d_hat   : estimated TX-RX distance (m). NaN if not recoverable.
%   eta_hat : estimated amplitude parameter.

if nargin < 6 || isempty(nr)
    nr = [0; 0; 1];
end
nd_hat = nd_hat(:); nr = nr(:);
mu_hat = mu_hat(:)';
K = size(nt, 2);

% 1. Model responses along the estimated direction
R_model = zeros(1, K);
for i = 1:K
    Q_i = nt(:, i)' * nd_hat;
    if Q_i > 0
        phi_i = acos(min(1, Q_i));
        R_model(i) = exp(-2 * (phi_i / theta_div)^2);
    end
end

% 2. Profiled-amplitude LS estimate of eta
denom = sum(R_model.^2);
if denom < 1e-30
    d_hat = NaN; eta_hat = NaN; return;
end
eta_hat = sum(mu_hat .* R_model) / denom;

% 3. Incidence cosine from known n_r
cos_psi = -(nr' * nd_hat);

% 4. Invert amplitude for distance
if eta_hat <= 0 || cos_psi <= 0
    d_hat = NaN; return;
end
d_hat = sqrt(C_opt * cos_psi / (theta_div^2 * eta_hat));
end
