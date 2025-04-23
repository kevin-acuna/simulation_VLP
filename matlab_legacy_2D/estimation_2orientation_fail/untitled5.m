% test_C_known_grid_constraints.m
% Estimación 2D [-1,1]×[-1,1] con restricciones físicas

clear; clc; close all;

%% 1. Parámetros fijos
H     = 2.0;       % Altura del Tx (m)
h     = 0.8;       % Altura del Rx (m)
C     = 0.5;       % C = P_t*(m+1)*A_det/(2*pi)
m     = 1.5;       % Orden Lambertiano
K     = C*(H - h); % Constante combinada

% Orientaciones del Tx
n1 = [ 0;  0; -1 ];   % vertical
theta2 = 20; phi2 = 45;
n2 = [ sind(theta2)*cosd(phi2);
       sind(theta2)*sind(phi2);
      -cosd(theta2) ];

%% 2. Rejilla de prueba
X = -1:0.1:1; 
Y = -1:0.1:1;
NX = numel(X);
NY = numel(Y);

error_map = nan(NY, NX);
X_est = nan(NY, NX);
Y_est = nan(NY, NX);

%% 3. Prepara lsqnonlin con cotas y opciones
lb = [-1; -1];   % x,y mínimos
ub = [ 1;  1];   % x,y máximos
opts = optimoptions('lsqnonlin','Display','off',...
    'FunctionTolerance',1e-12,'StepTolerance',1e-12);

% Puntos iniciales para multi‐start
starts = [0 0;  0 1;  1 0;  0 -1;  -1 0];

%% 4. Bucle de estimación con restricciones
for ix = 1:NX
    for iy = 1:NY
        x_true = X(ix);
        y_true = Y(iy);
        d_true = [x_true; y_true; h - H];
        d_norm = norm(d_true);

        % --- Cálculo de P1 y P2 ---
        cosphi1 = (n1.' * d_true) / d_norm;
        cosphi2 = (n2.' * d_true) / d_norm;
        cospsi  = ([0 0 1] * (-d_true)) / d_norm;

        P1 = C * cosphi1^m * cospsi / d_norm^2;
        P2 = C * cosphi2^m * cospsi / d_norm^2;

        % Razón direccional
        r = (P1 / P2)^(1/m);

        % Define la función de residuos
        fun = @(xy) [
            (n1(1)-r*n2(1))*xy(1) + (n1(2)-r*n2(2))*xy(2) + (n1(3)-r*n2(3))*(h-H);
            P1*((xy(1))^2 + (xy(2))^2 + (h-H)^2)^((m+3)/2) ...
              - K*(n1(1)*xy(1) + n1(2)*xy(2) + n1(3)*(h-H))^m
        ];

        % Multi‐start con validación de cosphi>0
        sol_ok = false;
        for s = 1:size(starts,1)
            xy0 = starts(s,:).';
            [xy_est,~,res,exitflag] = lsqnonlin(fun, xy0, lb, ub, opts);
            if exitflag>0
                % Recalcular cosφ con la solución
                d_est = [xy_est; h-H];
                d_norm_est = norm(d_est);
                cp1 = (n1.'*d_est)/d_norm_est;
                cp2 = (n2.'*d_est)/d_norm_est;
                % Acepta sólo si ambas iluminan al Rx
                if cp1>0 && cp2>0
                    sol_ok = true;
                    break
                end
            end
        end
        if ~sol_ok
            % Marcamos fallo (por ejemplo con NaN) si no hubo solución física
            xy_est = [NaN; NaN];
        end

        % Guardar resultados
        X_est(iy, ix) = xy_est(1);
        Y_est(iy, ix) = xy_est(2);
        error_map(iy, ix) = norm(xy_est - [x_true; y_true]);
    end
end

%% 5. Resultados y visualización
max_error = nanmax(error_map(:));
fprintf('Error máximo en la rejilla (restricciones): %.2e m\n', max_error);

figure;
imagesc(X, Y, error_map);
axis xy equal tight;
colorbar;
title('Mapa de error 2D con restricciones físicas');
xlabel('x real (m)');
ylabel('y real (m)');

figure; hold on; grid on; axis equal;
[xg, yg] = meshgrid(X, Y);
scatter(xg(:), yg(:), 25, 'o', 'MarkerEdgeColor', 'b', 'DisplayName','Reales');
scatter(X_est(:),Y_est(:), 25,'x','MarkerEdgeColor','r','DisplayName','Estimados');
title('Real (o) vs Estimado (x) – con restricciones');
xlabel('x (m)'); ylabel('y (m)');
legend('Location','best');
