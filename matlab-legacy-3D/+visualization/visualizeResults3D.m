function visualizeResults3D(n_t_s, x_real, y_real, z_real, x_est, y_est, z_est)
% VISUALIZERESULTS  Grafica:
%   - Vectores de orientación del Tx
%   - Distribución (x_real,y_real)
%   - Posiciones estimadas (x_est,y_est)
%
%   n_t_s: [theta_1, rho_1, theta_2, rho_2, ...]
%   x_real, y_real: malla original
%   x_est, y_est, z_est : estimación en la misma malla (matrices de igual dim)

    figure; 
    hold on; grid on;

    % 7.1) Graficar los vectores de orientación en 3D
    nPairs = length(n_t_s)/2;
    colors = lines(nPairs);  % Genera nPairs colores distintos
    for tx = 1:nPairs
        theta_deg = n_t_s(2*(tx-1) + 1);
        rho_deg   = n_t_s(2*(tx-1) + 2);

        x_u = sind(theta_deg)*cosd(rho_deg);
        y_u = sind(theta_deg)*sind(rho_deg);
        z_u = -cosd(theta_deg);

        quiver3(0, 0, 0, 0.4*x_u, 0.4*y_u, 0.4*z_u, ...
            'Color', colors(tx,:), ...
            'LineWidth', 1.2, ...
            'MaxHeadSize', 0.5, ...
            'AutoScale','off');
    end

    % 7.2) Graficar la "distribución real" (o sea, la malla de puntos Rx)
    %scatter3(x_real(:), y_real(:), z_real(:), 'o', 'MarkerEdgeColor'); 

    h = scatter3(x_real(:), y_real(:), z_real(:), 20, 'o', 'MarkerEdgeColor', 'k');
    h.MarkerEdgeAlpha = 0.5;

    % 7.3) Graficar la posición estimada 
    %      (aquí x_est,y_est son toda la malla; en muchos experimentos
    %       uno sólo traza la "diferencia" en cada punto, o un subset.)
    %scatter3(x_est(:), y_est(:), z_est(:), 'x', 'MarkerEdgeColor',[0.8500 0.3250 0.0980]);

    scatter3(x_est(:), y_est(:), z_est(:), 20, 'x', 'MarkerEdgeColor',[0.8500 0.3250 0.0980]);
    

    % Ajuste de ejes (similar a tu snippet)
    axis([-1.2 1.2 -1.2 1.2 -2 0]);
    view([45 30]);  % Vista "desde arriba" 2D
    xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
    title('Estimation');

    hold off;
end
