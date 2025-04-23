close all, clear , clc
% Figure 1: RMS error ε₉₀% vs Number of Orientations

colorsMATLAB = [0.0000 0.4470 0.7410 ;... 
                0.8500 0.3250 0.0980 ;...
                0.9290 0.6940 0.1250 ;...
                0.4940 0.1840 0.5560 ;...
                0.4660 0.6740 0.1880 ;...
                0.3010 0.7450 0.9330 ;...
                0.6350 0.0780 0.1840];

% Data (RMS in meters)
n            = [   3,     4,      5,      6,      7,      8,     10];
LS_lowNoise  = [0.11, 0.11,  0.111, 0.113, 0.111, 0.114, 0.113];
WLS_lowNoise = [0.11, 0.048646, 0.02749, 0.023329, 0.02998, 0.02727, 0.02818];
WLS_highNoise= [0.4794, 0.2289, 0.1290, 0.1305, 0.1338, 0.1312, 0.1156];

% Convert RMS from meters to centimeters
LS_lowNoise_cm   = LS_lowNoise  * 100;
WLS_lowNoise_cm  = WLS_lowNoise * 100;
WLS_highNoise_cm = WLS_highNoise* 100;

% Plot
figure;
plot(n, LS_lowNoise_cm,   '--*', 'Color', colorsMATLAB(1,:) ); hold on;
plot(n, WLS_lowNoise_cm,  '--*', 'Color', colorsMATLAB(5,:));
plot(n, WLS_highNoise_cm, '--*', 'Color', colorsMATLAB(2,:));
hold off;

% Labels and legend
xlabel('Number of Orientations (n)','interpreter', 'latex');
ylabel('RMS error  $\varepsilon_{90\%}$ (cm)','interpreter', 'latex');
title('RMS error  $\varepsilon_{90\%}$ vs Number of Orientations','interpreter', 'latex');
legend({'LS (low noise)', 'WLS (low noise)', 'WLS (high noise)'}, ...
       'Location', 'northeast');
grid on;
%set(gca, 'FontSize', 11);
% , 'FontSize', 10


% Adjust axes limits if desired
xlim([min(n)-0.5, max(n)+0.5]);
ylim([0, max(WLS_highNoise_cm)*1.1]);


% aqui mencionar el tiempo por tiempo total de la simulacion

