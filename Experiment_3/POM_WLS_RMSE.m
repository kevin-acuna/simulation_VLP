function [cdf90_RMS] = POM_WLS_RMSE(n_t_s)
% RMS_ORIENTATION  Simula un escenario con orientaciones Tx y obtiene RMS error (CDF 90%).
%
%   n_t_s : vector con [theta_1, rho_1, theta_2, rho_2, ..., theta_n, rho_n]
%
%   Devuelve: cdf90_RMS - el valor del error RMS al 90% de la CDF.
%
%   Además, grafica:
%     1) Los vectores de orientación del Tx (quiver3).
%     2) La distribución real de receptores (scatter).
%     3) La posición estimada (scatter x).

    import opticalWireless.*  % Para usar h_LOS u otras funciones en +opticalWireless
    import positionEstimators.* % Estimar las posiciones

    %% 1) Preparar parámetros
    % Leer parámetros usando la función setupParameters
    params = setupParameters();
    
    H      = params.room.H;
    P_t    = params.P_t;
    m_t    = params.m_t;
    coord_t= params.coord_t;

    z_ref  = params.z_ref;
    p      = params.p; 
    q      = params.q;
    FOV    = params.FOV;
    n_r    = params.n_r;
    R_pd   = params.R_pd;

    N0     = params.N0;
    BW     = params.signalBandwidth;

    testbed= params.testbed;
    step   = params.step;

    % Ruido total
    sigma2_tot = BW * N0;

    %% 2) Construir las orientaciones a partir de n_t_s
    %    El número de orientaciones n = length(n_t_s)/2
    if mod(length(n_t_s),2)~=0
        error('n_t_s debe tener un número par de elementos [theta, rho].');
    end
    nPairs = length(n_t_s)/2;
    orientations = zeros(nPairs,3);  % nPairs x 3 (cada fila es un vector normal)

    for i = 1:nPairs
        theta = n_t_s(2*(i-1)+1);  % 1,3,5,...
        rho   = n_t_s(2*(i-1)+2);  % 2,4,6,...
        % Convertir a radianes si lo deseas, pero con sind/cosd es ok en grados:
        x_u = sind(theta)*cosd(rho);
        y_u = sind(theta)*sind(rho);
        z_u = -cosd(theta);
        orientations(i,:) = [x_u, y_u, z_u];
    end

    %% 3) Definir el plano de recepción
    X_r = testbed(1):step:testbed(2);
    Y_r = testbed(3):step:testbed(4);
    [x_real, y_real] = meshgrid(X_r, Y_r);
    z = z_ref - H;  % si el (0,0,0) es el techo en param_t

    N_rx = length(X_r);
    N_ry = length(Y_r);

    % Chequear que el plano no esté fuera de la sala
    if abs(z) > H
        error('La altura del plano Rx excede la sala (z=%f, H=%f).', z, H);
    end

    %% 4) Simular potencias medidas
    %    P_r  -> [N_rx x N_ry x nPairs]
    P_r = zeros(N_rx, N_ry, nPairs);

    % para el metodo 'WLS'
    SNR = zeros(N_rx, N_ry, nPairs);

    A_det = p*q;  % Área PD (simple) - si hay N_det, multiplícalo
    param_r = {A_det, n_r, FOV};

    for i_n = 1:nPairs
        param_t = {coord_t, orientations(i_n,:), m_t};
        for ix = 1:N_rx
            for iy = 1:N_ry
                x_pos = X_r(ix);
                y_pos = Y_r(iy);

                [hVal, ~, ~, ~] = h_LOS(param_t, 1, param_r, x_pos, y_pos, z);
                P_los = hVal * P_t;  % potencia óptica ideal

                % Añadir ruido simulando (opcional):
                % supondremos s_r ~ N( (R_pd * P_los), sqrt(sigma2_tot) ), 
                % generamos un vector estadístico:
                s_r = (R_pd * P_los) + sqrt(sigma2_tot)*randn(1,10000);
                Pr_elec = mean(s_r.^2); 
                P_r(ix, iy, i_n) = sqrt(Pr_elec)/R_pd;

                % para el metodo 'WLS'
                SNR(ix,iy,i_n) = 10*log10( (R_pd*P_los)^2/sigma2_tot );
            end
        end
    end

    %% 5) Llamar a la función de estimación
    %    (Si deseas, podrías enviar SNR o un flag. Por ahora, lo hacemos simple.)
    [x_est, y_est] = estimatePosition(P_r, orientations, m_t); 

    %  (El prototipo: estimatePosition(P, orientations, m, 'Method','LS'/'WLS','SNR',SNR,...))
    [x_est, y_est] = estimatePosition(P_r, orientations, m_t, 'Method', 'WLS', 'SNR', SNR);

    %% 6) Calcular error RMS y CDF
    rmsError = sqrt( (x_real' - x_est).^2 + (y_real' - y_est).^2 );
    [f_RMS, x_RMS] = ecdf(rmsError(:));

    % cdf90
    idx90 = find(f_RMS<0.9, 1, 'last');
    cdf90_RMS = x_RMS(idx90);

    %% 7) Visualización (al final)
    visualizeResults(n_t_s, x_real, y_real, x_est, y_est);
end


%% Función interna: visualizeResults
function visualizeResults(n_t_s, x_real, y_real, x_est, y_est)
% VISUALIZERESULTS  Grafica:
%   - Vectores de orientación del Tx
%   - Distribución (x_real,y_real)
%   - Posiciones estimadas (x_est,y_est)
%
%   n_t_s: [theta_1, rho_1, theta_2, rho_2, ...]
%   x_real, y_real: malla original
%   x_est, y_est  : estimación en la misma malla (matrices de igual dim)

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

        quiver3(0, 0, 0, x_u, y_u, z_u, ...
            'Color', colors(tx,:), ...
            'LineWidth', 1, ...
            'MaxHeadSize', 0.5, ...
            'AutoScale','off');
    end

    % 7.2) Graficar la "distribución real" (o sea, la malla de puntos Rx)
    scatter(x_real(:), y_real(:), 'o', 'MarkerEdgeColor', 'k'); 
    % 7.3) Graficar la posición estimada 
    %      (aquí x_est,y_est son toda la malla; en muchos experimentos
    %       uno sólo traza la "diferencia" en cada punto, o un subset.)
    scatter(x_est(:), y_est(:), 'x', 'MarkerEdgeColor',[0.8500 0.3250 0.0980]);

    % Ajuste de ejes (similar a tu snippet)
    axis([-1.2 1.2 -1.2 1.2 -2 0]);
    view([0 90]);  % Vista "desde arriba" 2D
    xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
    title('Estimation');

    hold off;
end
