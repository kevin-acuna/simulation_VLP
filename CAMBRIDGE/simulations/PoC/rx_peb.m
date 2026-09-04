function [PEB, FIM] = rx_peb(r, R, N_B, P)
%RX_PEB  Position error bound (CRLB) for the RX-steered single-anchor model.
%   [PEB, FIM] = rx_peb(r, R, N_B, P)
%   r   : 1x3 receiver position (world) ; R : 3x3 attitude (known)
%   N_B : Kx3 PD normals in the body frame
%
%   Gradient of mu_j w.r.t. r (same closed form as TCOM Eq. (grad_mu_closed)
%   with the roles swapped: n_t fixed, n_r -> n_j^W = R n_j^B):
%     grad mu_j = (C/d^3) [ m cos^{m-1}(phi) cos(psi_j) n_t
%                           - cos^m(phi) n_j^W
%                           - (m+3) cos^m(phi) cos(psi_j) n_d ]
%   FIM = (N/sigma^2) sum_j grad mu_j grad mu_j^T   (in-FOV orientations only)
%   PEB = sqrt(trace(FIM^-1))
d_vec = r(:) - P.t(:);
d = norm(d_vec);
n_d = d_vec / d;
n_t = P.n_t(:);
cos_phi = max(n_t' * n_d, 0);
N_W = (R * N_B')';                                  % Kx3 normals in world frame
cos_psi = -(N_W * n_d);                             % Kx1
in_fov = cos_psi >= cosd(P.FOV);
FIM = zeros(3);
for j = find(in_fov)'
    g = (P.C / d^3) * ( P.m * cos_phi^(P.m-1) * cos_psi(j) * n_t ...
                        - cos_phi^P.m * N_W(j, :)' ...
                        - (P.m + 3) * cos_phi^P.m * cos_psi(j) * n_d );
    FIM = FIM + g * g';
end
FIM = FIM / P.sigma2_mean;
if rank(FIM) < 3
    PEB = Inf;
else
    PEB = sqrt(trace(inv(FIM)));
end
end
