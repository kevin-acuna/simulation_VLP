% TEST_NL_OBJECTIVE - Script simple para probar NL_objective_function.m
% Prueba la función objetivo con orientaciones K5 predefinidas
% Kevin Acuña - 2024

clear; clc; close all;

% Añadir path para OWC_LOS_channel si no está disponible
if ~exist('OWC_LOS_channel', 'file')
    addpath('../../Comparison between estimators Linear-NonLinear');
end

fprintf('=== PRUEBA DE NL_OBJECTIVE_FUNCTION ===\n\n');

%% Configurar orientaciones de prueba
% Orientaciones K5 optimizadas del análisis CRLB
%orientations_K5 = [0.48, 294.81, 30, 87.79, 30, 358.55, 30, 177.68, 30, 268.14];
orientations_K5=[0.10,211.14,50.55,89.96,50.66,179.99,50.37,359.93,50.59,269.96];

fprintf('Orientaciones de prueba (K=5):\n');
for i = 1:5
    theta = orientations_K5(2*i-1);
    rho = orientations_K5(2*i);
    fprintf('  LED %d: θ = %6.2f°, ρ = %6.2f°\n', i, theta, rho);
end
fprintf('\n');

%% Configurar parámetros del sistema
system_params = struct();

% LED transmitter parameters
system_params.T = [0; 0; 2];                    % LED position at 2m height [m]
system_params.Pt = 0.405;                       % Transmitted optical power [W]
system_params.theta_half = deg2rad(45);         % LED half-power angle [rad]
system_params.m = -log(2)/log(cos(system_params.theta_half)); % Lambertian order
system_params.A_det = (4.8e-3)*(5.5e-3);        % Photodiode effective area [m²]
system_params.Psi_FOV = deg2rad(85);            % Receiver field of view [rad]

% Noise and sampling parameters
system_params.sigma2 = (10^(-21.0))*(30e6);     % Noise variance per sample [W²]
system_params.N = 1000;                         % Number of samples per orientation

% Optimization parameters
system_params.penalize_extreme_angles = false;   % No penalizar para prueba
system_params.debug_mode = true;                % Habilitar modo debug

fprintf('Parámetros del sistema configurados:\n');
fprintf('  Posición LED: [%.1f, %.1f, %.1f] m\n', system_params.T(1), system_params.T(2), system_params.T(3));
fprintf('  Potencia transmitida: %.3f W\n', system_params.Pt);
fprintf('  Ángulo de media potencia: %.1f°\n', rad2deg(system_params.theta_half));
fprintf('  Área del fotodiodo: %.2e m²\n', system_params.A_det);
fprintf('  FOV del receptor: %.1f°\n', rad2deg(system_params.Psi_FOV));
fprintf('  Muestras por orientación: %d\n\n', system_params.N);

%% Configurar posiciones de receptor (testbed reducido para prueba rápida)
L = 3; W = 3; Hmax = 1.2; step = 0.6; % Grid más espaciado para prueba rápida

x_range = -L/2:step:L/2;
y_range = -W/2:step:W/2;
% z_heights = [0, 0.6, 1.2]; % Solo 3 alturas para prueba
z_heights = [0, 0.6, 1.2];

receiver_positions = [];
for z = z_heights
    for x = x_range
        for y = y_range
            receiver_positions = [receiver_positions, [x; y; z]];
        end
    end
end

fprintf('Configuración del testbed de prueba:\n');
fprintf('  Dimensiones: L = %.1f m, W = %.1f m\n', L, W);
fprintf('  Alturas: [%.1f, %.1f, %.1f] m\n', z_heights);
fprintf('  Resolución: step = %.1f m\n', step);
fprintf('  Total de posiciones: %d\n', size(receiver_positions, 2));
fprintf('  Rango X: [%.1f, %.1f] m\n', min(receiver_positions(1,:)), max(receiver_positions(1,:)));
fprintf('  Rango Y: [%.1f, %.1f] m\n', min(receiver_positions(2,:)), max(receiver_positions(2,:)));
fprintf('  Rango Z: [%.1f, %.1f] m\n\n', min(receiver_positions(3,:)), max(receiver_positions(3,:)));

%% Ejecutar prueba de la función objetivo
fprintf('Ejecutando NL_objective_function...\n');
tic;

try
    rms_error = NL_objective_function(orientations_K5, system_params, receiver_positions);
    execution_time = toc;
    
    fprintf('  PRUEBA EXITOSA!\n');
    fprintf('  Error RMS obtenido: %.6f m = %.2f cm\n', rms_error, rms_error*100);
    fprintf('  Tiempo de ejecución: %.2f segundos\n', execution_time);
    
    % Mostrar estadísticas adicionales
    fprintf('\n=== ESTADÍSTICAS ===\n');
    fprintf('  Error RMS por posición: %.4f m\n', rms_error);
    fprintf('  Error RMS en cm: %.2f cm\n', rms_error*100);
    fprintf('  Número de posiciones evaluadas: %d\n', size(receiver_positions, 2));
    fprintf('  Tiempo : %.3f s\n', execution_time);
    
catch ME
    execution_time = toc;
    fprintf('  ERROR EN LA PRUEBA!\n');
    fprintf('  Mensaje de error: %s\n', ME.message);
    fprintf('  Tiempo antes del error: %.2f segundos\n', execution_time);
    fprintf('  Archivo: %s\n', ME.stack(1).file);
    fprintf('  Línea: %d\n', ME.stack(1).line);
end


fprintf('\n=== PRUEBA COMPLETADA ===\n');
