%% plot_random_tilt_vs_vertical.m
% Compares DF estimator CDFs under:
%   - Vertical n_r (reference, optimal conditions, from pre-computed .mat)
%   - Random receiver tilt  (aggregated over N_random_tilt orientations)
%   - Internal tilt=0 baseline (from within the random tilt experiment, sanity check)
%
% Each method is compared against its own optimal orientation set:
%   GLS / WLS  → orientations_GLS_DF_K5_MC10  (K5_DF_MC_1000_GLS-Optimized-MC10)
%   NL-MLE / DEB → orientations_DEB_K5        (K5_DF_MC_1000_DEB-Optimized)
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

save_figs = 0;   % 1 = export PNG
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

%% 3. Metrics helper
function s = metrics(r)
    r = r(isfinite(r) & ~isnan(r));
    s.rmse  = sqrt(mean(r.^2));
    s.cdf90 = prctile(r, 90);
    s.mn    = mean(r);
end

%% 4. Shared style
color_gls = [0,      0.4470, 0.7410];
color_wls = [0.8500, 0.3250, 0.0980];
color_nl  = [0.4940, 0.1840, 0.5560];
color_deb = [0.4660, 0.6740, 0.1880];
lw_ref = 2.0;
lw_rt  = 2.0;
lw_bl  = 1.2;

label_ref = sprintf('Vertical $n_r$ (ref)');
label_rt  = sprintf('Random tilt ($\\sigma$=%d$^{\\circ}$, max=%d$^{\\circ}$)', round(sigma_tilt), round(theta_max));
label_bl  = 'Tilt $= 0^{\circ}$ (internal baseline)';

%% 5. Figure 1 — Combined CDF (8 curves, solid=ref, dashed=random tilt)
fig1 = figure('Name', 'CDF: Vertical vs Random Tilt', 'Position', [50, 80, 720, 540]);
hold on;

% Reference — solid
[f,x] = ecdf(ref_GLS);              h1 = stairs(x,f,'-',  'LineWidth',lw_ref,'Color',color_gls);
[f,x] = ecdf(ref_WLS);              h2 = stairs(x,f,'-',  'LineWidth',lw_ref,'Color',color_wls);
[f,x] = ecdf(ref_NL);               h3 = stairs(x,f,'-',  'LineWidth',lw_ref,'Color',color_nl);
ref_DEB_v = ref_DEB(~isnan(ref_DEB));
[f,x] = ecdf(ref_DEB_v);            h4 = stairs(x,f,'-',  'LineWidth',lw_ref,'Color',color_deb);

% Random tilt — dashed
[f,x] = ecdf(rt_GLS);               h5 = stairs(x,f,'--', 'LineWidth',lw_rt,'Color',color_gls);
[f,x] = ecdf(rt_WLS);               h6 = stairs(x,f,'--', 'LineWidth',lw_rt,'Color',color_wls);
[f,x] = ecdf(rt_NL);                h7 = stairs(x,f,'--', 'LineWidth',lw_rt,'Color',color_nl);
rt_DEB_v = rt_DEB(~isnan(rt_DEB));
[f,x] = ecdf(rt_DEB_v);             h8 = stairs(x,f,'--', 'LineWidth',lw_rt,'Color',color_deb);

yline(0.9,'--','LineWidth',0.8,'Color',[0.5 0.5 0.5]);

xlabel('Per-position Angular RMSE [$^{\circ}$]','Interpreter','latex','FontSize',13);
ylabel('Empirical CDF','Interpreter','latex','FontSize',13);
title(sprintf('DF Estimators: Vertical $n_r$ (--) vs Random Tilt (- -) | $K$=%d, $M$=%d', N_or, M_trials), ...
    'Interpreter','latex','FontSize',13);
legend([h1 h2 h3 h4 h5 h6 h7 h8], ...
    'GLS -- vertical', 'WLS -- vertical', 'NL-MLE -- vertical', 'DEB -- vertical', ...
    'GLS -- rand. tilt', 'WLS -- rand. tilt', 'NL-MLE -- rand. tilt', 'DEB -- rand. tilt', ...
    'Location','southeast','Interpreter','latex','FontSize',9);
grid minor; box on; hold off;

%% 6. Figure 2 — 2×2 subplots per method (ref + rand tilt + baseline sanity)
fig2 = figure('Name', 'Per-method CDF comparison', 'Position', [100, 80, 900, 700]);

method_names  = {'GLS', 'WLS', 'NL-MLE', 'DEB'};
colors        = {color_gls, color_wls, color_nl, color_deb};
ref_data      = {ref_GLS,  ref_WLS,  ref_NL,  ref_DEB};
rt_data       = {rt_GLS,   rt_WLS,   rt_NL,   rt_DEB};
bl_data       = {bl_GLS,   bl_WLS,   bl_NL,   bl_DEB};

for k = 1:4
    subplot(2, 2, k);
    hold on;

    rv = ref_data{k}; rv = rv(isfinite(rv) & ~isnan(rv));
    rr = rt_data{k};  rr = rr(isfinite(rr) & ~isnan(rr));
    rb = bl_data{k};  rb = rb(isfinite(rb) & ~isnan(rb));

    [f,x] = ecdf(rv); ha = stairs(x,f,'-',  'LineWidth',lw_ref, 'Color',colors{k});
    [f,x] = ecdf(rr); hb = stairs(x,f,'--', 'LineWidth',lw_rt,  'Color',colors{k});
    [f,x] = ecdf(rb); hc = stairs(x,f,':',  'LineWidth',lw_bl,  'Color',colors{k}*0.7);

    yline(0.9,'--','LineWidth',0.7,'Color',[0.5 0.5 0.5]);

    xlabel('Angular RMSE [$^{\circ}$]','Interpreter','latex','FontSize',11);
    ylabel('Empirical CDF','Interpreter','latex','FontSize',11);
    title(method_names{k},'Interpreter','latex','FontSize',12);
    legend([ha hb hc], {label_ref, label_rt, label_bl}, ...
        'Location','southeast','Interpreter','latex','FontSize',8);
    grid minor; box on; hold off;
end
sgtitle(sprintf('Per-method CDF: Vertical $n_r$ vs Random Tilt ($K$=%d, $M$=%d)', N_or, M_trials), ...
    'Interpreter','latex','FontSize',13);

%% 7. Console metrics table
fprintf('%s\n', repmat('=', 1, 80));
fprintf('  VERTICAL n_r vs RANDOM TILT — ANGULAR RMSE COMPARISON\n');
fprintf('  Tilt: half-normal(sigma=%.1f°), max=%.1f°, N_tilt=%d\n', sigma_tilt, theta_max, N_random_tilt);
fprintf('%s\n', repmat('=', 1, 80));
fprintf('  %-10s  %-18s  %-10s  %-10s  %-10s\n', 'Method', 'Condition', 'RMSE [°]', 'CDF90 [°]', 'Mean [°]');
fprintf('%s\n', repmat('-', 1, 80));

all_ref  = {ref_GLS,  ref_WLS,  ref_NL,  ref_DEB};
all_rt   = {rt_GLS,   rt_WLS,   rt_NL,   rt_DEB};
all_bl   = {bl_GLS,   bl_WLS,   bl_NL,   bl_DEB};

for k = 1:4
    mr = metrics(all_ref{k});
    mt = metrics(all_rt{k});
    mb = metrics(all_bl{k});
    delta = mt.rmse - mr.rmse;
    pct   = 100 * delta / mr.rmse;

    fprintf('  %-10s  %-18s  %-10.4f  %-10.4f  %-10.4f\n', method_names{k}, 'Vertical (ref)',    mr.rmse, mr.cdf90, mr.mn);
    fprintf('  %-10s  %-18s  %-10.4f  %-10.4f  %-10.4f\n', '',              'Random tilt (agg)', mt.rmse, mt.cdf90, mt.mn);
    fprintf('  %-10s  %-18s  %-10.4f  %-10.4f  %-10.4f\n', '',              'Baseline tilt=0',   mb.rmse, mb.cdf90, mb.mn);
    fprintf('  %-10s  %-18s  %+.4f° (%+.2f%%)\n',          '',              'Degradation',       delta,   pct);
    fprintf('%s\n', repmat('-', 1, 80));
end
fprintf('%s\n', repmat('=', 1, 80));

%% Fig 3: Tilt distribution — model validation
tilt_all = d_rand.tilt_mat(:);

fig3 = figure('Name', 'Tilt distribution', 'Position', [150, 80, 560, 400]);
hold on;
histogram(tilt_all, 30, 'Normalization', 'pdf', ...
    'FaceColor', [0.6 0.6 0.6], 'EdgeColor', 'none', 'FaceAlpha', 0.75);

theta_vec  = linspace(0, theta_max + 2, 400);
Z_norm     = 2 * normcdf(theta_max, 0, sigma_tilt) - 1;
pdf_th     = 2 * normpdf(theta_vec, 0, sigma_tilt) / Z_norm;
pdf_th(theta_vec > theta_max) = 0;
plot(theta_vec, pdf_th, 'k-', 'LineWidth', 2);

xline(theta_max, '--', 'LineWidth', 1.2, 'Color', [0.4 0.4 0.4]);
xlabel('Receiver Tilt $\theta$ [$^{\circ}$]', 'Interpreter', 'latex', 'FontSize', 12);
ylabel('PDF', 'Interpreter', 'latex', 'FontSize', 12);
title(sprintf('Tilt Distribution: half-normal ($\\sigma$=%d$^{\\circ}$, max=%d$^{\\circ}$, $N_{\\mathrm{tot}}$=%d)', ...
    round(sigma_tilt), round(theta_max), numel(tilt_all)), ...
    'Interpreter', 'latex', 'FontSize', 12);
legend({'Sampled (histogram)', sprintf('Theoretical PDF ($\\sigma$=%d$^{\\circ}$)', round(sigma_tilt))}, ...
    'Interpreter', 'latex', 'FontSize', 10, 'Location', 'northeast');
grid on; box on; hold off;

%% Fig 4: Mean RMSE per tilt bin — sensitivity curve (key result)
rmse_GLS_vec = d_rand.rmse_GLS_all(:);
rmse_WLS_vec = d_rand.rmse_WLS_all(:);
rmse_NL_vec  = d_rand.rmse_NL_all(:);
deb_vec      = d_rand.DEB_ang_all(:);

n_bins    = 5;
bin_edges = linspace(0, theta_max, n_bins + 1);
bin_ctr   = (bin_edges(1:end-1) + bin_edges(2:end)) / 2;

mean_GLS = zeros(n_bins,1); std_GLS = zeros(n_bins,1);
mean_WLS = zeros(n_bins,1); std_WLS = zeros(n_bins,1);
mean_NL  = zeros(n_bins,1); std_NL  = zeros(n_bins,1);
mean_DEB = zeros(n_bins,1); std_DEB = zeros(n_bins,1);
n_pts    = zeros(n_bins,1);

for b = 1:n_bins
    if b < n_bins
        mask = tilt_all >= bin_edges(b) & tilt_all < bin_edges(b+1);
    else
        mask = tilt_all >= bin_edges(b);
    end
    n_pts(b)    = sum(mask);
    mean_GLS(b) = mean(rmse_GLS_vec(mask));   std_GLS(b) = std(rmse_GLS_vec(mask));
    mean_WLS(b) = mean(rmse_WLS_vec(mask));   std_WLS(b) = std(rmse_WLS_vec(mask));
    mean_NL(b)  = mean(rmse_NL_vec(mask));    std_NL(b)  = std(rmse_NL_vec(mask));
    mean_DEB(b) = nanmean(deb_vec(mask));     std_DEB(b) = nanstd(deb_vec(mask));
end

fig4 = figure('Name', 'RMSE vs tilt bin', 'Position', [200, 80, 620, 430]);
hold on;
errorbar(bin_ctr, mean_GLS, std_GLS, '-o', 'LineWidth', 1.8, 'Color', color_gls, 'MarkerFaceColor', color_gls, 'MarkerSize', 5);
errorbar(bin_ctr, mean_WLS, std_WLS, '-s', 'LineWidth', 1.8, 'Color', color_wls, 'MarkerFaceColor', color_wls, 'MarkerSize', 5);
errorbar(bin_ctr, mean_NL,  std_NL,  '-^', 'LineWidth', 1.8, 'Color', color_nl,  'MarkerFaceColor', color_nl,  'MarkerSize', 5);
errorbar(bin_ctr, mean_DEB, std_DEB, '-d', 'LineWidth', 1.8, 'Color', color_deb, 'MarkerFaceColor', color_deb, 'MarkerSize', 5);

xticks(bin_ctr);
xticklabels(arrayfun(@(a,b) sprintf('[%d,%d)', a, b), bin_edges(1:end-1), bin_edges(2:end), 'UniformOutput', false));
xlabel('Tilt bin [$^{\circ}$]', 'Interpreter', 'latex', 'FontSize', 12);
ylabel('Mean Angular RMSE [$^{\circ}$]', 'Interpreter', 'latex', 'FontSize', 12);
title(sprintf('RMSE vs Receiver Tilt ($K$=%d, $M$=%d, $N_{\\mathrm{tilt}}$=%d)', N_or, M_trials, N_random_tilt), ...
    'Interpreter', 'latex', 'FontSize', 12);
legend({'GLS', 'WLS', 'NL-MLE', 'DEB'}, ...
    'Interpreter', 'latex', 'FontSize', 11, 'Location', 'northwest');
grid on; box on; hold off;

%% Fig 5: Spatial RMSE degradation map (floor level, z = min)
X_r_d = d_rand.X_r;
Y_r_d = d_rand.Y_r;
Z_r_d = d_rand.Z_r;

z_min     = min(Z_r_d);
floor_idx = abs(Z_r_d - z_min) < 1e-6;
x_f = X_r_d(floor_idx);
y_f = Y_r_d(floor_idx);

deg_GLS_f = (d_rand.rmse_GLS_agg(floor_idx) - d_rand.rmse_GLS_baseline(floor_idx));
deg_DEB_f = (d_rand.DEB_ang_agg(floor_idx)  - d_rand.DEB_ang_baseline(floor_idx));

xi = linspace(min(x_f), max(x_f), 60);
yi = linspace(min(y_f), max(y_f), 60);
[XI, YI] = meshgrid(xi, yi);

ZI_GLS = griddata(x_f, y_f, deg_GLS_f, XI, YI, 'linear');
ZI_DEB = griddata(x_f, y_f, deg_DEB_f, XI, YI, 'linear');

fig5 = figure('Name', 'Spatial degradation map', 'Position', [250, 80, 900, 380]);

subplot(1, 2, 1);
imagesc(xi, yi, ZI_GLS);
axis xy equal tight;
colorbar; colormap(gca, 'hot');
xlabel('$x$ [m]', 'Interpreter', 'latex', 'FontSize', 11);
ylabel('$y$ [m]', 'Interpreter', 'latex', 'FontSize', 11);
title('$\Delta$ RMSE: GLS (rand.tilt $-$ baseline)', 'Interpreter', 'latex', 'FontSize', 11);
clim_max = max(abs(ZI_GLS(:)), [], 'omitnan');
clim([0, clim_max]);

subplot(1, 2, 2);
imagesc(xi, yi, ZI_DEB);
axis xy equal tight;
colorbar; colormap(gca, 'hot');
xlabel('$x$ [m]', 'Interpreter', 'latex', 'FontSize', 11);
ylabel('$y$ [m]', 'Interpreter', 'latex', 'FontSize', 11);
title('$\Delta$ RMSE: DEB (rand.tilt $-$ baseline)', 'Interpreter', 'latex', 'FontSize', 11);
clim_max2 = max(abs(ZI_DEB(:)), [], 'omitnan');
clim([0, max(clim_max2, 0.01)]);

sgtitle(sprintf('Spatial Degradation Map (floor $z$=%.1f m, $\\sigma$=%d$^{\\circ}$, max=%d$^{\\circ}$)', ...
    z_min, round(sigma_tilt), round(theta_max)), 'Interpreter', 'latex', 'FontSize', 12);

%% Fig 6: Grouped bar chart — global RMSE summary
mets_ref = [sqrt(mean(ref_GLS.^2)), sqrt(mean(ref_WLS.^2)), ...
            sqrt(nanmean(ref_NL.^2)), sqrt(nanmean(ref_DEB.^2))];
mets_rt  = [sqrt(mean(rt_GLS.^2)),  sqrt(mean(rt_WLS.^2)), ...
            sqrt(nanmean(rt_NL.^2)), sqrt(nanmean(rt_DEB.^2))];
mets_bl  = [sqrt(mean(bl_GLS.^2)),  sqrt(mean(bl_WLS.^2)), ...
            sqrt(nanmean(bl_NL.^2)), sqrt(nanmean(bl_DEB.^2))];

fig6 = figure('Name', 'Global RMSE bar chart', 'Position', [300, 80, 580, 420]);
hold on;
X_grp = categorical({'GLS','WLS','NL-MLE','DEB'});
X_grp = reordercats(X_grp, {'GLS','WLS','NL-MLE','DEB'});
bar_data = [mets_ref; mets_rt; mets_bl]';

b = bar(X_grp, bar_data, 'grouped');
b(1).FaceColor = [0.85 0.85 0.85];
b(2).FaceColor = [0.35 0.35 0.35];
b(3).FaceColor = [0.60 0.60 0.60];
b(1).EdgeColor = 'none';
b(2).EdgeColor = 'none';
b(3).EdgeColor = 'none';

ylabel('Global Angular RMSE [$^{\circ}$]', 'Interpreter', 'latex', 'FontSize', 12);
title(sprintf('Global RMSE: Vertical vs Random Tilt ($K$=%d, $M$=%d)', N_or, M_trials), ...
    'Interpreter', 'latex', 'FontSize', 12);
legend({'Vertical $n_r$ (ref)', ...
        sprintf('Random tilt ($\\sigma$=%d$^{\\circ}$)', round(sigma_tilt)), ...
        'Tilt $=0^{\circ}$ (baseline)'}, ...
    'Interpreter', 'latex', 'FontSize', 10, 'Location', 'northwest');
grid on; box on; hold off;

%% 8. Optional save
if save_figs
    tag = sprintf('K%d_M%d_Ntilt%d_sig%d_max%d', N_or, M_trials, N_random_tilt, round(sigma_tilt), round(theta_max));
    out_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
    figs = {fig1, fig2, fig3, fig4, fig5, fig6};
    names = {'CDF_combined', 'CDF_permethod', 'tilt_distribution', 'RMSE_vs_tilt', 'spatial_degradation', 'bar_summary'};
    for fi = 1:numel(figs)
        set(figs{fi}, 'Color', 'white');
        print(figs{fi}, fullfile(out_dir, sprintf('%s_%s.png', names{fi}, tag)), '-dpng', '-r300');
    end
    fprintf('Figures saved to: %s\n', out_dir);
end
