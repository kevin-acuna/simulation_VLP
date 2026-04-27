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

errorNormNL_K9 = load('K9_NL_optimized_fixed.mat').errorNorm;
%errorNormNL_K9_optimized = load('K9_NL_optimized.mat').errorNorm;



% CDF plot
figure(1)
hold on;
lw_5 = 1;
lw_9 = 1;
factor = 100;
[f2, x2] = ecdf(errorNormSVD_K3(:)*factor,'Function','cdf');stairs(x2, f2, '-', 'LineWidth', 0.5,'Color',[0.9290, 0.6940, 0.1250]);
[f2, x2] = ecdf(errorNormGLS_K5(:)*factor,'Function','cdf');stairs(x2, f2, '-', 'LineWidth', lw_5,'Color',[0, 0.4470, 0.7410]);
[f1, x1] = ecdf(errorNormWLS_K5(:)*factor,'Function','cdf');stairs(x1, f1, '-', 'LineWidth', lw_5,'Color',[0.8500, 0.3250, 0.0980]);
[f3, x3] = ecdf(errorNormNL_K5(:)*factor,'Function','cdf'); stairs(x3, f3, '-', 'LineWidth', lw_5,'Color',[0.4940, 0.1840, 0.5560]);
[f4, x4] = ecdf(errorNormCRLB_K5(:)*factor,'Function','cdf'); stairs(x4, f4, '-', 'LineWidth', lw_5,'Color',[0.4660, 0.6740, 0.1880]);

[f2, x2] = ecdf(errorNormGLS_K9(:)*factor,'Function','cdf');stairs(x2, f2, '--', 'LineWidth', lw_9,'Color',[0, 0.4470, 0.7410]);
[f1, x1] = ecdf(errorNormWLS_K9(:)*factor,'Function','cdf');stairs(x1, f1, '--', 'LineWidth', lw_9,'Color',[0.8500, 0.3250, 0.0980]);
[f3, x3] = ecdf(errorNormNL_K9(:)*factor,'Function','cdf'); stairs(x3, f3, '--', 'LineWidth', lw_9,'Color',[0.4940, 0.1840, 0.5560]);
[f4, x4] = ecdf(errorNormCRLB_K9(:)*factor,'Function','cdf'); stairs(x4, f4, '--', 'LineWidth', lw_9,'Color',[0.4660, 0.6740, 0.1880]);

yline(0.9,'--','LineWidth',0.4,'Color',[0.5 0.5 0.5])
grid on;
axis([0 14 0 1])
xlabel('Positioning Error [cm]','interpreter','latex');
ylabel('CDF','Interpreter','latex');
legend('K=3 [22]','K=5 (GLS)', 'K=5 (WLS)','K=5 (NL)', 'K=5 (PEB)', 'K=9 (GLS)','K=9 (WLS)','K=9 (NL)', 'K=9 (PEB)', 'Location', 'best','interpreter','latex');

ax = gca;           % obtiene el objeto de ejes actual
ax.Box = 'on';      % activa el marco completo
ax.LineWidth = 1; % grosor del borde

% figure(1);
% set(gcf, 'Color', 'white');
% print('Fig_CDF.png', '-dpng', '-r300');


%%
close all 
% Tiempo - Análisis comparativo de métodos de estimación
% avg_time_K5_WLS = median((load('K5_WLS_fixed.mat').time_WLS)*1000);
% avg_time_K5_GLS = median((load('K5_GLS_fixed.mat').time_GLS)*1000);
% avg_time_K5_NL = median((load('K5_NL_optimized_fixed.mat').time_NL)*1000);
% avg_time_K9_WLS = median((load('K9_WLS_fixed.mat').time_WLS)*1000);
% avg_time_K9_GLS = median((load('K9_GLS_fixed.mat').time_GLS)*1000);
% avg_time_K9_NL = median((load('K9_NL_optimized_fixed.mat').time_NL)*1000);

avg_time_K5_WLS = 0.0217;
avg_time_K5_GLS = 0.0267;
avg_time_K5_NL = median((load('K5_NL_optimized_fixed.mat').time_NL)*1000);
avg_time_K9_WLS = 0.026050;
avg_time_K9_GLS = 0.0341;
avg_time_K9_NL = median((load('K9_NL_optimized_fixed.mat').time_NL)*1000);



% Organizar datos por método y configuración (coherente con figura 1)
tiempos_K5 = [avg_time_K5_GLS, avg_time_K5_WLS, avg_time_K5_NL];
tiempos_K9 = [avg_time_K9_GLS, avg_time_K9_WLS, avg_time_K9_NL];

% Gráfico de barras agrupadas para comparativa de tiempos
fig = figure('Position', [100, 100, 800, 400]);
% figure(2)
hold on;

% Crear posiciones para las barras
pos_K5 = [1, 2, 3];
pos_K9 = [5, 6, 7];  % Separación para K=9

% Definir colores coherentes con figura 1
color_GLS = [0, 0.4470, 0.7410];      % Azul
color_WLS = [0.8500, 0.3250, 0.0980]; % Naranja  
color_NL = [0.4940, 0.1840, 0.5560];  % Púrpura
withbar = 0.6;
% Crear barras para K=5
bar1 = bar(pos_K5(1), tiempos_K5(1), withbar ,'FaceColor', color_GLS, 'EdgeColor', 'k', 'LineWidth', 0.5);
bar2 = bar(pos_K5(2), tiempos_K5(2), withbar ,'FaceColor', color_WLS, 'EdgeColor', 'k', 'LineWidth', 0.5);
bar3 = bar(pos_K5(3), tiempos_K5(3), withbar ,'FaceColor', color_NL, 'EdgeColor', 'k', 'LineWidth', 0.5);

% Crear barras para K=9 (GLS, WLS y NL disponibles)
bar4 = bar(pos_K9(1), tiempos_K9(1), withbar ,'FaceColor', color_GLS, 'EdgeColor', 'k', 'LineWidth', 0.5);
bar5 = bar(pos_K9(2), tiempos_K9(2), withbar ,'FaceColor', color_WLS, 'EdgeColor', 'k', 'LineWidth', 0.5);
bar6 = bar(pos_K9(3), tiempos_K9(3), withbar ,'FaceColor', color_NL, 'EdgeColor', 'k', 'LineWidth', 0.5);

% Configurar etiquetas del eje X
xticks([pos_K5, pos_K9]);
xticklabels({'GLS', 'WLS', 'NL', 'GLS', 'WLS', 'NL'});
set(gca, 'TickLabelInterpreter', 'latex');

% Etiquetas y formato
ylabel('Average time per estimation [ms]', 'Interpreter', 'latex');
xlabel('Method and configuration', 'Interpreter', 'latex');

% Añadir líneas de separación visual entre K=5 y K=9
xline(4, '--', 'Alpha', 0.3, 'LineWidth', 1);

% Añadir valores encima de cada barra
all_times = [tiempos_K5, tiempos_K9];
all_pos = [pos_K5, pos_K9];
for i = 1:length(all_times)
    text(all_pos(i), all_times(i), sprintf('%.3f', all_times(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
         'FontSize', 14, 'Interpreter', 'latex');
end

% Añadir etiquetas de grupo
text(2, max(all_times)*0.1, 'K = 5', 'HorizontalAlignment', 'center', ...
     'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'latex');
text(6, max(all_times)*0.1, 'K = 9', 'HorizontalAlignment', 'center', ...
     'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'latex');

% Configuración estética
grid on;
ax = gca;
ax.FontSize = 14;
ax.XGrid = 'off';  % Solo grid horizontal para mayor claridad
ax.YGrid = 'on';
ax.GridLineStyle = '-';
ax.GridAlpha = 0.3;
ax.FontName = 'Times New Roman';
box on;

% Ajustar límites para mejor visualización
xlim([0.5, 7.5]);
ylim([1e-2, 1e+3]);

set(gca, 'YScale', 'log');

% Leyenda coherente con figura 1
%legend([bar1, bar2, bar3], {'GLS', 'WLS', 'NL'}, 'Location', 'northeast', 'Interpreter', 'latex', 'FontSize', 10);

ax.Box = 'on';      % activa el marco completo
ax.LineWidth = 1; % grosor del borde

hold off;

figure(1);
set(gcf, 'Color', 'white');
print('Fig_Time.png', '-dpng', '-r300');


%%

%% Cálculo de métricas: RMSE, CDF_90%, APE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('======================================================================\n');
fprintf('MÉTRICAS DE RENDIMIENTO POR MÉTODO\n');
fprintf('======================================================================\n\n');

% Función para calcular CDF 90%
calculate_cdf90 = @(data) prctile(data*100, 90); % Percentil 90 en cm

% --- K=3 (SVD) ---
rmse_SVD_K3 = sqrt(mean(errorNormSVD_K3.^2));
cdf90_SVD_K3 = calculate_cdf90(errorNormSVD_K3);
ape_SVD_K3 = mean(errorNormSVD_K3);

fprintf('K=3 (SVD):\n');
fprintf('  RMSE: %.4f m (%.2f cm)\n', rmse_SVD_K3, rmse_SVD_K3*100);
fprintf('  CDF 90%%: %.2f cm\n', cdf90_SVD_K3);
fprintf('  APE: %.4f m (%.2f cm)\n\n', ape_SVD_K3, ape_SVD_K3*100);

% --- K=5 Methods ---
fprintf('K=5 METHODS:\n');
fprintf('----------------------------------------\n');

% GLS K=5
rmse_GLS_K5 = sqrt(mean(errorNormGLS_K5.^2));
cdf90_GLS_K5 = calculate_cdf90(errorNormGLS_K5);
ape_GLS_K5 = mean(errorNormGLS_K5);

fprintf('GLS K=5:\n');
fprintf('  RMSE: %.4f m (%.2f cm)\n', rmse_GLS_K5, rmse_GLS_K5*100);
fprintf('  CDF 90%%: %.2f cm\n', cdf90_GLS_K5);
fprintf('  APE: %.4f m (%.2f cm)\n\n', ape_GLS_K5, ape_GLS_K5*100);

% WLS K=5
rmse_WLS_K5 = sqrt(mean(errorNormWLS_K5.^2));
cdf90_WLS_K5 = calculate_cdf90(errorNormWLS_K5);
ape_WLS_K5 = mean(errorNormWLS_K5);

fprintf('WLS K=5:\n');
fprintf('  RMSE: %.4f m (%.2f cm)\n', rmse_WLS_K5, rmse_WLS_K5*100);
fprintf('  CDF 90%%: %.2f cm\n', cdf90_WLS_K5);
fprintf('  APE: %.4f m (%.2f cm)\n\n', ape_WLS_K5, ape_WLS_K5*100);

% NL K=5
rmse_NL_K5 = sqrt(mean(errorNormNL_K5.^2));
cdf90_NL_K5 = calculate_cdf90(errorNormNL_K5);
ape_NL_K5 = mean(errorNormNL_K5);

fprintf('NL K=5:\n');
fprintf('  RMSE: %.4f m (%.2f cm)\n', rmse_NL_K5, rmse_NL_K5*100);
fprintf('  CDF 90%%: %.2f cm\n', cdf90_NL_K5);
fprintf('  APE: %.4f m (%.2f cm)\n\n', ape_NL_K5, ape_NL_K5*100);

% CRLB K=5 (límite teórico)
rmse_CRLB_K5 = sqrt(mean(errorNormCRLB_K5.^2));
cdf90_CRLB_K5 = calculate_cdf90(errorNormCRLB_K5);
ape_CRLB_K5 = mean(errorNormCRLB_K5);

fprintf('CRLB K=5 (límite teórico):\n');
fprintf('  RMSE: %.4f m (%.2f cm)\n', rmse_CRLB_K5, rmse_CRLB_K5*100);
fprintf('  CDF 90%%: %.2f cm\n', cdf90_CRLB_K5);
fprintf('  APE: %.4f m (%.2f cm)\n\n', ape_CRLB_K5, ape_CRLB_K5*100);

% --- K=9 Methods ---
fprintf('K=9 METHODS:\n');
fprintf('----------------------------------------\n');

% GLS K=9
rmse_GLS_K9 = sqrt(mean(errorNormGLS_K9.^2));
cdf90_GLS_K9 = calculate_cdf90(errorNormGLS_K9);
ape_GLS_K9 = mean(errorNormGLS_K9);

fprintf('GLS K=9:\n');
fprintf('  RMSE: %.4f m (%.2f cm)\n', rmse_GLS_K9, rmse_GLS_K9*100);
fprintf('  CDF 90%%: %.2f cm\n', cdf90_GLS_K9);
fprintf('  APE: %.4f m (%.2f cm)\n\n', ape_GLS_K9, ape_GLS_K9*100);

% WLS K=9
rmse_WLS_K9 = sqrt(mean(errorNormWLS_K9.^2));
cdf90_WLS_K9 = calculate_cdf90(errorNormWLS_K9);
ape_WLS_K9 = mean(errorNormWLS_K9);

fprintf('WLS K=9:\n');
fprintf('  RMSE: %.4f m (%.2f cm)\n', rmse_WLS_K9, rmse_WLS_K9*100);
fprintf('  CDF 90%%: %.2f cm\n', cdf90_WLS_K9);
fprintf('  APE: %.4f m (%.2f cm)\n\n', ape_WLS_K9, ape_WLS_K9*100);

% NL K=9
rmse_NL_K9 = sqrt(mean(errorNormNL_K9.^2));
cdf90_NL_K9 = calculate_cdf90(errorNormNL_K9);
ape_NL_K9 = mean(errorNormNL_K9);

fprintf('NL K=9:\n');
fprintf('  RMSE: %.4f m (%.2f cm)\n', rmse_NL_K9, rmse_NL_K9*100);
fprintf('  CDF 90%%: %.2f cm\n', cdf90_NL_K9);
fprintf('  APE: %.4f m (%.2f cm)\n\n', ape_NL_K9, ape_NL_K9*100);

% CRLB K=9 (límite teórico)
rmse_CRLB_K9 = sqrt(mean(errorNormCRLB_K9.^2));
cdf90_CRLB_K9 = calculate_cdf90(errorNormCRLB_K9);
ape_CRLB_K9 = mean(errorNormCRLB_K9);

fprintf('CRLB K=9 (límite teórico):\n');
fprintf('  RMSE: %.4f m (%.2f cm)\n', rmse_CRLB_K9, rmse_CRLB_K9*100);
fprintf('  CDF 90%%: %.2f cm\n', cdf90_CRLB_K9);
fprintf('  APE: %.4f m (%.2f cm)\n\n', ape_CRLB_K9, ape_CRLB_K9*100);

% --- Resumen comparativo ---
fprintf('======================================================================\n');
fprintf('RESUMEN COMPARATIVO\n');
fprintf('======================================================================\n');
fprintf('Método\t\tRMSE (cm)\tCDF 90%% (cm)\tAPE (cm)\n');
fprintf('----------------------------------------------------------------------\n');
fprintf('SVD K=3\t\t%.2f\t\t%.2f\t\t%.2f\n', rmse_SVD_K3*100, cdf90_SVD_K3, ape_SVD_K3*100);
fprintf('GLS K=5\t\t%.2f\t\t%.2f\t\t%.2f\n', rmse_GLS_K5*100, cdf90_GLS_K5, ape_GLS_K5*100);
fprintf('WLS K=5\t\t%.2f\t\t%.2f\t\t%.2f\n', rmse_WLS_K5*100, cdf90_WLS_K5, ape_WLS_K5*100);
fprintf('NL K=5\t\t%.2f\t\t%.2f\t\t%.2f\n', rmse_NL_K5*100, cdf90_NL_K5, ape_NL_K5*100);
fprintf('CRLB K=5\t%.2f\t\t%.2f\t\t%.2f\n', rmse_CRLB_K5*100, cdf90_CRLB_K5, ape_CRLB_K5*100);
fprintf('GLS K=9\t\t%.2f\t\t%.2f\t\t%.2f\n', rmse_GLS_K9*100, cdf90_GLS_K9, ape_GLS_K9*100);
fprintf('WLS K=9\t\t%.2f\t\t%.2f\t\t%.2f\n', rmse_WLS_K9*100, cdf90_WLS_K9, ape_WLS_K9*100);
fprintf('NL K=9\t\t%.2f\t\t%.2f\t\t%.2f\n', rmse_NL_K9*100, cdf90_NL_K9, ape_NL_K9*100);
fprintf('CRLB K=9\t%.2f\t\t%.2f\t\t%.2f\n', rmse_CRLB_K9*100, cdf90_CRLB_K9, ape_CRLB_K9*100);
fprintf('======================================================================\n\n');








