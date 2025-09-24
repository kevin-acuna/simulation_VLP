% test_NL_monitor.m - Script de prueba para verificar la funcionalidad de logging
% de la función NL_monitor.m

clear; clc; close all;

fprintf('=== PRUEBA DE FUNCIONALIDAD NL_MONITOR ===\n\n');

% Simular datos de prueba para el algoritmo genético
K = 3; % Número de orientaciones LED
nvars = 2 * K; % Variables de decisión (theta, rho para cada LED)

% Crear estructura de opciones simulada
options = struct();

% Simular estados de generaciones
fprintf('Simulando 5 generaciones de optimización...\n\n');

% Inicialización
state_init = struct();
state_init.Generation = 0;
state_init.Population = [];
state_init.Score = [];

fprintf('1. Inicializando monitor...\n');
[~, ~, ~] = NL_monitor(options, state_init, 'init');

% Simular varias generaciones
for gen = 1:5
    % Crear población simulada (10 individuos)
    population = zeros(10, nvars);
    scores = zeros(10, 1);
    
    for i = 1:10
        % Generar orientaciones aleatorias
        for j = 1:K
            population(i, 2*j-1) = rand() * 80;      % theta: 0-80 grados
            population(i, 2*j) = rand() * 360;       % rho: 0-360 grados
        end
        
        % Simular score (RMS error) - decrece con las generaciones
        scores(i) = 0.5 + rand() * 0.3 - gen * 0.05;
    end
    
    % Crear estado de generación
    state_iter = struct();
    state_iter.Generation = gen;
    state_iter.Population = population;
    state_iter.Score = scores;
    
    fprintf('2. Procesando generación %d...\n', gen);
    [~, ~, ~] = NL_monitor(options, state_iter, 'iter');
    
    % Pausa breve para simular tiempo de procesamiento
    pause(0.5);
end

% Finalización
state_done = state_iter; % Usar el último estado
fprintf('3. Finalizando optimización...\n');
[~, ~, ~] = NL_monitor(options, state_done, 'done');

fprintf('\n=== PRUEBA COMPLETADA ===\n');
fprintf('Verifica que se haya creado el archivo de log con nombre:\n');
fprintf('orientation_log_NL_YYYY-MM-DD_HH-MM-SS.txt\n');
fprintf('El archivo debe contener los valores de orientación para cada generación.\n');
