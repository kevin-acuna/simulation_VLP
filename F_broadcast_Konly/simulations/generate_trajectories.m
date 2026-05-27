%% generate_trajectories.m — Realistic indoor pedestrian trajectories
%
% Generates N_users trajectories within a rectangular room using a
% waypoint model with cubic spline interpolation and human gait noise.
%
% Model:
%   1. Pick N_waypoints random waypoints inside room (with wall margin)
%   2. Smooth with cubic spline → continuous curved path
%   3. Add lateral sway (natural walking oscillation ~2-5 cm)
%   4. Add height variation (gait-induced vertical oscillation ~1-3 cm)
%   5. Clip to room boundaries
%
% Each user has a different mean height representing device position:
%   - Standing phone at ear:   z ~ 1.0 m
%   - Walking phone in hand:   z ~ 0.8 m
%   - Phone at hip:            z ~ 0.6 m
%   - Seated (tablet on lap):  z ~ 0.4 m
%
% Output: trajectories.mat with:
%   traj_true{iu}  : N_steps × 3, ground truth positions [x, y, z]
%   traj_info{iu}  : struct with user description
%
% Author: Kevin Acuna-Condori
% Date: 27 May 2026

clear; clc; close all;

% =========================================================================
% HYPERPARAMETERS
% =========================================================================
rng(2026);                   % Reproducible
N_users      = 4;
N_steps      = 25;           % Positions per trajectory
N_waypoints  = 5;            % Control points per trajectory (more = more turns)
wall_margin  = 0.20;         % Minimum distance from walls [m]

% Room (consistent with system_params_F)
L = 3; W = 3;
x_lim = [-L/2 + wall_margin,  L/2 - wall_margin];
y_lim = [-W/2 + wall_margin,  W/2 - wall_margin];

% Human gait parameters
lateral_sway_std = 0.03;     % Lateral sway std [m] (~3 cm)
gait_freq        = 1.8;      % Step frequency [Hz] (typical walking)
gait_z_amplitude = 0.015;    % Vertical oscillation amplitude [m] (~1.5 cm per step)
z_noise_std      = 0.005;    % Additional random z noise [m]

% Per-user configurations
user_configs = {
    struct('z_mean', 0.95, 'label', 'User 1: standing, phone at ear', ...
           'speed_factor', 0.8);
    struct('z_mean', 0.80, 'label', 'User 2: walking, phone in hand', ...
           'speed_factor', 1.0);
    struct('z_mean', 0.55, 'label', 'User 3: phone at hip level', ...
           'speed_factor', 1.1);
    struct('z_mean', 0.35, 'label', 'User 4: seated, tablet on lap', ...
           'speed_factor', 0.4);
};
% =========================================================================

%% Generate trajectories
traj_true = cell(N_users, 1);
traj_info = cell(N_users, 1);

for iu = 1:N_users
    cfg = user_configs{iu};
    
    %% 1. Random waypoints
    wp_x = x_lim(1) + diff(x_lim) * rand(N_waypoints, 1);
    wp_y = y_lim(1) + diff(y_lim) * rand(N_waypoints, 1);
    
    %% 2. Spline interpolation for smooth curved path
    % Parameterize by arc-length proxy (cumulative distance)
    t_wp = [0; cumsum(sqrt(diff(wp_x).^2 + diff(wp_y).^2))];
    t_wp = t_wp / t_wp(end);  % Normalize to [0, 1]
    
    t_fine = linspace(0, 1, N_steps)';
    
    % Cubic spline through waypoints
    x_smooth = interp1(t_wp, wp_x, t_fine, 'pchip');
    y_smooth = interp1(t_wp, wp_y, t_fine, 'pchip');
    
    %% 3. Lateral sway (perpendicular to walking direction)
    % Compute tangent direction at each point
    dx = gradient(x_smooth);
    dy = gradient(y_smooth);
    ds = sqrt(dx.^2 + dy.^2) + 1e-10;
    
    % Normal direction (perpendicular to tangent)
    nx = -dy ./ ds;
    ny =  dx ./ ds;
    
    % Oscillating sway (sinusoidal + noise)
    sway = lateral_sway_std * sin(2*pi*gait_freq * t_fine * cfg.speed_factor) ...
           + lateral_sway_std * 0.3 * randn(N_steps, 1);
    
    x_final = x_smooth + sway .* nx;
    y_final = y_smooth + sway .* ny;
    
    %% 4. Height with gait oscillation
    % Vertical bob from walking gait (double-bump per stride)
    z_gait = gait_z_amplitude * abs(sin(2*pi*gait_freq * t_fine * cfg.speed_factor));
    z_noise = z_noise_std * randn(N_steps, 1);
    z_final = cfg.z_mean + z_gait + z_noise;
    
    % Seated user: much less z variation
    if cfg.speed_factor < 0.5
        z_final = cfg.z_mean + z_noise_std * 0.3 * randn(N_steps, 1);
    end
    
    %% 5. Clip to room boundaries
    x_final = max(min(x_final, L/2 - 0.05), -L/2 + 0.05);
    y_final = max(min(y_final, W/2 - 0.05), -W/2 + 0.05);
    z_final = max(min(z_final, 1.2), 0.0);
    
    traj_true{iu} = [x_final, y_final, z_final];
    traj_info{iu} = cfg;
end

%% Visualization (preview)
figure('Position', [100, 100, 800, 600], 'Color', 'w');
hold on;

colors = [0.20, 0.40, 0.75;
          0.85, 0.35, 0.10;
          0.15, 0.65, 0.35;
          0.60, 0.20, 0.60];

for iu = 1:N_users
    tr = traj_true{iu};
    col = colors(iu,:);
    
    plot3(tr(:,1), tr(:,2), tr(:,3), '-', 'LineWidth', 2.2, 'Color', col);
    plot3(tr(1,1), tr(1,2), tr(1,3), 'o', 'MarkerSize', 9, ...
        'MarkerFaceColor', col, 'MarkerEdgeColor', 'k');
    plot3(tr(end,1), tr(end,2), tr(end,3), 's', 'MarkerSize', 10, ...
        'MarkerFaceColor', col, 'MarkerEdgeColor', 'k');
    
    text(tr(1,1)+0.05, tr(1,2)+0.05, tr(1,3)+0.05, ...
        sprintf('U%d (z=%.2fm)', iu, traj_info{iu}.z_mean), ...
        'FontSize', 8, 'Color', col);
end

% Room floor
plot3([-L/2 L/2 L/2 -L/2 -L/2], [-W/2 -W/2 W/2 W/2 -W/2], ...
    zeros(1,5), '-', 'Color', [0.7 0.7 0.7]);

plot3(0, 0, 2, 'p', 'MarkerSize', 15, 'MarkerFaceColor', [1 0.8 0], ...
    'MarkerEdgeColor', [0.8 0.5 0]);

xlabel('x [m]'); ylabel('y [m]'); zlabel('z [m]');
title('Generated Indoor Pedestrian Trajectories');
view(35, 25); grid on; axis equal;
xlim([-L/2 L/2]); ylim([-W/2 W/2]); zlim([0 2.1]);
legend(arrayfun(@(i) sprintf('User %d: z_{mean}=%.2f m', i, traj_info{i}.z_mean), ...
    1:N_users, 'UniformOutput', false), 'Location', 'northeastoutside');

%% Save
save(fullfile(pwd, 'trajectories.mat'), 'traj_true', 'traj_info', ...
    'N_users', 'N_steps', 'colors');
fprintf('Saved %d trajectories (%d steps each) to trajectories.mat\n', N_users, N_steps);

% Print path statistics
fprintf('\n%-8s %10s %10s %10s %10s\n', 'User', 'Length[m]', 'z_mean[m]', 'z_std[cm]', 'Label');
for iu = 1:N_users
    tr = traj_true{iu};
    path_len = sum(sqrt(sum(diff(tr).^2, 2)));
    fprintf('%-8d %10.2f %10.2f %10.2f   %s\n', ...
        iu, path_len, mean(tr(:,3)), std(tr(:,3))*100, traj_info{iu}.label);
end
