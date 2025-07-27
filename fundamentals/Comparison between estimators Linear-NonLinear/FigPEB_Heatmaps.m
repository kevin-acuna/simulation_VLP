close all; clear variables; clc;  
rng(42)

% ============================================================================
% Script para analizar Position Error Bound (PEB) en una altura específica
% Genera mapas de calor 2D y 3D del PEB en todo el plano XY
% ============================================================================

% ============================================================================
% Hiperparámetros de configuración
% ============================================================================
N_or = 5;  % Número de orientaciones

% Modo de análisis:
% 'descriptivo'  - Analiza solo las orientaciones optimizadas
% 'comparativo'  - Compara orientaciones optimizadas vs aleatorias
modo_analisis = 'comparativo';  % Cambiar aquí para seleccionar el modo

% Parámetros del sistema
sigma2 = 30e6*10^(-21.0);         % Varianza AWGN [A²]
altura_analisis = 0.8;            % Altura específica para análisis [m]
step = 0.05;                      % Step size para grid [m]
T = [0, 0, 2];                    % Posición del LED (origen) [m]
N_samples = 1000;                 % Número de muestras para cálculo PEB

% Parámetros del canal óptico
P_t = 0.405;                      % Potencia transmitida [W]
theta_half = deg2rad(45);         % Ángulo de media potencia LED [rad]
m_t = -log(2)/log(cos(theta_half)); % Orden Lambertiano
p = 4.8e-3; q = 5.5e-3;               % Dimensiones del fotodiodo rectangular [m]
N_det = 1;                             % Número de fotodiodos
A_det = p*q*N_det;                     % Área sensible del fotoreceptor [m²]
FOV = deg2rad(85);                % Campo de visión del receptor [rad]
R_pd = 0.63;                       % Responsividad del fotodiodo [A/W]

% Parámetros de la habitación (testbed)
L = 3; W = 3;                     % Dimensiones de la habitación [m]

% ============================================================================
% Configuración de orientaciones
% ============================================================================
% [theta1, rho1, theta2, rho2, ...] donde theta es elevación y rho es azimuth
orientations_K5_optimized = [0.48, 0, 50.5, 0, 50.5, 90, 50.5, 180, 50.5, 270];

% Generar orientaciones aleatorias para comparación
rng(40);  % Semilla fija para reproducibilidad
orientations_K5_random = [];
for i = 1:N_or
    theta_rand = rand() * 80;     % Elevación aleatoria 0-80°
    rho_rand = rand() * 360;      % Azimuth aleatorio 0-360°
    orientations_K5_random = [orientations_K5_random, theta_rand, rho_rand];
end

% Función auxiliar para convertir orientaciones a vectores unitarios
convert_orientations_to_vectors = @(orientations_array, N_orientations) ...
    reshape([sin(deg2rad(orientations_array(1:2:end))) .* cos(deg2rad(orientations_array(2:2:end))); ...
             sin(deg2rad(orientations_array(1:2:end))) .* sin(deg2rad(orientations_array(2:2:end))); ...
             -cos(deg2rad(orientations_array(1:2:end)))], 3, N_orientations);

% Configurar orientaciones según el modo
if strcmp(modo_analisis, 'comparativo')
    nt_orientations_optimized = convert_orientations_to_vectors(orientations_K5_optimized, N_or);
    nt_orientations_random = convert_orientations_to_vectors(orientations_K5_random, N_or);
    
    fprintf('==========================================\n');
    fprintf('ANÁLISIS COMPARATIVO DE PEB\n');
    fprintf('==========================================\n');
    fprintf('Modo: Comparativo (Optimizadas vs Aleatorias)\n');
    fprintf('Orientaciones optimizadas: ');
    for i = 1:N_or
        fprintf('[%.1f°,%.1f°] ', orientations_K5_optimized(2*i-1), orientations_K5_optimized(2*i));
    end
    fprintf('\n');
    fprintf('Orientaciones aleatorias: ');
    for i = 1:N_or
        fprintf('[%.1f°,%.1f°] ', orientations_K5_random(2*i-1), orientations_K5_random(2*i));
    end
    fprintf('\n');
else
    nt_orientations = convert_orientations_to_vectors(orientations_K5_optimized, N_or);
    
    fprintf('==========================================\n');
    fprintf('ANÁLISIS DESCRIPTIVO DE PEB\n');
    fprintf('==========================================\n');
    fprintf('Modo: Descriptivo (Solo orientaciones optimizadas)\n');
    fprintf('Orientaciones: ');
    for i = 1:N_or
        fprintf('[%.1f°,%.1f°] ', orientations_K5_optimized(2*i-1), orientations_K5_optimized(2*i));
    end
    fprintf('\n');
end

fprintf('==========================================\n');
fprintf('ANÁLISIS DE PEB - MAPAS DE CALOR\n');
fprintf('==========================================\n');
fprintf('Número de orientaciones: %d\n', N_or);
fprintf('Altura de análisis: %.2f m\n', altura_analisis);
fprintf('Resolución del grid: %.3f m\n', step);
fprintf('Dimensiones del cuarto: %.1f × %.1f m\n', L, W);
fprintf('Posición LED: [%.1f, %.1f, %.1f] m\n', T(1), T(2), T(3));
fprintf('==========================================\n');

% ============================================================================
% Generación del grid de posiciones
% ============================================================================
% Crear grid 2D en la altura específica
x_range = -L/2:step:L/2;
y_range = -W/2:step:W/2;
[X_grid, Y_grid] = meshgrid(x_range, y_range);

% Aplanar para procesamiento
X_flat = X_grid(:);
Y_flat = Y_grid(:);
Z_flat = altura_analisis * ones(size(X_flat));

N_pos = length(X_flat);
fprintf('Calculando PEB para %d posiciones en Z = %.2f m\n', N_pos, altura_analisis);

% ============================================================================
% Cálculo del PEB para cada posición
% ============================================================================
if strcmp(modo_analisis, 'comparativo')
    % Modo comparativo: calcular PEB para ambos conjuntos
    PEB_values_optimized = zeros(size(X_flat));
    PEB_values_random = zeros(size(X_flat));
    
    fprintf('Calculando PEB para orientaciones optimizadas...\n');
    fprintf('Progreso: ');
    progress_step = round(N_pos / 20);
    
    tic;
    for i = 1:N_pos
        R = [X_flat(i); Y_flat(i); Z_flat(i)];
        
        % PEB para orientaciones optimizadas
        try
            PEB_values_optimized(i) = PEB_complete(R, nt_orientations_optimized, T', P_t, m_t, ...
                                                  A_det, theta_half, FOV, sigma2, N_samples);
        catch
            PEB_values_optimized(i) = NaN;
        end
        
        % PEB para orientaciones aleatorias
        try
            PEB_values_random(i) = PEB_complete(R, nt_orientations_random, T', P_t, m_t, ...
                                               A_det, theta_half, FOV, sigma2, N_samples);
        catch
            PEB_values_random(i) = NaN;
        end
        
        if mod(i, progress_step) == 0
            fprintf('█');
        end
    end
    
else
    % Modo descriptivo: calcular PEB solo para orientaciones optimizadas
    PEB_values = zeros(size(X_flat));
    
    fprintf('Progreso del cálculo: ');
    progress_step = round(N_pos / 20);
    
    tic;
    for i = 1:N_pos
        R = [X_flat(i); Y_flat(i); Z_flat(i)];
        
        try
            PEB_values(i) = PEB_complete(R, nt_orientations, T', P_t, m_t, ...
                                       A_det, theta_half, FOV, sigma2, N_samples);
        catch
            PEB_values(i) = NaN;
        end
        
        if mod(i, progress_step) == 0
            fprintf('█');
        end
    end
end
elapsed_time = toc;

fprintf('\n');
fprintf('Cálculo completado en %.2f segundos\n', elapsed_time);

% ============================================================================
% Procesamiento de resultados
% ============================================================================
if strcmp(modo_analisis, 'comparativo')
    % Modo comparativo: procesar ambos conjuntos
    PEB_matrix_optimized = reshape(PEB_values_optimized, size(X_grid));
    PEB_matrix_random = reshape(PEB_values_random, size(X_grid));
    
    valid_peb_opt = PEB_values_optimized(~isnan(PEB_values_optimized) & ~isinf(PEB_values_optimized));
    valid_peb_rand = PEB_values_random(~isnan(PEB_values_random) & ~isinf(PEB_values_random));
    
    % Estadísticas comparativas
    if ~isempty(valid_peb_opt) && ~isempty(valid_peb_rand)
        fprintf('\n=== ESTADÍSTICAS COMPARATIVAS DEL PEB ===\n');
        fprintf('\n--- ORIENTACIONES OPTIMIZADAS ---\n');
        fprintf('PEB mínimo: %.4f m\n', min(valid_peb_opt));
        fprintf('PEB máximo: %.4f m\n', max(valid_peb_opt));
        fprintf('PEB promedio: %.4f m\n', mean(valid_peb_opt));
        fprintf('PEB mediano: %.4f m\n', median(valid_peb_opt));
        fprintf('PEB RMS: %.4f m\n', sqrt(mean(valid_peb_opt.^2)));
        fprintf('PEB percentile-90: %.4f m\n', prctile(valid_peb_opt, 90));
        fprintf('Desviación estándar: %.4f m\n', std(valid_peb_opt));
        
        fprintf('\n--- ORIENTACIONES ALEATORIAS ---\n');
        fprintf('PEB mínimo: %.4f m\n', min(valid_peb_rand));
        fprintf('PEB máximo: %.4f m\n', max(valid_peb_rand));
        fprintf('PEB promedio: %.4f m\n', mean(valid_peb_rand));
        fprintf('PEB mediano: %.4f m\n', median(valid_peb_rand));
        fprintf('PEB RMS: %.4f m\n', sqrt(mean(valid_peb_rand.^2)));
        fprintf('PEB percentile-90: %.4f m\n', prctile(valid_peb_rand, 90));
        fprintf('Desviación estándar: %.4f m\n', std(valid_peb_rand));
        
        fprintf('\n--- MEJORA RELATIVA (Optimizadas vs Aleatorias) ---\n');
        mejora_promedio = (mean(valid_peb_rand) - mean(valid_peb_opt)) / mean(valid_peb_rand) * 100;
        mejora_rms = (sqrt(mean(valid_peb_rand.^2)) - sqrt(mean(valid_peb_opt.^2))) / sqrt(mean(valid_peb_rand.^2)) * 100;
        mejora_p90 = (prctile(valid_peb_rand, 90) - prctile(valid_peb_opt, 90)) / prctile(valid_peb_rand, 90) * 100;
        fprintf('Mejora en PEB promedio: %.1f%%\n', mejora_promedio);
        fprintf('Mejora en PEB RMS: %.1f%%\n', mejora_rms);
        fprintf('Mejora en PEB percentile-90: %.1f%%\n', mejora_p90);
    else
        fprintf('Error: No se pudieron calcular valores PEB válidos\n');
        return;
    end
    
else
    % Modo descriptivo: procesar solo orientaciones optimizadas
    PEB_matrix = reshape(PEB_values, size(X_grid));
    valid_peb = PEB_values(~isnan(PEB_values) & ~isinf(PEB_values));
    
    if ~isempty(valid_peb)
        fprintf('\n=== ESTADÍSTICAS DEL PEB ===\n');
        fprintf('PEB mínimo: %.4f m\n', min(valid_peb));
        fprintf('PEB máximo: %.4f m\n', max(valid_peb));
        fprintf('PEB promedio: %.4f m\n', mean(valid_peb));
        fprintf('PEB mediano: %.4f m\n', median(valid_peb));
        fprintf('PEB RMS: %.4f m\n', sqrt(mean(valid_peb.^2)));
        fprintf('PEB percentile-90: %.4f m\n', prctile(valid_peb, 90));
        fprintf('Desviación estándar: %.4f m\n', std(valid_peb));
        fprintf('Posiciones válidas: %d de %d (%.1f%%)\n', ...
                length(valid_peb), N_pos, 100*length(valid_peb)/N_pos);
    else
        fprintf('Error: No se pudieron calcular valores PEB válidos\n');
        return;
    end
end

% ============================================================================
% VISUALIZACIONES
% ============================================================================
if strcmp(modo_analisis, 'comparativo')
    % Modo comparativo: crear visualizaciones lado a lado
    
    % Determinar escala común para ambas visualizaciones
    all_valid_peb = [valid_peb_opt(:); valid_peb_rand(:)];
    min_peb_global = min(all_valid_peb);
    max_peb_global = max(all_valid_peb);
    
    % === FIGURA 1: Mapas de calor 2D comparativos ===
    figure(1);
    set(gcf, 'Position', [50, 100, 1600, 600]);
    
    % Subfigura 1: Orientaciones optimizadas
    subplot(1, 2, 1);
    imagesc(x_range, y_range, PEB_matrix_optimized);
    set(gca, 'YDir', 'normal');
    colormap(jet);
    caxis([min_peb_global, max_peb_global]);
    colorbar;
    xlabel('X [m]', 'Interpreter', 'latex', 'FontSize', 11);
    ylabel('Y [m]', 'Interpreter', 'latex', 'FontSize', 11);
    title('PEB - Orientaciones Optimizadas', 'Interpreter', 'latex', 'FontSize', 12);
    hold on;
    plot(T(1), T(2), 'w*', 'MarkerSize', 12, 'LineWidth', 2);
    plot(T(1), T(2), 'k*', 'MarkerSize', 10, 'LineWidth', 1);
    axis equal; grid on; set(gca, 'FontSize', 9);
    
    % Subfigura 2: Orientaciones aleatorias
    subplot(1, 2, 2);
    imagesc(x_range, y_range, PEB_matrix_random);
    set(gca, 'YDir', 'normal');
    colormap(jet);
    caxis([min_peb_global, max_peb_global]);
    colorbar;
    xlabel('X [m]', 'Interpreter', 'latex', 'FontSize', 11);
    ylabel('Y [m]', 'Interpreter', 'latex', 'FontSize', 11);
    title('PEB - Orientaciones Aleatorias', 'Interpreter', 'latex', 'FontSize', 12);
    hold on;
    plot(T(1), T(2), 'w*', 'MarkerSize', 12, 'LineWidth', 2);
    plot(T(1), T(2), 'k*', 'MarkerSize', 10, 'LineWidth', 1);
    axis equal; grid on; set(gca, 'FontSize', 9);
    
    % Título general
    sgtitle(sprintf('Comparacion PEB - Altura Z = %.2f m', altura_analisis), ...
            'Interpreter', 'none', 'FontSize', 14, 'FontWeight', 'bold');
    
    % === FIGURA 2: Superficies 3D comparativas ===
    figure(2);
    set(gcf, 'Position', [50, 550, 1600, 600]);
    
    % Subfigura 1: Superficie optimizada
    subplot(1, 2, 1);
    surf(X_grid, Y_grid, PEB_matrix_optimized, 'LineWidth', 0.1);
    colormap(jet);
    caxis([min_peb_global, max_peb_global]);
    zlim([0, max_peb_global]);  % Fijar rango Z desde 0 al máximo
    xlabel('X [m]', 'Interpreter', 'latex', 'FontSize', 11);
    ylabel('Y [m]', 'Interpreter', 'latex', 'FontSize', 11);
    zlabel('PEB [m]', 'Interpreter', 'latex', 'FontSize', 11);
    title('Superficie 3D - Optimizadas', 'Interpreter', 'latex', 'FontSize', 12);
    view(45, 30); grid on; set(gca, 'FontSize', 9);
    colorbar;
    
    % Subfigura 2: Superficie aleatoria
    subplot(1, 2, 2);
    surf(X_grid, Y_grid, PEB_matrix_random, 'LineWidth', 0.1);
    colormap(jet);
    caxis([min_peb_global, max_peb_global]);
    zlim([0, max_peb_global]);  % Fijar rango Z desde 0 al máximo
    xlabel('X [m]', 'Interpreter', 'latex', 'FontSize', 11);
    ylabel('Y [m]', 'Interpreter', 'latex', 'FontSize', 11);
    zlabel('PEB [m]', 'Interpreter', 'latex', 'FontSize', 11);
    title('Superficie 3D - Aleatorias', 'Interpreter', 'latex', 'FontSize', 12);
    view(45, 30); grid on; set(gca, 'FontSize', 9);
    colorbar;
    
    % Título general
    sgtitle(sprintf('Superficies 3D Comparativas - Altura Z = %.2f m', altura_analisis), ...
            'Interpreter', 'none', 'FontSize', 14, 'FontWeight', 'bold');
    
    % === FIGURA 3: Mapa de diferencias ===
    figure(3);
    set(gcf, 'Position', [750, 300, 800, 600]);
    
    % Calcular diferencia (aleatorias - optimizadas)
    PEB_diff = PEB_matrix_random - PEB_matrix_optimized;
    
    imagesc(x_range, y_range, PEB_diff);
    set(gca, 'YDir', 'normal');
    colormap(jet);
    colorbar;
    xlabel('X [m]', 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Y [m]', 'Interpreter', 'latex', 'FontSize', 12);
    title(sprintf('Diferencia PEB (Aleatorias - Optimizadas) - Z = %.2f m', altura_analisis), ...
          'Interpreter', 'latex', 'FontSize', 14);
    
    hold on;
    plot(T(1), T(2), 'w*', 'MarkerSize', 15, 'LineWidth', 2);
    plot(T(1), T(2), 'k*', 'MarkerSize', 12, 'LineWidth', 1);
    axis equal; grid on; set(gca, 'FontSize', 10);
    
    cb = colorbar;
    ylabel(cb, '$\Delta$ PEB [m]', 'Interpreter', 'latex', 'FontSize', 10);
    
    fprintf('\n=== VISUALIZACIONES COMPARATIVAS GENERADAS ===\n');
    fprintf('Figura 1: Mapas de calor 2D comparativos\n');
    fprintf('Figura 2: Superficies 3D comparativas\n');
    fprintf('Figura 3: Mapa de diferencias PEB\n');
    fprintf('==============================================\n');
    
else
    % Modo descriptivo: visualizaciones originales
    
    % Usar log scale para mejor visualización si hay gran rango de valores
    if max(valid_peb)/min(valid_peb) > 100
        PEB_matrix_plot = log10(PEB_matrix);
        use_log_scale = true;
        fprintf('Usando escala logarítmica debido al gran rango de valores\n');
    else
        PEB_matrix_plot = PEB_matrix;
        use_log_scale = false;
    end
    
    % === FIGURA 1: Mapa de calor 2D ===
    figure(1);
    set(gcf, 'Position', [100, 100, 800, 600]);
    
    imagesc(x_range, y_range, PEB_matrix_plot);
    set(gca, 'YDir', 'normal');
    colormap(jet);
    colorbar;
    
    xlabel('X [m]', 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Y [m]', 'Interpreter', 'latex', 'FontSize', 12);
    if use_log_scale
        title(sprintf('Mapa de Calor PEB (log_{10}) - Altura Z = %.2f m', altura_analisis), ...
              'Interpreter', 'latex', 'FontSize', 14);
        cb = colorbar;
        ylabel(cb, 'log_{10}(PEB) [log_{10}(m)]', 'Interpreter', 'latex', 'FontSize', 10);
    else
        title(sprintf('Mapa de Calor PEB - Altura Z = %.2f m', altura_analisis), ...
              'Interpreter', 'latex', 'FontSize', 14);
        cb = colorbar;
        ylabel(cb, 'PEB [m]', 'Interpreter', 'latex', 'FontSize', 10);
    end
    
    hold on;
    plot(T(1), T(2), 'w*', 'MarkerSize', 15, 'LineWidth', 2);
    plot(T(1), T(2), 'k*', 'MarkerSize', 12, 'LineWidth', 1);
    legend('', 'Posición LED', 'Location', 'best');
    
    axis equal; grid on; set(gca, 'FontSize', 10);
    
    % === FIGURA 2: Superficie 3D ===
    figure(2);
    set(gcf, 'Position', [950, 100, 800, 600]);
    
    surf(X_grid, Y_grid, PEB_matrix, 'LineWidth', 0.1);
    colormap(jet);
    colorbar;
    
    xlabel('X [m]', 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Y [m]', 'Interpreter', 'latex', 'FontSize', 12);
    zlabel('PEB [m]', 'Interpreter', 'latex', 'FontSize', 12);
    title(sprintf('Superficie 3D del PEB - Altura Z = %.2f m', altura_analisis), ...
          'Interpreter', 'latex', 'FontSize', 14);
    
    view(45, 30); grid on; set(gca, 'FontSize', 10);
    
    cb = colorbar;
    ylabel(cb, 'PEB [m]', 'Interpreter', 'latex', 'FontSize', 10);
    
    % === FIGURA 3: Vista superior ===
    figure(3);
    set(gcf, 'Position', [450, 500, 800, 600]);
    
    surf(X_grid, Y_grid, PEB_matrix, 'LineWidth', 0.1);
    colormap(jet);
    colorbar;
    
    view(0, 90);
    
    xlabel('X [m]', 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Y [m]', 'Interpreter', 'latex', 'FontSize', 12);
    title(sprintf('PEB - Vista Superior (Z = %.2f m)', altura_analisis), ...
          'Interpreter', 'latex', 'FontSize', 14);
    
    hold on;
    plot3(T(1), T(2), max(valid_peb)*1.1, 'w*', 'MarkerSize', 15, 'LineWidth', 2);
    plot3(T(1), T(2), max(valid_peb)*1.1, 'k*', 'MarkerSize', 12, 'LineWidth', 1);
    
    grid on; set(gca, 'FontSize', 10);
    
    cb = colorbar;
    ylabel(cb, 'PEB [m]', 'Interpreter', 'latex', 'FontSize', 10);
    
    fprintf('\n=== VISUALIZACIONES GENERADAS ===\n');
    fprintf('Figura 1: Mapa de calor 2D (vista plana)\n');
    fprintf('Figura 2: Superficie 3D (perspectiva)\n');
    fprintf('Figura 3: Superficie 3D (vista superior)\n');
    fprintf('=====================================\n');
end
