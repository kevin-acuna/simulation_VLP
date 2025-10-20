function n_hat = estimate_UE_orientation_svd(AP, UE, p_est_xyz, Pblock)
% ESTIMATE_UE_ORIENTATION  Estima la orientación (vector normal unitario) del PD
% con 2 transmisores beamsteering a partir de medidas absolutas.
%
% Modelo (LOS Lambertiano):
%   P_{jk} = C_j * ((u_{jk}·v_j)^m / d_j^2) * (n_PD · (-v_j))
% donde v_j es la dirección LED->PD (unitaria), d_j la distancia, u_{jk} el eje
% del haz del Tx j en la orientación k, m el orden Lambertiano, y C_j agrupa
% constantes ópticas/geométricas.
%
% ENTRADAS
%   AP(1:2): struct con .pos [1x3], .set_n_t [Kj x 2] (tilt_deg, yaw_deg),
%            .m (orden), .P_t (W)
%   UE     : struct con .A_det, .Ts, .g_ri, .R_pd (si tus P son corrientes)
%   p_est_xyz : [1x3] posición estimada del UE
%   Pblock    : Kmax x 2, columna j contiene P_{jk} (NaN donde no hay muestra)
%
% SALIDA
%   n_hat : [1x3] orientación estimada (unitaria)

    % --- Geometría LED->PD (v_j) y distancias d_j
    p = p_est_xyz(:)';
    v  = zeros(2,3);
    d  = zeros(1,2);
    for j = 1:2
        rj = p - AP(j).pos(:)';   % vector LED->PD
        d(j) = norm(rj);
        v(j,:) = rj / d(j);       % dirección LED->PD
    end

    % --- Constantes C_j (incluye responsividad si tus P son corrientes)
    C = zeros(1,2);
    for j = 1:2
        m_j = AP(j).m;
        C(j) = AP(j).P_t * ((m_j + 1)/(2*pi)) * UE.A_det * UE.Ts * UE.g_ri;
    end

    % --- Para cada Tx, estimar s_j = n·(-v_j) a partir de P_{jk}
    s = zeros(1,2);
    for j = 1:2
        % Diseño angular del Tx j
        Uj = angles2vec(AP(j).set_n_t);        % Kj x 3
        Kj = sum(isfinite(Pblock(:,j)));
        Pj = Pblock(1:Kj,j);                    % Kj x 1 (quita NaNs finales)
        cos_th = max(0, Uj(1:Kj,:) * v(j,:)');  % Kj x 1
        gj = (cos_th.^AP(j).m) / (d(j)^2);      % Kj x 1

        % Modelo lineal: Pj ≈ (Cj * s_j) * gj  →  escalar LS (vía SVD implícita)
        % sC_j = argmin || gj*sC - Pj ||  = (gj'Pj)/(gj'gj)
        sC = (gj' * Pj) / (gj' * gj);          % sC_j = C_j * s_j
        s(j) = sC / C(j);                      % s_j = n·(-v_j)
    end

    %s = mean(Pj.*d.^2./(C(1).*cos_th.^AP(1).m));
    % --- Sistema lineal en n:  [v1; v2] * n = -[s1; s2]
    A = -[v(1,:); v(2,:)];
    b = s(:);                                 % por cos_psi = n·(-v)

    % --- SVD y solución en la variedad A n = b, ||n||=1
    [U,S,V] = svd(A);          % A = U S V^T, S = diag(s1,s2)
    % Solución particular (en la subvariedad de mínimos cuadrados exactos)
    Sinv = diag(1./diag(S));           % 2x2
    n_p  = V(:,1:2) * (Sinv * (U(:,1:2)' * b));   % pseudoinversa sin normalizar
    % Componente nulo (no altera A n = b)
    v0   = V(:,3);                      % vector nulo derecho (A*v0 = 0)
    t2   = max(0, 1 - dot(n_p,n_p));    % cantidad que falta para norma 1
    % Dos soluciones; elige la que “mire hacia arriba” (signo sencillo y físico)
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
% tiltAz_deg: [K x 2] = [tilt_deg, az_deg]
% Convención usada aquí:
%  - tilt = 0° significa "mirando hacia -z" (vertical hacia abajo, típico en luminarias de techo)
%  - azimut medido en grados en el plano xy desde +x, CCW.
% Ajusta si tu angles2vec ya implementa otra convención.

    K = size(tiltAz_deg,1);
    U = zeros(K,3);
    for k = 1:K
        tilt = deg2rad(tiltAz_deg(k,1));
        az   = deg2rad(tiltAz_deg(k,2));
        % Eje del haz, apuntando hacia el receptor (abajo): base -z
        % Vector esférico tomando polar=tilt desde -z:
        % Construimos desde +z y luego invertimos el signo z al final si prefieres tu convención.
        % Aquí: u = [sin(tilt)*cos(az), sin(tilt)*sin(az), -cos(tilt)]
        U(k,:) = [sin(tilt)*cos(az), sin(tilt)*sin(az), -cos(tilt)];
        U(k,:) = U(k,:)/norm(U(k,:));
    end
end
