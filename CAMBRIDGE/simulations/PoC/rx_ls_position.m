function [r_hat, u_B_hat, eta_hat, d_hat, n_used] = rx_ls_position(mu_hat, N_B, R, P, thr)
%RX_LS_POSITION  Closed-form 3D position from K PD-orientation power means (RX-steered).
%   [r_hat, u_B_hat, eta_hat, d_hat, n_used] = rx_ls_position(mu_hat, N_B, R, P, thr)
%   mu_hat : Kx1 sample-mean powers
%   N_B    : Kx3 PD normals (body frame, rows)
%   R      : 3x3 body-to-world attitude (assumed known: IMU / robot kinematics / CNC)
%   P      : parameter struct (needs C, m, n_t, t)
%   thr    : dropout threshold [W]; measurements below it are treated as out of FOV
%
%   Stage 1 (direction + amplitude, body frame) — LINEAR model  mu = N_B * w,
%   w = eta_R * u^B  ->  ordinary LS is the BLUE / MLE under AWGN.
%     u_B_hat = w_hat/||w_hat||,  eta_hat = ||w_hat||
%   Independent of the LED orientation, Lambertian order, power and pattern.
%
%   Stage 2 (distance, needs attitude and the LED pattern):
%     u_W = R u_B,  cos(phi) = -n_t . u_W,  d = sqrt(C cos^m(phi) / eta),
%     r_hat = t - d * u_W
if nargin < 5, thr = 0; end
mu_hat = mu_hat(:);
use = mu_hat > thr;
n_used = nnz(use);
if n_used < 3 || rank(N_B(use, :)) < 3
    r_hat = nan(1, 3); u_B_hat = nan(3, 1); eta_hat = NaN; d_hat = NaN;
    return;
end
w_hat = N_B(use, :) \ mu_hat(use);            % ordinary LS (BLUE)
eta_hat = norm(w_hat);
u_B_hat = w_hat / eta_hat;
u_W_hat = R * u_B_hat;
cos_phi_hat = max(-P.n_t(:)' * u_W_hat, 1e-6);
d_hat = sqrt(P.C * cos_phi_hat^P.m / eta_hat);
r_hat = (P.t(:) - d_hat * u_W_hat)';
end
