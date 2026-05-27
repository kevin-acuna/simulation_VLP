%% sim03_PEB_vs_SNR.m — RMS-PEB_B vs SNR (envelope style, like TCOM Fig. 5)
%
% Plots the broadcast PEB (PEB_B) vs SNR for n_r = [0,0,1] (no tilt).
% Envelope design:
%   * Shaded band   → range spanned by K=Kmin..Kmax
%   * Dotted edges  → Kmin (top) and Kmax (bottom)
%   * Bold curve    → K_HIGHLIGHT (recommended operating point)
%
% SNR is varied by scaling sigma2: sigma2(SNR) = sigma2_ref / SNR_lin
% where sigma2_ref is the nominal value from system_params_F (≈14 dB).
%
% Author: Kevin Acuna-Condori
% Date: 27 May 2026
% Project: Proposal F — Broadcast OWP

clear; clc; close all;

%% Paths
project_root = fileparts(pwd);
addpath(fullfile(project_root, 'core'));
addpath(fullfile(fileparts(project_root), 'fundamentals', 'core'));
addpath(project_root);

%% System Parameters
system_params_F;

% =========================================================================
% HYPERPARAMETERS
% =========================================================================
METRIC      = 'rms';             % 'rms' or 'cdf90'
SNR_dB      = 0:5:50;           % SNR sweep [dB] (absolute)
K_VALUES    = 5:15;             % K range for envelope
K_HIGHLIGHT = 9;                 % Accent curve (bold)
SAVE_OUTPUT = false;
% =========================================================================

%% Testbed (full 3D)
x_range = -L/2:step:L/2;
y_range = -W/2:step:W/2;
z_range = 0:stepH:Hmax;
[Xg, Yg, Zg] = meshgrid(x_range, y_range, z_range);
positions = [Xg(:), Yg(:), Zg(:)]';
N_pos = size(positions, 2);
fprintf('Testbed: %d positions\n', N_pos);

%% Noise levels (absolute SNR)
% The nominal sigma2 from system_params_F gives ~14 dB average SNR.
% We define: sigma2(SNR) = sigma2_nominal * 10^((SNR_nominal - SNR)/10)
% so that at SNR = SNR_nominal, sigma2 = sigma2_nominal.
SNR_nominal = 14;  % dB — corresponds to sigma2 in system_params_F
sigma2_ref  = sigma2;
SNR_lin     = 10.^((SNR_dB - SNR_nominal) / 10);
sigma2_vec  = sigma2_ref ./ SNR_lin;
nSNR = numel(SNR_dB);
nK   = numel(K_VALUES);

%% Orientation map
ori_map = containers.Map('KeyType','double','ValueType','any');
for ik = 1:length(K_values)
    ori_map(K_values(ik)) = all_orientations_DEB{ik};
end

%% Compute PEB_B for all (SNR, K) combinations
peb_mat = nan(nSNR, nK);  % [cm]

fprintf('Computing PEB_B: %d SNR × %d K = %d combos × %d positions\n', ...
    nSNR, nK, nSNR*nK, N_pos);
total_tic = tic;

nr_col = n_r';  % column vector [0;0;1]

for ik = 1:nK
    K_i = K_VALUES(ik);
    nt = orient_to_vectors(ori_map(K_i));  % 3 x K
    
    for is = 1:nSNR
        s2 = sigma2_vec(is);
        t0 = tic;
        
        peb_vals = nan(N_pos, 1);
        for j = 1:N_pos
            R = positions(:, j);
            p = PEB_Konly(R, nt, T', P_t, m_t, A_det, deg2rad(FOV), s2, N_samples, nr_col);
            if isfinite(p) && isreal(p) && p > 0
                peb_vals(j) = p;
            end
        end
        
        valid = peb_vals(isfinite(peb_vals));
        switch METRIC
            case 'rms'
                peb_mat(is, ik) = sqrt(mean(valid.^2)) * 100;  % cm
            case 'cdf90'
                peb_mat(is, ik) = prctile(valid, 90) * 100;    % cm
        end
        
        fprintf('  K=%d  SNR=%+3.0f dB  PEB_B(%s)=%6.2f cm  (%.1fs)\n', ...
            K_i, SNR_dB(is), METRIC, peb_mat(is,ik), toc(t0));
    end
end

total_time = toc(total_tic);
fprintf('Total time: %.1f s (%.1f min)\n', total_time, total_time/60);

%% Envelope computation
peb_max = max(peb_mat, [], 2);   % worst K (= Kmin)
peb_min = min(peb_mat, [], 2);   % best K  (= Kmax)

ihl = find(K_VALUES == K_HIGHLIGHT, 1);
peb_hl = peb_mat(:, ihl);

ikmin_idx = 1;  % K_VALUES(1) = smallest K
ikmax_idx = nK; % K_VALUES(end) = largest K
peb_kmin = peb_mat(:, ikmin_idx);
peb_kmax = peb_mat(:, ikmax_idx);

%% Metric label
switch lower(METRIC)
    case 'rms',   metric_lbl = 'RMS';
    case 'cdf90', metric_lbl = 'CDF_{90\%}';
end

%% Figure
fig = figure('Position', [100, 100, 700, 500], 'Color', 'w');
ax = axes(fig);
hold(ax, 'on');

c_peb = [0.000, 0.447, 0.741];  % blue

% Shaded band
x_band = [SNR_dB, fliplr(SNR_dB)];
y_band = [peb_max(:)', fliplr(peb_min(:)')];
patch(x_band, y_band, c_peb, 'FaceAlpha', 0.18, 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');

% Dotted edges (Kmin = top, Kmax = bottom)
plot(SNR_dB, peb_kmin, ':', 'Color', c_peb*0.7, 'LineWidth', 0.8, ...
    'HandleVisibility', 'off');
plot(SNR_dB, peb_kmax, ':', 'Color', c_peb*0.7, 'LineWidth', 0.8, ...
    'HandleVisibility', 'off');

% Bold highlight curve
h_hl = plot(SNR_dB, peb_hl, '-o', 'Color', c_peb, ...
    'MarkerFaceColor', c_peb, 'LineWidth', 2, 'MarkerSize', 5);

% Formatting
set(ax, 'YScale', 'log');
xlabel('SNR [dB]', 'Interpreter', 'latex', 'FontSize', 11);
ylabel(sprintf('%s-$\\mathrm{PEB}_\\mathrm{B}$ [cm]', metric_lbl), ...
    'Interpreter', 'latex', 'FontSize', 11);
title(sprintf('Broadcast PEB vs SNR ($\\Phi_{1/2}{=}%d^\\circ$, $\\mathbf{n}_r{=}[0,0,1]^T$, DEB-opt.)', ...
    theta_half), 'Interpreter', 'latex', 'FontSize', 12);
grid on; grid minor;
xlim([SNR_dB(1), SNR_dB(end)]);
set(ax, 'FontSize', 9, 'Box', 'on', 'LineWidth', 0.8);

% Reference lines
yline(1, '--', '1 cm', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, ...
    'LabelHorizontalAlignment', 'left', 'FontSize', 8);

% Mark nominal operating point (SNR = 14 dB)
if any(SNR_dB == SNR_nominal)
    idx0 = find(SNR_dB == SNR_nominal);
    plot(SNR_nominal, peb_hl(idx0), 'r^', 'MarkerSize', 10, 'MarkerFaceColor', 'r', ...
        'HandleVisibility', 'off');
    text(SNR_nominal+0.5, peb_hl(idx0)*1.3, sprintf('Nominal (%.1f cm)', peb_hl(idx0)), ...
        'FontSize', 8, 'Color', 'r');
end

% Legend
h_band_proxy = patch(NaN, NaN, c_peb, 'FaceAlpha', 0.18, 'EdgeColor', 'none');
legend([h_hl, h_band_proxy], ...
    {sprintf('$\\mathrm{PEB}_\\mathrm{B}$, $K{=}%d$', K_HIGHLIGHT), ...
     sprintf('$\\mathrm{PEB}_\\mathrm{B}$ band, $K{\\in}[%d,%d]$', min(K_VALUES), max(K_VALUES))}, ...
    'Interpreter', 'latex', 'Location', 'northeast', 'FontSize', 9);

hold(ax, 'off');

%% Save
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

if SAVE_OUTPUT
    saveas(fig, fullfile(results_dir, sprintf('Fig_A6_PEB_vs_SNR_%s.png', METRIC)));
    saveas(fig, fullfile(results_dir, sprintf('Fig_A6_PEB_vs_SNR_%s.fig', METRIC)));
    
    save(fullfile(results_dir, 'sim03_PEB_vs_SNR_data.mat'), ...
        'peb_mat', 'SNR_dB', 'K_VALUES', 'K_HIGHLIGHT', ...
        'METRIC', 'sigma2_ref', 'sigma2_vec', 'N_pos', 'total_time');
    
    fprintf('Saved to: %s\n', results_dir);
end

%% Summary table
fprintf('\n=== PEB_B [cm] vs SNR ===\n');
fprintf('%-8s', 'SNR[dB]');
for ik = 1:nK
    fprintf(' | K=%-2d  ', K_VALUES(ik));
end
fprintf('\n%s\n', repmat('-', 1, 8 + nK*9));
for is = 1:nSNR
    fprintf('%+5.0f   ', SNR_dB(is));
    for ik = 1:nK
        fprintf(' | %5.2f ', peb_mat(is, ik));
    end
    fprintf('\n');
end
