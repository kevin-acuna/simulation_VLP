clear all;
close all;
clc;

load workspace_Fig2_LOS.mat

colorsMATLAB = [0.0000 0.4470 0.7410 ;... 
                0.8500 0.3250 0.0980 ;...
                0.9290 0.6940 0.1250 ;...
                0.4940 0.1840 0.5560 ;...
                0.4660 0.6740 0.1880 ;...
                0.3010 0.7450 0.9330 ;...
                0.6350 0.0780 0.1840];


rmsError_65dB = sqrt((x_real'-x_est_cell{6,38}).^2+(y_real'-y_est_cell{6,38}).^2); % RMS positioning error over the whole room        
[f_RMS_65dB,x_RMS_65dB] = ecdf(rmsError_65dB(:));
cdf90_RMS_65dB = x_RMS_65dB(max(find(f_RMS_65dB<0.9)));

rmsError_25dB = sqrt((x_real'-x_est_cell{6,78}).^2+(y_real'-y_est_cell{6,78}).^2); % RMS positioning error over the whole room        
[f_RMS_25dB,x_RMS_25dB] = ecdf(rmsError_25dB(:));
cdf90_RMS_25dB = x_RMS_25dB(max(find(f_RMS_25dB<0.9)));

rmsError_25dB_Q1 = rmsError_25dB(21:31,21:31); % RMS positioning error over the top right corner of the room
[f_RMS_25dB_Q1,x_RMS_25dB_Q1] = ecdf(rmsError_25dB_Q1(:));
cdf90_RMS_25dB_Q1 = x_RMS_25dB_Q1(max(find(f_RMS_25dB_Q1<0.9)));

SNR_25dB_Q1 = SNR{6,78}(21:31,21:31,:); % SNR over the top right corner of the room
[f_SNR_25dB_Q1,x_SNR_25dB_Q1] = ecdf(SNR_25dB_Q1(:));
cdf90_SNR_25dB_Q1 = x_SNR_25dB_Q1(min(find(f_SNR_25dB_Q1>0.9)));

rmsError_25dB_Q2 = rmsError_25dB(31:41,31:41); % RMS positioning error over the top right corner of the room
[f_RMS_25dB_Q2,x_RMS_25dB_Q2] = ecdf(rmsError_25dB_Q2(:));
cdf90_RMS_25dB_Q2 = x_RMS_25dB_Q2(max(find(f_RMS_25dB_Q2<0.9)));

SNR_25dB_Q2 = SNR{6,78}(31:41,31:41,:); % SNR over the top right corner of the room
[f_SNR_25dB_Q2,x_SNR_25dB_Q2] = ecdf(SNR_25dB_Q2(:));
cdf90_SNR_25dB_Q2 = x_SNR_25dB_Q2(min(find(f_SNR_25dB_Q2>0.9)));

figure;
s1 = scatter(x_real(1:2:41,1:2:41)', y_real(1:2:41,1:2:41)', 'o', 'MarkerEdgeColor', "k"); hold on;
s2 = scatter(x_est_cell{6,38}(1:2:41,1:2:41), y_est_cell{6,38}(1:2:41,1:2:41), '.', 'MarkerEdgeColor', colorsMATLAB(1,:)); hold on;
s3 = scatter(x_est_cell{6,68}(1:2:41,1:2:41), y_est_cell{6,78}(1:2:41,1:2:41), 'x', 'MarkerEdgeColor', colorsMATLAB(2,:)); hold on;


load workspace_Fig2_LOS_NLOS.mat

s4 = scatter(x_est(1:2:41,1:2:41), y_est(1:2:41,1:2:41), '*', 'MarkerEdgeColor', colorsMATLAB(3,:)); hold on;
% legend([s1(1),s2(1),s3(1),s4(1)], ...
%     "Real positions", ...
%     "Positions estimated (LOS only, SNR_{90} = 65 dB)", ...
%     "Positions estimated (LOS only, SNR_{90} = 35 dB)", ...
%     "Positions estimated (LOS+NLOS with \rho = 0.6, SNR_{90} = 65 dB)",...
%     'Location','north');
xlim([-2.1,2.1]); ylim([-2.1,2.1]); grid on;
xlabel('x (m)'); ylabel('y (m)');
legend([s1(1),s2(1),s3(1),s4(1)], ...
    "Real positions", ...
    "Configuration 1", ...
    "Configuration 2", ...
    "Configuration 3",...
    'Location','southwest');


rmsError_NLOS = sqrt((x_real'-x_est).^2+(y_real'-y_est).^2); % RMS positioning error over the whole room        
[f_RMS_NLOS,x_RMS_NLOS] = ecdf(rmsError_NLOS(:));
cdf90_RMS_NLOS = x_RMS_NLOS(max(find(f_RMS_NLOS<0.9)));

rmsError_NLOS_Q1 = rmsError_NLOS(21:31,21:31); % RMS positioning error over the top right corner of the room
[f_RMS_NLOS_Q1,x_RMS_NLOS_Q1] = ecdf(rmsError_NLOS_Q1(:));
cdf90_RMS_NLOS_Q1 = x_RMS_NLOS_Q1(max(find(f_RMS_NLOS_Q1<0.9)));

H_ratio_Q1 = H_NLOS(21:31,21:31,:)./(H_LOS(21:31,21:31,:)+H_NLOS(21:31,21:31,:));
H_ratio_Q1_max = max(H_ratio_Q1(:));

rmsError_NLOS_Q2 = rmsError_NLOS(31:41,31:41); % RMS positioning error over the top right corner of the room
[f_RMS_NLOS_Q2,x_RMS_NLOS_Q2] = ecdf(rmsError_NLOS_Q2(:));
cdf90_RMS_NLOS_Q2 = x_RMS_NLOS_Q2(max(find(f_RMS_NLOS_Q2<0.9)));

H_ratio_Q2 = H_NLOS(31:41,31:41,:)./(H_LOS(31:41,31:41,:)+H_NLOS(31:41,31:41,:));
H_ratio_Q2_max = max(H_ratio_Q2(:));

