clear; close all; clc;

% Eje descentrado/alineado.

% Cargar datos
x_data = readtable('radiation_pattern_axis_X.csv');
x_angulo = x_data.angulo_grados;
x_voltaje = -x_data.voltaje;

y_data = readtable('radiation_pattern_axis_Y.csv');
y_angulo = (y_data.angulo_grados);
y_voltaje = -y_data.voltaje;

% Simetria
y_angulo = y_angulo;


% Figure
figure(1);
hold on
plot(x_angulo, x_voltaje, '.', 'MarkerSize', 4, 'Color', [0.2 0.4 0.8]);
plot(y_angulo, y_voltaje, '.', 'MarkerSize', 4, 'Color', [0.2 0.4 0.8]);
grid minor;
xlabel('angle (degree)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('voltage (V)', 'FontSize', 12, 'FontWeight', 'bold');


% Obtener ángulos únicos y calcular media para cada uno
x_angulos_unicos = unique(x_angulo);
x_voltaje_median = zeros(size(x_angulos_unicos));

y_angulos_unicos = unique(y_angulo);
y_voltaje_median = zeros(size(y_angulos_unicos));

for i = 1:length(x_angulos_unicos)
    idx = x_angulo == x_angulos_unicos(i);
    x_voltaje_median(i) = median(x_voltaje(idx));
end

for i = 1:length(y_angulos_unicos)
    idx = y_angulo == y_angulos_unicos(i);
    y_voltaje_median(i) = median(y_voltaje(idx));
end


plot(x_angulos_unicos, x_voltaje_median,'LineWidth', 2,'DisplayName','X-axis')
plot(y_angulos_unicos, y_voltaje_median,'LineWidth', 2,'DisplayName','Y-axis')

xline(0)
legend
hold off;
