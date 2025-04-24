% main.m - Punto de entrada principal para el experimento de posicionamiento VLP
% Utiliza un conjunto de orientaciones predefinidas o ejecuta el optimizador genético

clear, clc

% 1. Ejecutar un escenario con orientaciones predefinidas
disp('Ejecutando escenario con orientaciones predefinidas...');
% n_t_s = [0,0,50,0,50,120,50,240]; % Vector de [theta_1, rho_1, theta_2, rho_2, ...]
% n_t_s = [30,0,30,120,30,240];
n_t_s = [1.28, 318.46, 49.09, 159.26, 59.94, 344.35, 49.36, 118.45, 57.72, 294.29];

cdf90_val = rmseCalculator3D(n_t_s);
fprintf('CDF 90%% RMS Error con orientaciones predefinidas: %.4f m\n\n', cdf90_val);

% 2. Para ejecutar el optimizador genético (GA), descomenta la siguiente línea
% run('optimization/gaOptimizer.m');