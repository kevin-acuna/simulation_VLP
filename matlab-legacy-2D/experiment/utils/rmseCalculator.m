function [cdf90_RMS] = rmseCalculator(n_t_s)
% RMSECALCULATOR Simula un escenario con orientaciones Tx y obtiene RMS error (CDF 90%).
%
%   n_t_s : vector con [theta_1, rho_1, theta_2, rho_2, ..., theta_n, rho_n]
%
%   Devuelve: cdf90_RMS - el valor del error RMS al 90% de la CDF.
%
%   Además, grafica:
%     1) Los vectores de orientación del Tx (quiver3).
%     2) La distribución real de receptores (scatter).
%     3) La posición estimada (scatter x).

    import visualization.* % Para usar funciones de visualización

    % Obtener las estimaciones de posición utilizando la función positionEstimator
    [x_est, y_est, x_real, y_real] = positionEstimator(n_t_s);
    
    % Calcular error RMS y CDF
    rmsError = sqrt( (x_real' - x_est).^2 + (y_real' - y_est).^2 );
    [f_RMS, x_RMS] = ecdf(rmsError(:));

    % cdf90
    idx90 = find(f_RMS<0.9, 1, 'last');
    cdf90_RMS = x_RMS(idx90);

%     % ********************************************************
%     % OPCIONES
%     % ********************************************************
%     % Visualizacion
%     visualizeResults(n_t_s, x_real, y_real, x_est, y_est);
%     
%     % Grabar
%     pos = struct();
%     pos.x_real=x_real;
%     pos.y_real=y_real;
%     pos.x_est=x_est;
%     pos.y_est=y_est;
%     
%     save 'test.mat' pos n_t_s cdf90_RMS
%     % ********************************************************

end
