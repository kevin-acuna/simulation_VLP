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

%% Figure: side-by-side heatmaps
fig = figure('Units','inches', 'Position',[0.5 0.5 7.16 3.0], 'Color', 'w');

% Common color scale
all_valid = cellfun(@(g) g(isfinite(g)), PEB_grids, 'UniformOutput', false);
cmax = min(prctile(vertcat(all_valid{:})*100, 98), 10);  % Cap at 10 cm or p98

for ik = 1:nP
    subplot(1, nP, ik);
    imagesc(x_range*100, y_range*100, PEB_grids{ik}*100);
    set(gca, 'YDir', 'normal');
    caxis([0 cmax]);
    colormap(gca, 'jet');
    cb = colorbar;
    ylabel(cb, '[cm]', 'Interpreter', 'latex');
    axis equal tight;
    hold on;
    plot(0, 0, 'w.', 'MarkerSize', 10);
    
    xlabel('$x$ [cm]', 'Interpreter', 'latex', 'FontSize', 10);
    ylabel('$y$ [cm]', 'Interpreter', 'latex', 'FontSize', 10);
    title(sprintf('$\\mathrm{PEB}_\\mathrm{B}$, $K{=}%d$', K_panels(ik)), ...
        'Interpreter', 'latex', 'FontSize', 11);
    set(gca, 'FontSize', 8);
end

sgtitle(sprintf('Broadcast PEB at $z{=}%.1f$ m ($\\Phi_{1/2}{=}%d^\\circ$, $\\mathbf{n}_r{=}[0,0,1]^T$)', ...
    z_analysis, theta_half), 'Interpreter', 'latex', 'FontSize', 12);

%% Save
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

if SAVE_FIGS
    exportgraphics(fig, fullfile(results_dir, 'Fig01_PEB_B_heatmap.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig, fullfile(results_dir, 'Fig01_PEB_B_heatmap.png'), 'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig, fullfile(results_dir, 'Fig01_PEB_B_heatmap.eps'), 'ContentType','vector','BackgroundColor','white');
    fprintf('Heatmap saved (pdf/png/eps)\n');
end
