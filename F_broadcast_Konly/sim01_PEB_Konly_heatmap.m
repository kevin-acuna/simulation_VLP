%% sim01_PEB_Konly_heatmap.m
% Compare PEB_Konly (broadcast, no K+1) vs PEB_TCOM (cooperative K+1)
% Heatmaps at z = 0.8 m for K=5 DEB-optimized orientations
%
% Output figures:
%   Fig 1a: PEB_Konly heatmap
%   Fig 1b: PEB_TCOM heatmap (reference)
%   Fig 1c: Ratio PEB_Konly / PEB_TCOM
%
% Author: Kevin Acuna-Condori
% Date: 26 May 2026
% Project: Proposal F - Broadcast K-only OWP

clear; clc; close all;

%% Add paths
addpath(fullfile(pwd, 'core'));
addpath(fullfile(fileparts(pwd), 'fundamentals', 'core'));

%% System Parameters (Table II of TCOM RV2)
params.T = [0; 0; 2];                     % Transmitter position (ceiling)
params.Pt = 0.405;                         % Transmitted optical power (W)
params.Phi_half = 45;                      % Half-power semi-angle (degrees)
params.m = -log(2)/log(cosd(params.Phi_half)); % Lambertian order
params.A_det = 4.8e-3 * 5.5e-3;           % PD effective area (m^2)
params.Psi_FOV = deg2rad(85);              % Receiver FOV (radians)
params.sigma2 = 3e-14;                     % Noise variance (W^2)
params.N = 1000;                           % Samples per orientation
params.nr = [0; 0; 1];                     % Receiver orientation (vertical)

%% DEB-optimized orientations for K=5 (Table III of TCOM RV2)
% Format: [theta, phi] in degrees for each orientation
orientations_K5_deg = [
    0.1, 74.2;    % i=1 (nearly vertical)
    65.7, 269.8;  % i=2
    65.7, 179.9;  % i=3
    65.9, 359.8;  % i=4
    65.9, 89.9    % i=5
];

K = size(orientations_K5_deg, 1);

% Convert to unit vectors (nadir-referenced)
nt_orientations = zeros(3, K);
for i = 1:K
    theta_i = deg2rad(orientations_K5_deg(i, 1));
    phi_i = deg2rad(orientations_K5_deg(i, 2));
    nt_orientations(:, i) = [sin(theta_i)*cos(phi_i); 
                              sin(theta_i)*sin(phi_i); 
                              -cos(theta_i)];
end

%% Spatial grid
step = 0.1;  % Grid resolution (m)
z_analysis = 0.8;  % Analysis height (m)

x_range = -1.5:step:1.5;
y_range = -1.5:step:1.5;
Nx = length(x_range);
Ny = length(y_range);

%% Compute PEB at each position
PEB_Konly_grid = zeros(Ny, Nx);
PEB_TCOM_grid = zeros(Ny, Nx);

fprintf('Computing PEB grids (%d x %d = %d points)...\n', Nx, Ny, Nx*Ny);
tic;

for ix = 1:Nx
    for iy = 1:Ny
        R = [x_range(ix); y_range(iy); z_analysis];
        
        % K-only PEB (Proposal F)
        PEB_Konly_grid(iy, ix) = PEB_Konly(R, nt_orientations, params.T, ...
            params.Pt, params.m, params.A_det, params.Psi_FOV, ...
            params.sigma2, params.N, params.nr);
        
        % TCOM PEB (with K+1 cooperative measurement)
        PEB_TCOM_grid(iy, ix) = PEB_complete(R, nt_orientations, params.T, ...
            params.Pt, params.m, params.A_det, deg2rad(params.Phi_half), ...
            params.Psi_FOV, params.sigma2, params.N);
    end
end

elapsed = toc;
fprintf('Done in %.1f seconds.\n', elapsed);

%% Ratio
ratio_grid = PEB_Konly_grid ./ PEB_TCOM_grid;

%% Statistics
valid_Konly = PEB_Konly_grid(isfinite(PEB_Konly_grid));
valid_TCOM = PEB_TCOM_grid(isfinite(PEB_TCOM_grid));
valid_ratio = ratio_grid(isfinite(ratio_grid));

fprintf('\n=== PEB Statistics (z = %.1f m, K = %d) ===\n', z_analysis, K);
fprintf('PEB_Konly:  RMS = %.2f cm, Mean = %.2f cm, Max = %.2f cm\n', ...
    100*sqrt(mean(valid_Konly.^2)), 100*mean(valid_Konly), 100*max(valid_Konly));
fprintf('PEB_TCOM:   RMS = %.2f cm, Mean = %.2f cm, Max = %.2f cm\n', ...
    100*sqrt(mean(valid_TCOM.^2)), 100*mean(valid_TCOM), 100*max(valid_TCOM));
fprintf('Ratio:      Mean = %.2fx, Median = %.2fx, Max = %.2fx\n', ...
    mean(valid_ratio), median(valid_ratio), max(valid_ratio));

%% Figure 1: Side-by-side heatmaps
figure('Position', [100, 100, 1400, 400]);

% Determine common color scale
cmax_peb = max(max(valid_Konly), max(valid_TCOM)) * 100; % in cm
cmax_peb = min(cmax_peb, 10); % Cap at 10 cm for visualization

% Fig 1a: PEB_Konly
subplot(1, 3, 1);
imagesc(x_range, y_range, PEB_Konly_grid * 100);
set(gca, 'YDir', 'normal');
xlabel('x [m]'); ylabel('y [m]');
title(sprintf('PEB_{K-only} (K=%d, no K+1)', K));
colorbar; caxis([0 cmax_peb]);
colormap(gca, 'jet');
axis equal tight;
hold on;
plot(0, 0, 'w^', 'MarkerSize', 10, 'MarkerFaceColor', 'w');
text(0.05, 0.1, 'LED', 'Color', 'w', 'FontWeight', 'bold');

% Fig 1b: PEB_TCOM
subplot(1, 3, 2);
imagesc(x_range, y_range, PEB_TCOM_grid * 100);
set(gca, 'YDir', 'normal');
xlabel('x [m]'); ylabel('y [m]');
title(sprintf('PEB_{TCOM} (K=%d + K+1 cooperative)', K));
colorbar; caxis([0 cmax_peb]);
colormap(gca, 'jet');
axis equal tight;
hold on;
plot(0, 0, 'w^', 'MarkerSize', 10, 'MarkerFaceColor', 'w');

% Fig 1c: Ratio
subplot(1, 3, 3);
imagesc(x_range, y_range, ratio_grid);
set(gca, 'YDir', 'normal');
xlabel('x [m]'); ylabel('y [m]');
title('Ratio PEB_{K-only} / PEB_{TCOM}');
cb = colorbar;
ylabel(cb, 'Factor');
colormap(gca, 'hot');
axis equal tight;
hold on;
plot(0, 0, 'w^', 'MarkerSize', 10, 'MarkerFaceColor', 'w');

sgtitle(sprintf('PEB Comparison: K-only (Broadcast) vs TCOM (Cooperative) — z = %.1f m, K = %d, n_r = [0,0,1]', ...
    z_analysis, K), 'FontSize', 12);

%% Save
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
saveas(gcf, fullfile(results_dir, 'Fig01_PEB_comparison_heatmap.png'));
saveas(gcf, fullfile(results_dir, 'Fig01_PEB_comparison_heatmap.fig'));

%% Figure 2: Histogram of the ratio
figure('Position', [100, 600, 600, 400]);
histogram(valid_ratio, 30, 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'none');
xlabel('PEB_{K-only} / PEB_{TCOM}');
ylabel('Number of positions');
title(sprintf('Distribution of PEB penalty (K=%d, z=%.1f m)', K, z_analysis));
xline(median(valid_ratio), 'r--', sprintf('Median = %.2f\\times', median(valid_ratio)), ...
    'LineWidth', 2, 'LabelOrientation', 'horizontal');
grid on;

saveas(gcf, fullfile(results_dir, 'Fig01b_PEB_ratio_histogram.png'));

fprintf('\nFigures saved to: %s\n', results_dir);
