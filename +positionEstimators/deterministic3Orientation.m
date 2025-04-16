% +opticalWireless/deterministic3Orientation.m
function [x_est, y_est] = deterministic3Orientation(P, orientations, m)
%DETERMINISTIC3ORIENTATION  Estima (x,y) asumiendo 3 orientaciones y modelo ideal sin ruido.
%   [x_est, y_est] = deterministic3Orientation(P, orientations, m)
%
%   - P           : [N_x, N_y, 3] matriz de potencias (ópticas) simuladas/medidas
%   - orientations: [3 x 3], cada fila es el vector n_t_i = [a_i, b_i, c_i]
%   - m           : exponente lambertiano
%
%   Devuelve:
%   - x_est, y_est: [N_x, N_y], con la posición estimada en cada punto de la malla.
%
%   NOTA:
%     Este ejemplo reproduce la fórmula "clásica" que usaste en RMS_orientation
%     para i=1, j=2, k=1, l=3.

    % Extraemos a, b, c
    a = orientations(:,1);  % [a1; a2; a3]
    b = orientations(:,2);  % [b1; b2; b3]
    c = orientations(:,3);  % [c1; c2; c3]

    % Indices fijos en tu fórmula
    i = 1; j = 2; k = 1; l = 3;

    % Tomamos P1, P2, P3
    P1 = P(:,:,i);
    P2 = P(:,:,j);
    P3 = P(:,:,l);

    % Construimos los factores K_ij, K_kl:
    K_ij = (P1 ./ P2).^(1/m);  % (P1/P2)^(1/m)
    K_kl = (P1 ./ P3).^(1/m);  % (P1/P3)^(1/m)
    % (En tu RMS_orientation original tenías (P_r(:,:,i)./P_r(:,:,j))^(1/m_t), etc.
    %  Ajusta según corresponda.)

    % Altura receptora. Ajustar si tu escenario difiere:
    % (en tu RMS_orientation, usabas z = z_ref - H, y la fórmula multiplicada por z).
    % Supongamos por simplicidad z = -1.04 (o el que corresponda).
    % Aquí lo dejamos como ejemplo (ajusta a tu caso):
    z = -1.04;  % EJEMPLO: escenario donde el Tx está en (0,0,0) y Rx plane a 1.04m por debajo

    % Aplicamos la ecuación cerrada (versión vectorizada) extraída de tu RMS_orientation
    x_est = z .* ( (K_kl .* b(l) - b(k)) .* (c(i) - K_ij .* c(j)) ...
                  - (K_ij .* b(j) - b(i)) .* (c(k) - c(l) .* K_kl ) ) ...
            ./ ( (K_kl .* b(l) - b(k)) .* (K_ij .* a(j) - a(i)) ...
               - (K_ij .* b(j) - b(i)) .* (K_kl .* a(l) - a(k)) );

    y_est = z .* ( (K_kl .* a(l) - a(k)) .* (c(i) - K_ij .* c(j)) ...
                  - (K_ij .* a(j) - a(i)) .* (c(k) - c(l) .* K_kl ) ) ...
            ./ ( (K_kl .* a(l) - a(k)) .* (K_ij .* b(j) - b(i)) ...
               - (K_ij .* a(j) - a(i)) .* (K_kl .* b(l) - b(k)) );

end
