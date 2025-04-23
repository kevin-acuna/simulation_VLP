close all, clear, clc

colorsMATLAB = [0.0000 0.4470 0.7410 ;... 
                0.8500 0.3250 0.0980 ;...
                0.9290 0.6940 0.1250 ;...
                0.4940 0.1840 0.5560 ;...
                0.4660 0.6740 0.1880 ;...
                0.3010 0.7450 0.9330 ;...
                0.6350 0.0780 0.1840];

scenario01 = load('scenario01.mat'); % scenario1 : n=3 (without optimization)
scenario02 = load('scenario02.mat'); % scenario2 : n=3 (with optimization)
scenario03 = load('scenario03.mat'); % scenario3 : n=5 (best number of orientation + optimization)

figure(1)
hold on
scatter(scenario01.pos.x_real(:), scenario01.pos.y_real(:), 'o', 'MarkerEdgeColor', 'k','DisplayName','Ground True'); 

scatter(scenario03.pos.x_est(:) , scenario03.pos.y_est(:), 'p', 'MarkerEdgeColor', colorsMATLAB(1,:), 'DisplayName','n=5 (GA)' ); 
scatter(scenario02.pos.x_est(:) , scenario02.pos.y_est(:), 'x', 'MarkerEdgeColor', colorsMATLAB(2,:), 'DisplayName','n=3 (GA)' ); 

scatter(scenario01.pos.x_est(:) , scenario01.pos.y_est(:), '*', 'MarkerEdgeColor', colorsMATLAB(3,:), 'DisplayName','n=3 (non-GA)' ); 

legend('Location','best')
axis([-1.3 1.3 -1.3 1.3]);
xlabel('X (m)'); ylabel('Y (m)');
grid minor
title('Estimation');


% Grafica: estimacion de posicion
% n=3 (sin GA, n al centro, n2 y n3 en X y Y , como la configuracion inicial del experimental setup)
% n=3 (obtenido por GA)
% n = n_optimo (n=5, con valores optimos)

% Gráfica: Subplot: 1ra fila orientaciones optimas con ruido bajo, 2da fila orientaciones optimas con ruido alto
% Objetivo : comparar las orientaciones óptimas

