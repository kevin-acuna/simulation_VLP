%% plot_RMSE_vs_SNR.m
% IEEE TCOM — Publication figure: Estimator RMSE vs SNR
% Loads the .mat file produced by run_RMSE_vs_SNR_parallel.m and generates
% a two-panel figure suitable for the paper (responds to R2-C11 and R3-C6).
%
% Figure 1: Angular RMSE [°] vs SNR — GLS, WLS, NLS + DEB
% Figure 2: Position RMSE [cm] vs SNR — GLS, WLS, NLS + PEB
%
% Usage:
%   1. Run run_RMSE_vs_SNR_parallel.m first to generate the .mat results
%   2. Set MAT_FILE below to the generated .mat path
%   3. Run this script
%
% Author: Kevin Acuña

close all; clear variables; clc;

%% ===== CONFIGURATION =====
% Point this to the .mat file from the simulation
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results', 'K5_RMSE_vs_SNR');
mat_files = dir(fullfile(results_dir, 'K5_RMSE_vs_SNR_*.mat'));
if isempty(mat_files)
    error('No results .mat file found in %s. Run run_RMSE_vs_SNR_parallel.m first.', results_dir);
end
% Use the most recent file
[~, idx] = max([mat_files.datenum]);
MAT_FILE = fullfile(results_dir, mat_files(idx).name);
fprintf('Loading: %s\n', MAT_FILE);

SAVE_FIGURE = true;
OUT_DIR = fullfile(fileparts(mfilename('fullpath')), 'figures');
if ~exist(OUT_DIR, 'dir'), mkdir(OUT_DIR); end

%% ===== LOAD DATA =====
S = load(MAT_FILE);
SNR_dB = S.SNR_dB;
K = S.N_or;

%% ===== COMMON STYLE =====
% Colors (consistent with paper style)
c_gls = [0.000, 0.447, 0.741];   % blue
c_wls = [0.850, 0.325, 0.098];   % orange
c_nls = [0.494, 0.184, 0.556];   % purple
c_bnd = [0.466, 0.674, 0.188];   % green (bounds)

lw_est = 1.5;
lw_bnd = 1.3;
ms = 6;

%% ===== FIGURE 1: Direction Finding (Angular RMSE vs SNR) =====
fig_DF = figure('Units', 'inches', 'Position', [0.5, 0.5, 3.5, 2.8], 'Color', 'w');
hold on;

semilogy(SNR_dB, S.rmse_DF_GLS, '-o', 'Color', c_gls, 'LineWidth', lw_est, ...
    'MarkerSize', ms, 'MarkerFaceColor', c_gls);
semilogy(SNR_dB, S.rmse_DF_WLS, '-s', 'Color', c_wls, 'LineWidth', lw_est, ...
    'MarkerSize', ms, 'MarkerFaceColor', c_wls);
semilogy(SNR_dB, S.rmse_DF_NLS, '-^', 'Color', c_nls, 'LineWidth', lw_est, ...
    'MarkerSize', ms, 'MarkerFaceColor', c_nls);
semilogy(SNR_dB, S.rmse_DEB, '--d', 'Color', c_bnd, 'LineWidth', lw_bnd, ...
    'MarkerSize', ms, 'MarkerFaceColor', 'w');

set(gca, 'YScale', 'log');
xlabel('SNR [dB]', 'Interpreter', 'latex', 'FontSize', 10);
ylabel('RMS Angular Error [$^\circ$]', 'Interpreter', 'latex', 'FontSize', 10);
legend('GLS', 'WLS', 'NLS', 'DEB', ...
    'Interpreter', 'latex', 'FontSize', 9, 'Location', 'northeast');
grid on; grid minor;
set(gca, 'FontName', 'Times New Roman', 'FontSize', 9, ...
    'TickLabelInterpreter', 'latex', 'LineWidth', 0.8, 'Box', 'on');
xlim([SNR_dB(3), SNR_dB(end)]);
ylim([1e-2 1e1])
hold off;

%% ===== FIGURE 2: 3D Positioning (Position RMSE vs SNR) =====
fig_3D = figure('Units', 'inches', 'Position', [4.5, 0.5, 3.5, 2.8], 'Color', 'w');
hold on;

factor = 100; % m to cm
semilogy(SNR_dB, S.rmse_3D_GLS*factor, '-o', 'Color', c_gls, 'LineWidth', lw_est, ...
    'MarkerSize', ms, 'MarkerFaceColor', c_gls);
semilogy(SNR_dB, S.rmse_3D_WLS*factor, '-s', 'Color', c_wls, 'LineWidth', lw_est, ...
    'MarkerSize', ms, 'MarkerFaceColor', c_wls);
semilogy(SNR_dB, S.rmse_3D_NLS*factor, '-^', 'Color', c_nls, 'LineWidth', lw_est, ...
    'MarkerSize', ms, 'MarkerFaceColor', c_nls);
semilogy(SNR_dB, S.rmse_PEB*factor, '--d', 'Color', c_bnd, 'LineWidth', lw_bnd, ...
    'MarkerSize', ms, 'MarkerFaceColor', 'w');

set(gca, 'YScale', 'log');
xlabel('SNR [dB]', 'Interpreter', 'latex', 'FontSize', 10);
ylabel('RMS Position Error [cm]', 'Interpreter', 'latex', 'FontSize', 10);
legend('GLS', 'WLS', 'NLS', 'PEB', ...
    'Interpreter', 'latex', 'FontSize', 9, 'Location', 'northeast');
grid on; grid minor;
set(gca, 'FontName', 'Times New Roman', 'FontSize', 9, ...
    'TickLabelInterpreter', 'latex', 'LineWidth', 0.8, 'Box', 'on');
xlim([SNR_dB(3), SNR_dB(end)]);
hold off;

%% ===== EXPORT =====
if SAVE_FIGURE
    % Direction Finding figure
    fname_DF = sprintf('Fig_DF_RMSE_vs_SNR_K%d', K);
    exportgraphics(fig_DF, fullfile(OUT_DIR, [fname_DF, '.pdf']), ...
        'ContentType', 'vector', 'BackgroundColor', 'white');
    exportgraphics(fig_DF, fullfile(OUT_DIR, [fname_DF, '.png']), ...
        'Resolution', 600, 'BackgroundColor', 'white');
    fprintf('DF figure saved: %s\n', fullfile(OUT_DIR, fname_DF));
    
    % 3D Positioning figure
    fname_3D = sprintf('Fig_3D_RMSE_vs_SNR_K%d', K);
    exportgraphics(fig_3D, fullfile(OUT_DIR, [fname_3D, '.pdf']), ...
        'ContentType', 'vector', 'BackgroundColor', 'white');
    exportgraphics(fig_3D, fullfile(OUT_DIR, [fname_3D, '.png']), ...
        'Resolution', 600, 'BackgroundColor', 'white');
    fprintf('3D figure saved: %s\n', fullfile(OUT_DIR, fname_3D));
end

%% ===== PRINT SUMMARY TABLE =====
fprintf('\n--- Direction Finding RMSE [degrees] ---\n');
fprintf('%-8s %10s %10s %10s %10s\n', 'SNR[dB]', 'GLS', 'WLS', 'NLS', 'DEB');
for i = 1:numel(SNR_dB)
    fprintf('%-8.0f %10.4f %10.4f %10.4f %10.4f\n', ...
        SNR_dB(i), S.rmse_DF_GLS(i), S.rmse_DF_WLS(i), S.rmse_DF_NLS(i), S.rmse_DEB(i));
end

fprintf('\n--- 3D Positioning RMSE [cm] ---\n');
fprintf('%-8s %10s %10s %10s %10s\n', 'SNR[dB]', 'GLS', 'WLS', 'NLS', 'PEB');
for i = 1:numel(SNR_dB)
    fprintf('%-8.0f %10.2f %10.2f %10.2f %10.2f\n', ...
        SNR_dB(i), S.rmse_3D_GLS(i)*100, S.rmse_3D_WLS(i)*100, ...
        S.rmse_3D_NLS(i)*100, S.rmse_PEB(i)*100);
end
