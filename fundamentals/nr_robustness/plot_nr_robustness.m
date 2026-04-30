%% plot_nr_robustness.m
% Loads nr_robustness_K*_M*.mat and generates publication-quality figures
% demonstrating n_r-agnosticism of ratio-based DF estimators.
%
% Figures produced:
%   Fig 1 - RMSE vs receiver tilt angle (main result)
%           GLS/WLS/NL-MLE should be nearly flat; DEB varies.
%   Fig 2 - CDF overlay for selected tilts (GLS only)
%           Curves should overlap if GLS is truly n_r-agnostic.
%   Fig 3 - CDF overlay at extreme tilts (all methods)
%           Solid = 0°, dashed = max tilt.
%
% All metrics use the COMMON COVERAGE set (positions valid for ALL tilts)
% to isolate the n_r effect from coverage changes.
%
% Author: Kevin Acuña

close all; clear variables; clc;

% =========================================================================
% HYPERPARAMETERS
% =========================================================================
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
mat_file    = fullfile(results_dir, 'nr_robustness_K5_M1000.mat');

save_figs   = 0;   % 1 = export as PNG
% =========================================================================

%% 1. Load data
d = load(mat_file);
all_results  = d.all_results;
tilt_angles  = d.tilt_angles;
common_cov   = d.common_cov;
N_or         = d.N_or;
M_trials     = d.M_trials;
N_tilts      = length(tilt_angles);
n_common     = sum(common_cov);

fprintf('Loaded: %s\n', mat_file);
fprintf('K=%d, M=%d, %d tilts, %d common-coverage positions\n\n', ...
    N_or, M_trials, N_tilts, n_common);

%% 2. Extract metrics per tilt (common coverage only)
rmse_GLS_vs_tilt = zeros(N_tilts, 1);
rmse_WLS_vs_tilt = zeros(N_tilts, 1);
rmse_NL_vs_tilt  = zeros(N_tilts, 1);
rmse_DEB_vs_tilt = zeros(N_tilts, 1);

med_GLS_vs_tilt  = zeros(N_tilts, 1);
med_WLS_vs_tilt  = zeros(N_tilts, 1);
med_NL_vs_tilt   = zeros(N_tilts, 1);
med_DEB_vs_tilt  = zeros(N_tilts, 1);

cdf90_GLS_vs_tilt = zeros(N_tilts, 1);
cdf90_WLS_vs_tilt = zeros(N_tilts, 1);
cdf90_NL_vs_tilt  = zeros(N_tilts, 1);
cdf90_DEB_vs_tilt = zeros(N_tilts, 1);

for i = 1:N_tilts
    g = all_results(i).rmse_ang_GLS(common_cov);
    w = all_results(i).rmse_ang_WLS(common_cov);
    n = all_results(i).rmse_ang_NL(common_cov);
    b = all_results(i).DEB_ang(common_cov);

    rmse_GLS_vs_tilt(i) = sqrt(mean(g.^2));
    rmse_WLS_vs_tilt(i) = sqrt(mean(w.^2));
    rmse_NL_vs_tilt(i)  = sqrt(mean(n.^2));
    rmse_DEB_vs_tilt(i) = sqrt(nanmean(b.^2));

    med_GLS_vs_tilt(i)  = median(g);
    med_WLS_vs_tilt(i)  = median(w);
    med_NL_vs_tilt(i)   = median(n);
    med_DEB_vs_tilt(i)  = nanmedian(b);

    cdf90_GLS_vs_tilt(i) = prctile(g, 90);
    cdf90_WLS_vs_tilt(i) = prctile(w, 90);
    cdf90_NL_vs_tilt(i)  = prctile(n, 90);
    cdf90_DEB_vs_tilt(i) = prctile(b(~isnan(b)), 90);
end

%% 3. Shared colors
color_gls = [0,      0.4470, 0.7410];
color_wls = [0.8500, 0.3250, 0.0980];
color_nl  = [0.4940, 0.1840, 0.5560];
color_deb = [0.4660, 0.6740, 0.1880];
lw = 1.8;
ms = 7;

%% 4. Figure 1 — RMSE vs Receiver Tilt Angle (main result)
fig1 = figure('Name', 'RMSE vs Tilt', 'Position', [50, 100, 640, 480]);
hold on;
plot(tilt_angles, rmse_GLS_vs_tilt, '-o', 'Color', color_gls, 'LineWidth', lw, 'MarkerSize', ms, 'MarkerFaceColor', color_gls);
plot(tilt_angles, rmse_WLS_vs_tilt, '-s', 'Color', color_wls, 'LineWidth', lw, 'MarkerSize', ms, 'MarkerFaceColor', color_wls);
plot(tilt_angles, rmse_NL_vs_tilt,  '-d', 'Color', color_nl,  'LineWidth', lw, 'MarkerSize', ms, 'MarkerFaceColor', color_nl);
plot(tilt_angles, rmse_DEB_vs_tilt, '-^', 'Color', color_deb, 'LineWidth', lw, 'MarkerSize', ms, 'MarkerFaceColor', color_deb);

xlabel('Receiver Tilt Angle $\theta_{\mathrm{tilt}}$ [deg]', 'Interpreter', 'latex', 'FontSize', 13);
ylabel('Global Angular RMSE [deg]', 'Interpreter', 'latex', 'FontSize', 13);
legend('GLS', 'WLS', 'NL-MLE', 'DEB', ...
    'Location', 'best', 'Interpreter', 'latex', 'FontSize', 11);
title(sprintf('DF Robustness to Receiver Tilt ($K$=%d, $M$=%d, %d positions)', ...
    N_or, M_trials, n_common), 'Interpreter', 'latex', 'FontSize', 14);
xticks(tilt_angles);
grid on; box on;
hold off;

%% 5. Figure 2 — CDF overlay for selected tilts (GLS only)
% Select three representative tilts: 0°, middle, max
sel_idx = [1, ceil(N_tilts/2), N_tilts];
sel_colors = {[0, 0.4, 0.8], [0.9, 0.5, 0.1], [0.7, 0.1, 0.1]};

fig2 = figure('Name', 'CDF GLS vs Tilt', 'Position', [100, 100, 640, 480]);
hold on;
leg_str = {};
for k = 1:length(sel_idx)
    idx = sel_idx(k);
    g = all_results(idx).rmse_ang_GLS(common_cov);
    [f, x] = ecdf(g);
    stairs(x, f, '-', 'LineWidth', lw, 'Color', sel_colors{k});
    leg_str{end+1} = sprintf('$\\theta_{\\mathrm{tilt}} = %d^\\circ$', tilt_angles(idx));
end
yline(0.9, '--', 'LineWidth', 0.8, 'Color', [0.5 0.5 0.5]);

xlabel('Per-position Angular RMSE [deg]', 'Interpreter', 'latex', 'FontSize', 13);
ylabel('Empirical CDF', 'Interpreter', 'latex', 'FontSize', 13);
legend(leg_str, 'Location', 'southeast', 'Interpreter', 'latex', 'FontSize', 11);
title(sprintf('CDF of GLS Angular RMSE at Different Tilts ($K$=%d)', N_or), ...
    'Interpreter', 'latex', 'FontSize', 14);
grid minor; box on;
hold off;

%% 6. Figure 3 — All methods at extreme tilts (0° solid, max° dashed)
idx_0   = 1;
idx_max = N_tilts;
theta_max = tilt_angles(idx_max);

fig3 = figure('Name', 'CDF All Methods Extreme Tilts', 'Position', [150, 100, 700, 520]);
hold on;

% Tilt = 0° (solid)
[f,x] = ecdf(all_results(idx_0).rmse_ang_GLS(common_cov)); h1 = stairs(x,f,'-',  'LineWidth', lw,   'Color', color_gls);
[f,x] = ecdf(all_results(idx_0).rmse_ang_WLS(common_cov)); h2 = stairs(x,f,'-',  'LineWidth', lw,   'Color', color_wls);
[f,x] = ecdf(all_results(idx_0).rmse_ang_NL(common_cov));  h3 = stairs(x,f,'-',  'LineWidth', lw,   'Color', color_nl);
deb0 = all_results(idx_0).DEB_ang(common_cov); deb0 = deb0(~isnan(deb0));
[f,x] = ecdf(deb0); h4 = stairs(x,f,'-',  'LineWidth', lw,   'Color', color_deb);

% Tilt = max° (dashed)
[f,x] = ecdf(all_results(idx_max).rmse_ang_GLS(common_cov)); h5 = stairs(x,f,'--', 'LineWidth', lw+0.3, 'Color', color_gls);
[f,x] = ecdf(all_results(idx_max).rmse_ang_WLS(common_cov)); h6 = stairs(x,f,'--', 'LineWidth', lw+0.3, 'Color', color_wls);
[f,x] = ecdf(all_results(idx_max).rmse_ang_NL(common_cov));  h7 = stairs(x,f,'--', 'LineWidth', lw+0.3, 'Color', color_nl);
debM = all_results(idx_max).DEB_ang(common_cov); debM = debM(~isnan(debM));
[f,x] = ecdf(debM); h8 = stairs(x,f,'--', 'LineWidth', lw+0.3, 'Color', color_deb);

yline(0.9, '--', 'LineWidth', 0.8, 'Color', [0.5 0.5 0.5]);

xlabel('Per-position Angular RMSE [deg]', 'Interpreter', 'latex', 'FontSize', 13);
ylabel('Empirical CDF', 'Interpreter', 'latex', 'FontSize', 13);
legend([h1 h2 h3 h4 h5 h6 h7 h8], ...
    sprintf('GLS ($%d^\\circ$)',    0), ...
    sprintf('WLS ($%d^\\circ$)',    0), ...
    sprintf('NL-MLE ($%d^\\circ$)', 0), ...
    sprintf('DEB ($%d^\\circ$)',    0), ...
    sprintf('GLS ($%d^\\circ$)',    theta_max), ...
    sprintf('WLS ($%d^\\circ$)',    theta_max), ...
    sprintf('NL-MLE ($%d^\\circ$)', theta_max), ...
    sprintf('DEB ($%d^\\circ$)',    theta_max), ...
    'Location', 'southeast', 'Interpreter', 'latex', 'FontSize', 9);
title(sprintf('CDF: $\\theta_{\\mathrm{tilt}}=0^\\circ$ (solid) vs $%d^\\circ$ (dashed), $K$=%d', ...
    theta_max, N_or), 'Interpreter', 'latex', 'FontSize', 14);
grid minor; box on;
hold off;

%% 7. Metrics table
fprintf('\n%s\n', repmat('=', 1, 80));
fprintf('  n_r ROBUSTNESS — COMMON COVERAGE METRICS (%d positions)\n', n_common);
fprintf('%s\n', repmat('=', 1, 80));
fprintf('  %-8s  %-10s  %-10s  %-10s  %-10s  %-10s  %-10s\n', ...
    'Tilt', 'GLS RMSE', 'WLS RMSE', 'NL RMSE', 'DEB RMSE', 'GLS CDF90', 'Coverage');
fprintf('%s\n', repmat('-', 1, 80));
for i = 1:N_tilts
    n_cov_i = sum(all_results(i).coverage);
    fprintf('  %-8s  %-10.4f  %-10.4f  %-10.4f  %-10.4f  %-10.4f  %d/%d\n', ...
        sprintf('%d°', tilt_angles(i)), ...
        rmse_GLS_vs_tilt(i), rmse_WLS_vs_tilt(i), rmse_NL_vs_tilt(i), ...
        rmse_DEB_vs_tilt(i), cdf90_GLS_vs_tilt(i), n_cov_i, length(common_cov));
end
fprintf('%s\n', repmat('=', 1, 80));

% Relative change from 0° to max tilt
fprintf('\n  Relative change (0° → %d°):\n', tilt_angles(end));
fprintf('    GLS  RMSE: %.2f%%\n', 100*(rmse_GLS_vs_tilt(end)-rmse_GLS_vs_tilt(1))/rmse_GLS_vs_tilt(1));
fprintf('    WLS  RMSE: %.2f%%\n', 100*(rmse_WLS_vs_tilt(end)-rmse_WLS_vs_tilt(1))/rmse_WLS_vs_tilt(1));
fprintf('    NL   RMSE: %.2f%%\n', 100*(rmse_NL_vs_tilt(end)-rmse_NL_vs_tilt(1))/rmse_NL_vs_tilt(1));
fprintf('    DEB  RMSE: %.2f%%\n', 100*(rmse_DEB_vs_tilt(end)-rmse_DEB_vs_tilt(1))/rmse_DEB_vs_tilt(1));
fprintf('%s\n', repmat('=', 1, 80));

%% 8. Optional save
if save_figs
    tag = sprintf('K%d_M%d', N_or, M_trials);
    set(fig1, 'Color', 'white');
    set(fig2, 'Color', 'white');
    set(fig3, 'Color', 'white');
    print(fig1, fullfile(results_dir, sprintf('nr_robustness_RMSE_vs_tilt_%s.png',  tag)), '-dpng', '-r300');
    print(fig2, fullfile(results_dir, sprintf('nr_robustness_CDF_GLS_%s.png',       tag)), '-dpng', '-r300');
    print(fig3, fullfile(results_dir, sprintf('nr_robustness_CDF_extreme_%s.png',    tag)), '-dpng', '-r300');
    fprintf('Figures saved to: %s\n', results_dir);
end
