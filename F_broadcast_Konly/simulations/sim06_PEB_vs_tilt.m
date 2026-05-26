%% sim06_PEB_vs_tilt.m — PEB_B vs receiver tilt angle θ_tilt
%
% Two-level aggregation:
%   Level 1 (azimut): For each (position, tilt), compute the RMS of PEB_B
%     over N_az uniformly spaced azimuts:
%       PEB_B_eff(r,θ) = sqrt( (1/N_az) Σ_φ PEB_B²(r,θ,φ) )
%     This is the correct aggregation because PEB_B is a std. deviation,
%     so averaging PEB_B² = averaging variances (valid), then taking sqrt.
%     Arithmetic mean of PEB_B would be methodologically incorrect.
%
%   Level 2 (spatial): Apply selected metric over positions → scalar per tilt
%
% Interpretation:
%   - Level 1 = "user tilts by θ in any direction equally likely; IMU knows φ"
%   - Level 2 = "system performance across the room"
%
% Output:
%   Figure:  metric-PEB_B [cm] vs θ_tilt [°], one curve per K
%   .mat:    Full raw data + per-position averaged data (for box-plots)
%
% Author: Kevin Acuna-Condori
% Date: 27 May 2026
% Project: Proposal F — Broadcast OWP

clear; clc; close all;

%% Paths
project_root = fileparts(pwd);  % F_broadcast_Konly/
addpath(fullfile(project_root, 'core'));
addpath(fullfile(fileparts(project_root), 'fundamentals', 'core'));
addpath(project_root);

%% System Parameters
system_params_F;

% =========================================================================
% HYPERPARAMETERS
% =========================================================================
K_sweep            = [5,7,9];          % K values to evaluate
theta_tilt_range   = 0:3:30;         % Tilt angles [deg]
N_az               = 36;              % Azimut samples (every 10°)
spatial_metric     = 'rms';           % 'rms', 'mean', 'median', 'cdf90'
% =========================================================================

%% Generate FULL 3D testbed (as defined in system_params_F)
x_range = -L/2:step:L/2;
y_range = -W/2:step:W/2;
z_range = 0:stepH:Hmax;
[X, Y, Z] = meshgrid(x_range, y_range, z_range);
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);
fprintf('Full 3D testbed: %d positions (%.1f×%.1f×%.1f m³, step=%.2f m)\n', ...
    N_pos, L, W, Hmax, step);

%% Azimut samples
phi_az_range = linspace(0, 360 - 360/N_az, N_az);

%% Preallocate
N_tilt = length(theta_tilt_range);
N_K    = length(K_sweep);

% Raw data: PEB_B(position, azimut, tilt, K_index) — for full analysis
PEB_B_raw = zeros(N_pos, N_az, N_tilt, N_K);

% Level 1 result: PEB_B averaged over azimuts → one value per (position, tilt, K)
% This is what goes into box-plots
PEB_B_per_pos = zeros(N_pos, N_tilt, N_K);

% Level 2 result: spatial metric → one scalar per (tilt, K)
PEB_B_agg = zeros(N_tilt, N_K);

%% Main computation
fprintf('Computing PEB_B vs tilt: %d K × %d tilts × %d azimuts × %d positions\n', ...
    N_K, N_tilt, N_az, N_pos);
fprintf('Total PEB evaluations: %d\n', N_K * N_tilt * N_az * N_pos);
total_tic = tic;

for ik = 1:N_K
    K = K_sweep(ik);
    K_idx = find(K_values == K);
    nt = orient_to_vectors(all_orientations_DEB{K_idx});  % 3 x K
    
    fprintf('\n--- K = %d ---\n', K);
    
    for i_tilt = 1:N_tilt
        theta_t = theta_tilt_range(i_tilt);
        
        peb_pos_az = zeros(N_pos, N_az);
        
        for i_az = 1:N_az
            phi_az = phi_az_range(i_az);
            
            % Tilted receiver orientation
            nr_tilted = [sind(theta_t)*cosd(phi_az); ...
                         sind(theta_t)*sind(phi_az); ...
                         cosd(theta_t)];
            
            for i_pos = 1:N_pos
                R = [X_r(i_pos); Y_r(i_pos); Z_r(i_pos)];
                
                peb_val = PEB_Konly(R, nt, T', P_t, m_t, A_det, ...
                    deg2rad(FOV), sigma2, N_samples, nr_tilted);
                
                if isfinite(peb_val) && isreal(peb_val)
                    peb_pos_az(i_pos, i_az) = peb_val;
                else
                    peb_pos_az(i_pos, i_az) = NaN;
                end
            end
        end
        
        % Store raw data
        PEB_B_raw(:, :, i_tilt, ik) = peb_pos_az;
        
        % --- Level 1: RMS over azimuts per position ---
        % PEB_B_eff(r,θ) = sqrt( E_φ[PEB_B²(r,θ,φ)] )
        % = sqrt( (1/N_az) Σ_φ PEB_B² )  [averaging variances, not std devs]
        peb_per_pos = sqrt(nanmean(peb_pos_az.^2, 2));  % N_pos × 1
        PEB_B_per_pos(:, i_tilt, ik) = peb_per_pos;
        
        % --- Level 2: Spatial metric over positions ---
        valid = peb_per_pos(isfinite(peb_per_pos));
        if isempty(valid)
            PEB_B_agg(i_tilt, ik) = NaN;
        else
            switch spatial_metric
                case 'rms'
                    PEB_B_agg(i_tilt, ik) = sqrt(mean(valid.^2));
                case 'mean'
                    PEB_B_agg(i_tilt, ik) = mean(valid);
                case 'median'
                    PEB_B_agg(i_tilt, ik) = median(valid);
                case 'cdf90'
                    PEB_B_agg(i_tilt, ik) = prctile(valid, 90);
            end
        end
        
        fprintf('  θ_tilt = %2d° : PEB_B(%s) = %.2f cm\n', ...
            theta_t, spatial_metric, PEB_B_agg(i_tilt, ik)*100);
    end
end

total_time = toc(total_tic);
fprintf('\nTotal time: %.1f s (%.1f min)\n', total_time, total_time/60);

%% Figure: PEB_B vs θ_tilt
metric_labels = struct('rms','RMS', 'mean','Mean', 'median','Median', 'cdf90','CDF_{90\%}');
metric_label = metric_labels.(spatial_metric);

figure('Position', [100, 100, 700, 500]);
hold on;

colors = lines(N_K);
markers = {'o', 's', 'd', '^', 'v', 'p', 'h'};

for ik = 1:N_K
    mk = markers{min(ik, length(markers))};
    plot(theta_tilt_range, PEB_B_agg(:, ik)*100, ...
        ['-' mk], 'LineWidth', 1.8, 'MarkerSize', 7, ...
        'Color', colors(ik,:), 'MarkerFaceColor', colors(ik,:));
end

xlabel('Receiver tilt $\theta_{\mathrm{tilt}}$ [$^\circ$]', 'Interpreter', 'latex');
ylabel(sprintf('%s $\\mathrm{PEB}_\\mathrm{B}$ [cm]', metric_label), 'Interpreter', 'latex');
title(sprintf('Broadcast PEB vs Receiver Tilt ($\\Phi_{1/2}{=}%d^\\circ$, DEB-opt., 3D testbed)', ...
    theta_half), 'Interpreter', 'latex');
legend(arrayfun(@(k) sprintf('$K{=}%d$', k), K_sweep, 'UniformOutput', false), ...
    'Interpreter', 'latex', 'Location', 'northwest');
grid on; box on;
xlim([0 max(theta_tilt_range)]);

%% Save
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

saveas(gcf, fullfile(results_dir, sprintf('Fig_A4_PEB_vs_tilt_%s.png', spatial_metric)));
saveas(gcf, fullfile(results_dir, sprintf('Fig_A4_PEB_vs_tilt_%s.fig', spatial_metric)));

save(fullfile(results_dir, 'sim06_PEB_vs_tilt_data.mat'), ...
    'PEB_B_raw', 'PEB_B_per_pos', 'PEB_B_agg', ...
    'theta_tilt_range', 'phi_az_range', 'K_sweep', 'spatial_metric', ...
    'X_r', 'Y_r', 'Z_r', 'N_pos', 'N_az', ...
    'step', 'total_time');

fprintf('Figure saved to: %s\n', results_dir);
fprintf('Data saved:\n');
fprintf('  PEB_B_raw      [%d pos × %d az × %d tilt × %d K]  (full raw)\n', N_pos, N_az, N_tilt, N_K);
fprintf('  PEB_B_per_pos  [%d pos × %d tilt × %d K]           (azimut-averaged, for box-plots)\n', N_pos, N_tilt, N_K);
fprintf('  PEB_B_agg      [%d tilt × %d K]                    (spatial %s)\n', N_tilt, N_K, spatial_metric);

%% Print degradation summary
fprintf('\n=== Degradation vs tilt (relative to θ=0°, metric=%s) ===\n', spatial_metric);
fprintf('%-6s', 'θ_tilt');
for ik = 1:N_K
    fprintf(' | K=%-2d              ', K_sweep(ik));
end
fprintf('\n');
fprintf('%s\n', repmat('-', 1, 6 + N_K*21));
for i_tilt = 1:N_tilt
    fprintf('%4d° ', theta_tilt_range(i_tilt));
    for ik = 1:N_K
        ratio = PEB_B_agg(i_tilt, ik) / PEB_B_agg(1, ik);
        fprintf(' | %6.2f cm (%+5.1f%%) ', PEB_B_agg(i_tilt, ik)*100, (ratio-1)*100);
    end
    fprintf('\n');
end
