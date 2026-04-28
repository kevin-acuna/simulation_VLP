function DEB = DEB_complete(R, nt_orientations, T, Pt, m, A_det, theta_half, Psi_FOV, sigma2, N)
% DEB_complete - Direction Error Bound calculation for Single LED VLP system
% Reparameterized with alpha = ln(eta) for perfect numerical conditioning.

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

K = size(nt_orientations, 2);

%% System parameters & Ground Truth State
nr = [0; 0; 1];
d_vec = R - T;                    
d = norm(d_vec);                  
nd = d_vec / d;                   

% Spherical angles of the true direction vector
theta_d = acos(-nd(3));
phi_d = atan2(nd(2), nd(1));

% Avoid exact pole singularity for Jacobian calculation
if theta_d < 1e-6
    theta_d = 1e-6;
end

% Nuisance parameter: eta = (C * cos(psi)) / d^2
C = (Pt * (m + 1) * A_det) / (2 * pi);
cos_psi = (nr' * (-d_vec)) / d;       
eta = (C * cos_psi) / d^2;            

%% Jacobian of the Cartesian Unit Vector w.r.t Spherical Angles
u_theta = [cos(theta_d)*cos(phi_d); 
           cos(theta_d)*sin(phi_d); 
           sin(theta_d)];
       
u_phi = [-sin(theta_d)*sin(phi_d); 
          sin(theta_d)*cos(phi_d); 
          0];

J_sph = [u_theta, u_phi];

%% Initialize Fisher Information Matrix
I_fisher = zeros(3, 3);

%% Contribution from K orientations (Direction Finding ONLY)
for i = 1:K
    nt_i = nt_orientations(:, i);
    
    Q_i = nt_i' * nd;             
    psi = acos(abs(cos_psi));
    
    if psi > Psi_FOV || Q_i <= 0
        continue;
    end
    
    % WELL-CONDITIONED GRADIENTS: Using alpha = ln(eta)
    % This extracts 'eta' out of the derivative, making all terms ~O(1)
    dmu_dtheta_scaled = m * Q_i^(m-1) * (nt_i' * u_theta);
    dmu_dphi_scaled   = m * Q_i^(m-1) * (nt_i' * u_phi);
    dmu_dalpha        = Q_i^m;
    
    grad_scaled = [dmu_dtheta_scaled; dmu_dphi_scaled; dmu_dalpha];
    
    % The common factor eta^2 multiplies the entire outer product
    I_fisher = I_fisher + (N * eta^2 / sigma2) * (grad_scaled * grad_scaled');
end

%% Calculate Direction Error Bound (DEB)
% Matrix is now perfectly conditioned mathematically. No aggressive regularization needed.
try
    Inv_I = inv(I_fisher);
    % Extract the 2x2 angular covariance block [theta_d, phi_d]
    C_ang = Inv_I(1:2, 1:2);
    % Project angular covariance to Cartesian unit-vector covariance
    DEB = sqrt(trace(J_sph * C_ang * J_sph'));
catch ME
    warning('Matrix inversion failed: %s', ME.message);
    DEB = Inf;
end

% Additional check for invalid results
if ~isreal(DEB) || ~isfinite(DEB) || DEB < 0
    DEB = Inf;
end

end