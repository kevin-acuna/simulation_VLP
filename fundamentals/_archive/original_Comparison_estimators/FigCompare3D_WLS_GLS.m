%% Compare WLS Robust and GLS Estimators for VLP
% Este script compara los estimadores WLS y GLS para VLP,
% correspondientes a los casos 5 y 6 del archivo main_3D_withNoise.m
% Usa parámetros del sistema de analyze_PEB_vs_theta_half.m pero solo con theta_half=45°
%
% Author: Kevin Acuña
% Date: 28/07/2025


% Escenarios con problemas:
% 1. Cuando tenemos N=9 el WLS presenta errores considerables.
% 2. El comportamiento comparativo del RMS del CRLB debe de considerarse.
%    - Quitar en la grafica el CDF del CRLB.
%    - Comparar el RMSE de CRLB.
close all;clear variables;clc;

% =================================================
% PARAMETROS A CONFIGURAR
% =================================================
rng(42); % Repetibilidad
N_or = 9;  % Número de orientaciones
save_files = 0;

% Define common parameters
L = 3; % Length of room [m]
W = 3; % Width of room [m]
Hmax = 1.2; % Maximum height [m]

% Parametros para el estudio 
step = 0.2; % step en X,Y
stepH = 0.2; % Step size [m]
% % % Parametros para la Figura Comparacion de posiciones estimadas vs reales
% step = 0.25; % step X,Y
% stepH = 0.6; % Step size [m]


% Seleccionar modo de posiciones del receptor
% Opciones: 
%   'fixed'  - Utiliza posiciones fijas en grid de testbed (como en analyze_PEB_vs_theta_half.m)
%   'random' - Utiliza 1000 posiciones aleatorias (como en main_3D_withNoise.m)
receiver_mode = 'fixed';  % Cambiar aquí para seleccionar el modo deseado

% Control para filtrado de valores imaginarios
% true: elimina todos los valores imaginarios para estadísticas más precisas
% false: mantiene todos los valores (comportamiento original)
filter_imaginary = false;  % Cambiar a false para mantener todos los valores



% Use optimized orientations for K=5 from the CRLB analysis
% [theta1, rho1, theta2, rho2, ...] donde theta es elevación y rho es azimuth
% Configurations
orientations_K3=[35.40,140.13,33.31,36.38,29.58,262.70];
orientations_K4=[38.89,90.56,41.48,0.15,41.80,180.10,38.79,270.24];
orientations_K5=[0.10,211.14,50.55,89.96,50.66,179.99,50.37,359.93,50.59,269.96];
orientations_K6=[17.19,306.94,54.55,266.13,22.49,140.37,52.23,360.00,52.41,84.05,55.76,185.16];
orientations_K7=[58.91,355.65,53.77,170.74,27.75,43.75,5.36,305.88,54.35,96.46,35.10,220.04,54.78,278.61];
orientations_K8=[51.82,89.38,61.50,268.26,27.32,316.99,6.46,318.34,57.76,5.84,53.65,171.30,37.97,200.35,39.27,91.12];
orientations_K9=[0,28.15,56.92,178.69,36.54,266.83,33.86,182.29,42.20,78.36,53.07,97.46,57.91,359.73,37.07,355.08,58.23,272.07];
orientations_K10=[56.00,3.61,53.20,182.48,54.93,356.82,11.94,38.06,61.28,270.34,50.17,91.30,47.56,174.73,43.39,89.36,32.54,277.55,15.14,255.31];

all_orientations = {orientations_K3, orientations_K4, orientations_K5, orientations_K6, orientations_K7, orientations_K8, orientations_K9, orientations_K10};
K_values = [3, 4, 5, 6, 7, 8, 9, 10];


%% 1. System Parameters (from analyze_PEB_vs_theta_half.m with theta_half=45°)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Number of samples per orientation
N_samples=1000;

% LED Parameters
theta_half = 45;                        % Semi-ángulo a media potencia (45°)
P_t = 0.405;                           % Potencia óptica transmitida [W]
T = [0, 0, 2];                         % Posición de la fuente de luz (origen)
m_t = -log(2)./log(cosd(theta_half));  % Orden lambertiano

% Photodetector Parameters
p = 4.8e-3; q = 5.5e-3;               % Dimensiones del fotodiodo rectangular [m]
N_det = 1;                             % Número de fotodiodos
A_det = p*q*N_det;                     % Área sensible del fotoreceptor [m²]
R_pd = 0.63;                           % Fotosensibilidad del fotodiodo [A/W]
FOV = 85;                              % Campo de visión del fotoreceptor [°]
n_r = [0, 0, 1];                       % Vector normal del fotoreceptor
sigma2 = 30e6*10^(-21.0);     % Varianza AWGN [A²]
C = -P_t*(m_t+1)*A_det/(2*pi);         % Factor de normalización



% Convert spherical orientation angles to cartesian vectors
n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = all_orientations{N_or-2}(2*i-1);  % elevation angle
    rho_i = all_orientations{N_or-2}(2*i);      % azimuth angle
    % Convert from spherical to cartesian coordinates
    n_t(i,1) = sind(theta_i) * cosd(rho_i);  % x component
    n_t(i,2) = sind(theta_i) * sind(rho_i);  % y component
    n_t(i,3) = -cosd(theta_i);               % z component (negative because pointing down)
end

%% 3. Generate Receiver Positions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if strcmp(receiver_mode, 'fixed')
    % Opción 1: Posiciones fijas (testbed grid de analyze_PEB_vs_theta_half.m)
    % Generate 3D grid of positions
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
    
    % Convert to vector form
    X_r = X(:)';
    Y_r = Y(:)';
    Z_r = Z(:)';
    
    % Count the number of positions
    N_pos = length(X_r);
    
    fprintf('Usando %d posiciones fijas en grid (testbed)\n', N_pos);
else
    % Opción 2: Posiciones aleatorias (como en main_3D_withNoise.m)
    N_pos = 1000; % Number of random Rx positions simulated
    X_r = -L/2 + L.*rand(1,N_pos); % x-axis Rx coordinate
    Y_r = -W/2 + W.*rand(1,N_pos); % y-axis Rx coordinate
    Z_r = Hmax*rand(1,N_pos); % z-axis Rx coordinate (random altitudes)
    
    fprintf('Usando %d posiciones aleatorias\n', N_pos);
end

fprintf('Testing with %d receiver positions\n', N_pos);
fprintf('Position range: X ∈ [%.1f, %.1f], Y ∈ [%.1f, %.1f], Z ∈ [%.1f, %.1f]\n', ...
    min(X_r), max(X_r), ...
    min(Y_r), max(Y_r), ...
    min(Z_r), max(Z_r));

% Parameters for channel simulation
param_r = {A_det, n_r, FOV};           % Vector de parámetros del receptor

% 3. Simulation Core - Calculate Received Powers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize variables
P_r = cell(N_pos, N_or);               % Potencia real recibida [W]
P_r_noisy = cell(N_pos, N_or);         % Potencia con ruido [W]
v_tr = zeros(N_pos, 3);                % Vector unitario real desde Tx a Rx
d_tr = zeros(N_pos, 1);                % Distancia real entre Tx y Rx
SNR = cell(N_pos, N_or);               % SNR en dB

% Inicializar variables para estimadores
estPosWLS = zeros(N_pos, 3);    % Posiciones estimadas WLS
estPosGLS = zeros(N_pos, 3);           % Posiciones estimadas GLS

% Calculate received powers for each position and orientation
SNR_avg = [];
for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), d_tr(i_pos,1)] = OWC_LOS_channel(x, y, z, param_t, param_r);
        
        % Add noise to received power - 1000 noise realizations
        P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,N_samples));
        
        % Calculate SNR-lineal
        SNR_lin{i_pos,i_dir} = ((R_pd*P_r{i_pos,i_dir})^2/(sigma2*R_pd^2)); %lineal
        SNR_avg = [SNR_avg, ((R_pd*P_r{i_pos,i_dir})^2/(sigma2*R_pd^2))]; %lineal
    end
end

average_SNR_lin = mean(SNR_avg);
average_SNR_db = 10*log10(average_SNR_lin);
fprintf('Promedio SNR: %.2f dB\n', average_SNR_db);

%% 4. Position Estimation using WLS Robust and GLS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

time_WLS=[];
time_GLS=[];

for i_pos = 1:N_pos
    x_real = X_r(i_pos); y_real = Y_r(i_pos); z_real = Z_r(i_pos); % Posición real del receptor
    
    %---------------------------------------------------------------------------------------%
    % Case 5: WLS con pesos optimizados y distancia por beamsteering
    %---------------------------------------------------------------------------------------%
    % Obtener potencias crudas para cada orientación
    P_raw = zeros(N_samples, N_or); % Cada fila es una muestra, cada columna una orientación
    for i_dir = 1:N_or
        P_raw(:, i_dir) = P_r_noisy{i_pos, i_dir}; % N_samples muestras de potencia para cada orientación
    end

    % % =============================
    % %Por propocitos de debug (usar el breakpoint)
    % if(i_pos==1568)
    %     kevin=1; 
    % end
    % % =============================

    tic;
    % Obtener dirección usando el método WLS 
    [d_hat_robust, ~, ~] = vlp_wls(n_t', P_raw, m_t);
    tiempo_ejecucion = toc;
    time_WLS = [time_WLS; tiempo_ejecucion];

    % Calcular distancia usando el enfoque beamsteering (Tx-Rx)
    v_tr_est_WLS = d_hat_robust';
    param_t_axis = {T, v_tr_est_WLS, P_t, m_t};
    param_r_axis = {A_det, -v_tr_est_WLS, FOV}; % Vector de parámetros del receptor
    [~, P_r_axis_WLS, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
    P_r_axis_noisy_WLS = (P_r_axis_WLS + sqrt(sigma2).*randn(1,N_samples)); % Potencia con ruido
    
    % Cálculo de la distancia con la fórmula del modelo lambertiano
    d_tr_est_WLS = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_WLS)));
    
    % Posición final combinando dirección WLS robusta con distancia
    estPosWLS(i_pos,:) = T + (v_tr_est_WLS.*d_tr_est_WLS);


    %---------------------------------------------------------------------------------------%
    % Case 6: GLS (Generalized Least Squares) con matriz de covarianza completa
    %---------------------------------------------------------------------------------------%
    % Usar mismo P_raw definido antes
    tic;
    % Obtener dirección usando el método GLS (con matriz de covarianza completa)
    [d_hat_gls] = vlp_gls(n_t', P_raw, m_t, sigma2);
    tiempo_ejecucion = toc;
    time_GLS = [time_GLS; tiempo_ejecucion];
    % Calcular distancia usando el enfoque beamsteering (Tx-Rx)
    v_tr_est_GLS = d_hat_gls';
    param_t_axis = {T, v_tr_est_GLS, P_t, m_t};
    param_r_axis = {A_det, -v_tr_est_GLS, FOV}; % Vector de parámetros del receptor
    [~, P_r_axis_GLS, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
    P_r_axis_noisy_GLS = P_r_axis_GLS + sqrt(sigma2).*randn(1,N_samples); % Potencia con ruido
    
    % Cálculo de la distancia con la fórmula del modelo lambertiano
    d_tr_est_GLS = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_GLS)));
    
    % Posición final combinando dirección GLS con distancia por beamsteering
    estPosGLS(i_pos,:) = T + (v_tr_est_GLS.*d_tr_est_GLS);

end

%% 5. Error Calculation and CRLB Bound
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Prepare actual positions as matrix
realPos = [X_r ; Y_r ; Z_r]';

% Calculate error for WLS method
errorWLS = realPos - estPosWLS;
errorNormWLS = zeros(N_pos, 1);
valid_indices_WLS = true(N_pos, 1);  % Vector lógico para marcar índices válidos WLS
num_imaginarios_WLS = 0;

for i = 1:N_pos
    % Verificar si hay componentes imaginarias en la estimación WLS
    if ~isreal(estPosWLS(i,:))
        valid_indices_WLS(i) = false;  % Marcar como no válido
        num_imaginarios_WLS = num_imaginarios_WLS + 1;
        % Si no filtramos, usar magnitud como error
        if ~filter_imaginary
            errorNormWLS(i) = norm(abs(errorWLS(i,:)));
        end
    else
        errorNormWLS(i) = norm(errorWLS(i,:));
    end
end

% Procesar resultados WLS según configuración de filtrado
if filter_imaginary
    filtered_errorNormWLS = errorNormWLS(valid_indices_WLS);
    fprintf('Número total de valores WLS imaginarios filtrados: %d\n', num_imaginarios_WLS);
else
    filtered_errorNormWLS = errorNormWLS;
    fprintf('Número total de valores WLS imaginarios encontrados (no filtrados): %d\n', num_imaginarios_WLS);
end

% Calculate RMSE for WLS
rmseWLS = sqrt(mean(filtered_errorNormWLS.^2));

% Calculate error for GLS method
errorGLS = realPos - estPosGLS;
errorNormGLS = zeros(N_pos, 1);
valid_indices_GLS = true(N_pos, 1);  % Vector lógico para marcar índices válidos GLS
num_imaginarios_GLS = 0;

for i = 1:N_pos
    % Verificar si hay componentes imaginarias en la estimación GLS
    if ~isreal(estPosGLS(i,:))
        valid_indices_GLS(i) = false;  % Marcar como no válido
        num_imaginarios_GLS = num_imaginarios_GLS + 1;
        % Si no filtramos, usar magnitud como error
        if ~filter_imaginary
            errorNormGLS(i) = norm(abs(errorGLS(i,:)));
        end
    else
        errorNormGLS(i) = norm(errorGLS(i,:));
    end
end

if filter_imaginary
    % Filtrar valores imaginarios GLS
    filtered_errorNormGLS = errorNormGLS(valid_indices_GLS);
    fprintf('Número total de valores GLS imaginarios filtrados: %d\n', num_imaginarios_GLS);
else
    % Usar todos los valores, incluyendo magnitud de imaginarios
    filtered_errorNormGLS = errorNormGLS;
    fprintf('Número total de valores GLS imaginarios encontrados (no filtrados): %d\n', num_imaginarios_GLS);
end

% Calculate RMSE for GLS
rmseGLS = sqrt(mean(filtered_errorNormGLS.^2));

% Calculate CRLB (theoretical error bound)
tmp_errorNormCRLB = zeros(1, N_pos);
valid_indices_CRLB = true(1, N_pos);  % Vector lógico para marcar índices válidos CRLB
num_imaginarios_CRLB = 0;

for i = 1:N_pos
    % Parámetros para CRLB
    R_real = [X_r(i); Y_r(i); Z_r(i)];  % Posición del receptor
    K = P_t*(m_t+1)*A_det/(2*pi);       % Constante radiométrica P_t(m+1)/(2π)
    
    % Calcular CRLB para esta posición usando la función PEB_complete
    % PEB_complete(R, nt_orientations, T, Pt, m, A_det, theta_half, Psi_FOV, sigma2, N)
    % Convertimos los parámetros para la nueva función
    peb_value = PEB_complete(R_real, n_t', T', P_t, m_t, A_det, deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples);
    
    % Verificar si el valor es imaginario
    if ~isreal(peb_value)
        valid_indices_CRLB(i) = false;  % Marcar como no válido
        num_imaginarios_CRLB = num_imaginarios_CRLB + 1;
        % Si no filtramos, usar magnitud como error
        if ~filter_imaginary
            tmp_errorNormCRLB(i) = abs(peb_value);  % Usar magnitud del valor complejo
        end
    else
        tmp_errorNormCRLB(i) = real(peb_value);  % Guardar solo la parte real
    end
end

if filter_imaginary
    % Filtrar valores imaginarios CRLB
    errorNormCRLB = tmp_errorNormCRLB(valid_indices_CRLB);
    fprintf('Número total de valores CRLB imaginarios filtrados: %d\n', num_imaginarios_CRLB);
else
    % Usar todos los valores, incluyendo magnitud de imaginarios
    errorNormCRLB = tmp_errorNormCRLB;
    fprintf('Número total de valores CRLB imaginarios encontrados (no filtrados): %d\n', num_imaginarios_CRLB);
end

% Calcular RMSE promedio para CRLB (valor teórico)
rmseCRLB = sqrt(mean(errorNormCRLB.^2));

% Calcular percentil 90 para los métodos (usando valores filtrados)
[f_RMS_WLS, x_RMS_WLS] = ecdf(filtered_errorNormWLS(:));
idx90_WLS = find(f_RMS_WLS<0.9, 1, 'last');
cdf90_RMS_WLS_cm = x_RMS_WLS(idx90_WLS)*100; % cm

[f_RMS_GLS, x_RMS_GLS] = ecdf(filtered_errorNormGLS(:));
idx90_GLS = find(f_RMS_GLS<0.9, 1, 'last');
cdf90_RMS_GLS_cm = x_RMS_GLS(idx90_GLS)*100; % cm

% Estadísticas para CRLB
[f_RMS_CRLB, x_RMS_CRLB] = ecdf(errorNormCRLB(:));
idx90_CRLB = find(f_RMS_CRLB<0.9, 1, 'last');
cdf90_RMS_CRLB_cm = x_RMS_CRLB(idx90_CRLB)*100; % cm

%% 6. Results Display
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Mostrar resultados de error
fprintf('\n==== RESUMEN DE ERRORES ====\n');
fprintf('\n-- Percentil 90 (CDF) --\n');
fprintf('WLS: %.2f cm\n', cdf90_RMS_WLS_cm);
fprintf('GLS: %.2f cm\n', cdf90_RMS_GLS_cm);
fprintf('CRLB (límite teórico): %.2f cm\n', cdf90_RMS_CRLB_cm);

fprintf('\n-- RMSE --\n');
fprintf('WLS: %.4f m (%.2f cm)\n', rmseWLS, rmseWLS*100);
fprintf('GLS: %.4f m (%.2f cm)\n', rmseGLS, rmseGLS*100);
fprintf('CRLB (límite teórico): %.4f m (%.2f cm)\n', rmseCRLB, rmseCRLB*100);

fprintf('\n-- Ratio respecto al CRLB --\n');
fprintf('WLS: %.2f veces CRLB\n', rmseWLS/rmseCRLB);
fprintf('GLS: %.2f veces CRLB\n', rmseGLS/rmseCRLB);



%%
% 3D scatter plot
figure(2)
plot3(realPos(:,1), realPos(:,2), realPos(:,3),'ko', 'MarkerSize', 2); hold on;

if filter_imaginary
    % Mostrar solo posiciones WLS reales (filtradas)
    plot3(estPosWLS(valid_indices_WLS,1), estPosWLS(valid_indices_WLS,2), estPosWLS(valid_indices_WLS,3), 'ms', 'MarkerSize', 2);
    
    % Mostrar solo posiciones GLS reales (filtradas)
    plot3(estPosGLS(valid_indices_GLS,1), estPosGLS(valid_indices_GLS,2), estPosGLS(valid_indices_GLS,3), 'cd', 'MarkerSize', 2);
    
else
    % Mostrar todas las posiciones (usando valores reales)
    plot3(estPosWLS(:,1), estPosWLS(:,2), estPosWLS(:,3), 'rs', 'MarkerSize', 2);
    plot3(estPosGLS(:,1), estPosGLS(:,2), estPosGLS(:,3), 'bd', 'MarkerSize', 2);
    
end

xlabel('X [m]','Interpreter','latex');
ylabel('Y [m]','Interpreter','latex');
zlabel('Z [m]','Interpreter','latex');
legend('Reference', 'WLS', 'GLS','Interpreter','latex');
axis([-L/2 L/2 -W/2 W/2 min(Z_r)-0.1 max(Z_r)+0.1])
grid on;
% view(44.6,17.28);
view(68.96,16.08);
% Tiempo de ejecución

figure(2);
set(gcf, 'Color', 'white');
print('Fig_Comparison.png', '-dpng', '-r300');


fprintf('\nTiempo de ejecución: %.2f segundos\n', tiempo_ejecucion);

if save_files==1
    save(sprintf('K%d_CRLB_fixed.mat', N_or), 'errorNormCRLB')
    save(sprintf('K%d_GLS_fixed.mat', N_or), 'filtered_errorNormGLS', 'time_GLS')
    save(sprintf('K%d_WLS_fixed.mat', N_or), 'filtered_errorNormWLS', 'time_WLS')
end