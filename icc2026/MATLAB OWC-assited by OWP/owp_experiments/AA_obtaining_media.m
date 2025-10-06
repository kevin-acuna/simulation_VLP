clc, clear all, close all

% Flag para guardar las medias
save_mean = true;  % Cambiar a false para no guardar

colorsMATLAB = [0.0000 0.4470 0.7410 ;... 
                0.8500 0.3250 0.0980 ;...
                0.9290 0.6940 0.1250 ;...
                0.4940 0.1840 0.5560 ;...
                0.4660 0.6740 0.1880 ;...
                0.3010 0.7450 0.9330 ;...
                0.6350 0.0780 0.1840];

data = readtable('data_20251006_181811.csv');

% Corregir el voltaje: aplicar el negativo del voltaje leído
data.medida_daq = -data.medida_daq;

%% 1. Obtener posiciones únicas
% Extraer las posiciones (x, y, z) únicas
unique_positions = unique(data(:, {'x', 'y', 'z'}), 'rows');
fprintf('Total de posiciones únicas: %d\n', height(unique_positions));
disp(unique_positions);

%% 2. Identificar las orientaciones únicas (K_1, K_2, K_3)
unique_orientations = unique(data(:, {'inclinacion', 'azimuth'}), 'rows');
fprintf('\nOrientaciones únicas (K):\n');
for k = 1:height(unique_orientations)
    fprintf('K_%d: inclinacion=%.1f°, azimuth=%.1f°\n', ...
            k, unique_orientations.inclinacion(k), unique_orientations.azimuth(k));
end

%% 3. Crear gráfica con 3 subgráficas
figure('Position', [100 100 1200 900]);

for k = 1:3
    subplot(3, 1, k);
    hold on;
    grid on;
    
    % Filtrar datos para esta orientación
    incl = unique_orientations.inclinacion(k);
    azim = unique_orientations.azimuth(k);
    
    data_orientacion = data(data.inclinacion == incl & data.azimuth == azim, :);
    
    % Concatenar todos los datos de todas las posiciones
    all_data = [];
    idx_acumulado = 0;
    
    % Para cada posición única, concatenar sus muestras
    for p = 1:height(unique_positions)
        pos_x = unique_positions.x(p);
        pos_y = unique_positions.y(p);
        pos_z = unique_positions.z(p);
        
        % Filtrar muestras para esta posición
        muestras = data_orientacion(data_orientacion.x == pos_x & ...
                                     data_orientacion.y == pos_y & ...
                                     data_orientacion.z == pos_z, :);
        
        if height(muestras) > 0
            % Concatenar las muestras
            n_muestras = height(muestras);
            x_vals = (1:n_muestras) + idx_acumulado;
            
            % Graficar con color diferente para cada posición
            plot(x_vals, muestras.medida_daq, '-', 'Color', colorsMATLAB(mod(p-1,7)+1,:), ...
                 'MarkerSize', 6, 'DisplayName', sprintf('Pos %d: (%.2f,%.2f,%.2f)', ...
                 p, pos_x, pos_y, pos_z));
            
            idx_acumulado = idx_acumulado + n_muestras;
        end
    end
    
    ylabel(sprintf('K%d', k));
    %title(sprintf('Orientación K_%d: inclinación=%.1f°, azimuth=%.1f°', k, incl, azim));
    legend('Location', 'best', 'FontSize', 8);
    hold off;
end

%% 4. Guardar medias si save_mean es true
if save_mean
    fprintf('\n=== Calculando y guardando medias ===\n');
    
    % Inicializar arreglos para almacenar resultados
    n_total = height(unique_positions) * height(unique_orientations);
    x_vals = zeros(n_total, 1);
    y_vals = zeros(n_total, 1);
    z_vals = zeros(n_total, 1);
    incl_vals = zeros(n_total, 1);
    azim_vals = zeros(n_total, 1);
    mean_vals = zeros(n_total, 1);
    median_vals = zeros(n_total, 1);
    
    idx = 1;
    
    % Para cada posición única (primero por posición)
    for p = 1:height(unique_positions)
        pos_x = unique_positions.x(p);
        pos_y = unique_positions.y(p);
        pos_z = unique_positions.z(p);
        
        % Para cada orientación (luego por orientación)
        for k = 1:height(unique_orientations)
            incl = unique_orientations.inclinacion(k);
            azim = unique_orientations.azimuth(k);
            
            % Filtrar datos para esta orientación y posición
            muestras = data(data.inclinacion == incl & data.azimuth == azim & ...
                           data.x == pos_x & data.y == pos_y & data.z == pos_z, :);
            
            if height(muestras) > 0
                % Calcular la media y mediana
                media = mean(muestras.medida_daq);
                mediana = median(muestras.medida_daq);
                
                % Guardar en los arreglos
                x_vals(idx) = pos_x;
                y_vals(idx) = pos_y;
                z_vals(idx) = pos_z;
                incl_vals(idx) = incl;
                azim_vals(idx) = azim;
                mean_vals(idx) = media;
                median_vals(idx) = mediana;
                
                idx = idx + 1;
            end
        end
    end
    
    % Recortar arreglos al tamaño real (en caso de que hubiera posiciones sin datos)
    x_vals = x_vals(1:idx-1);
    y_vals = y_vals(1:idx-1);
    z_vals = z_vals(1:idx-1);
    incl_vals = incl_vals(1:idx-1);
    azim_vals = azim_vals(1:idx-1);
    mean_vals = mean_vals(1:idx-1);
    median_vals = median_vals(1:idx-1);
    
    % Crear tabla con los resultados
    medias_table = table(x_vals, y_vals, z_vals, incl_vals, azim_vals, mean_vals, median_vals, ...
                         'VariableNames', {'x', 'y', 'z', 'inclinacion', 'azimuth', 'mean', 'median'});
    
    % Guardar en archivo CSV
    writetable(medias_table, 'database.csv');
else
    fprintf('\n=== save_mean = false: No se guardaron las medias ===\n');
end

