%% 7. Visualization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all, close all, clc

% Folder con los resultados de las metricas por cada método
addpath('methods_errors_time');

errorNormCRLB_K5 = load('K5_CRLB_fixed.mat').errorNormCRLB;
errorNormCRLB_K9 = load('K9_CRLB_fixed.mat').errorNormCRLB;

errorNormSVD_K3 = load('SVD_K3.mat').errorNormSVD;

errorNormWLS_K5 = load('K5_WLS_fixed.mat').filtered_errorNormWLS;
errorNormWLS_K9 = load('K9_WLS_fixed.mat').filtered_errorNormWLS;

errorNormGLS_K5 = load('K5_GLS_fixed.mat').filtered_errorNormGLS;
errorNormGLS_K9 = load('K9_GLS_fixed.mat').filtered_errorNormGLS;


errorNormNL_K5 = load('K5_NL_optimized_fixed.mat').errorNorm;
% errorNormNL_K5 = load('K5_NL.mat').errorNorm;

errorNormNL_K9 = load('K9_NL.mat').errorNorm;
%errorNormNL_K9_optimized = load('K9_NL_optimized.mat').errorNorm;



% CDF plot
figure(1)
hold on;
lw_5 = 1.5;
lw_9 = 0.2;
[f2, x2] = ecdf(errorNormSVD_K3(:)*100,'Function','cdf');stairs(x2, f2, '-', 'LineWidth', 0.5,'Color',[0.9290, 0.6940, 0.1250]);
[f2, x2] = ecdf(errorNormGLS_K5(:)*100,'Function','cdf');stairs(x2, f2, '-', 'LineWidth', lw_5,'Color',[0, 0.4470, 0.7410]);
[f1, x1] = ecdf(errorNormWLS_K5(:)*100,'Function','cdf');stairs(x1, f1, '-', 'LineWidth', lw_5,'Color',[0.8500, 0.3250, 0.0980]);
[f3, x3] = ecdf(errorNormNL_K5(:)*100,'Function','cdf'); stairs(x3, f3, '-', 'LineWidth', lw_5,'Color',[0.4940, 0.1840, 0.5560]);
[f4, x4] = ecdf(errorNormCRLB_K5(:)*100,'Function','cdf'); stairs(x4, f4, '-', 'LineWidth', lw_5,'Color',[0.4660, 0.6740, 0.1880]);

[f2, x2] = ecdf(errorNormGLS_K9(:)*100,'Function','cdf');stairs(x2, f2, '--', 'LineWidth', lw_9,'Color',[0, 0.4470, 0.7410]);
[f1, x1] = ecdf(errorNormWLS_K9(:)*100,'Function','cdf');stairs(x1, f1, '--', 'LineWidth', lw_9,'Color',[0.8500, 0.3250, 0.0980]);
[f3, x3] = ecdf(errorNormNL_K9(:)*100,'Function','cdf'); stairs(x3, f3, '--', 'LineWidth', lw_9,'Color',[0.4940, 0.1840, 0.5560]);
[f4, x4] = ecdf(errorNormCRLB_K9(:)*100,'Function','cdf'); stairs(x4, f4, '--', 'LineWidth', lw_9,'Color',[0.4660, 0.6740, 0.1880]);


grid on;
axis([0 16 0 1])
xlabel('Positioning Error (cm)','interpreter','latex');
ylabel('CDF','Interpreter','latex');
legend('K=3','K=5 (GLS)', 'K=5 (WLS)','K=5 (NL)', 'K=5 (PEB)', 'K=9 (GLS)','K=9 (WLS)','K=9 (NL)', 'K=9 (PEB)', 'Location', 'best','interpreter','latex');

%%
% Tiempo - Análisis comparativo de métodos de estimación
avg_time_K5_WLS = mean((load('K5_WLS_fixed.mat').time_WLS)*1000);
avg_time_K5_GLS = mean((load('K5_GLS_fixed.mat').time_GLS)*1000);
avg_time_K5_NL = mean((load('K5_NL_optimized_fixed.mat').time_NL)*1000);
avg_time_K9_WLS = mean((load('K9_WLS_fixed.mat').time_WLS)*1000);
avg_time_K9_GLS = mean((load('K9_GLS_fixed.mat').time_GLS)*1000);
avg_time_K9_NL = mean((load('K9_NL.mat').time_NL)*1000);

% Organizar datos por método y configuración (coherente con figura 1)
tiempos_K5 = [avg_time_K5_GLS, avg_time_K5_WLS, avg_time_K5_NL];
tiempos_K9 = [avg_time_K9_GLS, avg_time_K9_WLS, 97.7];

% Gráfico de barras agrupadas para comparativa de tiempos
figure(2)
hold on;

% Crear posiciones para las barras
pos_K5 = [1, 2, 3];
pos_K9 = [5, 6, 7];  % Separación para K=9

% Definir colores coherentes con figura 1
color_GLS = [0, 0.4470, 0.7410];      % Azul
color_WLS = [0.8500, 0.3250, 0.0980]; % Naranja  
color_NL = [0.4940, 0.1840, 0.5560];  % Púrpura

% Crear barras para K=5
bar1 = bar(pos_K5(1), tiempos_K5(1), 'FaceColor', color_GLS, 'EdgeColor', 'k', 'LineWidth', 0.5);
bar2 = bar(pos_K5(2), tiempos_K5(2), 'FaceColor', color_WLS, 'EdgeColor', 'k', 'LineWidth', 0.5);
bar3 = bar(pos_K5(3), tiempos_K5(3), 'FaceColor', color_NL, 'EdgeColor', 'k', 'LineWidth', 0.5);

% Crear barras para K=9 (GLS, WLS y NL disponibles)
bar4 = bar(pos_K9(1), tiempos_K9(1), 'FaceColor', color_GLS, 'EdgeColor', 'k', 'LineWidth', 0.5);
bar5 = bar(pos_K9(2), tiempos_K9(2), 'FaceColor', color_WLS, 'EdgeColor', 'k', 'LineWidth', 0.5);
bar6 = bar(pos_K9(3), tiempos_K9(3), 'FaceColor', color_NL, 'EdgeColor', 'k', 'LineWidth', 0.5);

% Configurar etiquetas del eje X
xticks([pos_K5, pos_K9]);
xticklabels({'GLS', 'WLS', 'NL', 'GLS', 'WLS', 'NL'});
set(gca, 'TickLabelInterpreter', 'latex');

% Etiquetas y formato
ylabel('Average Time per Estimation (ms)', 'Interpreter', 'latex');
xlabel('Method and Configuration', 'Interpreter', 'latex');

% Añadir líneas de separación visual entre K=5 y K=9
xline(4, '--', 'Alpha', 0.3, 'LineWidth', 1);

% Añadir valores encima de cada barra
all_times = [tiempos_K5, tiempos_K9];
all_pos = [pos_K5, pos_K9];
for i = 1:length(all_times)
    text(all_pos(i), all_times(i), sprintf('%.2f', all_times(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
         'FontSize', 10, 'Interpreter', 'latex');
end

% Añadir etiquetas de grupo
text(2, max(all_times)*0.1, 'K = 5', 'HorizontalAlignment', 'center', ...
     'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'latex');
text(6, max(all_times)*0.1, 'K = 9', 'HorizontalAlignment', 'center', ...
     'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'latex');

% Configuración estética
grid on;
ax = gca;
ax.XGrid = 'off';  % Solo grid horizontal para mayor claridad
ax.YGrid = 'on';
ax.GridLineStyle = '-';
ax.GridAlpha = 0.3;
ax.FontName = 'Times New Roman';
box on;

% Ajustar límites para mejor visualización
xlim([0.5, 7.5]);
ylim([1e-2, 2e+2]);

set(gca, 'YScale', 'log');

% Leyenda coherente con figura 1
legend([bar1, bar2, bar3], {'GLS', 'WLS', 'NL'}, 'Location', 'northeast', ...
       'Interpreter', 'latex', 'FontSize', 10);

hold off;
