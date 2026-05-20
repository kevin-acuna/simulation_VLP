%% Figure: 3D Position Estimates — K=5 (GLS, WLS, Ground Truth)
% IEEE TCOM scatter figure of GLS and/or WLS position estimates at three
% receiver heights z ∈ {0, 0.6, 1.2} m for the K=5 GLS-DF-optimised
% orientation set in a 3×3×2 m³ room.
%
% Testbed: step=0.20 m (16×16×3 = 768 positions), fine enough for
% visual density while remaining fast.
%
% Requires: ../core/  (OWC_LOS_channel.m, vlp_gls.m, vlp_wls.m)
%
% Author: Kevin Acuña

close all; clear variables; clc;
addpath('../core');

%% ===== HYPERPARAMETERS =====
rng(42);
SHOW_GLS    = true;   % plot GLS estimates
SHOW_WLS    = false;  % plot WLS estimates
SHOW_STEMS  = true;   % draw error lines from GT to estimates
SAVE_OUTPUT = true;

%% ===== PATHS =====
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
out_local = fullfile(script_dir, 'outputs');
out_paper = fullfile(script_dir, '..', '..', 'TCOM', 'Reviewed_submission', ...
    'TCOM_paper', 'Figures', 'VII.Simulations');
if ~exist(out_local, 'dir'), mkdir(out_local); end
fname = 'Fig_Comparison_3D';

%% ===== SYSTEM PARAMETERS =====
theta_half = 45;
P_t    = 0.405;
T      = [0, 0, 2];
m_t    = -log(2)/log(cosd(theta_half));
A_det  = 4.8e-3 * 5.5e-3;
FOV    = 85;
sigma2 = 30e6 * 10^(-21.0);

%% ===== ORIENTATION SET (K=5, GLS-DF-optimised) =====
orient_K5 = [1.58, 153.32, 41.37, 129.51, 31.95, 217.36, ...
             34.21, 306.97, 30.33,  42.52];

%% ===== TESTBED =====
L = 3; W = 3; Hmax = 1.2;
step   = 0.30;   % X,Y step [m]  → 16×16 = 256 pts/height
stepH  = 0.60;   % Z step   [m]  → heights: 0, 0.6, 1.2 m
N_samp = 1000;   % noise samples per orientation

[X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos   = length(X_r);
realPos = [X_r; Y_r; Z_r]';
fprintf('Testbed: %d positions  (step=%.2f m, stepH=%.2f m)\n', N_pos, step, stepH);

%% ===== SIMULATION =====
fprintf('Running K=5 estimators ... '); tic;
[estGLS, estWLS] = estimate_pos(X_r, Y_r, Z_r, N_pos, orient_K5, 5, ...
    T, P_t, m_t, A_det, FOV, sigma2, N_samp);
fprintf('done (%.1f s).\n', toc);

%% ===== STYLING =====
color_gt  = [0.15, 0.15, 0.15];    % near-black  — ground truth
color_gls = [0.000, 0.447, 0.741]; % blue        — GLS
color_wls = [0.850, 0.325, 0.098]; % orange-red  — WLS
color_led = [0.929, 0.694, 0.125]; % gold        — LED transmitter

ms_gt   = 3.0;   % marker size: ground truth (+)
ms_est  = 3.0;   % marker size: estimates (x)
ms_led  = 9.0;   % marker size: LED (pentagram)
lw_mark = 0.8;   % line width for open markers (+, x)
view_az = 45;    % azimuth  [deg]
view_el = 30;    % elevation [deg]

ax_fmt = {'FontName','Times New Roman','FontSize',9, ...
          'TickLabelInterpreter','latex','LineWidth',0.8, ...
          'Box','on','GridLineStyle',':','GridAlpha',0.30, ...
          'MinorGridLineStyle',':','MinorGridAlpha',0.10};

%% ===== MAIN FIGURE =====
fig = figure('Units','inches','Position',[1 1 3.5 4.0],'Color','w');
ax  = axes(fig, 'Position',[0.15 0.09 0.75 0.76]);
hold(ax, 'on');

% --- 1. Error stems (plotted first so they appear behind markers) ---
if SHOW_STEMS
    if SHOW_GLS
        sx = reshape([realPos(:,1)'; estGLS(:,1)'; nan(1,N_pos)], 1, []);
        sy = reshape([realPos(:,2)'; estGLS(:,2)'; nan(1,N_pos)], 1, []);
        sz = reshape([realPos(:,3)'; estGLS(:,3)'; nan(1,N_pos)], 1, []);
        plot3(ax, sx, sy, sz, '-', 'Color', [0.72, 0.72, 0.72], ...
            'LineWidth', 0.35, 'HandleVisibility', 'off');
    end
    if SHOW_WLS
        sx = reshape([realPos(:,1)'; estWLS(:,1)'; nan(1,N_pos)], 1, []);
        sy = reshape([realPos(:,2)'; estWLS(:,2)'; nan(1,N_pos)], 1, []);
        sz = reshape([realPos(:,3)'; estWLS(:,3)'; nan(1,N_pos)], 1, []);
        plot3(ax, sx, sy, sz, '-', 'Color', [0.82, 0.78, 0.72], ...
            'LineWidth', 0.35, 'HandleVisibility', 'off');
    end
end

% --- 2. Ground truth (+) ---
h_gt = plot3(ax, realPos(:,1), realPos(:,2), realPos(:,3), ...
    '+', 'Color', color_gt, 'MarkerSize', ms_gt, ...
    'LineWidth', lw_mark, 'LineStyle', 'none');

% --- 3. Estimates (x) ---
h_gls = []; h_wls = [];
if SHOW_GLS
    h_gls = plot3(ax, estGLS(:,1), estGLS(:,2), estGLS(:,3), ...
        'o', 'Color', color_gls, 'MarkerSize', ms_est, ...
        'LineWidth', 1.2, 'LineStyle', 'none');
end
if SHOW_WLS
    h_wls = plot3(ax, estWLS(:,1), estWLS(:,2), estWLS(:,3), ...
        'x', 'Color', color_wls, 'MarkerSize', ms_est, ...
        'LineWidth', lw_mark, 'LineStyle', 'none');
end

% --- 4. LED transmitter (pentagram at ceiling) ---
h_led = plot3(ax, T(1), T(2), T(3), 'p', ...
    'Color', color_led, 'MarkerFaceColor', color_led, ...
    'MarkerSize', ms_led, 'LineStyle', 'none');

set(ax, ax_fmt{:});
xlabel(ax, '$x$\,[m]', 'Interpreter','latex','FontSize',9);
ylabel(ax, '$y$\,[m]', 'Interpreter','latex','FontSize',9);
zlabel(ax, '$z$\,[m]', 'Interpreter','latex','FontSize',9);
xlim(ax, [-L/2, L/2]);
ylim(ax, [-W/2, W/2]);
zlim(ax, [-0.05, T(3) + 0.15]);     % extend to show LED at z=2
xticks(ax, [-1.5, 0, 1.5]);
yticks(ax, [-1.5, 0, 1.5]);
zticks(ax, [0, 0.6, 1.2, T(3)]);   % include LED height as tick
grid(ax, 'on');
grid(ax, 'minor');
view(ax, view_az, view_el);

% --- Legend (horizontal, above axes) ---
h_leg   = [h_led, h_gt];
leg_str = {'LED', 'Ground truth'};
if SHOW_GLS
    h_leg   = [h_leg,   h_gls];
    leg_str = [leg_str, {'GLS'}];
end
if SHOW_WLS
    h_leg   = [h_leg,   h_wls];
    leg_str = [leg_str, {'WLS'}];
end
lg = legend(ax, h_leg, leg_str, 'Interpreter','latex','FontSize',8.5, ...
    'Box','on','Orientation','horizontal','Location','northoutside');
lg.ItemTokenSize = [10, 8];
drawnow;
lpos = lg.Position;
lg.Position = [(1 - lpos(3))/2,  0.88,  lpos(3), lpos(4)];

hold(ax, 'off');

%% ===== EXPORT =====
if SAVE_OUTPUT
    for d = {out_local, out_paper}
        base = fullfile(d{1}, fname);
        exportgraphics(fig, [base, '.pdf'], 'ContentType','vector','BackgroundColor','white');
        exportgraphics(fig, [base, '.eps'], 'ContentType','vector','BackgroundColor','white');
        exportgraphics(fig, [base, '.png'], 'Resolution',600,'BackgroundColor','white');
    end
    fprintf('Figures exported to: %s\n', out_local);
    
end

%% ===== LOCAL FUNCTION =====
function [estGLS, estWLS] = estimate_pos(X_r, Y_r, Z_r, N_pos, ...
        orientations, N_or, T, P_t, m_t, A_det, FOV, sigma2, N_samp)

    n_t = zeros(N_or, 3);
    for i = 1:N_or
        th = orientations(2*i-1);
        rh = orientations(2*i);
        n_t(i,:) = [sind(th)*cosd(rh), sind(th)*sind(rh), -cosd(th)];
    end

    param_r = {A_det, [0, 0, 1], FOV};
    estGLS  = zeros(N_pos, 3);
    estWLS  = zeros(N_pos, 3);

    for i_pos = 1:N_pos
        x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);

        P_raw = zeros(N_samp, N_or);
        for i_dir = 1:N_or
            [~, Pc, ~, ~] = OWC_LOS_channel(x, y, z, ...
                {T, n_t(i_dir,:), P_t, m_t}, param_r);
            P_raw(:, i_dir) = Pc + sqrt(sigma2)*randn(N_samp, 1);
        end

        % GLS direction + distance recovery
        v = vlp_gls(n_t', P_raw, m_t, sigma2)';
        [~, Pa, ~, ~] = OWC_LOS_channel(x, y, z, ...
            {T, v, P_t, m_t}, {A_det, -v, FOV});
        d = sqrt(P_t*(m_t+1)*A_det / ...
            (2*pi*mean(Pa + sqrt(sigma2)*randn(1, N_samp))));
        estGLS(i_pos,:) = T + v*d;

        % WLS direction + distance recovery
        v = vlp_wls(n_t', P_raw, m_t)';
        [~, Pa, ~, ~] = OWC_LOS_channel(x, y, z, ...
            {T, v, P_t, m_t}, {A_det, -v, FOV});
        d = sqrt(P_t*(m_t+1)*A_det / ...
            (2*pi*mean(Pa + sqrt(sigma2)*randn(1, N_samp))));
        estWLS(i_pos,:) = T + v*d;
    end
end
