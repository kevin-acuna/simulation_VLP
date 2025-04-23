function [x_est, y_est, z_est] = deterministic3D(P, orientations, C, m, n_r, T)
% ESTIMATEPOSITION3D  Estima (x,y,z) en toda la grilla de potencia
%  P           : [Nx x Ny x Nz x 3]
%  orientations: [3 x 3]
%  C, m        : escalares
%  n_r, T      : [1 x 3]

    %-- 1) Preparar datos ----------------------------------------
    [Nx, Ny, Nz, ~] = size(P);
    N = Nx * Ny * Nz;

    % "Aplano" P a [N x 3]
    Pmat = reshape(P, [N, 3]);
    P1 = Pmat(:,1);
    P2 = Pmat(:,2);
    P3 = Pmat(:,3);

    % Extraigo orientaciones
    n1 = orientations(1,:);    % 1x3
    n2 = orientations(2,:);
    n3 = orientations(3,:);

    %-- 2) Cálculo de betas --------------------------------------
    beta2 = (P2 ./ P1).^(1/m);  % N×1
    beta3 = (P3 ./ P1).^(1/m);  % N×1

    %-- 3) Construyo v2, v3 vía repmat ----------------------------
    n1_mat = repmat(n1, N, 1);  % N×3
    n2_mat = repmat(n2, N, 1);
    n3_mat = repmat(n3, N, 1);

    beta2_mat = repmat(beta2, 1, 3);  % N×3
    beta3_mat = repmat(beta3, 1, 3);

    v2 = n2_mat - beta2_mat .* n1_mat;  % N×3
    v3 = n3_mat - beta3_mat .* n1_mat;  % N×3

    %-- 4) Dirección con producto cruz ----------------------------
    d = cross(v2, v3, 2);          % N×3
    norms = sqrt(sum(d.^2, 2));    % N×1
    hatd = d ./ repmat(norms, 1, 3);

    %-- 5) Corregir sentido según n1 --------------------------------
    %  dot = hatd * n1'
    dots = hatd * n1';             % N×1
    idx = (dots < 0);
    hatd(idx, :) = -hatd(idx, :);

    %-- 6) Cálculo de lambda usando P1 absoluto --------------------
    cos_phi1 = sum(hatd .* repmat(n1, N, 1), 2);   % N×1
    cos_psi  = sum(hatd .* repmat(-n_r, N, 1), 2); % N×1

    lambda = sqrt( C .* (cos_phi1.^m) .* cos_psi ./ P1 );  % N×1

    %-- 7) Reconstrucción de la posición --------------------------
    T_mat = repmat(T, N, 1);       % N×3
    pos = T_mat + hatd .* repmat(lambda, 1, 3);  % N×3

    %-- 8) Reformo a grillas 3D -----------------------------------
    Xv = reshape(pos(:,1), [Nx, Ny, Nz]);
    Yv = reshape(pos(:,2), [Nx, Ny, Nz]);
    Zv = reshape(pos(:,3), [Nx, Ny, Nz]);

     % permutamos dims [Nx x Ny x Nz] → [Ny x Nx x Nz]
    x_est = permute(Xv, [2,1,3]);
    y_est = permute(Yv, [2,1,3]);
    z_est = permute(Zv, [2,1,3]);
end
