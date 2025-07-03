%% 7. Visualization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all, close all, clc

errorNormSVD_K3 = load('SVD_K3.mat').errorNormSVD;
errorNormWLS_K5 = load('K5_WLS.mat').filtered_errorNormWLS_Robust;
errorNormGLS_K5 = load('K5_GLS.mat').filtered_errorNormGLS;
errorNormWLS_K9 = load('K9_WLS.mat').filtered_errorNormWLS_Robust;
errorNormGLS_K9 = load('K9_GLS.mat').filtered_errorNormGLS;
errorNormNL_K5 = load('K5_NL.mat').errorNorm;

% CDF plot
figure(1)
hold on;
ecdf(errorNormSVD_K3(:)*100,'Function','cdf');
ecdf(errorNormGLS_K5(:)*100,'Function','cdf');
ecdf(errorNormWLS_K5(:)*100,'Function','cdf');
ecdf(errorNormNL_K5(:)*100,'Function','cdf');

[f2, x2] = ecdf(errorNormGLS_K9(:)*100,'Function','cdf');
h2 = stairs(x2, f2, '--', 'LineWidth', 1);

[f1, x1] = ecdf(errorNormWLS_K9(:)*100,'Function','cdf');
h1 = stairs(x1, f1, '--', 'LineWidth', 1);
%ecdf(errorNormCRLB(:)*100,'Function','cdf');

grid on;
axis([0 16 0 1])
xlabel('Error de posicionamiento [cm]','interpreter','latex');
ylabel('CDF','Interpreter','latex');
legend('K=3','K=5 (GLS)', 'K=5 (WLS)','K=5 (NL)', 'K=9 (GLS)','K=9 (WLS)','Location', 'southeast','interpreter','latex');

% Tiempo
avg_time_K5_WLS = mean((load('K5_WLS.mat').time_WLS)*1000);
avg_time_K5_GLS = mean((load('K5_GLS.mat').time_GLS)*1000);
avg_time_K9_WLS = mean((load('K9_WLS.mat').time_WLS)*1000);
avg_time_K9_GLS = mean((load('K9_GLS.mat').time_GLS)*1000);
avg_time_K5_NL = mean((load('K5_NL.mat').time_NL)*1000);

% Gráfico de barras para comparativa de tiempos
figure(2)
tiempos = [avg_time_K5_WLS, avg_time_K5_GLS, avg_time_K9_WLS, avg_time_K9_GLS, avg_time_K5_NL];

% Crear gráfico de barras con colores personalizados
barras = bar(tiempos, 'FaceColor', 'flat');

% Definir colores para cada barra (formato RGB)
barras.CData(1,:) = [0.8500, 0.3250, 0.0980]; % K5 WLS (naranja)
barras.CData(2,:) = [0, 0.4470, 0.7410];      % K5 GLS (azul)
barras.CData(3,:) = [0.9290, 0.6940, 0.1250]; % K9 WLS (amarillo)
barras.CData(4,:) = [0.4940, 0.1840, 0.5560]; % K9 GLS (púrpura)
barras.CData(5,:) = [0.4660, 0.6740, 0.1880]; % K5 NL (verde)

% Añadir etiquetas y título
set(gca, 'XTickLabel', {'K=5 WLS', 'K=5 GLS', 'K=9 WLS', 'K=9 GLS', 'K=5 NL'}, 'TickLabelInterpreter','latex');
ylabel('Average Time per Estimation (ms)', 'interpreter', 'latex');

% Añadir valores encima de cada barra
txt = arrayfun(@(x) sprintf('%.2f ms', x), tiempos, 'UniformOutput', false);
y = tiempos;
x = 1:length(tiempos);
text(x, y, txt, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom','interpreter','latex');

% Mejorar estética
set(gcf, 'Color', 'white');
set(gca, 'FontName', 'Times New Roman');
box on;

grid on;
ax = gca;
ax.XGrid = 'on';
ax.YGrid = 'on';
ax.GridLineStyle = ':';      % Estilo punteado
ax.GridAlpha = 0.2;          % Transparencia de la rejilla
% ax.GridColor = [0.2 0.2 0.2]; % Color gris oscuro (personalizable)


% Ajustar límites del eje Y para dejar espacio para las etiquetas
axes_limits = get(gca, 'YLim');
set(gca, 'YLim', [0, axes_limits(2)*1.1]);

