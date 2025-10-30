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

data = readtable('db_icc2026_randnr/data_20251029_162859.csv');
% data_20251028_121959 | robot :  0.00 0.4 
% data_20251029_112748 | robot :  0.00 0.4 
% data_20251029_120128 | robot : -0.25 0.4 
% data_20251029_151741 | robot : -0.50 0.4 
% data_20251029_154538 | robot : -0.50 0.4
% data_20251029_162859 | robot : -0.4 0.4

% Corregir el voltaje: aplicar el negativo del voltaje leído
data.medida_daq = -data.medida_daq;

%% 1. Obtener sample_id únicos
% Extraer los sample_id únicos (cada uno representa una medición única)
unique_samples = unique(data.sample_id);
fprintf('Total de muestras únicas (sample_id): %d\n', length(unique_samples));

% Mostrar información de cada sample_id
for i = 1:length(unique_samples)
    sample_data = data(strcmp(data.sample_id, unique_samples{i}), :);
    if height(sample_data) > 0
        fprintf('Sample ID: %s - Pos: (%.2f, %.2f, %.2f)\n', ...
                unique_samples{i}, sample_data.x(1), sample_data.y(1), sample_data.z(1));
    end
end

%% 2. Identificar las orientaciones únicas (K_1, K_2, K_3)
unique_orientations = unique(data(:, {'inclinacion', 'azimuth'}), 'rows');
fprintf('\nOrientaciones únicas (K):\n');
for k = 1:height(unique_orientations)
    fprintf('K_%d: inclinacion=%.1f°, azimuth=%.1f°\n', ...
            k, unique_orientations.inclinacion(k), unique_orientations.azimuth(k));
end

%% 3. Crear gráfica con 3 subgráficas
figure('Position', [100 100 1200 900]);

sigma2=[];
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
    
    % Para cada sample_id único, concatenar sus muestras
    for s = 1:length(unique_samples)
        sample_id = unique_samples{s};
        
        % Filtrar muestras para este sample_id
        muestras = data_orientacion(strcmp(data_orientacion.sample_id, sample_id), :);
        
        if height(muestras) > 0
            % Concatenar las muestras
            n_muestras = height(muestras);
            x_vals = (1:n_muestras) + idx_acumulado;
            sigma2 = [sigma2 var(muestras.medida_daq)];
            
            % Obtener información de posición para la leyenda
            pos_x = muestras.x(1);
            pos_y = muestras.y(1);
            pos_z = muestras.z(1);
            
            % Graficar con color diferente para cada sample_id
            plot(x_vals, muestras.medida_daq, '-', 'Color', colorsMATLAB(mod(s-1,7)+1,:), ...
                 'MarkerSize', 6, 'DisplayName', sprintf('ID:%s (%.2f,%.2f,%.2f)', ...
                 sample_id, pos_x, pos_y, pos_z));
            
            idx_acumulado = idx_acumulado + n_muestras;
%             axis([-inf inf 0 5 ])
        end
    end
    
    ylabel(sprintf('K%d', k));
    ylim([0 5]);
    %title(sprintf('Orientación K_%d: inclinación=%.1f°, azimuth=%.1f°', k, incl, azim));
    %legend('Location', 'best', 'FontSize', 8);
    legend('Location', 'eastoutside', 'FontSize', 8);
    hold off;
end

%% 4. Guardar medias si save_mean es true
if save_mean
    fprintf('\n=== Calculando y guardando medias ===\n');
    
    % Inicializar arreglos para almacenar resultados
    n_total = length(unique_samples) * height(unique_orientations);
    sample_id_vals = cell(n_total, 1);
    x_vals = zeros(n_total, 1);
    y_vals = zeros(n_total, 1);
    z_vals = zeros(n_total, 1);
    incl_vals = zeros(n_total, 1);
    azim_vals = zeros(n_total, 1);
    mean_vals = zeros(n_total, 1);
    median_vals = zeros(n_total, 1);
    
    idx = 1;
    
    % Para cada sample_id único
    for s = 1:length(unique_samples)
        sample_id = unique_samples{s};
        
        % Obtener información de posición para este sample_id
        sample_data = data(strcmp(data.sample_id, sample_id), :);
        if height(sample_data) > 0
            pos_x = sample_data.x(1);
            pos_y = sample_data.y(1);
            pos_z = sample_data.z(1);
        else
            continue;
        end
        
        % Para cada orientación
        for k = 1:height(unique_orientations)
            incl = unique_orientations.inclinacion(k);
            azim = unique_orientations.azimuth(k);
            
            % Filtrar datos para esta orientación y sample_id
            muestras = data(strcmp(data.sample_id, sample_id) & ...
                           data.inclinacion == incl & data.azimuth == azim, :);
            
            if height(muestras) > 0
                % Calcular la media y mediana
                media = mean(muestras.medida_daq);
                mediana = median(muestras.medida_daq);
                
                % Guardar en los arreglos
                sample_id_vals{idx} = sample_id;
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
    
    % Recortar arreglos al tamaño real (en caso de que hubiera sample_ids sin datos)
    sample_id_vals = sample_id_vals(1:idx-1);
    x_vals = x_vals(1:idx-1)+0.02; % if data_20251029_120128 (+0.01 : pos-calibration)
    y_vals = y_vals(1:idx-1);
    z_vals = z_vals(1:idx-1);
    incl_vals = incl_vals(1:idx-1);
    azim_vals = azim_vals(1:idx-1);
    mean_vals = mean_vals(1:idx-1);
    median_vals = median_vals(1:idx-1);
    
    % Crear tabla con los resultados
    medias_table = table(sample_id_vals, x_vals, y_vals, z_vals, incl_vals, azim_vals, mean_vals, median_vals, ...
                         'VariableNames', {'sample_id', 'x', 'y', 'z', 'inclinacion', 'azimuth', 'mean', 'median'});
    
    % Guardar en archivo CSV
    writetable(medias_table, 'database.csv');
else
    fprintf('\n=== save_mean = false: No se guardaron las medias ===\n');
end
