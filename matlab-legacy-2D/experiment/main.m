% main.m - Punto de entrada principal para el experimento de posicionamiento VLP
% Utiliza un conjunto de orientaciones predefinidas o ejecuta el optimizador genético

clear, clc

% 1. Ejecutar un escenario con orientaciones predefinidas
disp('Ejecutando escenario con orientaciones predefinidas...');

% Vector de [theta_1, rho_1, theta_2, rho_2, ...]
%n_t_s = [0,0,30,0,30,90]; %scenario 1
%n_t_s = [5.69,157.87,3.41,239.76,2.5,43.66]; %scenario 2

%n_t_s = [1.28, 318.46, 49.09, 159.26, 59.94, 344.35, 49.36, 118.45, 57.72,
%294.29] %scenario 3

cdf90_val = rmseCalculator(n_t_s);
fprintf('CDF 90%% RMS Error con orientaciones predefinidas: %.4f m\n\n', cdf90_val);

% 2. Para ejecutar el optimizador genético (GA), descomenta la siguiente línea
% run('optimization/gaOptimizer.m');