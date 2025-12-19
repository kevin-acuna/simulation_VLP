% analyze_positions.m
% Script para analizar y visualizar puntos registrados en positions3D.txt
% Columnas: x, y, z, done (1=registrado, 0=no registrado)

clear; close all; clc;

%% 1. Leer datos del archivo
filename = 'positions3D_updated.txt';
data = load(filename);

% Extraer columnas
x = data(:, 1);
y = data(:, 2);
z = data(:, 3);
done = data(:, 4);

%% 2. Contar puntos registrados
total_points = length(done);
registered_points = sum(done == 1);
unregistered_points = sum(done == 0);

% Calcular porcentaje
percentage_registered = (registered_points / total_points) * 100;

%% 3. Mostrar estadísticas
fprintf('========================================\n');
fprintf('  ANÁLISIS DE PUNTOS REGISTRADOS\n');
fprintf('========================================\n');
fprintf('Total de puntos:          %d\n', total_points);
fprintf('Puntos registrados:       %d\n', registered_points);
fprintf('Puntos no registrados:    %d\n', unregistered_points);
fprintf('Porcentaje registrado:    %.2f%%\n', percentage_registered);
fprintf('========================================\n\n');

%% 4. Separar puntos registrados y no registrados
idx_registered = (done == 1);
idx_unregistered = (done == 0);

x_reg = x(idx_registered);
y_reg = y(idx_registered);
z_reg = z(idx_registered);

x_unreg = x(idx_unregistered);
y_unreg = y(idx_unregistered);
z_unreg = z(idx_unregistered);

%% 5. Crear visualización 3D
figure('Position', [100, 100, 1200, 500]);

% Subplot 1: Todos los puntos con registrados destacados
subplot(1, 2, 1);
hold on; grid on;

% Plotear puntos no registrados (gris claro)
scatter3(x_unreg, y_unreg, z_unreg, 30, [0.8 0.8 0.8], 'filled', ...
    'MarkerFaceAlpha', 0.3, 'DisplayName', 'No registrados');

% Plotear puntos registrados (rojo)
scatter3(x_reg, y_reg, z_reg, 50, 'r', 'filled', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'DisplayName', 'Registrados');

xlabel('X [m]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Y [m]', 'FontSize', 12, 'FontWeight', 'bold');
zlabel('Z [m]', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Nube de Puntos 3D\n%d registrados de %d totales (%.1f%%)', ...
    registered_points, total_points, percentage_registered), ...
    'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
view(45, 30);
axis equal;
set(gca, 'FontSize', 10);

% Subplot 2: Solo puntos registrados
subplot(1, 2, 2);
hold on; grid on;

% Plotear solo puntos registrados con colormap por altura
scatter3(x_reg, y_reg, z_reg, 80, z_reg, 'filled', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 0.5);

xlabel('X [m]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Y [m]', 'FontSize', 12, 'FontWeight', 'bold');
zlabel('Z [m]', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Solo Puntos Registrados\n(Coloreados por altura Z)'), ...
    'FontSize', 14, 'FontWeight', 'bold');
colorbar('FontSize', 10);
colormap(jet);
view(45, 30);
axis equal;
set(gca, 'FontSize', 10);

%% 6. Crear vista superior (plano XY)
figure('Position', [100, 100, 1200, 500]);

% Subplot 1: Vista superior con todos los puntos
subplot(1, 2, 1);
hold on; grid on;

% Plotear puntos no registrados
scatter(x_unreg, y_unreg, 30, [0.8 0.8 0.8], 'filled', ...
    'MarkerFaceAlpha', 0.3, 'DisplayName', 'No registrados');

% Plotear puntos registrados
scatter(x_reg, y_reg, 50, 'r', 'filled', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'DisplayName', 'Registrados');

xlabel('X [m]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Y [m]', 'FontSize', 12, 'FontWeight', 'bold');
title('Vista Superior (Plano XY)', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
axis equal;
set(gca, 'FontSize', 10);

% Subplot 2: Vista superior solo registrados coloreados por Z
subplot(1, 2, 2);
hold on; grid on;

scatter(x_reg, y_reg, 80, z_reg, 'filled', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 0.5);

xlabel('X [m]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Y [m]', 'FontSize', 12, 'FontWeight', 'bold');
title('Puntos Registrados - Vista Superior', 'FontSize', 14, 'FontWeight', 'bold');
colorbar('FontSize', 10);
colormap(jet);
caxis([min(z_reg) max(z_reg)]);
axis equal;
set(gca, 'FontSize', 10);

%% 7. Análisis por altura
unique_z = unique(z);
fprintf('Distribución por altura Z:\n');
fprintf('---------------------------\n');
for i = 1:length(unique_z)
    z_val = unique_z(i);
    total_at_z = sum(z == z_val);
    registered_at_z = sum((z == z_val) & (done == 1));
    percentage_at_z = (registered_at_z / total_at_z) * 100;
    fprintf('Z = %.1f m: %d/%d registrados (%.1f%%)\n', ...
        z_val, registered_at_z, total_at_z, percentage_at_z);
end

fprintf('\n¡Análisis completado!\n');
