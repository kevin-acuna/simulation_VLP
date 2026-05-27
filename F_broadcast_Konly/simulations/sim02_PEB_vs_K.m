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
SAVE_FIGS = true;  % Save in IEEE format (png, pdf, eps)
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
% Create at IEEE single-column size directly to avoid marker/line distortion
fig = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w');

plot(K_values, RMS_PEB_B*100, '-o', 'LineWidth', 1.0, 'MarkerSize', 4, ...
    'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74]);
hold on;
plot(K_values, RMS_PEB_C*100, '--s', 'LineWidth', 1.0, 'MarkerSize', 4, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10]);
ylabel('RMS-PEB [cm]', 'Interpreter', 'latex', 'FontSize', 8);
ylim([0, max(RMS_PEB_B*100)*1.1]);

xlabel('Number of orientations $K$', 'Interpreter', 'latex', 'FontSize', 8);
legend({'$\mathrm{PEB}_\mathrm{B}$ (broadcast)', ...
        '$\mathrm{PEB}_\mathrm{C}$ (cooperative)'}, ...
    'Location', 'northeast', 'Interpreter', 'latex', 'FontSize', 6);
grid on;
set(gca, 'XTick', K_values, 'FontSize', 7, 'LineWidth', 0.5);

%% Save
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
if SAVE_FIGS
    exportgraphics(fig, fullfile(results_dir, 'Fig02_PEB_vs_K.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig, fullfile(results_dir, 'Fig02_PEB_vs_K.png'), 'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig, fullfile(results_dir, 'Fig02_PEB_vs_K.eps'), 'ContentType','vector','BackgroundColor','white');
    fprintf('Figures saved (pdf/png/eps)\n');
end

%% Print summary table
fprintf('\n=== Summary Table ===\n');
fprintf('%-4s | %-15s | %-15s | %-10s\n', 'K', 'PEB_B [cm]', 'PEB_C [cm]', 'rho');
fprintf('---- | --------------- | --------------- | ----------\n');
for ik = 1:length(K_values)
    fprintf('%-4d | %11.2f     | %11.2f     | %7.2fx\n', ...
        K_values(ik), RMS_PEB_B(ik)*100, RMS_PEB_C(ik)*100, Mean_rho(ik));
end

fprintf('\nDone. Figures saved to: %s\n', results_dir);
