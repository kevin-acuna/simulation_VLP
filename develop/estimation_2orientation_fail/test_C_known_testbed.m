% test_C_known_grid_with_scatter.m
% Demostración de estimación 2D sobre un testbed completo [-1,1]×[-1,1]
% con mapa de error y comparación visual real vs estimado

clear; clc; close all;

%% 1. Parámetros fijos
H     = 2.0;       % Altura del Tx (m)
h     = 0.8;       % Altura del Rx (m)
C     = 0.5;       % C = P_t*(m+1)*A_det/(2*pi)
m     = 2;       % Orden Lambertiano
K     = C*(H - h); % Constante combinada

% Orientaciones del Tx
n1 = [ 0;  0; -1 ];   % vertical
theta2 = 20; phi2 = 45;
n2 = [ sind(theta2)*cosd(phi2);
       sind(theta2)*sind(phi2);
      -cosd(theta2) ];

% Opciones de fsolve
opts = optimoptions('fsolve','Display','off','FunctionTolerance',1e-12);

%% 2. Definir rejilla de prueba
X = -1:0.1:1; 
Y = -1:0.1:1;
NX = numel(X);
NY = numel(Y);

error_map = nan(NY, NX);
X_est = nan(NY, NX);
Y_est = nan(NY, NX);

%% 3. Bucle sobre todos los puntos (x_true, y_true)
for ix = 1:NX
    for iy = 1:NY
        x_true = X(ix);
        y_true = Y(iy);
        d_true = [x_true; y_true; h - H];
        d_norm = norm(d_true);

        % --- Calcular potencias P1, P2 ---
        cosphi1 = (n1.' * d_true) / d_norm;
        cosphi2 = (n2.' * d_true) / d_norm;
        cospsi  = ([0 0 1] * (-d_true)) / d_norm;

        P1 = C * cosphi1^m * cospsi / d_norm^2;
        P2 = C * cosphi2^m * cospsi / d_norm^2;

        % Razón direccional
        r = (P1 / P2)^(1/m);

        % Sistema de dos ecuaciones en (x,y)
        fun = @(xy) [
            (n1(1)-r*n2(1))*xy(1) + (n1(2)-r*n2(2))*xy(2) + (n1(3)-r*n2(3))*(h-H);
            P1*((xy(1))^2 + (xy(2))^2 + (h-H)^2)^((m+3)/2) ...
              - K*(n1(1)*xy(1) + n1(2)*xy(2) + n1(3)*(h-H))^m
        ];

        % Resolver con fsolve, inicializamos cerca de la posición real
        xy0    = [0;0];
        xy_est = fsolve(fun, xy0, opts);
        x_e = xy_est(1);
        y_e = xy_est(2);

        % Guardar estimado y error
        X_est(iy, ix) = x_e;
        Y_est(iy, ix) = y_e;
        error_map(iy, ix) = norm([x_e; y_e] - [x_true; y_true]);
    end
end

%% 4. Mapa de error
max_error = max(error_map(:));
fprintf('Error máximo en la rejilla: %.2e m\n', max_error);

figure;
imagesc(X, Y, error_map);
axis xy equal tight;
colorbar;
title('Mapa de error 2D (m)');
xlabel('x true (m)');
ylabel('y true (m)');

%% 5. Gráfica comparativa real vs estimado
figure; hold on; grid on; axis equal;
% scatter de puntos reales
[xg, yg] = meshgrid(X, Y);
scatter(xg(:), yg(:), 25, 'o', 'MarkerEdgeColor', 'k', 'DisplayName', 'Reales');
% scatter de puntos estimados
scatter(X_est(:), Y_est(:), 25, 'x', 'MarkerEdgeColor', 'r', 'DisplayName', 'Estimados');
title('Comparación de posiciones reales (o) vs estimadas (x)');
xlabel('x (m)');
ylabel('y (m)');
legend('Location','best');
