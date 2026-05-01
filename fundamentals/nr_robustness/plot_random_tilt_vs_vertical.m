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
    'nr_random_tilt_K5_M1000_Ntilt50.mat');

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
label_rt  = sprintf('Random tilt ($\\sigma$=%d°, max=%d°)', round(sigma_tilt), round(theta_max));
label_bl  = 'Tilt$=0°$ (internal baseline)';

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

xlabel('Per-position Angular RMSE [°]','Interpreter','latex','FontSize',13);
ylabel('Empirical CDF','Interpreter','latex','FontSize',13);
title(sprintf('DF Estimators: Vertical $n_r$ (—) vs Random Tilt (- -) | $K$=%d, $M$=%d', N_or, M_trials), ...
    'Interpreter','latex','FontSize',13);
legend([h1 h2 h3 h4 h5 h6 h7 h8], ...
    'GLS — vertical', 'WLS — vertical', 'NL-MLE — vertical', 'DEB — vertical', ...
    'GLS — rand. tilt', 'WLS — rand. tilt', 'NL-MLE — rand. tilt', 'DEB — rand. tilt', ...
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

    xlabel('Angular RMSE [°]','Interpreter','latex','FontSize',11);
    ylabel('Empirical CDF','Interpreter','latex','FontSize',11);
    title(method_names{k},'Interpreter','latex','FontSize',12);
    legend(ha, hb, hc, label_ref, label_rt, label_bl, ...
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

%% 8. Optional save
if save_figs
    tag = sprintf('K%d_M%d_Ntilt%d', N_or, M_trials, N_random_tilt);
    out_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
    set(fig1, 'Color', 'white'); set(fig2, 'Color', 'white');
    print(fig1, fullfile(out_dir, sprintf('rand_tilt_CDF_combined_%s.png', tag)), '-dpng', '-r300');
    print(fig2, fullfile(out_dir, sprintf('rand_tilt_CDF_permethod_%s.png', tag)), '-dpng', '-r300');
    fprintf('Figures saved to: %s\n', out_dir);
end
