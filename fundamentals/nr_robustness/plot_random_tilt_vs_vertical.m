%% plot_random_tilt_vs_vertical.m
% Compares DF estimator CDFs under:
%   - Vertical n_r (reference, optimal conditions, from pre-computed .mat)
%   - Random receiver tilt  (aggregated over N_random_tilt orientations)
%   - Internal tilt=0 baseline (from within the random tilt experiment, sanity check)
%
% Each method is compared against its own optimal orientation set:
%   GLS / WLS  → orientations_GLS_DF_K5_MC10  (K5_DF_MC_1000_GLS-Optimized-MC10)
%   NLS / DEB → orientations_DEB_K5        (K5_DF_MC_1000_DEB-Optimized)
%
% Figures:
%   Fig 1 — Combined CDF (8 curves): solid = vertical, dashed = random tilt
%   Fig 2 — 2×2 subplots per method: adds dotted = tilt=0 baseline (sanity)
%   Console — Metrics table + degradation percentages
%
% Author: Kevin Acuña

close all; clear variables; clc;

% =========================================================================
% FILE PATHS
% =========================================================================
% Random tilt experiment (full workspace save)
file_rand = fullfile(fileparts(mfilename('fullpath')), 'results', ...
    'nr_random_tilt_K5_M1000_Ntilt100_sig5_max30.mat');

% Reference: vertical n_r, GLS/WLS orientations
ref_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'estimators', 'results');
file_gls_ref = fullfile(ref_dir, 'K5_DF_MC_1000_GLS-Optimized-MC10', 'K5_DF_MC_results.mat');

% Reference: vertical n_r, NL/DEB orientations
file_deb_ref = fullfile(ref_dir, 'K5_DF_MC_1000_DEB-Optimized', 'K5_DF_MC_results.mat');

save_figs = 1;   % 1 = export PNG
% =========================================================================

%% 1. Load data
fprintf('Loading files...\n');
d_rand     = load(file_rand);
d_gls_ref  = load(file_gls_ref);
d_deb_ref  = load(file_deb_ref);
fprintf('  Random tilt : %s\n', file_rand);
fprintf('  GLS/WLS ref : %s\n', file_gls_ref);
fprintf('  NL/DEB  ref : %s\n', file_deb_ref);

%% 2. Extract vectors
% --- Vertical n_r reference (each method with its optimal set) ---
ref_GLS = d_gls_ref.rmse_ang_GLS_pos;
ref_WLS = d_gls_ref.rmse_ang_WLS_pos;
ref_NL  = d_deb_ref.rmse_ang_NL_pos;
ref_DEB = d_deb_ref.DEB_ang_pos;

% --- Random tilt (aggregated over N_random_tilt tilts) ---
rt_GLS  = d_rand.rmse_GLS_agg;
rt_WLS  = d_rand.rmse_WLS_agg;
rt_NL   = d_rand.rmse_NL_agg;
rt_DEB  = d_rand.DEB_ang_agg;

% --- Tilt=0 baseline from within random tilt experiment (sanity check) ---
bl_GLS  = d_rand.rmse_GLS_baseline;
bl_WLS  = d_rand.rmse_WLS_baseline;
bl_NL   = d_rand.rmse_NL_baseline;
bl_DEB  = d_rand.DEB_ang_baseline;

% Metadata
N_or         = d_rand.N_or;
M_trials     = d_rand.M_trials;
N_random_tilt = d_rand.N_random_tilt;
sigma_tilt   = d_rand.sigma_tilt;
theta_max    = d_rand.theta_max_tilt;

fprintf('\nParameters — K=%d, M=%d, N_tilt=%d, sigma=%.1f°, max=%.1f°\n', ...
    N_or, M_trials, N_random_tilt, sigma_tilt, theta_max);
fprintf('Positions  — Ref(GLS): %d | Ref(DEB): %d | RandTilt: %d\n\n', ...
    length(ref_GLS), length(ref_NL), length(rt_GLS));

%% 3. Output directory and styling
out_dir = fullfile(fileparts(mfilename('fullpath')), 'outputs');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
tag = sprintf('K%d_M%d_Ntilt%d_sig%d_max%d', ...
    N_or, M_trials, N_random_tilt, round(sigma_tilt), round(theta_max));

% Colours and markers (B/W friendly: distinct marker per method)
color_gls = [0.000, 0.447, 0.741];   mk_gls = 'o';
color_wls = [0.850, 0.325, 0.098];   mk_wls = 's';
color_nl  = [0.494, 0.184, 0.556];   mk_nl  = '^';
color_deb = [0.466, 0.674, 0.188];   mk_deb = 'd';

method_names = {'GLS', 'WLS', 'NLS', 'DEB'};
method_cols  = {color_gls, color_wls, color_nl, color_deb};
method_mks   = {mk_gls, mk_wls, mk_nl, mk_deb};

% IEEE TCOM common axes formatting
ax_fmt = {'FontName','Times New Roman','FontSize',9, ...
          'TickLabelInterpreter','latex','LineWidth',0.8,'Box','on', ...
          'GridLineStyle',':','GridAlpha',0.30, ...
          'MinorGridLineStyle',':','MinorGridAlpha',0.10};

%% 4. Console metrics table
fprintf('%s\n', repmat('=', 1, 80));
fprintf('  VERTICAL n_r vs RANDOM TILT — ANGULAR RMSE COMPARISON\n');
fprintf('  Tilt: half-normal(sigma=%.1f°), max=%.1f°, N_tilt=%d\n', sigma_tilt, theta_max, N_random_tilt);
fprintf('%s\n', repmat('=', 1, 80));
fprintf('  %-10s  %-18s  %-10s  %-10s  %-10s\n', 'Method', 'Condition', 'RMSE [°]', 'CDF90 [°]', 'Mean [°]');
fprintf('%s\n', repmat('-', 1, 80));

all_ref = {ref_GLS, ref_WLS, ref_NL, ref_DEB};
all_rt  = {rt_GLS,  rt_WLS,  rt_NL,  rt_DEB};
all_bl  = {bl_GLS,  bl_WLS,  bl_NL,  bl_DEB};

for k = 1:4
    mr = local_metrics(all_ref{k});
    mt = local_metrics(all_rt{k});
    mb = local_metrics(all_bl{k});
    delta = mt.rmse - mr.rmse;
    pct   = 100 * delta / mr.rmse;
    fprintf('  %-10s  %-18s  %-10.4f  %-10.4f  %-10.4f\n', method_names{k}, 'Vertical (ref)',    mr.rmse, mr.cdf90, mr.mn);
    fprintf('  %-10s  %-18s  %-10.4f  %-10.4f  %-10.4f\n', '',              'Random tilt (agg)', mt.rmse, mt.cdf90, mt.mn);
    fprintf('  %-10s  %-18s  %-10.4f  %-10.4f  %-10.4f\n', '',              'Baseline tilt=0',   mb.rmse, mb.cdf90, mb.mn);
    fprintf('  %-10s  %-18s  %+.4f° (%+.2f%%)\n',          '',              'Degradation',       delta,   pct);
    fprintf('%s\n', repmat('-', 1, 80));
end

%% =====================================================================
%% Figure 1 — CDF: Vertical n_r vs Random Tilt (with tilt PDF inset)
% Main panel: empirical CDFs per method (solid=vertical, dashed=random tilt).
% Inset: truncated half-normal tilt distribution applied in the experiment.
%% =====================================================================
fig1 = figure('Units','inches','Position',[1 1 5.0*0.8 3.4*0.8],'Color','w');
ax_main = axes('Position',[0.105 0.135 0.875 0.83]);
hold(ax_main,'on');

% --- Main panel: ECDFs ---
% Vertical (solid)
h_vert = gobjects(4,1);
h_tilt = gobjects(4,1);
ref_data = {ref_GLS, ref_WLS, ref_NL, ref_DEB};
rt_data  = {rt_GLS,  rt_WLS,  rt_NL,  rt_DEB};
for k = 1:4
    rv = ref_data{k}; rv = rv(isfinite(rv) & ~isnan(rv));
    rt = rt_data{k};  rt = rt(isfinite(rt) & ~isnan(rt));
    [fv,xv] = ecdf(rv);  [ft,xt] = ecdf(rt);
    h_vert(k) = stairs(ax_main, xv, fv, '-',  'Color', method_cols{k}, 'LineWidth', 0.75);
    h_tilt(k) = stairs(ax_main, xt, ft, '--', 'Color', method_cols{k}, 'LineWidth', 1.5);
end
yline(ax_main, 0.9, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility','off');

xlabel(ax_main,'Per-position angular RMSE [$^{\circ}$]','Interpreter','latex','FontSize',10);
ylabel(ax_main,'Empirical CDF','Interpreter','latex','FontSize',10);
set(ax_main, ax_fmt{:});
grid(ax_main,'on'); grid(ax_main,'minor');
xlim(ax_main, [0, 4]);
ylim(ax_main, [0, 1.02]);

% --- Custom legend (3 columns: methods + 2 conditions) ---
hp_GLS = plot(ax_main, NaN, NaN, '-', 'Color', color_gls, 'LineWidth', 1.4);
hp_WLS = plot(ax_main, NaN, NaN, '-', 'Color', color_wls, 'LineWidth', 1.4);
hp_NL  = plot(ax_main, NaN, NaN, '-', 'Color', color_nl,  'LineWidth', 1.4);
hp_DEB = plot(ax_main, NaN, NaN, '-', 'Color', color_deb, 'LineWidth', 1.4);
hp_v   = plot(ax_main, NaN, NaN, '-',  'Color', [0.3 0.3 0.3], 'LineWidth', 1.4);
hp_t   = plot(ax_main, NaN, NaN, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.4);

lg = legend([hp_GLS, hp_v, hp_WLS, hp_t, hp_NL, hp_DEB], ...
    {'GLS', 'Vertical $n_r$', 'WLS', 'Random tilt', 'NLS', 'DEB'}, ...
    'Interpreter','latex','FontSize',7,'NumColumns',3, ...
    'Location','southeast','Box','on');
lg.ItemTokenSize = [12, 12];



% --- Tilt PDF inset (top-right of CDF plot) ---
% Visualises the random-tilt distribution that produced the "Random tilt"
% curves in the main panel (input side of the experiment).
ax_pdf = axes('Position',[0.62 0.45 0.27*1.2 0.33*1.2]);
hold(ax_pdf,'on');

tilt_all_inset = d_rand.tilt_mat(:);
histogram(ax_pdf, tilt_all_inset, 25, 'Normalization','pdf', ...
    'FaceColor',[0.55 0.55 0.55],'EdgeColor','none','FaceAlpha',0.65);

theta_vec_inset = linspace(0, theta_max + 2, 400);
Z_norm_inset    = 2 * normcdf(theta_max, 0, sigma_tilt) - 1;
pdf_th_inset    = 2 * normpdf(theta_vec_inset, 0, sigma_tilt) / Z_norm_inset;
pdf_th_inset(theta_vec_inset > theta_max) = 0;
plot(ax_pdf, theta_vec_inset, pdf_th_inset, 'k--', 'LineWidth', 0.8);

xline(ax_pdf, sigma_tilt, ':',  'Color', [0.20 0.20 0.20], 'LineWidth', 0.7, 'HandleVisibility','off');
xline(ax_pdf, theta_max,  '--', 'Color', [0.40 0.40 0.40], 'LineWidth', 0.8, 'HandleVisibility','off');

xlabel(ax_pdf, sprintf('Tilt [$^{\\circ}$]'), 'Interpreter','latex','FontSize',7);
ylabel(ax_pdf, 'PDF', 'Interpreter','latex','FontSize',7);
title(ax_pdf, 'Tilt distribution', 'Interpreter','latex','FontSize',8);
set(ax_pdf, ax_fmt{:});
set(ax_pdf, 'FontSize', 7);
xlim(ax_pdf, [0, theta_max + 2]);
grid(ax_pdf,'on');
hold(ax_pdf,'off');

hold(ax_main,'off');

%% =====================================================================
%% Figure 3 — Tilt distribution (model validation)
%% =====================================================================
tilt_all = d_rand.tilt_mat(:);

fig3 = figure('Units','inches','Position',[1 1 3.5 2.6],'Color','w');
ax3 = axes(fig3);
hold(ax3,'on');

histogram(ax3, tilt_all, 30, 'Normalization','pdf', ...
    'FaceColor',[0.55 0.55 0.55],'EdgeColor','none','FaceAlpha',0.70);

theta_vec = linspace(0, theta_max + 2, 500);
Z_norm    = 2 * normcdf(theta_max, 0, sigma_tilt) - 1;
pdf_th    = 2 * normpdf(theta_vec, 0, sigma_tilt) / Z_norm;
pdf_th(theta_vec > theta_max) = 0;
plot(ax3, theta_vec, pdf_th, 'k-', 'LineWidth', 1.6);

xline(ax3, sigma_tilt, ':', 'LineWidth', 0.9, 'Color', [0.20 0.20 0.20], ...
    'Label', sprintf('$\\sigma=%d^{\\circ}$',round(sigma_tilt)), ...
    'LabelOrientation','horizontal','LabelVerticalAlignment','top', ...
    'Interpreter','latex','FontSize',8);
xline(ax3, theta_max, '--', 'LineWidth', 1.0, 'Color', [0.40 0.40 0.40], ...
    'Label', sprintf('$\\theta_{\\max}=%d^{\\circ}$',round(theta_max)), ...
    'LabelOrientation','horizontal','LabelVerticalAlignment','top', ...
    'Interpreter','latex','FontSize',8);

xlabel(ax3, 'Receiver tilt $\theta$ [$^{\circ}$]', 'Interpreter','latex','FontSize',10);
ylabel(ax3, 'PDF', 'Interpreter','latex','FontSize',10);
legend(ax3, {sprintf('Sampled ($N=%d$)',numel(tilt_all)), ...
             'Half-normal model'}, ...
    'Interpreter','latex','FontSize',8,'Location','northeast','Box','on');
set(ax3, ax_fmt{:});
grid(ax3,'on');
xlim(ax3, [0, theta_max + 2]);
hold(ax3,'off');

%% =====================================================================
%% Figure 5 — Spatial RMSE degradation map at floor level
% Two panels: GLS (estimator) and DEB (analytical bound), shared diverging
% colormap centred at 0 so over- and under-estimation are equally visible.
%% =====================================================================
X_r_d = d_rand.X_r;  Y_r_d = d_rand.Y_r;  Z_r_d = d_rand.Z_r;
z_min     = min(Z_r_d);
floor_idx = abs(Z_r_d - z_min) < 1e-6;
x_f = X_r_d(floor_idx);
y_f = Y_r_d(floor_idx);

deg_GLS_f = d_rand.rmse_GLS_agg(floor_idx) - d_rand.rmse_GLS_baseline(floor_idx);
deg_DEB_f = d_rand.DEB_ang_agg(floor_idx)  - d_rand.DEB_ang_baseline(floor_idx);

xi = linspace(min(x_f), max(x_f), 80);
yi = linspace(min(y_f), max(y_f), 80);
[XI, YI] = meshgrid(xi, yi);
ZI_GLS = griddata(x_f, y_f, deg_GLS_f, XI, YI, 'linear');
ZI_DEB = griddata(x_f, y_f, deg_DEB_f, XI, YI, 'linear');

% Shared symmetric colour limits (diverging map) — centred at 0
vmax = max([max(abs(ZI_GLS(:)),[],'omitnan'), ...
            max(abs(ZI_DEB(:)),[],'omitnan'), 1e-3]);

fig5 = figure('Units','inches','Position',[1 1 7.0 3.0],'Color','w');
tl = tiledlayout(fig5, 1, 2, 'TileSpacing','compact','Padding','compact');

ax5a = nexttile(tl, 1);
imagesc(ax5a, xi, yi, ZI_GLS);
axis(ax5a,'xy'); axis(ax5a,'equal'); axis(ax5a,'tight');
colormap(ax5a, redblue_div(256));
clim(ax5a, [-vmax, vmax]);
hold(ax5a,'on');
plot(ax5a, 0, 0, 'kp', 'MarkerSize', 9, 'MarkerFaceColor', [1 0.85 0]);
hold(ax5a,'off');
xlabel(ax5a,'$x$ [m]','Interpreter','latex','FontSize',9);
ylabel(ax5a,'$y$ [m]','Interpreter','latex','FontSize',9);
title(ax5a,'(a) GLS  $\Delta$RMSE','Interpreter','latex','FontSize',10);
set(ax5a, ax_fmt{:});

ax5b = nexttile(tl, 2);
imagesc(ax5b, xi, yi, ZI_DEB);
axis(ax5b,'xy'); axis(ax5b,'equal'); axis(ax5b,'tight');
colormap(ax5b, redblue_div(256));
clim(ax5b, [-vmax, vmax]);
hold(ax5b,'on');
plot(ax5b, 0, 0, 'kp', 'MarkerSize', 9, 'MarkerFaceColor', [1 0.85 0]);
hold(ax5b,'off');
xlabel(ax5b,'$x$ [m]','Interpreter','latex','FontSize',9);
title(ax5b,'(b) DEB  $\Delta$bound','Interpreter','latex','FontSize',10);
set(ax5b, ax_fmt{:});

cb = colorbar(ax5b);
cb.Layout.Tile = 'east';
cb.Label.String = '$\Delta$RMSE [$^{\circ}$] (tilt $-$ baseline)';
cb.Label.Interpreter = 'latex';
cb.Label.FontSize = 9;
cb.TickLabelInterpreter = 'latex';

%% =====================================================================
%% Export
%% =====================================================================
if save_figs
    figs  = {fig1, fig3, fig5};
    names = {'NR_robust_CDF', 'NR_tilt_distribution', 'NR_spatial_degradation'};
    for fi = 1:numel(figs)
        base = fullfile(out_dir, sprintf('%s_%s', names{fi}, tag));
        exportgraphics(figs{fi}, [base,'.pdf'], 'ContentType','vector','BackgroundColor','white');
        exportgraphics(figs{fi}, [base,'.png'], 'Resolution',600,'BackgroundColor','white');
        exportgraphics(figs{fi}, [base,'.eps'], 'ContentType','vector','BackgroundColor','white');
    end
    fprintf('\nFigures exported to: %s\n', out_dir);
end

%% =====================================================================
%% Local functions (must be at the END of a script)
%% =====================================================================
function s = local_metrics(r)
    r = r(isfinite(r) & ~isnan(r));
    s.rmse  = sqrt(mean(r.^2));
    s.cdf90 = prctile(r, 90);
    s.mn    = mean(r);
end

function cmap = redblue_div(n)
    % Diverging blue-white-red colormap (no toolbox dependency)
    if nargin < 1, n = 256; end
    half = floor(n/2);
    blue = [linspace(0.13, 1, half).', linspace(0.30, 1, half).', linspace(0.55, 1, half).'];
    red  = [linspace(1, 0.70, n-half).', linspace(1, 0.10, n-half).', linspace(1, 0.10, n-half).'];
    cmap = [blue; red];
end
