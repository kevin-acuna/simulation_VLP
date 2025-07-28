close all; clear variables; clc;  
rng(42)

% Seleccionar modo de posiciones del receptor
% Opciones: 
%   'fixed'  - Utiliza posiciones fijas en grid de testbed (como en analyze_PEB_vs_theta_half.m)
%   'random' - Utiliza 1000 posiciones aleatorias (como en main_3D_withNoise.m)
receiver_mode = 'fixed';  % Cambiar aquí para seleccionar el modo deseado

% Control para filtrado de valores imaginarios
% true: elimina todos los valores imaginarios para estadísticas más precisas
% false: mantiene todos los valores (comportamiento original)
filter_imaginary = false;  % Cambiar a false para mantener todos los valores

% ============================================================================
% Hiperparametros de configuracion importante
% ============================================================================
N_or = 5;  % Número de orientaciones

% Varianza AWGN [A²]
SNR_target_db = 10;
SNR_target_lin =10^(SNR_target_db/10);

sigma2 = 30e6*10^(-21.0)*10^0.392*10*(1/SNR_target_lin);
% sigma2 = 30e6*10^(-30.0); % sin ruido 

% Rango de alturas para análisis en hiperparámetros
H_range = [0:0.2:1.2]; % [m] - Alturas para análisis en grid [0.6 0.8 1]
altura_analisis = 0.8;  % Altura a la que se visualizará la potencia

SNR_umbral_lin = 1e-6; %dB
SNR_umbral_db = 10*log10(SNR_umbral_lin);

T = [0, 0, 2];                         % Posición de la fuente de luz (origen)
step = 0.1; % Step size [m]

% Number of samples per orientation
N_samples=1000;

% ============================================================================
% Set de orientaciones optimizadas
% Use optimized orientations for K from the CRLB analysis
% [theta1, rho1, theta2, rho2, ...] donde theta es elevación y rho es azimuth
% ============================================================================

% Configuration estudiada con K=5.
% orientations_K5 = [0.48, 294.81, 57.57, 87.79, 57.71, 358.55, 57.17, 177.68, 55.72, 268.14]; % theta = 57
% orientations_K5 = [0.48, 294.81, 30, 87.79, 30, 358.55, 30, 177.68, 30, 268.14]; % theta = 30
orientations_K5 = [0, 0, 50.5, 0, 50.5, 90, 50.5, 180, 50.5, 270]; % theta = 50

% Todas las otras configuracioens
orientations_K3 = [36.93, 56.20, 35.42, 176.85, 33.39, 296.52];
orientations_K4 = [36.87, 17.59, 41.59, 198.61, 42.40, 108.42, 39.37, 293.57];
orientations_K6 = [17.19,306.94,54.55,266.13,22.49,140.37,52.23,360.00,52.41,84.05,55.76,185.16];
orientations_K7 = [27.60, 355.20, 49.75, 182.12, 51.74, 280.40, 39.06, 251.04, 58.92, 352.88, 16.73, 71.81, 42.72, 104.45];
orientations_K8 = [32.76, 218.19, 28.47, 61.48, 51.87, 178.18, 35.72, 25.47, 51.63, 338.81, 57.74, 273.57, 49.66, 106.23, 18.14, 243.22];
orientations_K9 = [26.09, 251.86, 64.05, 261.27, 60.74, 358.44, 57.22, 187.22, 63.10, 175.67, 11.75, 76.79, 44.54, 119.76, 58.20, 85.09, 25.17, 304.81];
all_orientations = {orientations_K3, orientations_K4, orientations_K5, orientations_K6, orientations_K7, orientations_K8, orientations_K9};
K_values = [3, 4, 5, 6, 7, 8, 9];



%% 1. System Parameters (from analyze_PEB_vs_theta_half.m with theta_half=45°)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



% LED Parameters
theta_half = 45;                        % Semi-ángulo a media potencia (45°)
P_t = 0.405;                           % Potencia óptica transmitida [W]
m_t = -log(2)./log(cosd(theta_half));  % Orden lambertiano

% Photodetector Parameters
p = 4.8e-3; q = 5.5e-3;               % Dimensiones del fotodiodo rectangular [m]
N_det = 1;                             % Número de fotodiodos
A_det = p*q*N_det;                     % Área sensible del fotoreceptor [m²]
R_pd = 0.63;                           % Fotosensibilidad del fotodiodo [A/W]
FOV = 85;                              % Campo de visión del fotoreceptor [°]
n_r = [0, 0, 1];                       % Vector normal del fotoreceptor

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

% Define common parameters
L = 3; % Length of room [m]
W = 3; % Width of room [m]
Hmax = 1.2; % Maximum height [m]

if strcmp(receiver_mode, 'fixed')
    % Opción 1: Posiciones fijas (testbed grid de analyze_PEB_vs_theta_half.m)
    % Generate 3D grid of positions
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, H_range);
    
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
estPosWLS_Robust = zeros(N_pos, 3);    % Posiciones estimadas WLS
estPosGLS = zeros(N_pos, 3);           % Posiciones estimadas GLS

% Calculate received powers for each position and orientation
SNR_avg = [];
for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), d_tr(i_pos,1)] = OWC_LOS_channel(x, y, z, param_t, param_r);
        
        % Add noise to received power - 1000 noise realizations
        P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,N_samples)); %uW
        
        % Calculate SNR-lineal
        SNR_lin{i_pos,i_dir} = ((R_pd*P_r{i_pos,i_dir})^2/(sigma2*R_pd^2)); %lineal
        SNR_avg = [SNR_avg, ((R_pd*P_r{i_pos,i_dir})^2/(sigma2*R_pd^2))]; %lineal
    end
end

% Analisis cuando el SNR registrado esta en dB
% Replace -Inf SNR values with -80 dB for averaging
% pos_negInf = isinf(SNR_avg); %dB 
% SNR_avg(pos_negInf) = -80; %dB

average_SNR_lin = mean(SNR_avg);
average_SNR_db = 10*log10(average_SNR_lin);
fprintf('Promedio SNR: %.2f dB\n', average_SNR_db);


%% 8. Visualización de potencia recibida para cada orientación
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Solo proceder con el análisis si estamos en modo 'fixed'
if strcmp(receiver_mode, 'fixed')

    indices_altura = (abs(Z_r - altura_analisis)<1e-7);  % Comparación exacta

    if sum(indices_altura) > 0
        % Extraer coordenadas X,Y en esa altura
        X_slice = X_r(indices_altura);
        Y_slice = Y_r(indices_altura);
        
        % Determinar la estructura de la rejilla (grid)
        unique_X = unique(X_slice);
        unique_Y = unique(Y_slice);
        [X_grid, Y_grid] = meshgrid(unique_X, unique_Y);
        
        % Crear figura con subfiguras para cada orientación
        figure(1);
        
        % Encontrar los valores mínimos y máximos de potencia para normalizar la escala
        min_power = Inf;
        max_power = -Inf;
        
        % Recopilamos datos para todas las orientaciones primero
        potencias_orientaciones = cell(N_or, 1);
        
        % Encontrar los índices de posición que corresponden a la altura seleccionada
        indices_posiciones_altura = find(indices_altura);
        
        Coverage_matrix = 0;

        for i_or = 1:N_or
            % Inicializar matriz de potencia
            P_matrix = zeros(length(unique_Y), length(unique_X));
            SNR_matrix = zeros(length(unique_Y), length(unique_X));
        
            % Llenar matriz de potencia para cada posición a la altura especificada
            for idx = 1:length(indices_posiciones_altura)
                i_pos = indices_posiciones_altura(idx);
                
                % Encontrar posición en la rejilla (grid)
                x_pos = X_r(i_pos);
                y_pos = Y_r(i_pos);
                
                % Encontrar los índices más cercanos en la rejilla
                [~, idx_x] = min(abs(unique_X - x_pos));
                [~, idx_y] = min(abs(unique_Y - y_pos));
                
                % Asignar valor de potencia media con ruido
                P_matrix(idx_y, idx_x) = mean(P_r_noisy{i_pos, i_or});
                SNR_matrix(idx_y, idx_x) = mean(SNR_lin{i_pos, i_or});
                
            end
            
            % Evaluación de la cobertura
            Coverage = (SNR_matrix > SNR_umbral_lin);
            Coverage_matrix = Coverage_matrix + Coverage;
            % Evaluacion del SNR util
            % SNR_util = 

            % Guardar matriz de potencia
            potencias_orientaciones{i_or} = P_matrix;
            
            % Actualizar mínimos y máximos globales
            min_power = min(min_power, min(P_matrix(:)));
            max_power = max(max_power, max(P_matrix(:)));
        end
        
        % Ahora graficar cada orientación con la misma escala
        for i_or = 1:N_or
            % Extraer coordenadas esféricas de esta orientación para el título
            theta_i = all_orientations{N_or-2}(2*i_or-1);
            rho_i = all_orientations{N_or-2}(2*i_or);
            
            % Crear subfigura
            subplot(ceil(N_or/3), min(N_or,3), i_or);
            
            % Dibujar superficie con estilo malla
            surf(X_grid, Y_grid, potencias_orientaciones{i_or},'LineWidth',0.1);
            hold on;
            
            title(sprintf('$\\theta=%.1f^\\circ,\\rho=%.1f^\\circ$', theta_i, rho_i), 'Interpreter', 'latex');
            xlabel('X [m]','Interpreter','latex');
            ylabel('Y [m]','Interpreter','latex');
            zlabel('Optical Power [$\mu$W]','Interpreter','latex');
            axis([min(X_slice) max(X_slice) min(Y_slice) max(Y_slice) min_power max_power]);
            grid on;
            colormap(jet);
            
            % Añadir barra de colores solo para la última subfigura en cada fila
%             if mod(i_or, min(N_or,3)) == 0 || i_or == N_or
                colorbar;
%             end
            
            % Ajustar vista
            view(45, 30);
        end
        
        

        figure(2)
        surf(X_grid, Y_grid, Coverage_matrix,'LineWidth',0.1);
        view(0,90);

    else
        fprintf('No hay puntos de análisis en la altura Z = %.2f m\n', altura_analisis);
    end
else
    fprintf('La visualización de potencia por superficies solo está disponible en modo ''fixed''\n');
end
