%% sim01_PEB_broadcast_heatmap.m
% Spatial heatmap of the broadcast PEB (PEB_B) at a fixed height.
% Shows two panels: (a) PEB_B for K=5, (b) PEB_B for K=9.
% No cooperative comparison — this is a standalone broadcast proposal.
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
K_panels     = [5, 9];          % K values to show side by side
z_analysis   = 0.8;             % Height [m]
step_hm      = 0.05;            % Fine grid for smooth heatmap [m]
SAVE_FIGS    = true;
% =========================================================================

%% Spatial grid
x_range = -L/2:step_hm:L/2;
y_range = -W/2:step_hm:W/2;
Nx = length(x_range);
Ny = length(y_range);
nP = length(K_panels);

fprintf('Heatmap grid: %d x %d = %d points per panel\n', Nx, Ny, Nx*Ny);

%% Compute PEB_B for each K
PEB_grids = cell(nP, 1);

for ik = 1:nP
    K = K_panels(ik);
    K_idx = find(K_values == K);
    nt = orient_to_vectors(all_orientations_DEB{K_idx});
    
    grid_k = NaN(Ny, Nx);
    fprintf('Computing PEB_B (K=%d)... ', K);
    tic;
    for ix = 1:Nx
        for iy = 1:Ny
            R = [x_range(ix); y_range(iy); z_analysis];
            pv = PEB_Konly(R, nt, T', P_t, m_t, A_det, deg2rad(FOV), sigma2, N_samples, n_r');
            if isfinite(pv) && isreal(pv) && pv > 0
                grid_k(iy, ix) = pv;
            end
        end
    end
    PEB_grids{ik} = grid_k;
    fprintf('done (%.1f s)\n', toc);
    
    valid = grid_k(isfinite(grid_k));
    fprintf('  RMS = %.2f cm, Mean = %.2f cm, CDF90 = %.2f cm\n', ...
        sqrt(mean(valid.^2))*100, mean(valid)*100, prctile(valid,90)*100);
end

%% Figure: one separate figure per K value
cmap = parula(256);

% Common color scale (shared between both panels for fair visual comparison)
all_valid = cellfun(@(g) g(isfinite(g)), PEB_grids, 'UniformOutput', false);
cmax = min(prctile(vertcat(all_valid{:})*100, 98), 10);  % Cap at 10 cm or p98

%% Save
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

for ik = 1:nP
    K = K_panels(ik);
    
    fig = figure('Units','inches', 'Position',[0.5 0.5 1.75 2.0], 'Color', 'w');
    ax  = axes(fig);
    
    imagesc(ax, x_range*100, y_range*100, PEB_grids{ik}*100);
    set(ax, 'YDir', 'normal');
    clim(ax, [0, cmax]);
    colormap(ax, cmap);
    axis(ax, 'equal', 'tight');
    hold(ax, 'on');
    plot(ax, 0, 0, 'w*', 'MarkerSize', 6, 'LineWidth', 1.2);
    hold(ax, 'off');
    
    cb = colorbar(ax, 'Location', 'eastoutside');
    cb.Label.String      = '$\mathrm{PEB}_\mathrm{B}$ [cm]';
    cb.Label.Interpreter = 'latex';
    cb.Label.FontSize    = 7;
    set(cb, 'FontName', 'Times New Roman', 'FontSize', 6, 'TickLabelInterpreter', 'latex');
    
    xlabel(ax, '$x$ [cm]', 'Interpreter', 'latex', 'FontSize', 8);
    ylabel(ax, '$y$ [cm]', 'Interpreter', 'latex', 'FontSize', 8);
    set(ax, 'FontName', 'Times New Roman', 'FontSize', 7, ...
        'TickLabelInterpreter', 'latex', 'Box', 'on', 'LineWidth', 0.5, ...
        'XTick', [-150 0 150], 'YTick', [-150 0 150]);
    
    if SAVE_FIGS
        fig_name = sprintf('Fig01_PEB_B_heatmap_K%d', K);
        exportgraphics(fig, fullfile(results_dir, [fig_name '.pdf']), 'ContentType','vector','BackgroundColor','white');
        exportgraphics(fig, fullfile(results_dir, [fig_name '.png']), 'Resolution',600,'BackgroundColor','white');
        exportgraphics(fig, fullfile(results_dir, [fig_name '.eps']), 'ContentType','vector','BackgroundColor','white');
        fprintf('Heatmap K=%d saved (pdf/png/eps)\n', K);
    end
end
