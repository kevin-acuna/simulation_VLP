%% sim02_PEB_vs_K.m
% RMS broadcast PEB (PEB_B) and cooperative PEB (PEB_C) vs K
%
% Uses DEB-optimized orientations from TCOM Table III for each K.
% Evaluates over the full 3D testbed.
%
% Author: Kevin Acuna-Condori
% Date: 26 May 2026
% Project: Proposal F — Broadcast OWP

clear; clc; close all;

%% Add paths
project_root = fileparts(pwd);
addpath(fullfile(project_root, 'core'));
addpath(fullfile(fileparts(project_root), 'fundamentals', 'core'));
addpath(project_root);

%% System Parameters
system_params_F;
%K_values = K_values_Phi30
%all_orientations_DEB = all_orientations_DEB_Phi30

%% 3D Testbed grid
x_range = -L/2:step:L/2;
y_range = -W/2:step:W/2;
z_range = 0:stepH:Hmax;

% Generate all positions
[X, Y, Z] = meshgrid(x_range, y_range, z_range);
positions = [X(:), Y(:), Z(:)]';
N_pos = size(positions, 2);
fprintf('Testbed: %d positions\n', N_pos);

%% Compute RMS-PEB for each K
RMS_PEB_B = zeros(1, length(K_values));
RMS_PEB_C = zeros(1, length(K_values));
Mean_rho  = zeros(1, length(K_values));


for ik = 1:length(K_values)
    K = K_values(ik);
    nt = orient_to_vectors(all_orientations_DEB{ik});  % 3 x K
    
    % Evaluate at all positions
    peb_b = zeros(1, N_pos);
    peb_c = zeros(1, N_pos);
    
    for ip = 1:N_pos
        R = positions(:, ip);
        
        peb_b(ip) = PEB_Konly(R, nt, T', P_t, m_t, A_det, ...
            deg2rad(FOV), sigma2, N_samples, n_r');
        
        peb_c(ip) = PEB_complete(R, nt, T', P_t, m_t, A_det, ...
            deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples);
    end
    
    % RMS over valid positions
    valid_k = isfinite(peb_b) & isfinite(peb_c);
    RMS_PEB_B(ik) = sqrt(mean(peb_b(valid_k).^2));
    RMS_PEB_C(ik) = sqrt(mean(peb_c(valid_k).^2));
    Mean_rho(ik)  = mean(peb_b(valid_k) ./ peb_c(valid_k));
    
    fprintf('K=%d: RMS-PEB_B = %.2f cm, RMS-PEB_C = %.2f cm, rho = %.2fx\n', ...
        K, 100*RMS_PEB_B(ik), 100*RMS_PEB_C(ik), Mean_rho(ik));
end

%% Figure: RMS-PEB vs K
figure('Position', [100, 100, 700, 500]);

yyaxis left
plot(K_values, RMS_PEB_B*100, 'b-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
hold on;
plot(K_values, RMS_PEB_C*100, 'r--s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
ylabel('RMS-PEB [cm]');
ylim([0, max(RMS_PEB_B*100)*1.1]);

yyaxis right
plot(K_values, Mean_rho, 'k:d', 'LineWidth', 1.5, 'MarkerSize', 7, 'MarkerFaceColor', [0.5 0.5 0.5]);
ylabel('Broadcast penalty $\rho$', 'Interpreter', 'latex');

xlabel('Number of orientations $K$', 'Interpreter', 'latex');
title('RMS-PEB vs $K$: Broadcast vs Cooperative', 'Interpreter', 'latex');
legend({'$\mathrm{PEB}_\mathrm{B}$ (broadcast)', ...
        '$\mathrm{PEB}_\mathrm{C}$ (cooperative)', ...
        '$\bar{\rho}$ (mean penalty)'}, ...
    'Location', 'northeast', 'Interpreter', 'latex');
grid on;
set(gca, 'XTick', K_values);

%% Save
results_dir = fullfile(project_root, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
saveas(gcf, fullfile(results_dir, 'Fig02_PEB_vs_K.png'));
saveas(gcf, fullfile(results_dir, 'Fig02_PEB_vs_K.fig'));

%% Print summary table
fprintf('\n=== Summary Table ===\n');
fprintf('%-4s | %-15s | %-15s | %-10s\n', 'K', 'PEB_B [cm]', 'PEB_C [cm]', 'rho');
fprintf('---- | --------------- | --------------- | ----------\n');
for ik = 1:length(K_values)
    fprintf('%-4d | %11.2f     | %11.2f     | %7.2fx\n', ...
        K_values(ik), RMS_PEB_B(ik)*100, RMS_PEB_C(ik)*100, Mean_rho(ik));
end

fprintf('\nDone. Figures saved to: %s\n', results_dir);
