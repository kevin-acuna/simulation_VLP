%% plot_DF_MC_comparison.m
% Loads two K*_DF_MC_results.mat files and generates:
%   Fig 1 — CDF of per-position angular RMSE for file A (4 estimators)
%   Fig 2 — CDF of per-position angular RMSE for file B (4 estimators)
%   Fig 3 — Combined CDF (8 curves): same colors, solid=A, dashed=B
%   Console — Metrics table: global RMSE, CDF90, Mean for all estimators × files
%
% Both .mat files must have been produced by run_DF_comparison_MC.m or
% run_DF_comparison_MC_parallel.m (same variable structure).
%
% Author: Kevin Acuña

close all; clear variables; clc;

% =========================================================================
% HYPERPARAMETERS — set the two .mat file paths here
% =========================================================================
base_dir = fullfile(fileparts(mfilename('fullpath')), 'results');

file_A = fullfile(base_dir, 'K5_DF_MC_100',  'K5_DF_MC_results.mat');
file_B = fullfile(base_dir, 'K5_DF_MC_1000', 'K5_DF_MC_results.mat');

save_figs = 0;   % 1 = export figures as PNG to results/
% =========================================================================

%% 1. Load data
dA = load(file_A);
dB = load(file_B);

% Angular per-position RMSE vectors
rA_GLS = dA.rmse_ang_GLS_pos;
rA_WLS = dA.rmse_ang_WLS_pos;
rA_NL  = dA.rmse_ang_NL_pos;
rA_DEB = dA.DEB_ang_pos;

rB_GLS = dB.rmse_ang_GLS_pos;
rB_WLS = dB.rmse_ang_WLS_pos;
rB_NL  = dB.rmse_ang_NL_pos;
rB_DEB = dB.DEB_ang_pos;

% Labels for legend / axis
labelA = sprintf('K=%d, M=%d', dA.N_or, dA.M_trials);
labelB = sprintf('K=%d, M=%d', dB.N_or, dB.M_trials);

%% 2. Compute metrics (global RMSE, CDF90, Mean) for each file
function s = compute_metrics(r_GLS, r_WLS, r_NL, r_DEB)
    s.rmse_GLS = sqrt(mean(r_GLS.^2));
    s.rmse_WLS = sqrt(mean(r_WLS.^2));
    s.rmse_NL  = sqrt(mean(r_NL.^2));
    s.rmse_DEB = sqrt(nanmean(r_DEB.^2));

    s.cdf90_GLS = prctile(r_GLS, 90);
    s.cdf90_WLS = prctile(r_WLS, 90);
    s.cdf90_NL  = prctile(r_NL, 90);
    s.cdf90_DEB = prctile(r_DEB(~isnan(r_DEB)), 90);

    s.mean_GLS = mean(r_GLS);
    s.mean_WLS = mean(r_WLS);
    s.mean_NL  = mean(r_NL);
    s.mean_DEB = nanmean(r_DEB);
end

mA = compute_metrics(rA_GLS, rA_WLS, rA_NL, rA_DEB);
mB = compute_metrics(rB_GLS, rB_WLS, rB_NL, rB_DEB);

%% 3. Shared style
color_gls = [0,      0.4470, 0.7410];
color_wls = [0.8500, 0.3250, 0.0980];
color_nl  = [0.4940, 0.1840, 0.5560];
color_deb = [0.4660, 0.6740, 0.1880];
lw = 1.5;

%% 4. Figure 1 — File A only
fig1 = figure('Name', sprintf('CDF DF Angular RMSE — %s', labelA), ...
    'Position', [50, 100, 600, 500]);
hold on;

[f,x] = ecdf(rA_GLS); stairs(x, f, '-',  'LineWidth', lw, 'Color', color_gls);
[f,x] = ecdf(rA_WLS); stairs(x, f, '-',  'LineWidth', lw, 'Color', color_wls);
[f,x] = ecdf(rA_NL);  stairs(x, f, '-',  'LineWidth', lw, 'Color', color_nl);
[f,x] = ecdf(rA_DEB(~isnan(rA_DEB))); stairs(x, f, '-', 'LineWidth', lw, 'Color', color_deb);
yline(0.9, '--', 'LineWidth', 0.8, 'Color', [0.5 0.5 0.5]);

xlabel('Per-position Angular RMSE [°]', 'Interpreter', 'latex', 'FontSize', 12);
ylabel('Empirical CDF',                 'Interpreter', 'latex', 'FontSize', 12);
legend(sprintf('GLS (%s)',         labelA), ...
       sprintf('WLS (%s)',         labelA), ...
       sprintf('NL-MLE (%s)',      labelA), ...
       sprintf('Theoretical DEB (%s)', labelA), ...
       'Location', 'southeast', 'Interpreter', 'latex', 'FontSize', 10);
title(sprintf('CDF of Spatial RMSE — %s', labelA), 'Interpreter', 'latex', 'FontSize', 13);
grid minor; hold off;

%% 5. Figure 2 — File B only
fig2 = figure('Name', sprintf('CDF DF Angular RMSE — %s', labelB), ...
    'Position', [100, 100, 600, 500]);
hold on;

[f,x] = ecdf(rB_GLS); stairs(x, f, '-',  'LineWidth', lw, 'Color', color_gls);
[f,x] = ecdf(rB_WLS); stairs(x, f, '-',  'LineWidth', lw, 'Color', color_wls);
[f,x] = ecdf(rB_NL);  stairs(x, f, '-',  'LineWidth', lw, 'Color', color_nl);
[f,x] = ecdf(rB_DEB(~isnan(rB_DEB))); stairs(x, f, '-', 'LineWidth', lw, 'Color', color_deb);
yline(0.9, '--', 'LineWidth', 0.8, 'Color', [0.5 0.5 0.5]);

xlabel('Per-position Angular RMSE [°]', 'Interpreter', 'latex', 'FontSize', 12);
ylabel('Empirical CDF',                 'Interpreter', 'latex', 'FontSize', 12);
legend(sprintf('GLS (%s)',         labelB), ...
       sprintf('WLS (%s)',         labelB), ...
       sprintf('NL-MLE (%s)',      labelB), ...
       sprintf('Theoretical DEB (%s)', labelB), ...
       'Location', 'southeast', 'Interpreter', 'latex', 'FontSize', 10);
title(sprintf('CDF of Spatial RMSE — %s', labelB), 'Interpreter', 'latex', 'FontSize', 13);
grid minor; hold off;

%% 6. Figure 3 — Combined (8 curves)
%  Same color per method. Solid line = file A, dashed line = file B.
fig3 = figure('Name', sprintf('CDF DF Combined — %s vs %s', labelA, labelB), ...
    'Position', [150, 100, 720, 540]);
hold on;

% File A — solid
[f,x] = ecdf(rA_GLS); hA_GLS = stairs(x, f, '-',  'LineWidth', lw,   'Color', color_gls);
[f,x] = ecdf(rA_WLS); hA_WLS = stairs(x, f, '-',  'LineWidth', lw,   'Color', color_wls);
[f,x] = ecdf(rA_NL);  hA_NL  = stairs(x, f, '-',  'LineWidth', lw,   'Color', color_nl);
[f,x] = ecdf(rA_DEB(~isnan(rA_DEB))); hA_DEB = stairs(x, f, '-', 'LineWidth', lw, 'Color', color_deb);

% File B — dashed, slightly thicker
[f,x] = ecdf(rB_GLS); hB_GLS = stairs(x, f, '--', 'LineWidth', lw+0.5, 'Color', color_gls);
[f,x] = ecdf(rB_WLS); hB_WLS = stairs(x, f, '--', 'LineWidth', lw+0.5, 'Color', color_wls);
[f,x] = ecdf(rB_NL);  hB_NL  = stairs(x, f, '--', 'LineWidth', lw+0.5, 'Color', color_nl);
[f,x] = ecdf(rB_DEB(~isnan(rB_DEB))); hB_DEB = stairs(x, f, '--', 'LineWidth', lw+0.5, 'Color', color_deb);

yline(0.9, '--', 'LineWidth', 0.8, 'Color', [0.5 0.5 0.5]);

xlabel('Per-position Angular RMSE [°]', 'Interpreter', 'latex', 'FontSize', 12);
ylabel('Empirical CDF',                 'Interpreter', 'latex', 'FontSize', 12);
legend([hA_GLS, hA_WLS, hA_NL, hA_DEB, hB_GLS, hB_WLS, hB_NL, hB_DEB], ...
       sprintf('GLS — %s',         labelA), ...
       sprintf('WLS — %s',         labelA), ...
       sprintf('NL-MLE — %s',      labelA), ...
       sprintf('DEB — %s',         labelA), ...
       sprintf('GLS — %s',         labelB), ...
       sprintf('WLS — %s',         labelB), ...
       sprintf('NL-MLE — %s',      labelB), ...
       sprintf('DEB — %s',         labelB), ...
       'Location', 'southeast', 'Interpreter', 'latex', 'FontSize', 9);
title(sprintf('CDF of Spatial RMSE — Combined (%s \\ solid / %s \\ dashed)', labelA, labelB), ...
    'Interpreter', 'latex', 'FontSize', 13);
grid minor; hold off;

%% 7. Print metrics table
fprintf('\n');
fprintf('%s\n', repmat('=', 1, 72));
fprintf('  DIRECTION-FINDING ANGULAR RMSE COMPARISON\n');
fprintf('%s\n', repmat('=', 1, 72));
fprintf('  %-12s  %-10s  %-10s  %-10s  %-10s\n', ...
    'File', 'Method', 'RMSE [°]', 'CDF90 [°]', 'Mean [°]');
fprintf('%s\n', repmat('-', 1, 72));

methods   = {'GLS', 'WLS', 'NL-MLE', 'DEB'};
rmse_A    = [mA.rmse_GLS,  mA.rmse_WLS,  mA.rmse_NL,  mA.rmse_DEB];
cdf90_A   = [mA.cdf90_GLS, mA.cdf90_WLS, mA.cdf90_NL, mA.cdf90_DEB];
mean_A    = [mA.mean_GLS,  mA.mean_WLS,  mA.mean_NL,  mA.mean_DEB];
rmse_B    = [mB.rmse_GLS,  mB.rmse_WLS,  mB.rmse_NL,  mB.rmse_DEB];
cdf90_B   = [mB.cdf90_GLS, mB.cdf90_WLS, mB.cdf90_NL, mB.cdf90_DEB];
mean_B    = [mB.mean_GLS,  mB.mean_WLS,  mB.mean_NL,  mB.mean_DEB];

for i = 1:4
    fprintf('  %-12s  %-10s  %-10.4f  %-10.4f  %-10.4f\n', ...
        labelA, methods{i}, rmse_A(i), cdf90_A(i), mean_A(i));
end
fprintf('%s\n', repmat('-', 1, 72));
for i = 1:4
    fprintf('  %-12s  %-10s  %-10.4f  %-10.4f  %-10.4f\n', ...
        labelB, methods{i}, rmse_B(i), cdf90_B(i), mean_B(i));
end
fprintf('%s\n', repmat('=', 1, 72));

fprintf('\n  Δ RMSE (B - A):  GLS=%.4f°  WLS=%.4f°  NL-MLE=%.4f°  DEB=%.4f°\n', ...
    rmse_B(1)-rmse_A(1), rmse_B(2)-rmse_A(2), ...
    rmse_B(3)-rmse_A(3), rmse_B(4)-rmse_A(4));
fprintf('%s\n', repmat('=', 1, 72));

%% 8. Optional save
if save_figs
    fig_dir = base_dir;
    tag = sprintf('%s_vs_%s', strrep(labelA,' ',''), strrep(labelB,' ',''));
    set(fig1, 'Color', 'white');
    set(fig2, 'Color', 'white');
    set(fig3, 'Color', 'white');
    print(fig1, fullfile(fig_dir, sprintf('CDF_DF_A_%s.png',   tag)), '-dpng', '-r300');
    print(fig2, fullfile(fig_dir, sprintf('CDF_DF_B_%s.png',   tag)), '-dpng', '-r300');
    print(fig3, fullfile(fig_dir, sprintf('CDF_DF_AB_%s.png',  tag)), '-dpng', '-r300');
    fprintf('Figures saved to: %s\n', fig_dir);
end
