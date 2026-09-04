function [mu, eta_R, u_B] = rx_powers(r, R, N_B, P)
%RX_POWERS  Noise-free received optical powers for K PD orientations (LOS Lambertian).
%   [mu, eta_R, u_B] = rx_powers(r, R, N_B, P)
%   r    : 1x3 receiver position (world frame) [m]
%   R    : 3x3 body-to-world attitude matrix
%   N_B  : Kx3 PD normals commanded in the BODY frame (rows, unit)
%   P    : parameter struct from poc_params()
%   mu   : Kx1 noise-free powers  mu_j = eta_R * (n_j^B . u^B)   (FOV-masked)
%   eta_R: common amplitude  C cos^m(phi) / d^2
%   u_B  : 3x1 unit vector PD->LED expressed in the body frame
%
%   Model (dual of TCOM):  mu_j = (C/d^2) cos^m(phi) cos(psi_j),
%   cos(phi) = n_t . n_d  (LED irradiance angle, fixed during the scan),
%   cos(psi_j) = n_j^W . u = n_j^B . u^B   (only term that varies with j).
d_vec = r(:) - P.t(:);
d = norm(d_vec);
n_d = d_vec / d;                      % LED -> PD (world)
u_W = -n_d;                           % PD  -> LED (world)
u_B = R' * u_W;                       % PD  -> LED (body)
cos_phi = max(P.n_t(:)' * n_d, 0);
eta_R = P.C * cos_phi^P.m / d^2;
cos_psi = N_B * u_B;                  % Kx1
in_fov = cos_psi >= cosd(P.FOV);
mu = eta_R * cos_psi .* in_fov;
end
