function rms_error = NL_objective_function(orientation_vector, system_params, receiver_positions)
% NL_OBJECTIVE_FUNCTION - Función objetivo para optimización de orientaciones LED
% usando estimación no lineal de posición
%
% INPUTS:
%   orientation_vector: Vector de ángulos [theta1, rho1, theta2, rho2, ..., thetaK, rhoK]
%                      donde theta es elevación (0-90°) y rho es azimuth (0-360°)
%   system_params: Estructura con parámetros del sistema VLP
%   receiver_positions: Matriz 3xN con posiciones de receptores [x; y; z]
%
% OUTPUT:
%   rms_error: Error RMS promedio de estimación de posición [m]
%
% Basado en NL_K5_objetive.m - Convertido a función objetivo para GA
% Kevin Acuña - 2024

% Añadir path para OWC_LOS_channel si no está disponible
if ~exist('OWC_LOS_channel', 'file')
    addpath('../../Comparison between estimators Linear-NonLinear');
end

try
   
    K = length(orientation_vector) / 2; % Número de orientaciones
    N_pos = size(receiver_positions, 2); % Número de posiciones de receptor
    
    % Extraer parámetros del sistema
    T = system_params.T';                    % Posición del LED [x; y; z]
    P_t = system_params.Pt;                 % Potencia transmitida [W]
    theta_half = system_params.theta_half;  % Ángulo de media potencia [rad]
    m_t = system_params.m;                  % Orden Lambertiano
    A_det = system_params.A_det;            % Área del fotodiodo [m²]
    FOV = rad2deg(system_params.Psi_FOV);            % Campo de visión del receptor [rad]
    sigma2 = system_params.sigma2;          % Varianza del ruido [W²]
    N_samples = system_params.N;            % Número de muestras por orientación
    
    % Convertir ángulos esféricos a vectores cartesianos 3D
    n_t = zeros(K, 3);
    for i = 1:K
        theta_deg = orientation_vector(2*i-1);  % Ángulo de elevación
        rho_deg = orientation_vector(2*i);      % Ángulo de azimuth
        
        % Convertir a radianes
        theta_rad = deg2rad(theta_deg);
        rho_rad = deg2rad(rho_deg);
        
        % Convertir de coordenadas esféricas a cartesianas
        n_t(i,1) = sin(theta_rad) * cos(rho_rad);  % componente x
        n_t(i,2) = sin(theta_rad) * sin(rho_rad);  % componente y
        n_t(i,3) = -cos(theta_rad);                % componente z (negativo porque apunta hacia abajo)
    end
    
    % Parámetros del receptor
    n_r = [0, 0, 1]; % Vector normal del fotorreceptor (apuntando hacia arriba)
    alpha = n_r(1); beta = n_r(2); gamma = n_r(3);
    
    % Factor de normalización
    C = -P_t * (m_t + 1) * A_det / (2 * pi);
    
    % Parámetros para la función de canal
    param_r = {A_det, n_r, FOV};
    
    % Inicializar arrays para almacenar resultados
    P_r = cell(N_pos, K);           % Potencia recibida real [W]
    P_r_noisy = cell(N_pos, K);    % Potencia recibida con ruido [W]
    v_tr_est = zeros(N_pos, 3);    % Vector unitario estimado Tx->Rx
    estPos = zeros(N_pos, 3);      % Posiciones estimadas
    
    % Extraer coordenadas de posiciones de receptores
    X_r = receiver_positions(1, :);
    Y_r = receiver_positions(2, :);
    Z_r = receiver_positions(3, :);
    
    %% Paso 1: Cálculo de las potencias recibidas observadas
    for i_pos = 1:N_pos
        x = X_r(i_pos); 
        y = Y_r(i_pos); 
        z = Z_r(i_pos);
        
        for i_dir = 1:K
            param_t = {T, n_t(i_dir,:), P_t, m_t};
            [~, P_r{i_pos,i_dir}, ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
            
            % Añadir ruido gaussiano
            P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2) * randn(1, N_samples)) / (-C);
        end
    end
    
    %% Paso 2: Estimación de las posiciones del receptor usando optimización no lineal
    realPos = [X_r; Y_r; Z_r]';
    
    for i_pos = 1:N_pos
        % Definir variables de optimización
        x = optimvar('x'); 
        y = optimvar('y'); 
        z = optimvar('z');
        
        % Definir polinomios Q_i y L
        Q = cell(K, 1);
        F = cell(K, 1);
        
        for i = 1:K
            a_i = n_t(i, 1); 
            b_i = n_t(i, 2); 
            c_i = n_t(i, 3);
            
            Q{i} = a_i * x + b_i * y + c_i * z;
            F{i} = sum((C * (alpha * x + beta * y + gamma * z) .* Q{i}.^m_t - P_r_noisy{i_pos, i}).^2);
        end
        
        % Función objetivo total
        F_total = sum([F{:}]);
        
        % Definir problema de optimización
        prob = optimproblem('Objective', F_total);
        
        % Añadir restricciones
        for i = 1:K
            prob.Constraints.(sprintf('Q%d', i)) = Q{i} >= 0;
        end
        prob.Constraints.L = alpha * x + beta * y + gamma * z <= 0;
        
        % Punto inicial
        x0.x = 0; 
        x0.y = 0; 
        x0.z = -1;
        
        % Resolver problema de optimización
        try
            % Configurar opciones para evitar warnings y acelerar
            options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'interior-point');
            [sol, ~] = solve(prob, x0, 'Options', options);
            
            % Normalizar solución
            v_hat = [sol.x, sol.y, sol.z];
            v_tr_est(i_pos, :) = v_hat / norm(v_hat);
            
            % Estimar distancia usando el vector unitario estimado
            param_t_axis = {T, v_tr_est(i_pos, :), P_t, m_t};
            param_r_axis = {A_det, -v_tr_est(i_pos, :), FOV};
            
            x_real = X_r(i_pos); 
            y_real = Y_r(i_pos); 
            z_real = Z_r(i_pos);
            
            [~, P_r_axis, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
            P_r_axis_noisy = P_r_axis + sqrt(sigma2) * randn(1, N_samples);
            
            % Estimar distancia absoluta
            d_tr_est = sqrt(P_t * (m_t + 1) * A_det / (2 * pi * mean(P_r_axis_noisy)));
            
            % Calcular posición estimada
            estPos(i_pos, :) = T + v_tr_est(i_pos, :) * d_tr_est;
            
        catch ME
            % Si la optimización falla, usar una penalización alta
            if system_params.debug_mode
                warning('Optimización falló para posición %d: %s', i_pos, ME.message);
            end
            estPos(i_pos, :) = [NaN, NaN, NaN];
        end
    end
    
    %% Calcular error RMS
    errorNLS = realPos - estPos;
    
    % Calcular norma del error para cada posición
    errorNorm = zeros(N_pos, 1);
    valid_positions = 0;
    
    for i = 1:N_pos
        if ~any(isnan(estPos(i, :)))
            errorNorm(i) = norm(errorNLS(i, :));
            valid_positions = valid_positions + 1;
        else
            errorNorm(i) = Inf; % Penalización por fallo en optimización
        end
    end
    
    % Calcular RMS error promedio
    if valid_positions > 0
        % Usar solo posiciones válidas para el cálculo
        valid_errors = errorNorm(~isinf(errorNorm));
        rms_error = sqrt(mean(valid_errors.^2));
        
        % Penalizar si hay muchas posiciones fallidas
        failure_rate = (N_pos - valid_positions) / N_pos;
        if failure_rate > 0.1 % Si más del 10% de posiciones fallan
            rms_error = rms_error * (1 + 10 * failure_rate);
        end
    else
        % Si todas las optimizaciones fallan, retornar penalización máxima
        rms_error = 1000; % Error muy alto para descartar esta configuración
    end
    
    % Añadir penalizaciones por orientaciones extremas si está habilitado
    if isfield(system_params, 'penalize_extreme_angles') && system_params.penalize_extreme_angles
        for i = 1:K
            theta_deg = orientation_vector(2*i-1);
            if theta_deg < 5 || theta_deg > 85 % Penalizar ángulos muy verticales o muy horizontales
                rms_error = rms_error * 1.2;
            end
        end
    end
    
catch ME
    % Si hay cualquier error en la función, retornar penalización máxima
    if system_params.debug_mode
        warning('Error en función objetivo: %s', ME.message);
    end
    rms_error = 1000;
end

end
