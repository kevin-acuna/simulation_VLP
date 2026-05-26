%% sim01_PEB_broadcast_heatmap.m
% Compare broadcast PEB (PEB_B) vs cooperative PEB (PEB_C)
% Heatmaps at z = 0.8 m for K=5 DEB-optimized orientations
%
% Output figures:
%   Fig 1a: PEB_B (broadcast) heatmap
%   Fig 1b: PEB_C (cooperative) heatmap
%   Fig 1c: Broadcast penalty rho(r) = PEB_B / PEB_C
%
% Author: Kevin Acuna-Condori
% Date: 26 May 2026
% Project: Proposal F - Broadcast K-only OWP

clear; clc; close all;

%% Add paths
project_root = fileparts(pwd);  % F_broadcast_Konly/
addpath(fullfile(project_root, 'core'));
addpath(fullfile(fileparts(project_root), 'fundamentals', 'core'));
addpath(project_root);  % for system_params_F

%% System Parameters
system_params_F;

%% Orientations
K_sel = 5;
K_idx = find(K_values == K_sel);
nt_orientations = orient_to_vectors(all_orientations_DEB{K_idx});  % 3 x K
K = K_sel;

%% Spatial grid
step = 0.1;  % Grid resolution (m)
z_analysis = 0.8;  % Analysis height (m)

x_range = -1.5:step:1.5;
y_range = -1.5:step:1.5;
Nx = length(x_range);
Ny = length(y_range);

%% Compute PEB at each position
PEB_B_grid = zeros(Ny, Nx);  % Broadcast PEB
PEB_C_grid = zeros(Ny, Nx);  % Cooperative PEB

fprintf('Computing PEB grids (%d x %d = %d points)...\n', Nx, Ny, Nx*Ny);
tic;

for ix = 1:Nx
    for iy = 1:Ny
        R = [x_range(ix); y_range(iy); z_analysis];
        
        % Broadcast PEB (PEB_B): K measurements only, n_r known
        PEB_B_grid(iy, ix) = PEB_Konly(R, nt_orientations, T', ...
            P_t, m_t, A_det, deg2rad(FOV), sigma2, N_samples, n_r');
        
        % Cooperative PEB (PEB_C): K+1 measurements (TCOM)
        PEB_C_grid(iy, ix) = PEB_complete(R, nt_orientations, T', ...
            P_t, m_t, A_det, deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples);
    end
end

elapsed = toc;
fprintf('Done in %.1f seconds.\n', elapsed);

%% Broadcast penalty rho(r) = PEB_B / PEB_C
rho_grid = PEB_B_grid ./ PEB_C_grid;

%% Statistics
valid_B = PEB_B_grid(isfinite(PEB_B_grid));
valid_C = PEB_C_grid(isfinite(PEB_C_grid));
valid_rho = rho_grid(isfinite(rho_grid));

fprintf('\n=== PEB Statistics (z = %.1f m, K = %d) ===\n', z_analysis, K);
fprintf('PEB_B (broadcast):    RMS = %.2f cm, Mean = %.2f cm, Max = %.2f cm\n', ...
    100*sqrt(mean(valid_B.^2)), 100*mean(valid_B), 100*max(valid_B));
fprintf('PEB_C (cooperative):  RMS = %.2f cm, Mean = %.2f cm, Max = %.2f cm\n', ...
    100*sqrt(mean(valid_C.^2)), 100*mean(valid_C), 100*max(valid_C));
fprintf('Penalty rho:          Mean = %.2fx, Median = %.2fx, Max = %.2fx\n', ...
    mean(valid_rho), median(valid_rho), max(valid_rho));

%% Figure 1: Side-by-side heatmaps
figure('Position', [100, 100, 1400, 400]);

% Determine common color scale
cmax_peb = max(max(valid_B), max(valid_C)) * 100; % in cm
cmax_peb = min(cmax_peb, 10); % Cap at 10 cm for visualization

% Fig 1a: Broadcast PEB
subplot(1, 3, 1);
imagesc(x_range, y_range, PEB_B_grid * 100);
set(gca, 'YDir', 'normal');
xlabel('x [m]'); ylabel('y [m]');
title(sprintf('PEB_B (broadcast, K=%d)', K));
colorbar; caxis([0 cmax_peb]);
colormap(gca, 'jet');
axis equal tight;
hold on;
plot(0, 0, 'w^', 'MarkerSize', 10, 'MarkerFaceColor', 'w');
text(0.05, 0.1, 'LED', 'Color', 'w', 'FontWeight', 'bold');

% Fig 1b: Cooperative PEB
subplot(1, 3, 2);
imagesc(x_range, y_range, PEB_C_grid * 100);
set(gca, 'YDir', 'normal');
xlabel('x [m]'); ylabel('y [m]');
title(sprintf('PEB_C (cooperative, K=%d + K+1)', K));
colorbar; caxis([0 cmax_peb]);
colormap(gca, 'jet');
axis equal tight;
hold on;
plot(0, 0, 'w^', 'MarkerSize', 10, 'MarkerFaceColor', 'w');

% Fig 1c: Broadcast penalty
subplot(1, 3, 3);
imagesc(x_range, y_range, rho_grid);
set(gca, 'YDir', 'normal');
xlabel('x [m]'); ylabel('y [m]');
title('Broadcast penalty \rho = PEB_B / PEB_C');
cb = colorbar;
ylabel(cb, '\rho');
colormap(gca, 'hot');
axis equal tight;
hold on;
plot(0, 0, 'w^', 'MarkerSize', 10, 'MarkerFaceColor', 'w');

sgtitle(sprintf('Broadcast vs Cooperative PEB — z = %.1f m, K = %d, n_r = [0,0,1]^T', ...
    z_analysis, K), 'FontSize', 12);

%% Save
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
saveas(gcf, fullfile(results_dir, 'Fig01_PEB_broadcast_vs_cooperative.png'));
saveas(gcf, fullfile(results_dir, 'Fig01_PEB_broadcast_vs_cooperative.fig'));

%% Figure 2: Histogram of the broadcast penalty
figure('Position', [100, 600, 600, 400]);
histogram(valid_rho, 30, 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'none');
xlabel('Broadcast penalty \rho = PEB_B / PEB_C');
ylabel('Number of positions');
title(sprintf('Distribution of broadcast penalty (K=%d, z=%.1f m)', K, z_analysis));
xline(median(valid_rho), 'r--', sprintf('Median = %.2f\\times', median(valid_rho)), ...
    'LineWidth', 2, 'LabelOrientation', 'horizontal');
grid on;

saveas(gcf, fullfile(results_dir, 'Fig01b_broadcast_penalty_histogram.png'));

fprintf('\nFigures saved to: %s\n', results_dir);
