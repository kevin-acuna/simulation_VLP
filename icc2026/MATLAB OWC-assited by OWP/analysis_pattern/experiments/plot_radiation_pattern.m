% Script para analizar y graficar el patrón de radiación del eje X
% Autor: Cascade
% Fecha: 2025-10-01

clear; close all; clc;

%% Cargar datos
fprintf('Cargando datos del archivo CSV...\n');
data = readtable('radiation_pattern_axis_Y.csv');

% Extraer columnas
angulo_grados = data.angulo_grados;
voltaje = data.voltaje;

% ajuste de voltaje
voltaje = -voltaje;

fprintf('Datos cargados: %d mediciones\n', length(voltaje));
fprintf('Rango de ángulos: %.1f° a %.1f°\n', min(angulo_grados), max(angulo_grados));

%% Gráfica 1: Todos los datos (angulo_grados vs voltaje)
figure(1);
hold on

plot(angulo_grados, voltaje, '.', 'MarkerSize', 4, 'Color', [0.2 0.4 0.8]);
grid minor;
xlabel('angle (degree)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('voltage (V)', 'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'FontSize', 11);

% Estadísticas básicas
fprintf('\n=== Estadísticas de todos los datos ===\n');
fprintf('Voltaje promedio: %.6f V\n', mean(voltaje));
fprintf('Voltaje máximo: %.6f V\n', max(voltaje));
fprintf('Voltaje mínimo: %.6f V\n', min(voltaje));
fprintf('Desviación estándar: %.6f V\n', std(voltaje));

%% Gráfica 2: Media por ángulo (angulo_grados_media vs voltaje_medio)
fprintf('\nCalculando valores medios por ángulo...\n');

% Obtener ángulos únicos y calcular media para cada uno
angulos_unicos = unique(angulo_grados);
voltaje_medio = zeros(size(angulos_unicos));
voltaje_std = zeros(size(angulos_unicos));
num_muestras = zeros(size(angulos_unicos));

for i = 1:length(angulos_unicos)
    idx = angulo_grados == angulos_unicos(i);
    voltaje_medio(i) = median(voltaje(idx));
    voltaje_std(i) = std(voltaje(idx));
    num_muestras(i) = sum(idx);
end

fprintf('Número de ángulos únicos: %d\n', length(angulos_unicos));
fprintf('Muestras por ángulo: min=%d, max=%d, promedio=%.1f\n', ...
    min(num_muestras), max(num_muestras), mean(num_muestras));


% Graficar con barras de error (desviación estándar)
plot(angulos_unicos, voltaje_medio,'LineWidth', 2)

set(gca, 'FontSize', 11);
hold off;

%% Estadísticas de valores medios
fprintf('\n=== Estadísticas de valores medios ===\n');
[max_voltaje, idx_max] = max(voltaje_medio);
[min_voltaje, idx_min] = min(voltaje_medio);
fprintf('Voltaje medio máximo: %.6f V en ángulo %.1f°\n', max_voltaje, angulos_unicos(idx_max));
fprintf('Voltaje medio mínimo: %.6f V en ángulo %.1f°\n', min_voltaje, angulos_unicos(idx_min));
fprintf('Promedio global: %.6f V\n', mean(voltaje_medio));
fprintf('Desviación estándar promedio: %.6f V\n', mean(voltaje_std));

%% Guardar resultados
fprintf('\nGuardando resultados...\n');

% Guardar tabla con valores medios
result_table = table(angulos_unicos, voltaje_medio, ...
    'VariableNames', {'Angulo_grados', 'Voltaje_Medio_V'});
% writetable(result_table, 'experiment_axis_X.csv');
fprintf('Tabla de valores medios guardada en: radiation_pattern_axis_X_medias.csv\n');

fprintf('\n¡Análisis completado!\n');
