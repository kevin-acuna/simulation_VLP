% GA Optimizer for VLP orientation optimization
% Este script ejecuta el algoritmo genético para optimizar las orientaciones de transmisores
% en un sistema de posicionamiento óptico visible (VLP)
tic
rng('default'); 

% Número de orientaciones a optimizar
n_orientations = 3; % Cambiar esto al número deseado de orientaciones

% Número de variables de decisión (2 por orientación: theta y rho)
nvars = 2 * n_orientations;  % [theta1, rho1, theta2, rho2, ..., thetan, rhon]

% Límites inferior (lb) y superior (ub) para cada variable:
% Para cada orientación: theta en [0, 60] (grados) y rho en [0, 360] (grados).
lb = zeros(1, nvars);
ub = zeros(1, nvars);

for i = 1:nvars
    if mod(i, 2) == 1 % Índices impares son valores theta
        lb(i) = 0;
        ub(i) = 60;
    else % Índices pares son valores rho
        lb(i) = 0;
        ub(i) = 360;
    end
end

% Restricciones lineales o no lineales (ninguna en este ejemplo)
A = []; b = [];
Aeq = []; beq = [];
nonlcon = [];

% Opciones de GA
% options = optimoptions('ga', ...
%     'PopulationSize',   100, ...
%     'MaxGenerations',   100, ...
%     'CrossoverFraction', 0.6, ... 
%     'Display',          'iter', ...
%     'PlotFcn',          {@gaplotbestf}, ...  % Gráfico estándar de GA para mejor aptitud
%     'OutputFcn',        @gaMonitor); % Función de salida personalizada

options = optimoptions('ga', ...
    'PopulationSize',    150, ...     % 12×12
    'MaxGenerations',    200, ...     % 12×25
    'CrossoverFraction', 0.8, ...
    'MutationFcn',  @mutationadaptfeasible, ...
    'Display',           'iter', ...
    'PlotFcn',           {@gaplotbestf}, ...
    'OutputFcn',         @gaMonitor);


% Ejecutar GA con la función de estimación de posición WLS
[xOpt, fvalOpt, exitflag, output] = ga(@rmseCalculator, nvars, ...
                                       A, b, Aeq, beq, lb, ub, ...
                                       nonlcon, options);

% Mostrar resultados
fprintf('Mejor solución encontrada para %d orientaciones:\n', n_orientations);

% Formatear la salida para mostrar cada par de orientación
for i = 1:n_orientations
    fprintf('Orientación %d: theta = %.2f°, rho = %.2f°\n', i, xOpt(2*i-1), xOpt(2*i));
end

fprintf('\nRMS (costo) en esta solución: %f\n', fvalOpt);
fprintf('Información adicional:\n');
disp(output);

% Ejecutar la simulación final con las orientaciones optimizadas
fprintf('\nEjecutando simulación final con orientaciones optimizadas...\n');
final_rms = rmseCalculator(xOpt);
fprintf('Error RMS final (CDF 90%%): %.4f m\n', final_rms);

toc