close all;
clear variables;
clc;
tic;

%% 1. Simulation Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                    Main Simulation Parameters                     %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------------------------%
% LIGHT SOURCES CORE SIMULATION PARAMETERS %
%------------------------------------------%
theta_half = 45; % 60; % Semi-angle at half-power [°]
P_t = 0.405; % 1; % Transmitted optical power [W]
orientationMode = 'deterministic'; % 'randomEqual'
N_or = 5; % Number of orientations considered by the non-linear least square estimator
theta = 30; % Main angle of orientation (only for deterministic mode) [°]
L = 2.4; W = 2.4; H = 2; % Full length, width and height of the room [m]
% L = 2; W = 2; H = 2.5; % Full Length, width and height of the room [m]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                          AP Parameters                            %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------%
% LIGHT SOURCES GEOMETRY %
%------------------------%
T = [0 0 0]; x_n = T(1); y_n = T(2); z_n = T(3); % Positions of the light source (origin of the main frame)
m_t = -log(2)./log(cosd(theta_half)); % Lambertian order of emission
if( strcmp(orientationMode, 'randomEqual') ) % Case of random Tx orientation (from 3 to 9 orientations supported)
    U1 = [-0.5+rand(1,2), -H]; U2 = [-0.5+rand(1,2), -H]; U3 = [-0.5+rand(1,2), -H];
    U4 = [-0.5+rand(1,2), -H]; U5 = [-0.5+rand(1,2), -H]; U6 = [-0.5+rand(1,2), -H];
    U7 = [-0.5+rand(1,2), -H]; U8 = [-0.5+rand(1,2), -H]; U9 = [-0.5+rand(1,2), -H];
    n_t = [U1; U2; U3; U4; U5; U6; U7; U8; U9];
    for i = 1:size(n_t,1)
        n_t(i,:) = n_t(i,:)./norm(n_t(i,:));
    end
else % Case of fixed Tx orientation (from 3 to 9 orientations supported)
    n_t = [       0,              0,             -1;
                  0,    sind(theta),   -cosd(theta);
        sind(theta),              0,   -cosd(theta);
       -sind(theta),              0,   -cosd(theta);
                  0,   -sind(theta),   -cosd(theta);
              sqrt(2)/2*sind(theta),   sqrt(2)/2*sind(theta),  -cosd(theta);
              sqrt(2)/2*sind(theta),  -sqrt(2)/2*sind(theta),  -cosd(theta);
             -sqrt(2)/2*sind(theta),   sqrt(2)/2*sind(theta),  -cosd(theta);
             -sqrt(2)/2*sind(theta),  -sqrt(2)/2*sind(theta),  -cosd(theta)];
end
% Cartesian coordinates of the orientations vectors
a_i = n_t(1,1); b_i = n_t(1,2); c_i = n_t(1,3);
a_j = n_t(2,1); b_j = n_t(2,2); c_j = n_t(2,3);
a_k = n_t(3,1); b_k = n_t(3,2); c_k = n_t(3,3);
a_l = n_t(4,1); b_l = n_t(4,2); c_l = n_t(4,3);
a_m = n_t(5,1); b_m = n_t(5,2); c_m = n_t(5,3);
a_n = n_t(6,1); b_n = n_t(6,2); c_n = n_t(6,3);
a_o = n_t(7,1); b_o = n_t(7,2); c_o = n_t(7,3);
a_p = n_t(8,1); b_p = n_t(8,2); c_p = n_t(8,3);
a_q = n_t(9,1); b_q = n_t(9,2); c_q = n_t(9,3);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                          Rx Parameters                            %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%--------------------------%
% PHOTODETECTOR PARAMETERS %
%--------------------------%
p = 4.8e-3; q = 5.5e-3; % Dimensions of the rectangular photodiode [m]
N_det = 1; % Number of photodiodes
A_det = p*q*N_det; % Photoreceiver sensitive area [m²]
R_pd = 0.63; % Photosensitivity of the photodiode [A/W]
FOV = 85; % Fielf-of-view of the photoreceiver [°]
n_r = [0, 0, 1]; % Normal vector of the photoreceiver
alpha = n_r(1,1); beta = n_r(1,2); gamma = n_r(1,3); % Cartesian coordinates of the normal vector of the photoreceiver
sigma2 = 30e6*10^(-21.0); % AWGN variance [A²]
C = -P_t*(m_t+1)*A_det/(2*pi); % Normalization factor

%---------------------------%
% RECEIVER PLANE PARAMETERS %
%---------------------------%
N_pos = 1000; % Number of random Rx positions simulated
X_r = -L/2 + L.*rand(1,N_pos); % x-axis Rx coordinate
Y_r = -W/2 + W.*rand(1,N_pos); % y-axis Rx coordinate
% Z_r = (0.96-H).*ones(1,N_pos); % z-axis Rx coordinate (single reception plane)
Z_r = -(0.8+rand(1,N_pos)); % x-axis Rx coordinate (random altitudes)
% X_r = -L+2.*L.*rand(1,N_pos); % x-axis Rx coordinate
% Y_r = -W+2.*W.*rand(1,N_pos); % x-axis Rx coordinate
% Z_r = -H+rand(1,N_pos); % x-axis Rx coordinate
param_r = {A_det, n_r, FOV}; % Vector of the Rx parameters used for channel simulation


% Inicializar variables para WLS y método híbrido
estPosWLS = zeros(N_pos, 3);
estPosWLS_SVD = zeros(N_pos, 3);
estPosWLS_Robust = zeros(N_pos, 3);
estPosGLS = zeros(N_pos, 3);
%% 2. Simulations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                         Simulation Core                           %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
P_r = cell(N_pos,N_or); % Real received power [W]
P_r_noisy = cell(N_pos,N_or); % Noise power observed [W]
v_tr = zeros(N_pos,3); % Real unit vector from Tx to Rx
v_tr_est = zeros(N_pos,3); % Estimated unit vector from Tx to Rx
d_tr = zeros(N_pos,1); % Real absolute distance between Tx and Rx
SNR = cell(N_pos,N_or); % SNR in dB
%-----------------------------------------------------%
% Step 1: Computation of the observed received powers %
%-----------------------------------------------------%
for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), d_tr(i_pos,1)] = OWC_LOS_channel(x, y, z, param_t, param_r);
        P_r_noisy{i_pos,i_dir} = (R_pd.*P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000))./R_pd; % Noise power observed after normalization (needed for the non-linear MATLAB solver to coverge) [W]

        % para el metodo 'WLS' (basic)
        SNR{i_pos,i_dir} = 10*log10( (R_pd*P_r{i_pos,i_dir})^2/sigma2 );

    end
end

%----------------------------------------%
% Step 2: Estimation of the Rx positions %
%----------------------------------------%
for i_pos = 1:N_pos
    x_real = X_r(i_pos); y_real = Y_r(i_pos); z_real = Z_r(i_pos); % Real position of the Rx
    
    %---------------------------------------------------------------------------------------%
    % Case 2: Indirect position estimation with with estimation of the received power + SVD %      
    %---------------------------------------------------------------------------------------%
    K_ij = (mean(P_r_noisy{i_pos,1})./mean(P_r_noisy{i_pos,2})).^(1/m_t);
    K_jk = (mean(P_r_noisy{i_pos,2})./mean(P_r_noisy{i_pos,3})).^(1/m_t);
    K_ik = (mean(P_r_noisy{i_pos,1})./mean(P_r_noisy{i_pos,3})).^(1/m_t);
    alpha_ij = a_i - K_ij*a_j;
    alpha_jk = a_j - K_jk*a_k;
    alpha_ik = a_i - K_ik*a_k;
    beta_ij = b_i - K_ij*b_j;
    beta_jk = b_j - K_jk*b_k;
    beta_ik = b_i - K_ik*b_k;
    gamma_ij = c_i - K_ij*c_j;
    gamma_jk = c_j - K_jk*c_k;
    gamma_ik = c_i - K_ik*c_k;
    eigenVectorsSVD{i_pos,1} = null( [alpha_ij, beta_ij, gamma_ij;
                                      alpha_jk, beta_jk, gamma_jk;
                                      alpha_ik, beta_ik, gamma_ik]);

    if( length(eigenVectorsSVD{i_pos,1}) == 3 && eigenVectorsSVD{i_pos,1}(3) >= 0 )
        v_tr_est_SVD(i_pos,:) = -eigenVectorsSVD{i_pos,1};
        param_t_axis = {T, v_tr_est_SVD(i_pos,:), P_t, m_t};
        param_r_axis = {A_det, -v_tr_est_SVD(i_pos,:), FOV}; % Vector of the Rx parameters used for channel simulation
        [~, P_r_axis_SVD(i_pos), ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
        P_r_axis_noisy_SVD(i_pos,:) = (R_pd.*P_r_axis_SVD(i_pos) + sqrt(sigma2).*randn(1,1000))./R_pd; % Corresponding noise power observed [W]
        d_tr_est_SVD(i_pos) = sqrt( P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_SVD(i_pos,:))) );
        estPosSVD(i_pos,:) = v_tr_est_SVD(i_pos,:).*d_tr_est_SVD(i_pos);
    elseif( length(eigenVectorsSVD{i_pos,1}) == 3 && eigenVectorsSVD{i_pos,1}(3) < 0 )
        v_tr_est_SVD(i_pos,:) = eigenVectorsSVD{i_pos,1};
        param_t_axis = {T, v_tr_est_SVD(i_pos,:), P_t, m_t};
        param_r_axis = {A_det, -v_tr_est_SVD(i_pos,:), FOV}; % Vector of the Rx parameters used for channel simulation
        [~, P_r_axis_SVD(i_pos), ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
        P_r_axis_noisy_SVD(i_pos,:) = (R_pd.*P_r_axis_SVD(i_pos) + sqrt(sigma2).*randn(1,1000))./R_pd; % Corresponding noise power observed [W]
        d_tr_est_SVD(i_pos) = sqrt( P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_SVD(i_pos,:))) );
        estPosSVD(i_pos,:) = v_tr_est_SVD(i_pos,:).*d_tr_est_SVD(i_pos);
    else
        fprintf('Error: No valid orientation found for position %d\n', i_pos);
        fprintf('x_real = %f\n', x_real);
        fprintf('y_real = %f\n', y_real);
        fprintf('z_real = %f\n', z_real);
        v_tr_est_SVD(i_pos,:) = [NaN, NaN, NaN];
        estPosSVD(i_pos,:) = [NaN, NaN, NaN];
    end

    %---------------------------------------------------------------------------------------%
    % Case 3: WLS (simplified) %      
    %---------------------------------------------------------------------------------------%
    % Preparar datos para estimación WLS
    % Extraer potencias recibidas para esta posición
    Pvec = zeros(N_or, 1);
    snrVec = zeros(N_or, 1);
    for i_dir = 1:N_or
        Pvec(i_dir) = mean(P_r_noisy{i_pos,i_dir}); % Potencia media para cada orientación
        snrVec(i_dir) = SNR{i_pos,i_dir}; % SNR en dB
    end
    
    % Validar potencias
    if Pvec(1) <= 0
        fprintf('Error: Invalid power for position %d\n', i_pos);
        estPosWLS(i_pos,:) = [NaN, NaN, NaN];
        continue;
    end
    
    % Convertir SNR a lineal y normalizar pesos
    w_raw = 10.^(snrVec/10); % Convertir de dB a lineal
    wlims = [1e-3, 1e3]; % Límites de peso
    w_clipped = min(max(w_raw, wlims(1)), wlims(2)); % Limitar pesos
    w_norm = w_clipped / max(w_clipped); % Normalizar
    
    % 1) Calcular betas (ratios de potencia elevados a 1/m_t)
    beta = (Pvec(2:end) ./ Pvec(1)).^(1/m_t);  % (N_or-1)x1
    
    % 2) Construir matriz de restricción para hallar dirección
    n1 = n_t(1,:)'; % Orientación de referencia (primera)
    A_dir = zeros(3,3);
    for k = 2:N_or
        ai = n_t(k,:)' - beta(k-1)*n1;  % Vector de restricción
        wk = w_norm(k);
        A_dir = A_dir + wk * (ai*ai'); % Contribución ponderada a la matriz
    end
    
    % 3) Hallar dirección d_hat como autovector de mínimo autovalor
    [V, D] = eig(A_dir);
    [~, idx] = min(diag(D));
    d_hat = V(:, idx);
    % Corregir signo
    if d_hat'*n1 < 0
        d_hat = -d_hat;
    end
    d_hat = d_hat / norm(d_hat); % Normalizar
    
    % 4) Calcular lambdas individuales y combinar por WLS
    lambda_i = zeros(N_or,1);
    for k = 1:N_or
        cos_phi = max(d_hat'*n_t(k,:)', 0); % Coseno del ángulo de irradiancia
        cos_psi = max((-d_hat)'*n_r', 0);    % Coseno del ángulo de incidencia
        lambda_i(k) = sqrt(P_t*(m_t+1)*A_det/(2*pi) * cos_phi^m_t * cos_psi / Pvec(k));
    end
    lambda = sum(w_norm .* lambda_i) / sum(w_norm); % Promedio ponderado
    
    % 5) Calcular posición final
    pos = T(:) + lambda * d_hat;
    estPosWLS(i_pos,:) = pos';
    
    %---------------------------------------------------------------------------------------%
    % Case 4: WLS (simplified) con calculo de distancia en beamstearing (Tx-Rx)   
    %---------------------------------------------------------------------------------------%
    % Usamos la misma dirección estimada por el método WLS
    v_tr_est_WLS_SVD = d_hat';
    
    % Pero calculamos la distancia como en el caso 2 (SVD), apuntando uno al otro
    param_t_axis = {T, v_tr_est_WLS_SVD, P_t, m_t};
    param_r_axis = {A_det, -v_tr_est_WLS_SVD, FOV}; % Vector de parámetros del receptor
    [~, P_r_axis_WLS_SVD, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
    P_r_axis_noisy_WLS_SVD = (R_pd.*P_r_axis_WLS_SVD + sqrt(sigma2).*randn(1,1000))./R_pd; % Potencia observada con ruido
    
    % Cálculo de la distancia con la fórmula del modelo lambertiano
    d_tr_est_WLS_SVD = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_WLS_SVD)));
    
    % Posición final combinando dirección WLS con distancia estilo SVD
    estPosWLS_SVD(i_pos,:) = (v_tr_est_WLS_SVD.*d_tr_est_WLS_SVD);
    
    %---------------------------------------------------------------------------------------%
    % Case 5: WLS robusto con pesos optimizados y distancia en beamstearing (Tx-Rx)   
    %---------------------------------------------------------------------------------------%
    % Obtener potencias crudas para cada orientación
    P_raw = zeros(1000, N_or); % Cada fila es una muestra, cada columna una orientación
    for i_dir = 1:N_or
        P_raw(:, i_dir) = P_r_noisy{i_pos, i_dir}; % 1000 muestras de potencia para cada orientación
    end
    
    % Obtener dirección usando el método WLS robusto
    [d_hat_robust, ~, ~] = vlp_direction_full(n_t', P_raw, m_t);
    
    % Calcular distancia usando el enfoque beamsteering (Tx-Rx)
    v_tr_est_WLS_Robust = d_hat_robust';
    param_t_axis = {T, v_tr_est_WLS_Robust, P_t, m_t};
    param_r_axis = {A_det, -v_tr_est_WLS_Robust, FOV}; % Vector de parámetros del receptor
    [~, P_r_axis_WLS_Robust, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
    P_r_axis_noisy_WLS_Robust = (R_pd.*P_r_axis_WLS_Robust + sqrt(sigma2).*randn(1,1000))./R_pd; % Potencia observada con ruido
    
    % Cálculo de la distancia con la fórmula del modelo lambertiano
    d_tr_est_WLS_Robust = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_WLS_Robust)));
    
    % Posición final combinando dirección WLS robusta con distancia
    estPosWLS_Robust(i_pos,:) = (v_tr_est_WLS_Robust.*d_tr_est_WLS_Robust);
    
    %---------------------------------------------------------------------------------------%
    % Case 6: GLS (Generalized Least Squares) con matriz de covarianza completa
    %---------------------------------------------------------------------------------------%
    % Usar mismo P_raw definido en Case 5
    % Obtener dirección usando el método GLS (con matriz de covarianza completa)
    % Asumir una varianza común para las muestras (del ruido del receptor)
    [d_hat_gls] = vlp_direction_cov(n_t', P_raw, m_t, sigma2);
    
    % Calcular distancia usando el enfoque beamsteering (Tx-Rx)
    v_tr_est_GLS = d_hat_gls';
    param_t_axis = {T, v_tr_est_GLS, P_t, m_t};
    param_r_axis = {A_det, -v_tr_est_GLS, FOV}; % Vector de parámetros del receptor
    [~, P_r_axis_GLS, ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
    P_r_axis_noisy_GLS = (R_pd.*P_r_axis_GLS + sqrt(sigma2).*randn(1,1000))./R_pd; % Potencia observada con ruido
    
    % Cálculo de la distancia con la fórmula del modelo lambertiano
    d_tr_est_GLS = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_GLS)));
    
    % Posición final combinando dirección GLS con distancia por beamsteering
    estPosGLS(i_pos,:) = (v_tr_est_GLS.*d_tr_est_GLS);

end

realPos = [X_r ; Y_r ; Z_r];

% Calcular error para método SVD
errorSVD = realPos' - estPosSVD;
for i = 1:length(errorSVD)
    errorNormSVD(i) = norm(errorSVD(i,:));
end

% Calcular error para método WLS
errorWLS = realPos' - estPosWLS;
for i = 1:length(errorWLS)
    errorNormWLS(i) = norm(errorWLS(i,:));
end

% Calcular error para método híbrido WLS+SVD
errorWLS_SVD = realPos' - estPosWLS_SVD;
for i = 1:length(errorWLS_SVD)
    errorNormWLS_SVD(i) = norm(errorWLS_SVD(i,:));
end

% Calcular error para método WLS robusto
errorWLS_Robust = realPos' - estPosWLS_Robust;
for i = 1:length(errorWLS_Robust)
    errorNormWLS_Robust(i) = norm(errorWLS_Robust(i,:));
end

% Calcular error para método GLS
errorGLS = realPos' - estPosGLS;
for i = 1:length(errorGLS)
    errorNormGLS(i) = norm(errorGLS(i,:));
end

% Calcular percentil 90 para los tres métodos
[f_RMS_SVD, x_RMS_SVD] = ecdf(errorNormSVD(:));
idx90_SVD = find(f_RMS_SVD<0.9, 1, 'last');
cdf90_RMS_SVD_cm = x_RMS_SVD(idx90_SVD)*100 % cm

% [f_RMS_WLS, x_RMS_WLS] = ecdf(errorNormWLS(:));
% idx90_WLS = find(f_RMS_WLS<0.9, 1, 'last');
% cdf90_RMS_WLS_cm = x_RMS_WLS(idx90_WLS)*100 % cm

[f_RMS_WLS_SVD, x_RMS_WLS_SVD] = ecdf(errorNormWLS_SVD(:));
idx90_WLS_SVD = find(f_RMS_WLS_SVD<0.9, 1, 'last');
cdf90_RMS_WLS_SVD_cm = x_RMS_WLS_SVD(idx90_WLS_SVD)*100 % cm

[f_RMS_WLS_Robust, x_RMS_WLS_Robust] = ecdf(errorNormWLS_Robust(:));
idx90_WLS_Robust = find(f_RMS_WLS_Robust<0.9, 1, 'last');
cdf90_RMS_WLS_Robust_cm = x_RMS_WLS_Robust(idx90_WLS_Robust)*100 % cm

[f_RMS_GLS, x_RMS_GLS] = ecdf(errorNormGLS(:));
idx90_GLS = find(f_RMS_GLS<0.9, 1, 'last');
cdf90_RMS_GLS_cm = x_RMS_GLS(idx90_GLS)*100 % cm

load 'non-linear.mat'
[f_RMS_NLS, x_RMS_NLS] = ecdf(errorNorm(:));
idx90_NLS = find(f_RMS_NLS<0.9, 1, 'last');
cdf90_RMS_NLS_cm = x_RMS_NLS(idx90_NLS)*100 % cm

figure(1)
cdfplot(errorNormSVD.*100); hold on;
% cdfplot(errorNormWLS.*100);
cdfplot(errorNormWLS_SVD.*100);
cdfplot(errorNormWLS_Robust.*100);
cdfplot(errorNormGLS.*100);
cdfplot(errorNorm.*100);
xlabel('RMS error [cm]'); ylabel('Empirical cumulative distribution function'); xlim([0,10]);
% legend('Linear estimator of P_{r,i} + SVD', 'WLS(SNR)-wo beemstearing', 'WLS(SNR)', 'WLS(var)', 'GLS','Non-linear');
legend('Linear estimator of P_{r,i} + SVD', 'WLS(SNR)', 'WLS(var)', 'GLS','Non-linear','Location', 'southeast');

figure(2)
plot3(realPos(1,:), realPos(2,:), realPos(3,:),'ko', 'MarkerSize', 2); hold on;
plot3(estPosSVD(:,1), estPosSVD(:,2), estPosSVD(:,3), 'bx', 'MarkerSize', 2);
plot3(estPosWLS(:,1), estPosWLS(:,2), estPosWLS(:,3), 'r+', 'MarkerSize', 2);
plot3(estPosWLS_SVD(:,1), estPosWLS_SVD(:,2), estPosWLS_SVD(:,3), 'g*', 'MarkerSize', 2);
plot3(estPosWLS_Robust(:,1), estPosWLS_Robust(:,2), estPosWLS_Robust(:,3), 'ms', 'MarkerSize', 2);
plot3(estPosGLS(:,1), estPosGLS(:,2), estPosGLS(:,3), 'cd', 'MarkerSize', 2);
xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
legend('Posición real', 'Estimación SVD', 'Estimación WLS (basic)', 'Estimación WLS Tx-Rx', 'Estimación WLS robust', 'Estimación GLS');
axis([-1.2 1.2 -1.2 1.2 -1.8 -0.8])
grid on;

toc;


%% Appendix: Functions used by the main scipt
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

function [d_hat, beta_hat, w] = vlp_direction_full(nt, Praw, m)
% nt   : 3×n orientaciones del LED     (columna)
% Praw : N×n matriz de potencias crudas (filas = muestras k)
% m    : orden Lambertiano
% Devuelve:
%   d_hat    : dirección 3×1 (unitaria)
%   beta_hat : (n-1)×1 razones estimadas
%   w        : (n-1)×1 pesos finales

[N, n] = size(Praw);

% ---- 1. medias μ̂_i
mu_hat = mean(Praw, 1) .';          % n×1

mu1    = mu_hat(1);
beta_hat = (mu_hat(2:end) / mu1).^(1/m);   % (n-1)×1

% ---- 2. pesos según la fórmula simplificada
denom = beta_hat.^2 .* ( mu_hat(2:end).^(-2) + mu1^(-2) );
w     = 1 ./ denom;                 % (n-1)×1  (constante común omitida)

% ---- 3. matriz M
M = zeros(3);
for i = 2:n
    ai = nt(:,i) - beta_hat(i-1)*nt(:,1);
    M  = M + w(i-1) * (ai*ai.');
end

% ---- 4. autovector de menor autovalor
[V,D]  = eig(M);
[~,ix] = min(diag(D));
d_hat  = V(:,ix) / norm(V(:,ix));

if dot(d_hat, nt(:,1)) < 0
    d_hat = -d_hat;                 % direccion Tx → Rx
end
end

function d_hat = vlp_direction_cov(nt, Praw, m, sigma2)
% nt      : 3×n  — orientaciones n_t^(i) (columnas)
% Praw    : N×n  — muestras de potencia P_r^(k,i)
% m       : esc. Lambertiano
% sigma2  : varianza común de cada muestra
%
% d_hat   : dirección 3×1 del Tx al Rx (normada)

[N,n]  = size(Praw);
mu_hat = mean(Praw,1).';          % μ̂_i  (n×1)
mu1    = mu_hat(1);
beta   = (mu_hat(2:end)/mu1).^(1/m);      % (n-1)×1

% ---------- 1. matriz de covarianza completa Σ_r ----------
diagVar = beta.^2 .* ( mu_hat(2:end).^(-2) + mu1^(-2) );
Sigma_r = diag(diagVar) + (beta*beta.')*mu1^(-2) ...
          - diag(beta.^2*mu1^(-2));       % tamaño (n-1)×(n-1)

% factor σ²/(N m²) es común → suprimir
% ---------- 2. matriz A ----------
A = zeros(3, n-1);
for i = 2:n
    A(:,i-1) = nt(:,i) - beta(i-1)*nt(:,1);
end

% ---------- 3. matriz de información M ----------
W   = inv(Sigma_r);                %  Σ_r^{-1}
M   = A * W * A.';                 %  3×3

% ---------- 4. autovector de menor autovalor ----------
[V,D]  = eig(M);
[~,ix] = min(diag(D));
d_hat  = V(:,ix) / norm(V(:,ix));  % unitario

% ---------- 5. signo coherente (hacia el receptor) ----------
if dot(d_hat, nt(:,1)) < 0
    d_hat = -d_hat;
end
end
