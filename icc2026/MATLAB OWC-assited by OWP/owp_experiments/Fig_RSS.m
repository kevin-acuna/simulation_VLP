clc, clear all, close all

colorsMATLAB = [0.0000 0.4470 0.7410 ;... 
                0.8500 0.3250 0.0980 ;...
                0.9290 0.6940 0.1250 ;...
                0.4940 0.1840 0.5560 ;...
                0.4660 0.6740 0.1880 ;...
                0.3010 0.7450 0.9330 ;...
                0.6350 0.0780 0.1840];

data = readtable('db_icc2026_randnr/data_20251029_112748.csv');

% Corregir el voltaje: aplicar el negativo del voltaje leído
V_bg = 0.0411;
data.medida_daq = V_bg-data.medida_daq;

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
%figure('Position', [100 100 1200 900]);
figure(1)
sigma2=[];
for k = 1:3
    if k==1
        factor_correction = 1.0625;
    elseif k==2
        factor_correction = 0.9815;
    elseif k==3
        factor_correction = 0.9616;
    else
        factor_correction = 0;
    end
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
            plot(x_vals, factor_correction*muestras.medida_daq, '-', 'Color', [colorsMATLAB(mod(s-1,7)+1,:) 0.6], ...
                 'MarkerSize', 6, 'DisplayName', sprintf('ID:%s (%.2f,%.2f,%.2f)', ...
                 sample_id, pos_x, pos_y, pos_z));
            
            idx_acumulado = idx_acumulado + n_muestras;
%             axis([-inf inf 0 5 ])
        end
    end
    
    if k==1
        ylim([4 5]);
    elseif k==2
        ylim([3.5 4.5]);
    elseif k==3
        ylim([3 4]);
    else
        ylim([3 5]);
    end
    ylabel(sprintf('V_{%d}', k));
    box on
    %title(sprintf('Orientación K_%d: inclinación=%.1f°, azimuth=%.1f°', k, incl, azim));
    %legend('Location', 'best', 'FontSize', 8);
    %legend('Location', 'eastoutside', 'FontSize', 8);
    hold off;
end
xlabel('Samples');