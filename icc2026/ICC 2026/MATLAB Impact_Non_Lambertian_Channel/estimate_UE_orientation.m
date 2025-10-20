function n_hat = estimate_UE_orientation(AP, UE, p_est_xyz, Pblock)
% INPUTS
%   AP(1:2): struct with .pos [1x3], .set_n_t [Kj x 2] (tilt_deg, yaw_deg),
%            .m (order), .P_t (W)
%   UE     : struct with .A_det, .Ts, .g_ri, .R_pd (if your P are currents)
%   p_est_xyz : [1x3] estimated UE position
%   Pblock    : Kmax x 2, column j contains P_{jk} (NaN where no sample)
%
% OUTPUT
%   n_hat : [1x3] estimated orientation (unit)

    % --- LED->PD Geometry (v_j) and distances d_j
    p = p_est_xyz(:)';
    v  = zeros(2,3);
    d  = zeros(1,2);
    for j = 1:2
        rj = p - AP(j).pos(:)';   % LED->PD vector
        d(j) = norm(rj);
        v(j,:) = rj / d(j);       % LED->PD direction
    end

    % --- Constants C_j (includes responsivity if your P are currents)
    C = zeros(1,2);
    for j = 1:2
        m_j = AP(j).m;
        C(j) = UE.R_pd * AP(j).P_t * ((m_j + 1)/(2*pi)) * UE.A_det * UE.Ts * UE.g_ri;
    end

    % --- For each Tx, estimate s_j = n·(-v_j) from P_{jk}
    s = zeros(1,2);
    for j = 1:2
        % Angular design of Tx j
        Uj = angles2vec(AP(j).set_n_t);        % Kj x 3
        Kj = sum(isfinite(Pblock(:,j)));
        Pj = Pblock(1:Kj,j);                    % Kj x 1 (remove trailing NaNs)
        cos_th = max(0, Uj(1:Kj,:) * v(j,:)');  % Kj x 1
        gj = (cos_th.^AP(j).m) / (d(j)^2);      % Kj x 1

        % Linear model: Pj ≈ (Cj * s_j) * gj  →  scalar LS (via implicit SVD)
        % sC_j = argmin || gj*sC - Pj ||  = (gj'Pj)/(gj'gj)
        sC = (gj' * Pj) / (gj' * gj);          % sC_j = C_j * s_j
        s(j) = sC / C(j);                      % s_j = n·(-v_j)
    end

    %s = mean(Pj.*d.^2./(C(1).*cos_th.^AP(1).m));
    % --- Linear system in n:  [v1; v2] * n = -[s1; s2]
    A = -[v(1,:); v(2,:)];
    b = s(:);                                 % because cos_psi = n·(-v)

    % --- SVD and solution on the manifold A n = b, ||n||=1
    [U,S,V] = svd(A);          % A = U S V^T, S = diag(s1,s2)
    % Particular solution (in the exact least squares subspace)
    Sinv = diag(1./diag(S));           % 2x2
    n_p  = V(:,1:2) * (Sinv * (U(:,1:2)' * b));   % pseudoinverse without normalizing
    % Null component (does not alter A n = b)
    v0   = V(:,3);                      % right null vector (A*v0 = 0)
    t2   = max(0, 1 - dot(n_p,n_p));    % amount missing for norm 1
    % Two solutions; choose the one that "looks upward" (simple and physical sign)
    n1 = n_p + sqrt(t2)*v0;
    n2 = n_p - sqrt(t2)*v0;
    up = [0;0;1];
    if dot(n1,up) >= dot(n2,up)
        n_hat = (n1 / norm(n1)).';
    else
        n_hat = (n2 / norm(n2)).';
    end

end

function U = angles2vec(tiltAz_deg)
    K = size(tiltAz_deg,1);
    U = zeros(K,3);
    for k = 1:K
        tilt = deg2rad(tiltAz_deg(k,1));
        az   = deg2rad(tiltAz_deg(k,2));
        U(k,:) = [sin(tilt)*cos(az), sin(tilt)*sin(az), -cos(tilt)];
        U(k,:) = U(k,:)/norm(U(k,:));
    end
end
