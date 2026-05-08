%% Fig_DF_TargetPlot.m
% "Target plot" for direction-finding stage.
%
% Concept: orthographic projection of the unit sphere onto a 2D plane.
% Each testbed position defines a true direction n_d = (r - t)/||r - t||.
% Since n_d always points roughly downward, its (x,y) components define a
% natural 2D projection where:
%   - Centre (0,0) → position directly below the LED (theta_d = 0)
%   - Radius from centre → tilt angle theta_d (larger = corner positions)
%   - Angle around centre → azimuth phi_d
%
% For each selected position, M_vis MC trials are run for GLS and NLS.
% Each trial gives an estimated n_hat; its (x,y) projection is plotted as a
% small dot around the true direction marker.  DEB is shown as a circle of
% radius = DEB [rad] in the tangent-plane approximation.
%
% Author: Kevin Acuña

close all; clear variables; clc;
script_dir = fileparts(mfilename('fullpath'));
parent_dir = fileparts(script_dir);
addpath(fullfile(parent_dir, 'estimators'));  % system_params
addpath(fullfile(parent_dir, 'core'));        % vlp_gls, vlp_wls, DEB_complete, OWC_LOS_channel

%% =========================================================================
%  HYPERPARAMETERS
%% =========================================================================
rng(42);
M_vis        = 80;       % MC trials per displayed position (keep modest for speed)
N_sel        = 20;       % Number of positions to display
z_fixed      = 0.6;      % Height slice to pick positions from [m]
show_WLS     = false;    % Set true to also plot WLS (adds clutter)
save_fig     = true;     % Save output PNG

%% =========================================================================
%  1. System Parameters
%% =========================================================================
system_params;
T = [0, 0, 2];           % LED position [m]

% DEB-optimized orientations K=5
ori = orientations_DEB_K5;
N_or = 5;
n_t = zeros(N_or, 3);
for i = 1:N_or
    th = ori(2*i-1); ph = ori(2*i);
    n_t(i,:) = [sind(th)*cosd(ph), sind(th)*sind(ph), -cosd(th)];
end
param_r = {A_det, n_r, FOV};
options_nl = optimoptions('fmincon','Display','none','Algorithm','sqp');

%% =========================================================================
%  2. Select testbed positions on one height slice
%% =========================================================================
[X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, z_fixed);
X_all = X(:); Y_all = Y(:); Z_all = Z(:);

% Pick N_sel positions uniformly (skip positions directly under LED for clarity)
d_floor = sqrt(X_all.^2 + Y_all.^2);  % distance from LED nadir
valid = d_floor > 0.3;                 % avoid singularity at nadir
idx_pool = find(valid);
step_sel = max(1, floor(numel(idx_pool)/N_sel));
sel = idx_pool(1:step_sel:end);
sel = sel(1:min(N_sel, numel(sel)));
N_sel = numel(sel);

X_r = X_all(sel)'; Y_r = Y_all(sel)'; Z_r = Z_all(sel)';

%% =========================================================================
%  3. Monte Carlo per selected position
%% =========================================================================
fprintf('Running %d trials x %d positions...\n', M_vis, N_sel);

% Storage: each cell = [M_vis x 3] estimated directions
nd_true   = zeros(N_sel, 3);    % true direction
nd_GLS    = cell(N_sel, 1);
nd_NLS    = cell(N_sel, 1);
nd_WLS    = cell(N_sel, 1);
DEB_vals  = zeros(N_sel, 1);

for i_pos = 1:N_sel
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    R_real = [x; y; z];
    v_true = (R_real - T') / norm(R_real - T');
    nd_true(i_pos,:) = v_true';

    % Clean channel powers
    P_clean = zeros(1, N_or);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_clean(i_dir), ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
    end

    % DEB (theoretical)
    deb_val = DEB_complete(R_real, n_t', T', P_t, m_t, A_det, ...
        deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples);
    DEB_vals(i_pos) = real(deb_val);  % radians

    % MC trials
    gls_est = zeros(M_vis, 3);
    nls_est = zeros(M_vis, 3);
    wls_est = zeros(M_vis, 3);

    for mc = 1:M_vis
        P_raw = repmat(P_clean, N_samples, 1) + sqrt(sigma2)*randn(N_samples, N_or);
        p_means = mean(P_raw, 1);

        % GLS
        d_hat = vlp_gls(n_t', P_raw, m_t, sigma2);
        gls_est(mc,:) = (d_hat / norm(d_hat))';

        % WLS
        d_hat_w = vlp_wls(n_t', P_raw, m_t);
        wls_est(mc,:) = (d_hat_w / norm(d_hat_w))';

        % NLS
        max_p = max(p_means); if max_p <= 0; max_p = 1e-12; end
        p_tgt = p_means / max_p;
        [~, mx] = max(p_tgt);
        x0 = [n_t(mx,1), n_t(mx,2), n_t(mx,3), 1.0];
        lb = [-1,-1,-1, 1e-3]; ub = [1,1,0, 10];
        sol = fmincon(@(v) mle_cost_function(v, p_tgt, n_t, m_t), ...
                      x0, [], [], [], [], lb, ub, @sphere_constraint, options_nl);
        nls_est(mc,:) = (sol(1:3) / norm(sol(1:3)))';
    end

    nd_GLS{i_pos} = gls_est;
    nd_NLS{i_pos} = nls_est;
    nd_WLS{i_pos} = wls_est;

    if mod(i_pos, 5) == 0
        fprintf('  %d / %d done\n', i_pos, N_sel);
    end
end
fprintf('Done.\n');

%% =========================================================================
%  4. Build Figure — Orthographic projection on the (n_x, n_y) plane
%% =========================================================================
% n_d = [-sin(theta)*cos(phi), -sin(theta)*sin(phi), -cos(theta)]
% so n_d(1,2) give the 2D orthographic projection directly.

fig = figure('Units','centimeters','Position',[2 2 18 16],...
             'Color','white','PaperPositionMode','auto');

ax = axes('Parent', fig);
hold(ax, 'on');

% Colors
c_true = [0.1 0.1 0.1];      % black
c_gls  = [0.13 0.47 0.71];   % blue
c_nls  = [0.44 0.68 0.28];   % green
c_wls  = [0.93 0.54 0.15];   % orange
c_deb  = [0.80 0.12 0.12];   % red

% Marker sizes
sz_true   = 80;
sz_est    = 6;
alpha_est = 0.35;

% Reference circles (theta_d contours)
theta_contours = [20, 40, 60];
for th = theta_contours
    phi_c = linspace(0, 2*pi, 200);
    nx_c = -sin(deg2rad(th)) * cos(phi_c);
    ny_c = -sin(deg2rad(th)) * sin(phi_c);
    plot(ax, nx_c, ny_c, '--', 'Color', [0.8 0.8 0.8], 'LineWidth', 0.8);
    text(ax, -sin(deg2rad(th))*cos(deg2rad(135)), ...
             -sin(deg2rad(th))*sin(deg2rad(135)), ...
        sprintf('%d°', th), 'FontSize', 7, 'Color', [0.6 0.6 0.6], ...
        'HorizontalAlignment','center');
end

% Reference spokes (azimuth lines)
for phi_spoke = 0:45:315
    nx_s = [0, -sin(deg2rad(65))*cosd(phi_spoke)];
    ny_s = [0, -sin(deg2rad(65))*sind(phi_spoke)];
    plot(ax, nx_s, ny_s, '-', 'Color', [0.88 0.88 0.88], 'LineWidth', 0.6);
end

% Scatter plots and DEB circles per position
for i_pos = 1:N_sel
    nd  = nd_true(i_pos,:);
    gls = nd_GLS{i_pos};
    nls = nd_NLS{i_pos};
    wls = nd_WLS{i_pos};
    deb = DEB_vals(i_pos);   % radians

    % Scatter estimated
    if show_WLS
        scatter(ax, wls(:,1), wls(:,2), sz_est, c_wls, 'filled', ...
            'MarkerFaceAlpha', alpha_est, 'MarkerEdgeAlpha', 0);
    end
    scatter(ax, gls(:,1), gls(:,2), sz_est, c_gls, 'filled', ...
        'MarkerFaceAlpha', alpha_est, 'MarkerEdgeAlpha', 0);
    scatter(ax, nls(:,1), nls(:,2), sz_est, c_nls, 'filled', ...
        'MarkerFaceAlpha', alpha_est, 'MarkerEdgeAlpha', 0);

    % DEB circle (tangent-plane, radius ≈ DEB [rad] in projection)
    phi_c = linspace(0, 2*pi, 60);
    % Approximate tangent-plane circle: radius = sin(DEB) ≈ DEB for small angles
    % Centred at (nd(1), nd(2))
    r_deb = sin(deb);
    cx = nd(1) + r_deb * cos(phi_c);
    cy = nd(2) + r_deb * sin(phi_c);
    plot(ax, cx, cy, '-', 'Color', [c_deb, 0.55], 'LineWidth', 0.9);

    % True direction marker (on top)
    scatter(ax, nd(1), nd(2), sz_true, c_true, 'x', ...
        'LineWidth', 1.8, 'SizeData', sz_true);
end

% Dummy handles for legend
h_true = scatter(ax, NaN, NaN, sz_true, c_true, 'x', 'LineWidth', 1.8);
h_gls  = scatter(ax, NaN, NaN, 30, c_gls, 'filled', 'MarkerFaceAlpha', 0.7);
h_nls  = scatter(ax, NaN, NaN, 30, c_nls, 'filled', 'MarkerFaceAlpha', 0.7);
h_deb  = plot(ax, NaN, NaN, '-', 'Color', c_deb, 'LineWidth', 1.2);
if show_WLS
    h_wls = scatter(ax, NaN, NaN, 30, c_wls, 'filled', 'MarkerFaceAlpha', 0.7);
    legend(ax, [h_true, h_gls, h_nls, h_wls, h_deb], ...
        {'True $\mathbf{n}_d$','GLS','NLS','WLS','DEB ($1\sigma$)'}, ...
        'Interpreter','latex','Location','northeast','FontSize',9);
else
    legend(ax, [h_true, h_gls, h_nls, h_deb], ...
        {'True $\mathbf{n}_d$','GLS','NLS','DEB ($1\sigma$)'}, ...
        'Interpreter','latex','Location','northeast','FontSize',9);
end

% Axis formatting
axis(ax, 'equal');
xlim(ax, [-0.8 0.8]); ylim(ax, [-0.8 0.8]);
xlabel(ax, '$n_{d,x}$ (orthographic projection)', 'Interpreter','latex','FontSize',11);
ylabel(ax, '$n_{d,y}$ (orthographic projection)', 'Interpreter','latex','FontSize',11);
title(ax, sprintf('Direction-Finding Target Plot (K=%d, M=%d trials/pos, z=%.1fm)', ...
    N_or, M_vis, z_fixed), 'Interpreter','latex','FontSize',11);
set(ax,'FontSize',10,'Box','on','GridAlpha',0.2,'TickLabelInterpreter','latex');
grid(ax,'off');

% Add compass labels
text(ax,  0.82, 0,    'E',  'FontSize',8,'Color',[0.5 0.5 0.5],'HorizontalAlignment','center');
text(ax, -0.82, 0,    'W',  'FontSize',8,'Color',[0.5 0.5 0.5],'HorizontalAlignment','center');
text(ax,  0,    0.82, 'N',  'FontSize',8,'Color',[0.5 0.5 0.5],'HorizontalAlignment','center');
text(ax,  0,   -0.82, 'S',  'FontSize',8,'Color',[0.5 0.5 0.5],'HorizontalAlignment','center');

hold(ax,'off');

%% =========================================================================
%  5. Save
%% =========================================================================
if save_fig
    out_dir = fullfile(fileparts(mfilename('fullpath')), 'outputs');
    if ~exist(out_dir,'dir'); mkdir(out_dir); end
    out_path = fullfile(out_dir, 'Fig_DF_TargetPlot.png');
    exportgraphics(fig, out_path, 'Resolution', 300);
    fprintf('Saved → %s\n', out_path);
end

%% =========================================================================
%  LOCAL FUNCTIONS (copied from run_DF_comparison_MC_parallel.m)
%% =========================================================================
function F = mle_cost_function(vars, p_target, n_t, m_t)
    v   = vars(1:3)';
    eta = vars(4);
    F   = 0;
    for k = 1:size(n_t,1)
        q = max(0, dot(n_t(k,:), v));
        F = F + (eta * q^m_t - p_target(k))^2;
    end
end

function [c, ceq] = sphere_constraint(vars)
    c   = [];
    ceq = vars(1)^2 + vars(2)^2 + vars(3)^2 - 1;
end
