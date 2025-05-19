% GA Optimizer for VLP orientation optimization
% Este script ejecuta el algoritmo genético para optimizar las orientaciones de transmisores
% en un sistema de posicionamiento óptico visible (VLP)

rng('default'); 

% Vector de orientaciones a optimizar
n_orientations_vector = [4,5]; % Vector con diferentes números de orientaciones a optimizar

% Crear directorio base para resultados si no existe
results_base_dir = 'results/LS_highNoise_true';
if ~exist(results_base_dir, 'dir')
    mkdir(results_base_dir);
end

% Iterar sobre cada valor de n_orientations
for n_idx = 1:length(n_orientations_vector)
    % Limpiar variables y figuras del entorno para asegurar que cada iteración sea independiente
    close all;               % Cerrar todas las figuras existentes
    clear functions;         % Limpiar variables persistentes en todas las funciones
    clearvars -except n_orientations_vector n_idx results_base_dir;  % Mantener solo variables esenciales
    
    % Reiniciar el generador de números aleatorios para consistencia
    rng('default');
    
    % Obtener el valor actual de orientaciones a optimizar
    n_orientations = n_orientations_vector(n_idx);
    
    % Crear carpeta para los resultados de esta configuración
    result_dir = fullfile(results_base_dir, ['n', num2str(n_orientations)]);
    if ~exist(result_dir, 'dir')
        mkdir(result_dir);
    end
    
    % Configurar diary para guardar la salida de la consola
    diary_file = fullfile(result_dir, 'optimization_log.txt');
    diary(diary_file);
    
    fprintf('\n==================================\n');
    fprintf('Iniciando optimización para %d orientaciones\n', n_orientations);
    fprintf('==================================\n\n');
    
    tic
% Número de variables de decisión (2 por orientación: theta y rho)
nvars = 2 * n_orientations;  % [theta1, rho1, theta2, rho2, ..., thetan, rhon]

% Límites inferior (lb) y superior (ub) para cada variable:
% Para cada orientación: theta en [0, 60] (grados) y rho en [0, 360] (grados).
lb = zeros(1, nvars);
ub = zeros(1, nvars);

for i = 1:nvars
    if mod(i, 2) == 1 % Índices impares son valores theta
        lb(i) = 0;
        ub(i) = 80;
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
tiempo_ejecucion = toc;
fprintf('\nOptimización completada para %d orientaciones\n', n_orientations);
fprintf('Tiempo de ejecución: %.2f segundos\n', tiempo_ejecucion);
fprintf('Mejor RMSE encontrado: %.4f metros\n', fvalOpt);

% Formatear las orientaciones óptimas encontradas
fprintf('\nOrientaciones óptimas:\n');
for i = 1:n_orientations
    theta_idx = 2*i-1;
    rho_idx = 2*i;
    fprintf('Orientación %d: theta = %.2f°, rho = %.2f°\n', i, xOpt(theta_idx), xOpt(rho_idx));
end

% Guardar las figuras creadas por gaMonitor.m

% Obtener y guardar la figura 'Evolución de Ángulos'
fig_evolution = findobj('Type', 'figure', 'Name', 'Evolución de Ángulos');
if ~isempty(fig_evolution)
    figure(fig_evolution);
    title(['Evolución de Ángulos - ' num2str(n_orientations) ' orientaciones']);
    saveas(fig_evolution, fullfile(result_dir, 'evolucion_angulos.fig'));
    saveas(fig_evolution, fullfile(result_dir, 'evolucion_angulos.png'));
    fprintf('Figura "Evolución de Ángulos" guardada\n');
else
    fprintf('Advertencia: No se encontró la figura "Evolución de Ángulos"\n');
end

% Obtener y guardar la figura 'Orientación 3D'
fig_3d = findobj('Type', 'figure', 'Name', 'Orientación 3D');
if ~isempty(fig_3d)
    figure(fig_3d);
    title(['Orientación 3D - ' num2str(n_orientations) ' transmisores']);
    saveas(fig_3d, fullfile(result_dir, 'orientacion_3d.fig'));
    saveas(fig_3d, fullfile(result_dir, 'orientacion_3d.png'));
    fprintf('Figura "Orientación 3D" guardada\n');
else
    fprintf('Advertencia: No se encontró la figura "Orientación 3D"\n');
end

% Guardado de figura de convergencia (creada por ga)
fig_conv = findobj('Type', 'figure', 'Name', 'Genetic Algorithm');
if ~isempty(fig_conv)
    figure(fig_conv);
    title(['Convergencia GA - ' num2str(n_orientations) ' orientaciones']);
    saveas(fig_conv, fullfile(result_dir, 'convergencia_ga.fig'));
    saveas(fig_conv, fullfile(result_dir, 'convergencia_ga.png'));
    fprintf('Figura "Genetic Algorithm" guardada\n');
else
    fprintf('Advertencia: No se encontró la figura de convergencia de GA\n');
end

% Guardar resultados en un archivo .mat
resultados = struct();
resultados.n_orientations = n_orientations;
resultados.xOpt = xOpt;
resultados.fvalOpt = fvalOpt;
resultados.exitflag = exitflag;
resultados.output = output;
resultados.tiempo_ejecucion = tiempo_ejecucion;
save(fullfile(result_dir, 'resultados.mat'), 'resultados');

% Cerrar el diary
diary off;

% Cerrar todas las figuras y limpiar el entorno para la siguiente iteración
close all;

% Dar tiempo al sistema para liberar recursos
pause(2);

end % fin del bucle for para cada n_orientations

% Restaurar el entorno al finalizar todas las iteraciones
diary off;  % Asegurar que el diary esté cerrado al finalizar
fprintf('\nProceso de optimización completado para todos los valores de n_orientations.\n');
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