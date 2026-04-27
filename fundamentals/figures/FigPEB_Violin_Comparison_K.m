close all; clear variables; clc;  
rng(42)

% ============================================================================
% Script para comparar RMS de PEB por número de orientaciones K
% Genera violin plot comparativo: orientaciones optimizadas vs aleatorias
% Rango K = 3 hasta K = 10 (8 violines total)
% ============================================================================

% ============================================================================
% Configuración de paths desde la nueva ubicación
% ============================================================================
% Añadir directorio padre al path para acceder a PEB_complete.m
script_dir = fileparts(mfilename('fullpath'));
parent_dir = fileparts(script_dir);
addpath(parent_dir);

fprintf('Directorio del script: %s\n', script_dir);
fprintf('Directorio padre añadido al path: %s\n', parent_dir);

fprintf('=====================================================\n');
fprintf('ANÁLISIS COMPARATIVO RMS-PEB POR NÚMERO DE ORIENTACIONES\n');
fprintf('=====================================================\n');

% ============================================================================
% Hiperparámetros de configuración
% ============================================================================
K_values = 3:10;                      % Valores K a analizar
altura_analisis = 0.8;               % Altura específica para análisis [m]
step = 0.02;                           % Step size para grid [m] (más grueso para velocidad)
T = [0, 0, 2];                        % Posición del LED (origen) [m]
N_samples = 1000;                     % Número de muestras para cálculo PEB
N_realizations = 1;                  % Número de realizaciones aleatorias por K

% Parámetros del sistema (coherentes con FigPEB_Heatmaps.m)
sigma2 = 30e6*10^(-21.0);             % Varianza AWGN [A²]
P_t = 0.405;                          % Potencia transmitida [W]
theta_half = deg2rad(45);             % Ángulo de media potencia LED [rad]
m_t = -log(2)/log(cos(theta_half));   % Orden Lambertiano
p = 4.8e-3; q = 5.5e-3;               % Dimensiones del fotodiodo rectangular [m]
N_det = 1;                            % Número de fotodiodos
A_det = p*q*N_det;                    % Área sensible del fotoreceptor [m²]
FOV = deg2rad(85);                    % Campo de visión del receptor [rad]
R_pd = 0.63;                          % Responsividad del fotodiodo [A/W]

% Parámetros de la habitación (testbed)
L = 3; W = 3;                         % Dimensiones de la habitación [m]

fprintf('Configuración del análisis:\n');
fprintf('- Rango K: %d a %d orientaciones\n', min(K_values), max(K_values));
fprintf('- Altura de análisis: %.1f m\n', altura_analisis);
fprintf('- Resolución del grid: %.2f m\n', step);
fprintf('- Realizaciones aleatorias por K: %d\n', N_realizations);

% ============================================================================
% Lectura de orientaciones optimizadas
% ============================================================================
% Path relativo desde la nueva ubicación del script
orientations_file = '..\..\CRLB analysis\OPTIMIZATION\optimization\room_3x3\orientations_summary.txt';

% Convertir a path absoluto para asegurar que funcione
orientations_file = fullfile(fileparts(mfilename('fullpath')), orientations_file);

fprintf('\nLeyendo orientaciones optimizadas desde:\n%s\n', orientations_file);

if ~exist(orientations_file, 'file')
    error('No se encontró el archivo de orientaciones optimizadas: %s', orientations_file);
end

% Leer archivo línea por línea
fid = fopen(orientations_file, 'r');
optimized_orientations = containers.Map('KeyType', 'int32', 'ValueType', 'any');

while ~feof(fid)
    line = fgetl(fid);
    if ischar(line) && contains(line, 'K_')
        % Extraer K y orientaciones
        parts = split(line, '=');
        k_part = parts{1};
        orient_part = parts{2};
        
        % Extraer número K
        k_num = str2double(regexp(k_part, '\d+', 'match', 'once'));
        
        % Extraer orientaciones (remover [ y ])
        orient_str = regexprep(orient_part, '[[\]]', '');
        orientations = str2num(orient_str); %#ok<ST2NM>
        
        if ismember(k_num, K_values)
            optimized_orientations(k_num) = orientations;
            fprintf('  ✓ K=%d: %d orientaciones cargadas\n', k_num, length(orientations)/2);
        end
    end
end
fclose(fid);

% Verificar que se cargaron todas las orientaciones
missing_k = [];
for k = K_values
    if ~isKey(optimized_orientations, k)
        missing_k = [missing_k, k];
    end
end

if ~isempty(missing_k)
    warning('Orientaciones faltantes para K = %s', mat2str(missing_k));
end

% ============================================================================
% Generación del grid de posiciones (reducido para velocidad)
% ============================================================================
x_range = -L/2:step:L/2;
y_range = -W/2:step:W/2;
[X_grid, Y_grid] = meshgrid(x_range, y_range);

X_flat = X_grid(:);
Y_flat = Y_grid(:);
Z_flat = altura_analisis * ones(size(X_flat));
N_pos = length(X_flat);

fprintf('\nGrid de cálculo: %d posiciones (%dx%d)\n', N_pos, length(x_range), length(y_range));

% ============================================================================
% Cálculo de valores PEB individuales para orientaciones optimizadas y aleatorias
% ============================================================================
% Almacenamiento para todos los valores PEB individuales
peb_optimized = cell(length(K_values), 1);     % Un cell array por cada K
peb_random = cell(length(K_values), 1);        % Un cell array por cada K

fprintf('\n=== CALCULANDO VALORES PEB INDIVIDUALES ===\n');

for i = 1:length(K_values)
    k = K_values(i);
    fprintf('Procesando K=%d (%d/%d)...\n', k, i, length(K_values));
    
    % Valores PEB para orientaciones optimizadas
    if isKey(optimized_orientations, k)
        fprintf('  - Calculando PEB optimizado...');
        tic;
        orientations_opt = optimized_orientations(k);
        peb_optimized{i} = calculate_peb_values(orientations_opt, X_flat, Y_flat, Z_flat, ...
                                              T, P_t, m_t, A_det, theta_half, FOV, sigma2, N_samples);
        elapsed = toc;
        fprintf(' %d valores válidos (%.1fs)\n', length(peb_optimized{i}), elapsed);
    else
        peb_optimized{i} = [];
        fprintf('  - Orientaciones optimizadas no disponibles\n');
    end
    
    % Valores PEB para orientaciones aleatorias (múltiples realizaciones)
    fprintf('  - Calculando %d realizaciones aleatorias: ', N_realizations);
    all_random_values = [];
    for j = 1:N_realizations
        if mod(j, 10) == 0
            fprintf('%d ', j);
        end
        
        % Generar orientaciones aleatorias
        orientations_rand = [];
        for n = 1:k
            theta_rand = rand() * 30;     % Elevación aleatoria 0-30°
            rho_rand = rand() * 360;      % Azimuth aleatorio 0-360°
            orientations_rand = [orientations_rand, theta_rand, rho_rand];
        end
        
        % Calcular valores PEB para esta realización
        current_values = calculate_peb_values(orientations_rand, X_flat, Y_flat, Z_flat, ...
                                            T, P_t, m_t, A_det, theta_half, FOV, sigma2, N_samples);
        all_random_values = [all_random_values; current_values];
    end
    peb_random{i} = all_random_values;
    fprintf('\n     Total valores aleatorios: %d\n', length(peb_random{i}));
end

% ============================================================================
% Estadísticas y resumen
% ============================================================================
fprintf('\n=== RESUMEN DE RESULTADOS ===\n');
fprintf('K\tPEB_Opt_Mean[m]\tPEB_Rand_Mean[m]\tMejora[%%]\tN_Opt\tN_Rand\n');
fprintf('---\t--------------\t---------------\t--------\t-----\t------\n');
for i = 1:length(K_values)
    k = K_values(i);
    
    % Estadísticas para orientaciones optimizadas
    if ~isempty(peb_optimized{i})
        peb_opt_mean = mean(peb_optimized{i});
        n_opt = length(peb_optimized{i});
    else
        peb_opt_mean = NaN;
        n_opt = 0;
    end
    
    % Estadísticas para orientaciones aleatorias
    if ~isempty(peb_random{i})
        peb_rand_mean = mean(peb_random{i});
        n_rand = length(peb_random{i});
    else
        peb_rand_mean = NaN;
        n_rand = 0;
    end
    
    % Calcular mejora porcentual
    if ~isnan(peb_opt_mean) && ~isnan(peb_rand_mean) && peb_rand_mean > 0
        mejora = (peb_rand_mean - peb_opt_mean) / peb_rand_mean * 100;
    else
        mejora = NaN;
    end
    
    fprintf('%d\t%.6f\t\t%.6f\t\t%.1f%%\t\t%d\t%d\n', k, peb_opt_mean, peb_rand_mean, mejora, n_opt, n_rand);
end

% ============================================================================
% VISUALIZACIÓN: Violin Plot Comparativo
% ============================================================================
fprintf('\n=== GENERANDO VIOLIN PLOT ===\n');

figure(1);
set(gcf, 'Position', [100, 100, 1400, 700]);

hold on;

% Configuraciones para el violin plot
violin_width = 0.35;
colors_left = [0.5, 0.8, 0.5];   % Verde claro (optimizadas - izquierda)
colors_right = [1.0, 0.6, 0.4];  % Naranja (aleatorias - derecha)

% Preparar datos para todos los violines
all_peb_values = [];

for i = 1:length(K_values)
    k = K_values(i);
    x_center_opt = k - 0.2;  % Centro para orientaciones optimizadas
    x_center_rand = k + 0.2; % Centro para orientaciones aleatorias
    
    % Violin para orientaciones optimizadas (lado izquierdo)
    peb_opt_data = peb_optimized{i};
    if ~isempty(peb_opt_data)
        % Usar ksdensity para obtener densidad kernel suave
        try
            [density_opt, yi_opt] = ksdensity(peb_opt_data, 'NumPoints', 50);
        catch
            % Fallback si ksdensity falla
            [counts_opt, edges_opt] = histcounts(peb_opt_data, 20);
            yi_opt = (edges_opt(1:end-1) + edges_opt(2:end)) / 2;
            density_opt = counts_opt / sum(counts_opt);
        end
        
        % Normalizar densidad para ancho del violin
        density_norm_opt = density_opt / max(density_opt) * violin_width;
        
        % Crear violin simétrico
        x_left_opt = x_center_opt - density_norm_opt;
        x_right_opt = x_center_opt + density_norm_opt;
        
        % Dibujar violin optimizado
        fill([x_left_opt, fliplr(x_right_opt)], [yi_opt, fliplr(yi_opt)], ...
             colors_left, 'FaceAlpha', 0.8, 'EdgeColor', colors_left*0.7, 'LineWidth', 1.5);
        
        % Estadísticos para optimizadas
        median_opt = median(peb_opt_data);
        q25_opt = prctile(peb_opt_data, 25);
        q75_opt = prctile(peb_opt_data, 75);
        mean_opt = mean(peb_opt_data);
        
        % Líneas de estadísticos
        plot([x_center_opt-violin_width*0.8, x_center_opt+violin_width*0.8], [median_opt, median_opt], 'k-', 'LineWidth', 3);
        plot([x_center_opt-violin_width*0.6, x_center_opt+violin_width*0.6], [q25_opt, q25_opt], 'k-', 'LineWidth', 1.5);
        plot([x_center_opt-violin_width*0.6, x_center_opt+violin_width*0.6], [q75_opt, q75_opt], 'k-', 'LineWidth', 1.5);
        plot([x_center_opt, x_center_opt], [q25_opt, q75_opt], 'k-', 'LineWidth', 1.5);
        plot([x_center_opt-violin_width*0.4, x_center_opt+violin_width*0.4], [mean_opt, mean_opt], 'r-', 'LineWidth', 2);
    end
    
    % Violin para orientaciones aleatorias (lado derecho)
    peb_rand_data = peb_random{i};
    if ~isempty(peb_rand_data)
        % Usar ksdensity para obtener densidad kernel suave
        try
            [density_rand, yi_rand] = ksdensity(peb_rand_data, 'NumPoints', 50);
        catch
            % Fallback si ksdensity falla
            [counts_rand, edges_rand] = histcounts(peb_rand_data, 20);
            yi_rand = (edges_rand(1:end-1) + edges_rand(2:end)) / 2;
            density_rand = counts_rand / sum(counts_rand);
        end
        
        % Normalizar densidad para ancho del violin
        density_norm_rand = density_rand / max(density_rand) * violin_width;
        
        % Crear violin simétrico
        x_left_rand = x_center_rand - density_norm_rand;
        x_right_rand = x_center_rand + density_norm_rand;
        
        % Dibujar violin aleatorio
        fill([x_left_rand, fliplr(x_right_rand)], [yi_rand, fliplr(yi_rand)], ...
             colors_right, 'FaceAlpha', 0.8, 'EdgeColor', colors_right*0.7, 'LineWidth', 1.5);
        
        % Estadísticos para aleatorias
        median_rand = median(peb_rand_data);
        q25_rand = prctile(peb_rand_data, 25);
        q75_rand = prctile(peb_rand_data, 75);
        mean_rand = mean(peb_rand_data);
        
        % Líneas de estadísticos
        plot([x_center_rand-violin_width*0.8, x_center_rand+violin_width*0.8], [median_rand, median_rand], 'k-', 'LineWidth', 3);
        plot([x_center_rand-violin_width*0.6, x_center_rand+violin_width*0.6], [q25_rand, q25_rand], 'k-', 'LineWidth', 1.5);
        plot([x_center_rand-violin_width*0.6, x_center_rand+violin_width*0.6], [q75_rand, q75_rand], 'k-', 'LineWidth', 1.5);
        plot([x_center_rand, x_center_rand], [q25_rand, q75_rand], 'k-', 'LineWidth', 1.5);
        plot([x_center_rand-violin_width*0.4, x_center_rand+violin_width*0.4], [mean_rand, mean_rand], 'r-', 'LineWidth', 2);
    end
    
    % Recopilar todos los valores para escala Y
    all_peb_values = [all_peb_values; peb_opt_data(:); peb_rand_data(:)];
end

% Configurar ejes y etiquetas
xlim([min(K_values)-0.8, max(K_values)+0.8]);
ylim([0, max(all_peb_values)*1.1]);
xticks(K_values);
xlabel('Número de Orientaciones (K)', 'Interpreter', 'none', 'FontSize', 14);
ylabel('Position Error Bound (PEB) [m]', 'Interpreter', 'none', 'FontSize', 14);
title('Distribución de PEB por Punto: Orientaciones Optimizadas vs Aleatorias', ...
      'Interpreter', 'none', 'FontSize', 16, 'FontWeight', 'bold');

% Grid y formato
grid on;
set(gca, 'FontSize', 12);

% Leyenda personalizada
legend_patches = [
    patch([0 0 0 0], [0 0 0 0], colors_left, 'FaceAlpha', 0.8);
    patch([0 0 0 0], [0 0 0 0], colors_right, 'FaceAlpha', 0.8)
];
legend(legend_patches, {'Orientaciones Optimizadas', 'Orientaciones Aleatorias'}, ...
       'Location', 'northeast', 'FontSize', 11);

% Añadir texto informativo
info_text = sprintf('Grid: %dx%d puntos | Altura: %.1fm | Realizaciones: %d', ...
                   length(x_range), length(y_range), altura_analisis, N_realizations);
text(min(K_values), max(all_peb_values)*0.95, info_text, ...
     'FontSize', 10, 'BackgroundColor', 'white', 'EdgeColor', 'black');

hold off;

fprintf('Violin plot generado exitosamente!\n');
fprintf('=====================================================\n');

% ============================================================================
% Exportación de datos a archivos CSV
% ============================================================================
fprintf('\n=== EXPORTANDO DATOS A CSV ===\n');

% Determinar la longitud máxima de todas las listas
max_length_opt = 0;
max_length_rand = 0;
for i = 1:length(K_values)
    if ~isempty(peb_optimized{i})
        max_length_opt = max(max_length_opt, length(peb_optimized{i}));
    end
    if ~isempty(peb_random{i})
        max_length_rand = max(max_length_rand, length(peb_random{i}));
    end
end

fprintf('Longitud máxima - Optimizadas: %d, Aleatorias: %d\n', max_length_opt, max_length_rand);

% Crear matriz para orientaciones optimizadas
matrix_optimized = NaN(max_length_opt, length(K_values));
headers_opt = cell(1, length(K_values));

for i = 1:length(K_values)
    k = K_values(i);
    headers_opt{i} = sprintf('K_%d', k);
    
    if ~isempty(peb_optimized{i})
        data_length = length(peb_optimized{i});
        matrix_optimized(1:data_length, i) = peb_optimized{i};
        fprintf('  K=%d: %d valores cargados en matriz optimizada\n', k, data_length);
    else
        fprintf('  K=%d: Sin datos (columna con NaN)\n', k);
    end
end

% Crear matriz para orientaciones aleatorias
matrix_random = NaN(max_length_rand, length(K_values));
headers_rand = cell(1, length(K_values));

for i = 1:length(K_values)
    k = K_values(i);
    headers_rand{i} = sprintf('K_%d', k);
    
    if ~isempty(peb_random{i})
        data_length = length(peb_random{i});
        matrix_random(1:data_length, i) = peb_random{i};
        fprintf('  K=%d: %d valores cargados en matriz aleatoria\n', k, data_length);
    else
        fprintf('  K=%d: Sin datos (columna con NaN)\n', k);
    end
end

% Convertir a tablas para fácil exportación
table_optimized = array2table(matrix_optimized, 'VariableNames', headers_opt);
table_random = array2table(matrix_random, 'VariableNames', headers_rand);

% Generar nombres de archivos con timestamp
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
filename_opt = 'PEB_optimizadas.csv';
filename_rand = 'PEB_aleatorias.csv';

% Exportar a CSV
fprintf('\nGuardando archivos CSV:\n');
try
    writetable(table_optimized, filename_opt);
    fprintf('  ✓ %s (%.1f MB, %dx%d)\n', filename_opt, ...
            dir(filename_opt).bytes/1024/1024, size(matrix_optimized,1), size(matrix_optimized,2));
catch
    fprintf('  ✗ Error guardando %s\n', filename_opt);
end

try
    writetable(table_random, filename_rand);
    fprintf('  ✓ %s (%.1f MB, %dx%d)\n', filename_rand, ...
            dir(filename_rand).bytes/1024/1024, size(matrix_random,1), size(matrix_random,2));
catch
    fprintf('  ✗ Error guardando %s\n', filename_rand);
end

fprintf('\nEstadísticas de exportación:\n');
fprintf('- Orientaciones optimizadas: %d filas x %d columnas\n', size(matrix_optimized,1), size(matrix_optimized,2));
fprintf('- Orientaciones aleatorias: %d filas x %d columnas\n', size(matrix_random,1), size(matrix_random,2));
fprintf('- Valores totales exportados: %d\n', numel(matrix_optimized) + numel(matrix_random));
fprintf('\nCSV generados exitosamente!\n');
fprintf('=====================================================\n');

% ============================================================================
% Función auxiliar para calcular valores PEB individuales
% ============================================================================
function peb_values = calculate_peb_values(orientations_array, X_flat, Y_flat, Z_flat, ...
                                         T, P_t, m_t, A_det, theta_half, FOV, sigma2, N_samples)
    
    % Convertir orientaciones a vectores unitarios
    N_orientations = length(orientations_array) / 2;
    nt_orientations = zeros(3, N_orientations);
    
    for i = 1:N_orientations
        theta = deg2rad(orientations_array(2*i-1));  % Elevación
        rho = deg2rad(orientations_array(2*i));      % Azimuth
        nt_orientations(:, i) = [sin(theta)*cos(rho); sin(theta)*sin(rho); -cos(theta)];
    end
    
    % Calcular PEB para cada posición
    N_pos = length(X_flat);
    PEB_values = zeros(N_pos, 1);
    
    for i = 1:N_pos
        R = [X_flat(i); Y_flat(i); Z_flat(i)];
        try
            PEB_values(i) = PEB_complete(R, nt_orientations, T', P_t, m_t, ...
                                       A_det, theta_half, FOV, sigma2, N_samples);
        catch
            PEB_values(i) = NaN;
        end
    end
    
    % Devolver solo los valores válidos (filtrar NaN e Inf)
    peb_values = PEB_values(~isnan(PEB_values) & ~isinf(PEB_values));
end
