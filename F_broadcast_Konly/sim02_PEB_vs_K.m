%% sim02_PEB_vs_K.m
% RMS-PEB_Konly and RMS-PEB_TCOM vs number of orientations K
%
% Uses DEB-optimized orientations from TCOM Table III for each K.
% Evaluates over the full 3D testbed (1792 positions).
%
% Author: Kevin Acuna-Condori
% Date: 26 May 2026
% Project: Proposal F - Broadcast K-only OWP

clear; clc; close all;

%% Add paths
addpath(fullfile(pwd, 'core'));
addpath(fullfile(fileparts(pwd), 'fundamentals', 'core'));

%% System Parameters (Table II of TCOM RV2)
params.T = [0; 0; 2];
params.Pt = 0.405;
params.Phi_half = 45;
params.m = -log(2)/log(cosd(params.Phi_half));
params.A_det = 4.8e-3 * 5.5e-3;
params.Psi_FOV = deg2rad(85);
params.sigma2 = 3e-14;
params.N = 1000;
params.nr = [0; 0; 1];

%% DEB-optimized orientations from TCOM RV2 Table III
% theta, phi pairs in degrees
orientations_all = struct();
orientations_all.K3 = [17.5, 203.7; 17.2, 332.2; 18.7, 88.8];
orientations_all.K4 = [29.9, 315.0; 29.9, 135.0; 29.9, 45.0; 29.9, 225.0];
orientations_all.K5 = [0.1, 74.2; 65.7, 269.8; 65.7, 179.9; 65.9, 359.8; 65.9, 89.9];
orientations_all.K6 = [67.6, 253.4; 66.6, 321.1; 70.0, 176.9; 0.1, 274.3; 68.9, 98.4; 66.8, 24.9];
orientations_all.K7 = [65.6, 353.3; 2.5, 10.1; 66.2, 273.6; 64.6, 196.5; 62.5, 130.8; 2.6, 191.7; 63.8, 68.1];
orientations_all.K8 = [67.6, 67.1; 66.6, 247.3; 2.8, 39.7; 3.2, 227.0; 64.7, 2.8; 66.1, 179.7; 66.9, 298.2; 65.4, 114.9];
orientations_all.K9 = [66.1, 165.4; 8.7, 267.1; 66.8, 273.8; 62.4, 219.4; 64.2, 21.6; 67.2, 91.0; 13.9, 105.1; 4.5, 303.1; 62.0, 330.3];

K_values = 3:9;

%% 3D Testbed grid
step = 0.2;  % Same as TCOM (for speed)
x_range = -1.5:step:1.5;
y_range = -1.5:step:1.5;
z_range = 0:step:1.2;

% Generate all positions
[X, Y, Z] = meshgrid(x_range, y_range, z_range);
positions = [X(:), Y(:), Z(:)]';
N_pos = size(positions, 2);
fprintf('Testbed: %d positions\n', N_pos);

%% Compute RMS-PEB for each K
RMS_PEB_Konly = zeros(1, length(K_values));
RMS_PEB_TCOM = zeros(1, length(K_values));
Mean_ratio = zeros(1, length(K_values));

for ik = 1:length(K_values)
    K = K_values(ik);
    field_name = sprintf('K%d', K);
    orient_deg = orientations_all.(field_name);
    
    % Convert to unit vectors
    nt = zeros(3, K);
    for i = 1:K
        theta_i = deg2rad(orient_deg(i, 1));
        phi_i = deg2rad(orient_deg(i, 2));
        nt(:, i) = [sin(theta_i)*cos(phi_i); sin(theta_i)*sin(phi_i); -cos(theta_i)];
    end
    
    % Evaluate at all positions
    peb_konly = zeros(1, N_pos);
    peb_tcom = zeros(1, N_pos);
    
    for ip = 1:N_pos
        R = positions(:, ip);
        
        peb_konly(ip) = PEB_Konly(R, nt, params.T, params.Pt, params.m, ...
            params.A_det, params.Psi_FOV, params.sigma2, params.N, params.nr);
        
        peb_tcom(ip) = PEB_complete(R, nt, params.T, params.Pt, params.m, ...
            params.A_det, deg2rad(params.Phi_half), params.Psi_FOV, ...
            params.sigma2, params.N);
    end
    
    % RMS over valid positions
    valid_k = isfinite(peb_konly) & isfinite(peb_tcom);
    RMS_PEB_Konly(ik) = sqrt(mean(peb_konly(valid_k).^2));
    RMS_PEB_TCOM(ik) = sqrt(mean(peb_tcom(valid_k).^2));
    Mean_ratio(ik) = mean(peb_konly(valid_k) ./ peb_tcom(valid_k));
    
    fprintf('K=%d: RMS-PEB_Konly = %.2f cm, RMS-PEB_TCOM = %.2f cm, Mean ratio = %.2fx\n', ...
        K, 100*RMS_PEB_Konly(ik), 100*RMS_PEB_TCOM(ik), Mean_ratio(ik));
end

%% Figure: RMS-PEB vs K
figure('Position', [100, 100, 700, 500]);

yyaxis left
plot(K_values, RMS_PEB_Konly*100, 'b-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
hold on;
plot(K_values, RMS_PEB_TCOM*100, 'r--s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
ylabel('RMS-PEB [cm]');
ylim([0, max(RMS_PEB_Konly*100)*1.1]);

yyaxis right
plot(K_values, Mean_ratio, 'k:d', 'LineWidth', 1.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.5 0.5 0.5]);
ylabel('Mean Ratio PEB_{K-only} / PEB_{TCOM}');

xlabel('Number of orientations K');
title('RMS-PEB vs K: Broadcast (K-only) vs Cooperative (TCOM)');
legend({'PEB_{K-only} (broadcast)', 'PEB_{TCOM} (cooperative)', 'Ratio'}, ...
    'Location', 'northeast');
grid on;
set(gca, 'XTick', K_values);

%% Save
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
saveas(gcf, fullfile(results_dir, 'Fig02_PEB_vs_K.png'));
saveas(gcf, fullfile(results_dir, 'Fig02_PEB_vs_K.fig'));

%% Print summary table
fprintf('\n=== Summary Table ===\n');
fprintf('%-4s | %-15s | %-15s | %-10s\n', 'K', 'PEB_Konly [cm]', 'PEB_TCOM [cm]', 'Ratio');
fprintf('---- | --------------- | --------------- | ----------\n');
for ik = 1:length(K_values)
    fprintf('%-4d | %11.2f     | %11.2f     | %7.2fx\n', ...
        K_values(ik), RMS_PEB_Konly(ik)*100, RMS_PEB_TCOM(ik)*100, Mean_ratio(ik));
end

fprintf('\nDone. Figures saved to: %s\n', results_dir);
