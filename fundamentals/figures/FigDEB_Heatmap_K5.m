%% FigDEB_Heatmap_K5.m
% IEEE TCOM — DEB & PEB spatial heatmaps: K=5, optimal vs random orientations.
% Fixed height z = 0.8 m. Shared colorbar per bound for fair comparison.
%
% Outputs (in outputs/):
%   DEB_heatmap_K5.{png,pdf,eps}   — DEB 2-panel figure
%   PEB_heatmap_K5.{png,pdf,eps}   — PEB 2-panel figure (same orientations)
%   DEB_heatmap_K5_optimal.png     — panel (a) only
%   DEB_heatmap_K5_random.png      — panel (b) only
%
% Author: Kevin Acuña
close all; clear variables; clc;
rng(40);

%% ===== FLAGS =====
SAVE_OUTPUT = true;     % true → export to outputs/ ; false → screen only
RECOMPUTE   = true;     % false → load cached DEB_heatmap_data.mat
VIEW_3D     = true;    % false → 2D heatmap (IEEE recommended); true → 3D surf
SINGLE_COL  = true;    % true  → 2×1 layout [3.5" single column]
                        % false → 1×2 layout [7.16" double column]

%% ===== PATHS =====
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = fileparts(which('FigDEB_Heatmap_K5'));
end
core_dir  = fullfile(script_dir, '..', 'core');
param_dir = fullfile(script_dir, '..', 'estimators');
out_dir   = fullfile(script_dir, 'outputs');
data_file = fullfile(out_dir, 'DEB_heatmap_data.mat');

addpath(core_dir);
addpath(param_dir);
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fprintf('Output directory: %s\n', out_dir);

%% ===== SYSTEM PARAMETERS (from system_params.m) =====
run('system_params.m');
T       = [0; 0; 2];
FOV_rad = deg2rad(FOV);

%% ===== CONFIGURATION =====
K         = 5;
z_height  = 0.8;          % analysis height [m]
step_fine = 0.05;          % grid step [m]  (fine for publication quality)
MAX_DEB_DEG = 15;          % discard near-singular positions [deg]

% --- Orientations ---
ori_opt  = orientations_DEB_K5;

% Fixed random set: seed 40, elevation ∈ [0,70°], azimuth ∈ [0,360°)
rng(40);
ori_rand = zeros(1, 2*K);
for i = 1:K
    ori_rand(2*i-1) = rand() * 70;
    ori_rand(2*i)   = rand() * 360;
end

fprintf('\nOptimized K=5: ');
for i=1:K, fprintf('[%.1f° %.1f°] ', ori_opt(2*i-1), ori_opt(2*i)); end
fprintf('\nRandom    K=5: ');
for i=1:K, fprintf('[%.1f° %.1f°] ', ori_rand(2*i-1), ori_rand(2*i)); end
fprintf('\n');

%% ===== GRID =====
x_range = -L/2 : step_fine : L/2;
y_range = -W/2 : step_fine : W/2;
[X_g, Y_g] = meshgrid(x_range, y_range);
X_f = X_g(:);
Y_f = Y_g(:);
Z_f = z_height * ones(size(X_f));
N_pos = numel(X_f);
fprintf('\nGrid: %d × %d = %d positions at z=%.2f m\n', ...
    numel(x_range), numel(y_range), N_pos, z_height);

%% ===== COMPUTE / LOAD DEB + PEB =====
nt_opt  = ori2nt(ori_opt,  K);
nt_rand = ori2nt(ori_rand, K);

if ~RECOMPUTE && exist(data_file, 'file')
    fprintf('Loading cached data...\n');
    load(data_file, 'DEB_opt_map','DEB_rand_map','PEB_opt_map','PEB_rand_map', ...
         'X_g','Y_g','x_range','y_range');
else
    warning('off','MATLAB:nearlySingularMatrix');
    fprintf('\nComputing DEB + PEB for 4 maps (%d positions each)...\n', N_pos);

    fprintf('  DEB optimized ... '); tic;
    deb_opt_f  = compute_bound_flat('DEB', nt_opt,  X_f, Y_f, Z_f, T, P_t, m_t, ...
                                    A_det, FOV_rad, sigma2, N_samples);
    fprintf('%.1f s\n', toc);

    fprintf('  DEB random    ... '); tic;
    deb_rand_f = compute_bound_flat('DEB', nt_rand, X_f, Y_f, Z_f, T, P_t, m_t, ...
                                    A_det, FOV_rad, sigma2, N_samples);
    fprintf('%.1f s\n', toc);

    fprintf('  PEB optimized ... '); tic;
    peb_opt_f  = compute_bound_flat('PEB', nt_opt,  X_f, Y_f, Z_f, T, P_t, m_t, ...
                                    A_det, FOV_rad, sigma2, N_samples);
    fprintf('%.1f s\n', toc);

    fprintf('  PEB random    ... '); tic;
    peb_rand_f = compute_bound_flat('PEB', nt_rand, X_f, Y_f, Z_f, T, P_t, m_t, ...
                                    A_det, FOV_rad, sigma2, N_samples);
    fprintf('%.1f s\n', toc);

    warning('on','MATLAB:nearlySingularMatrix');

    DEB_opt_map  = reshape(deb_opt_f,  size(X_g));
    DEB_rand_map = reshape(deb_rand_f, size(X_g));
    PEB_opt_map  = reshape(peb_opt_f,  size(X_g));
    PEB_rand_map = reshape(peb_rand_f, size(X_g));

    if SAVE_OUTPUT
        save(data_file, 'DEB_opt_map','DEB_rand_map','PEB_opt_map','PEB_rand_map', ...
             'X_g','Y_g','x_range','y_range');
        fprintf('Data cached: %s\n', data_file);
    end
end

% Unit conversions
DEB_opt_deg  = rad2deg(DEB_opt_map);
DEB_rand_deg = rad2deg(DEB_rand_map);
PEB_opt_cm   = PEB_opt_map  * 100;   % m → cm
PEB_rand_cm  = PEB_rand_map * 100;

%% ===== STATISTICS =====
print_stats('DEB', DEB_opt_deg,  DEB_rand_deg,  '°');
print_stats('PEB', PEB_opt_cm,   PEB_rand_cm,   'cm');

%% ===== COLOUR LIMITS =====
deb_hi = 3;    % fixed upper limit [°]
peb_hi = max(prctile(PEB_opt_cm(isfinite(PEB_opt_cm)),    99), ...
             prctile(PEB_rand_cm(isfinite(PEB_rand_cm)),   99));
cmap = parula(256);

%% ===== FIGURE 1: DEB heatmap =====
fig_deb = make_heatmap_fig(x_range, y_range, X_g, Y_g, ...
    DEB_opt_deg, DEB_rand_deg, 0, deb_hi, cmap, T, ...
    'DEB [$^\circ$]', VIEW_3D, SINGLE_COL);

%% ===== FIGURE 2: PEB heatmap (same orientations) =====
fig_peb = make_heatmap_fig(x_range, y_range, X_g, Y_g, ...
    PEB_opt_cm, PEB_rand_cm, 0, peb_hi, cmap, T, ...
    'PEB [cm]', VIEW_3D, SINGLE_COL);

%% ===== EXPORT =====
if SAVE_OUTPUT
    save_fig(fig_deb, out_dir, 'DEB_heatmap_K5');
    save_fig(fig_peb, out_dir, 'PEB_heatmap_K5');

    % Individual panels for \subfloat
    print_panel(x_range, y_range, X_g, Y_g, DEB_opt_deg,  0, deb_hi, cmap, T, ...
        'DEB [$^\circ$]', VIEW_3D, out_dir, 'DEB_heatmap_K5_optimal');
    print_panel(x_range, y_range, X_g, Y_g, DEB_rand_deg, 0, deb_hi, cmap, T, ...
        'DEB [$^\circ$]', VIEW_3D, out_dir, 'DEB_heatmap_K5_random');

    fprintf('\nAll files saved to:\n  %s\n', out_dir);
end

%% ===== LOCAL FUNCTIONS =====

function nt = ori2nt(orientations, K)
    nt = zeros(3, K);
    for i = 1:K
        th = orientations(2*i-1); ph = orientations(2*i);
        nt(:,i) = [sind(th)*cosd(ph); sind(th)*sind(ph); -cosd(th)];
    end
end

function vals = compute_bound_flat(type, nt, X_f, Y_f, Z_f, T, P_t, m_t, ...
                                    A_det, FOV_rad, sigma2, N_samples)
    N    = numel(X_f);
    vals = nan(N, 1);
    for j = 1:N
        R = [X_f(j); Y_f(j); Z_f(j)];
        if strcmp(type, 'DEB')
            v = DEB_complete(R, nt, T, P_t, m_t, A_det, 0, FOV_rad, sigma2, N_samples);
        else
            v = PEB_complete(R, nt, T, P_t, m_t, A_det, 0, FOV_rad, sigma2, N_samples);
        end
        if isfinite(v) && isreal(v) && v > 0
            vals(j) = v;
        end
    end
end

function fig = make_heatmap_fig(x_range, y_range, X_g, Y_g, ...
        map_opt, map_rand, c_lo, c_hi, cmap, T, cb_label, view3d, single_col)
    if single_col
        fig_w = 3.5;  fig_h = 5;          % IEEE single column
        nr = 2; nc = 1;
    else
        fig_w = 7.16; fig_h = 3.1;          % IEEE double column
        nr = 1; nc = 2;
    end
    fig = figure('Units','inches','Position',[0.5 0.5 fig_w fig_h],'Color','w');
    tl  = tiledlayout(nr, nc, 'TileSpacing','tight','Padding','tight');

    ax1 = nexttile(tl);
    draw_panel(ax1, x_range, y_range, X_g, Y_g, map_opt,  c_lo, c_hi, cmap, T, ...
        '(a) Optimized', cb_label, view3d, true);

    ax2 = nexttile(tl);
    draw_panel(ax2, x_range, y_range, X_g, Y_g, map_rand, c_lo, c_hi, cmap, T, ...
        '(b) Random',    cb_label, view3d, true);
end

function draw_panel(ax, x_range, y_range, X_g, Y_g, data_map, ...
        c_lo, c_hi, cmap, T, ttl, cb_label, view3d, show_cb)
    axes(ax); %#ok<LAXES>
    v = data_map(isfinite(data_map));

    % Clip values above c_hi so both panels share the same z/colour range
    data_plot = data_map;
    data_plot(data_plot > c_hi) = c_hi;

    if view3d
        surf(X_g, Y_g, data_plot, 'EdgeColor','none');
        view(45, 24);
        set(ax, 'XLim',[x_range(1), x_range(end)], ...
                'YLim',[y_range(1), y_range(end)], ...
                'ZLim',[c_lo, c_hi]);
        pbaspect(ax, [1, 1, 0.55]);
        zlabel(cb_label,'Interpreter','latex','FontSize',9);
    else
        imagesc(x_range, y_range, data_plot, [c_lo, c_hi]);
        set(ax,'YDir','normal');
        axis(ax,'equal','tight');
        hold(ax,'on');
        plot(T(1), T(2), 'w*','MarkerSize',9,'LineWidth',1.8);
        hold(ax,'off');
    end

    colormap(ax, cmap);
    clim(ax, [c_lo, c_hi]);

    set(ax,'FontName','Times New Roman','FontSize',9,'TickLabelInterpreter','latex');
    xlabel('$x$ [m]','Interpreter','latex','FontSize',10);
    ylabel('$y$ [m]','Interpreter','latex','FontSize',10);

    % Stats annotation (top-left)
    p90 = prctile(v, 90);

    % Subfigure label at bottom (IEEE style)
    text(0.5, -0.16, ttl, ...
        'Units','normalized','HorizontalAlignment','center', ...
        'Interpreter','latex','FontSize',9,'FontName','Times New Roman');

    if show_cb
        cb = colorbar(ax,'Location','eastoutside');
        cb.Label.String      = cb_label;
        cb.Label.Interpreter = 'latex';
        cb.Label.FontSize    = 9;
        set(cb,'FontName','Times New Roman','FontSize',8,'TickLabelInterpreter','latex');
    end

    % 2D top-view inset (upper-right corner) — only for 3D panels
    if view3d
        drawnow;   % flush layout so ax.Position is up to date
        ap = ax.Position;   % [left, bottom, width, height] normalised
        iw = ap(3) * 0.336;  % inset width  (0.28 × 1.2)
        ih = ap(4) * 0.336;  % inset height (0.28 × 1.2)
        ax_in = axes('Position', [ap(1)+ap(3)*0.63, ap(2)+ap(4)*0.60, iw, ih]);
        imagesc(x_range, y_range, data_plot, [c_lo, c_hi]);
        set(ax_in,'YDir','normal');
        colormap(ax_in, cmap);
        clim(ax_in, [c_lo, c_hi]);
        axis(ax_in,'equal','tight');
        set(ax_in,'XTickLabel',[],'YTickLabel',[],'FontSize',5.5, ...
            'LineWidth',0.6,'Box','on','TickLength',[0 0]);
        hold(ax_in,'on');
        plot(T(1), T(2), 'wo','MarkerSize',3,'LineWidth',0.8,'MarkerFaceColor','w');
        hold(ax_in,'off');
        axes(ax); %#ok<LAXES>  % restore focus to main axes
    end
end

function save_fig(fig, out_dir, name)
    exportgraphics(fig, fullfile(out_dir,[name,'.pdf']), ...
        'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig, fullfile(out_dir,[name,'.png']), ...
        'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig, fullfile(out_dir,[name,'.eps']), ...
        'ContentType','vector','BackgroundColor','white');
end

function print_panel(x_range, y_range, X_g, Y_g, data_map, c_lo, c_hi, cmap, T, ...
        cb_label, view3d, out_dir, fname)
    fig_p = figure('Units','inches','Position',[0.5 0.5 3.5 3.1], ...
                   'Color','w','Visible','off');
    ax = axes(fig_p);
    draw_panel(ax, x_range, y_range, X_g, Y_g, data_map, c_lo, c_hi, cmap, T, ...
        '', cb_label, view3d, true);
    exportgraphics(fig_p, fullfile(out_dir,[fname,'.png']), ...
        'Resolution',600,'BackgroundColor','white');
    close(fig_p);
end

function print_stats(bound, map_opt, map_rand, unit)
    v_o = map_opt( isfinite(map_opt));
    v_r = map_rand(isfinite(map_rand));
    fprintf('\n%s\n', repmat('=',1,56));
    fprintf('  %s Statistics            Optimized       Random\n', bound);
    fprintf('%s\n', repmat('-',1,56));
    fprintf('  Mean              %10.3f%s    %10.3f%s\n', mean(v_o),unit,  mean(v_r),unit);
    fprintf('  Median            %10.3f%s    %10.3f%s\n', median(v_o),unit,median(v_r),unit);
    fprintf('  RMS               %10.3f%s    %10.3f%s\n', sqrt(mean(v_o.^2)),unit,sqrt(mean(v_r.^2)),unit);
    fprintf('  90th pct          %10.3f%s    %10.3f%s\n', prctile(v_o,90),unit,prctile(v_r,90),unit);
    fprintf('%s\n', repmat('=',1,56));
end
