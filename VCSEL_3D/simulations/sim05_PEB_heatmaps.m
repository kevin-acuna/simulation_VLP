%% sim05_PEB_heatmaps.m — Spatial PEB heatmaps for representative (K, theta) cases
%
% Floor heatmaps of the broadcast Gaussian PEB at a fixed height. Uncovered
% positions (low SNR or rank-deficient FIM) are shown as holes, exposing how
% divergence and K reshape the spatial structure of coverage and accuracy.
%
% One figure per configuration, IEEE single-column sizing (mirrors
% F_broadcast_Konly/simulations/sim01_PEB_Konly_heatmap.m).
%
% Author: Kevin Acuna-Condori
% Project: VCSEL Gaussian OWP

clear; clc; close all;

%% Paths + params
project_root = fileparts(pwd);
addpath(fullfile(project_root, 'core'));
system_params_VCSEL;

% =========================================================================
% CONFIGURATIONS: [K, theta_div_deg]
% =========================================================================
configs    = [9, 10; 25, 10; 9, 20; 15, 15];
z_analysis = 0.8;      % height [m]
step_hm    = 0.05;     % fine grid for smooth heatmap [m]
SAVE_FIGS  = true;
% =========================================================================

params = struct('T', T, 'Pt', P_t, 'A_det', A_det, 'Psi_FOV', deg2rad(FOV), ...
    'sigma2', sigma2, 'N', N_samples, 'nr', n_r, ...
    'SNR_min_dB', SNR_min_dB, 'PEB_max_cov', PEB_max_cov);

x_range = -L/2:step_hm:L/2;
y_range = -W/2:step_hm:W/2;
Nx = numel(x_range); Ny = numel(y_range);
fprintf('Heatmap grid: %d x %d = %d points per panel\n', Nx, Ny, Nx*Ny);

results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

grids = cell(size(configs,1), 1);
for ic = 1:size(configs,1)
    K = configs(ic,1);
    theta_deg = configs(ic,2);
    theta_div = deg2rad(theta_deg);
    nt = generate_codebook(K, theta_cap, 'sunflower');

    grid_k = NaN(Ny, Nx);
    fprintf('Computing PEB heatmap (K=%d, theta=%d deg)... ', K, theta_deg);
    tic;
    for ix = 1:Nx
        for iy = 1:Ny
            R = [x_range(ix); y_range(iy); z_analysis];

            % Coverage gate via peak SNR
            mu_max = 0;
            for i = 1:K
                mu_i = gaussian_channel(R, nt(:,i), T, P_t, theta_div, A_det, deg2rad(FOV), n_r);
                if mu_i > mu_max, mu_max = mu_i; end
            end
            snr_dB = -inf; if mu_max > 0, snr_dB = 10*log10(mu_max^2/(sigma2/N_samples)); end

            pv = PEB_Gaussian(R, nt, T, P_t, theta_div, A_det, deg2rad(FOV), sigma2, N_samples, n_r);
            if isfinite(pv) && isreal(pv) && pv > 0 && pv <= PEB_max_cov && snr_dB >= SNR_min_dB
                grid_k(iy, ix) = pv;
            end
        end
    end
    grids{ic} = grid_k;
    cov = mean(isfinite(grid_k(:)));
    fprintf('done (%.1f s) | coverage@z=%.1f: %.1f%%\n', toc, z_analysis, 100*cov);
end

% Shared colour scale
all_valid = cellfun(@(g) g(isfinite(g)), grids, 'UniformOutput', false);
cmax = min(prctile(vertcat(all_valid{:})*100, 98), 100*PEB_max_cov);

for ic = 1:size(configs,1)
    K = configs(ic,1); theta_deg = configs(ic,2);
    fig = figure('Units','inches', 'Position',[0.5 0.5 1.9 2.0], 'Color','w');
    ax = axes(fig);
    imagesc(ax, x_range*100, y_range*100, grids{ic}*100);
    set(ax, 'YDir', 'normal', 'Color', [0.9 0.9 0.9]);   % holes = grey
    set(ax, 'AlphaData', ~isnan(grids{ic}));
    clim(ax, [0, cmax]); colormap(ax, parula(256));
    axis(ax, 'equal', 'tight'); hold(ax, 'on');
    plot(ax, 0, 0, 'w*', 'MarkerSize', 6, 'LineWidth', 1.2);
    hold(ax, 'off');

    cb = colorbar(ax, 'Location','eastoutside');
    cb.Label.String = '$\mathrm{PEB}$ [cm]';
    cb.Label.Interpreter = 'latex'; cb.Label.FontSize = 7;
    set(cb, 'FontName','Times New Roman', 'FontSize', 6, 'TickLabelInterpreter','latex');

    xlabel(ax, '$x$ [cm]', 'Interpreter','latex', 'FontSize', 8);
    ylabel(ax, '$y$ [cm]', 'Interpreter','latex', 'FontSize', 8);
    title(ax, sprintf('$K{=}%d,\\ \\theta_{\\mathrm{div}}{=}%d^\\circ$', K, theta_deg), ...
        'Interpreter','latex', 'FontSize', 8);
    set(ax, 'FontName','Times New Roman', 'FontSize', 7, 'TickLabelInterpreter','latex', ...
        'Box','on', 'LineWidth', 0.5, 'XTick', [-150 0 150], 'YTick', [-150 0 150]);

    if SAVE_FIGS
        fig_name = sprintf('Fig05_PEB_heatmap_K%d_theta%d', K, theta_deg);
        exportgraphics(fig, fullfile(results_dir, [fig_name '.pdf']), 'ContentType','vector','BackgroundColor','white');
        exportgraphics(fig, fullfile(results_dir, [fig_name '.png']), 'Resolution',600,'BackgroundColor','white');
        fprintf('Heatmap saved: %s\n', fig_name);
    end
end
