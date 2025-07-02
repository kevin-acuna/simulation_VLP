%% Compare WLS Robust and GLS Estimators for VLP
% Este script compara los estimadores WLS robusto y GLS para VLP,
% correspondientes a los casos 5 y 6 del archivo main_3D_withNoise.m
% Usa parámetros del sistema de analyze_PEB_vs_theta_half.m pero solo con theta_half=45°
%
% Author: Kevin Acuña
% Date: July 2025

close all;
clear variables;
clc;
tic;

rng(42); % Para reproducibilidad

%% 1. System Parameters (from analyze_PEB_vs_theta_half.m with theta_half=45°)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% LED Parameters
theta_half = 45;                        % Semi-ángulo a media potencia (45°)
P_t = 0.405;                           % Potencia óptica transmitida [W]
T = [0, 0, 0];                         % Posición de la fuente de luz (origen)
m_t = -log(2)./log(cosd(theta_half));  % Orden lambertiano

% Use optimized orientations for K=5 from the CRLB analysis
% [theta1, rho1, theta2, rho2, ...] donde theta es elevación y rho es azimuth
orientations_K5 = [57.57, 87.79, 57.71, 358.55, 57.17, 177.68, 0.48, 294.81, 55.72, 268.14];
N_or = 5;  % Número de orientaciones

% Convert spherical orientation angles to cartesian vectors
n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = orientations_K5(2*i-1);  % elevation angle
    rho_i = orientations_K5(2*i);      % azimuth angle
    
    % Convert from spherical to cartesian coordinates
    n_t(i,1) = sind(theta_i) * cosd(rho_i);  % x component
    n_t(i,2) = sind(theta_i) * sind(rho_i);  % y component
    n_t(i,3) = -cosd(theta_i);               % z component (negative because pointing down)
end

% Photodetector Parameters
p = 4.8e-3; q = 5.5e-3;               % Dimensiones del fotodiodo rectangular [m]
N_det = 1;                             % Número de fotodiodos
A_det = p*q*N_det;                     % Área sensible del fotoreceptor [m²]
R_pd = 0.63;                           % Fotosensibilidad del fotodiodo [A/W]
FOV = 85;                              % Campo de visión del fotoreceptor [°]
n_r = [0, 0, 1];                       % Vector normal del fotoreceptor
sigma2 = 30e6*10^(-21.0)/(R_pd^2);     % Varianza AWGN [A²]
C = -P_t*(m_t+1)*A_det/(2*pi);         % Factor de normalización

%% 2. Room and Receiver Positions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Room dimensions
L = 3; W = 3; H = 2;                   % Largo, ancho y altura del cuarto [m]

% Generate random receiver positions
N_pos = 1000;                          % Número de posiciones aleatorias del receptor
X_r = -L/2 + L.*rand(1,N_pos);         % Coordenada x del receptor
Y_r = -W/2 + W.*rand(1,N_pos);         % Coordenada y del receptor
Z_r = -(0.8+0.4*rand(1,N_pos));        % Coordenada z del receptor (entre -0.8 y -1.2 m)

% Parameters for channel simulation
param_r = {A_det, n_r, FOV};           % Vector de parámetros del receptor

%% 3. Simulation Core - Calculate Received Powers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize variables
P_r = cell(N_pos, N_or);               % Potencia real recibida [W]
P_r_noisy = cell(N_pos, N_or);         % Potencia con ruido [W]
v_tr = zeros(N_pos, 3);                % Vector unitario real desde Tx a Rx
d_tr = zeros(N_pos, 1);                % Distancia real entre Tx y Rx
SNR = cell(N_pos, N_or);               % SNR en dB

% Inicializar variables para estimadores
estPosWLS_Robust = zeros(N_pos, 3);    % Posiciones estimadas WLS robusto
estPosGLS = zeros(N_pos, 3);           % Posiciones estimadas GLS

% Calculate received powers for each position and orientation
SNR_avg = [];
for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), d_tr(i_pos,1)] = OWC_LOS_channel(x, y, z, param_t, param_r);
        
        % Add noise to received power - 1000 noise realizations
        P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000));
        
        % Calculate SNR
        SNR{i_pos,i_dir} = 10*log10((R_pd*P_r{i_pos,i_dir})^2/sigma2);
        SNR_avg = [SNR_avg, 10*log10((R_pd*P_r{i_pos,i_dir})^2/sigma2)];
    end
end

% Replace -Inf SNR values with -80 dB for averaging
pos_negInf = isinf(SNR_avg);
SNR_avg(pos_negInf) = -80;
average_SNR = mean(SNR_avg);
fprintf('Promedio SNR: %.2f dB\n', average_SNR);

%% 4. Position Estimation using WLS Robust and GLS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i_pos = 1:N_pos
    x_real = X_r(i_pos); y_real = Y_r(i_pos); z_real = Z_r(i_pos); % Posición real del receptor
    
    %---------------------------------------------------------------------------------------%
    % Case 5: WLS robusto con pesos optimizados y distancia por beamsteering
    %---------------------------------------------------------------------------------------%
    % Obtener potencias crudas para cada orientación
    P_raw = zeros(1000, N_or); % Cada fila es una muestra, cada columna una orientación
    for i_dir = 1:N_or
        P_raw(:, i_dir) = P_r_noisy{i_pos, i_dir}; % 1000 muestras de potencia para cada orientación
    end
    
    % Obtener dirección usando el método WLS robusto
    [d_hat_robust, ~, ~] = vlp_wls_robust(n_t', P_raw, m_t);
    
    % Calcular distancia usando el enfoque beamsteering (Tx-Rx)
    v_tr_est_WLS_Robust = d_hat_robust';
    param_t_axis = {T, v_tr_est_WLS_Robust, P_t, m_t};
    param_r_axis = {A_det, -v_tr_est_WLS_Robust, FOV}; % Vector de parámetros del receptor
    [~, P_r_axis_WLS_Robust, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
    P_r_axis_noisy_WLS_Robust = (P_r_axis_WLS_Robust + sqrt(sigma2).*randn(1,1000)); % Potencia con ruido
    
    % Cálculo de la distancia con la fórmula del modelo lambertiano
    d_tr_est_WLS_Robust = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_WLS_Robust)));
    
    % Posición final combinando dirección WLS robusta con distancia
    estPosWLS_Robust(i_pos,:) = (v_tr_est_WLS_Robust.*d_tr_est_WLS_Robust);
    
    %---------------------------------------------------------------------------------------%
    % Case 6: GLS (Generalized Least Squares) con matriz de covarianza completa
    %---------------------------------------------------------------------------------------%
    % Usar mismo P_raw definido antes
    
    % Obtener dirección usando el método GLS (con matriz de covarianza completa)
    [d_hat_gls] = vlp_gls(n_t', P_raw, m_t, sigma2);
    
    % Calcular distancia usando el enfoque beamsteering (Tx-Rx)
    v_tr_est_GLS = d_hat_gls';
    param_t_axis = {T, v_tr_est_GLS, P_t, m_t};
    param_r_axis = {A_det, -v_tr_est_GLS, FOV}; % Vector de parámetros del receptor
    [~, P_r_axis_GLS, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
    P_r_axis_noisy_GLS = P_r_axis_GLS + sqrt(sigma2).*randn(1,1000); % Potencia con ruido
    
    % Cálculo de la distancia con la fórmula del modelo lambertiano
    d_tr_est_GLS = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_GLS)));
    
    % Posición final combinando dirección GLS con distancia por beamsteering
    estPosGLS(i_pos,:) = (v_tr_est_GLS.*d_tr_est_GLS);
end

%% 5. Error Calculation and CRLB Bound
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Prepare actual positions as matrix
realPos = [X_r ; Y_r ; Z_r]';

% Calculate error for WLS robust method
errorWLS_Robust = realPos - estPosWLS_Robust;
errorNormWLS_Robust = zeros(N_pos, 1);
for i = 1:N_pos
    errorNormWLS_Robust(i) = norm(errorWLS_Robust(i,:));
end
% Calculate RMSE for WLS robust
rmseWLS_Robust = sqrt(mean(errorNormWLS_Robust.^2));

% Calculate error for GLS method
errorGLS = realPos - estPosGLS;
errorNormGLS = zeros(N_pos, 1);
for i = 1:N_pos
    errorNormGLS(i) = norm(errorGLS(i,:));
end
% Calculate RMSE for GLS
rmseGLS = sqrt(mean(errorNormGLS.^2));

% Calculate CRLB (theoretical error bound)
tmp_errorNormCRLB = zeros(1, N_pos);
valid_indices = true(1, N_pos);  % Vector lógico para marcar índices válidos
num_imaginarios = 0;

for i = 1:N_pos
    % Parámetros para CRLB
    R_real = [X_r(i); Y_r(i); Z_r(i)];  % Posición del receptor
    K = P_t*(m_t+1)*A_det/(2*pi);       % Constante radiométrica P_t(m+1)/(2π)
    sigma2_crlb = sigma2;                % Varianza del ruido
    
    % Calcular CRLB para esta posición usando vlp_peb_beam
    peb_value = vlp_peb_beam(R_real, n_t', T', m_t, K, sigma2_crlb, 1000, 1000);
    
    % Verificar si el valor es imaginario
    if ~isreal(peb_value)
        valid_indices(i) = false;  % Marcar como no válido
        num_imaginarios = num_imaginarios + 1;
    else
        tmp_errorNormCRLB(i) = real(peb_value);  % Guardar solo la parte real
    end
end

% Filtrar valores imaginarios
errorNormCRLB = tmp_errorNormCRLB(valid_indices);
fprintf('Número total de valores CRLB imaginarios filtrados: %d\n', num_imaginarios);

% Calcular RMSE promedio para CRLB (valor teórico)
rmseCRLB = sqrt(mean(errorNormCRLB.^2));

% Calcular percentil 90 para los métodos
[f_RMS_WLS_Robust, x_RMS_WLS_Robust] = ecdf(errorNormWLS_Robust(:));
idx90_WLS_Robust = find(f_RMS_WLS_Robust<0.9, 1, 'last');
cdf90_RMS_WLS_Robust_cm = x_RMS_WLS_Robust(idx90_WLS_Robust)*100; % cm

[f_RMS_GLS, x_RMS_GLS] = ecdf(errorNormGLS(:));
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
fprintf('WLS Robusto: %.2f cm\n', cdf90_RMS_WLS_Robust_cm);
fprintf('GLS: %.2f cm\n', cdf90_RMS_GLS_cm);
fprintf('CRLB (límite teórico): %.2f cm\n', cdf90_RMS_CRLB_cm);

fprintf('\n-- RMSE --\n');
fprintf('WLS Robusto: %.4f m (%.2f cm)\n', rmseWLS_Robust, rmseWLS_Robust*100);
fprintf('GLS: %.4f m (%.2f cm)\n', rmseGLS, rmseGLS*100);
fprintf('CRLB (límite teórico): %.4f m (%.2f cm)\n', rmseCRLB, rmseCRLB*100);

fprintf('\n-- Ratio respecto al CRLB --\n');
fprintf('WLS Robusto: %.2f veces CRLB\n', rmseWLS_Robust/rmseCRLB);
fprintf('GLS: %.2f veces CRLB\n', rmseGLS/rmseCRLB);

%% 7. Visualization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% CDF plot
figure(1)
ecdf(errorNormWLS_Robust(:)*100,'Function','cdf'); hold on;
ecdf(errorNormGLS(:)*100,'Function','cdf');
ecdf(errorNormCRLB(:)*100,'Function','cdf');
grid on;
axis([0 16 0 1])
xlabel('Error de posicionamiento [cm]'); ylabel('CDF');
legend('WLS robusto', 'GLS', 'CRLB (límite teórico)','Location', 'southeast');
title('Comparativa de estimadores WLS robusto y GLS');

% 3D scatter plot
figure(2)
plot3(realPos(:,1), realPos(:,2), realPos(:,3),'ko', 'MarkerSize', 2); hold on;
plot3(estPosWLS_Robust(:,1), estPosWLS_Robust(:,2), estPosWLS_Robust(:,3), 'ms', 'MarkerSize', 2);
plot3(estPosGLS(:,1), estPosGLS(:,2), estPosGLS(:,3), 'cd', 'MarkerSize', 2);
xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
legend('Posición real', 'WLS robusto', 'GLS');
axis([-L/2 L/2 -W/2 W/2 min(Z_r)-0.1 max(Z_r)+0.1])
grid on;
title('Distribución espacial de posiciones estimadas');

% Tiempo de ejecución
tiempo_ejecucion = toc;
fprintf('\nTiempo de ejecución: %.2f segundos\n', tiempo_ejecucion);

%% Appendix: Functions used by the main script

function [H0, P_r_LOS, v_tr, d_tr] = OWC_LOS_channel(x, y, z, param_t, param_r)
% 1. Parameters initialization
T = param_t{1}; % Transmitter coordinates
n_t = param_t{2}; % Transmitter normal
P_t = param_t{3}; % Transmitter optical power
m = param_t{4}; % Transmitter Lambertian order
R = [x,y,z]; % Receiver coordinates
A_det = param_r{1}; % Receiver sensitive area
n_r = param_r{2}; % Receiver normal
FOV = param_r{3}; % Reveiver field of view

% 2. LOS received optical power calculation
v_tr = (R-T)./norm(R-T);
d_tr = sqrt(dot(R-T,R-T));
cos_phi = dot(n_t,v_tr);
cos_psi = dot(n_r,-v_tr);
if( abs(acosd(cos_psi)) <= FOV && cos_phi > 0 )
    H0 = (m+1)*A_det/(2*pi*d_tr^2)*cos_phi^m*cos_psi; % Channel DC gain (no units)
else
    H0 = 0;
end
P_r_LOS = P_t*H0;
end

function PEB = vlp_peb_beam(theta, nt, T, m, K, sigma2, N, Nb)
%-----------------------------------------------------------------
% theta   : 3×1  [x; y; z]      -> posición Rx (m)
% nt      : 3×n  orientaciones unitarias consideradas en la fase-1
% T       : 3×1  posición Tx [0;0;H] (m)
% m       : orden Lambertiano
% K       : constante radiométrica  P_t (m+1)A_det/(2π)
% sigma2  : varianza de UNA única muestra (W²)
% N       : nº de muestras promediadas en cada orientación de la fase-1
% Nb      : nº de muestras promediadas en la orientación *beam-steered*
%-----------------------------------------------------------------
% Devuelve: PEB  =  √tr{ I⁻¹ }  (m RMS)  con ambas fases incluidas
%-----------------------------------------------------------------

% -------- 1. Geometría ------------------------------------------
d      = theta - T;            % vector Tx→Rx (3×1)
nr     = [0;0;1];              % normal del receptor (arriba)
cr     = nr.'*(-d);            % cos(ψ)=H−z
normd  = norm(d);
n      = size(nt,2);

% Dirección "real" para la orientación beam-steered
d_unit = d / normd;            % = v_tr  (3×1)

% -------- 2. Fisher Information Matrix --------------------------
I = zeros(3);                  % inicializa FIM

% --- (a) Orientaciones de la fase-1 -----------------------------
for i = 1:n
    nt_i = nt(:,i);
    ci   = nt_i.'*d;           % cos(φ_i)*‖d‖
    g_i  = ( ...
           m     * ci^(m-1) * cr / normd^(m+3) * nt_i ...
         - (m+3)  * ci^m     * cr / normd^(m+5) * d     ...
         -             ci^m      / normd^(m+3) * nr );
    I = I + (N * K^2 / sigma2) * (g_i * g_i.');
end

% --- (b) Orientación beam-steered -------------------------------
% nt_beam =  d_unit   ;   cosφ = 1,  cosψ = 1
ci_b  = normd;                 % n_t·d  = ‖d‖  (porque cosφ=1)
cr_b  = cr;                    % sigue siendo H−z
g_b   = ( ...
        m     * ci_b^(m-1) * cr_b / normd^(m+3) * d_unit ...
      - (m+3) * ci_b^m     * cr_b / normd^(m+5) * d      ...
      -            ci_b^m         / normd^(m+3) * nr );
I = I + (Nb * K^2 / sigma2) * (g_b * g_b.');   % contribución extra

% -------- 3. PEB (RMS) ------------------------------------------
PEB = sqrt(trace(inv(I)));      % √tr{I⁻¹}
end
