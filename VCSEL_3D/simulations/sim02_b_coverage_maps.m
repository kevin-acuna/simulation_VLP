%% sim02_b_coverage_maps.m — Visual (spatial) coverage characterization
%
% Complements sim02 (which reports coverage as a percentage) with a VISUAL,
% side-by-side comparison of WHERE the room is covered:
%
%   Figure 1 : tiled binary coverage maps at a fixed height, arranged as a
%              (theta_div x K) grid of small multiples. Covered vs uncovered
%              cells expose the narrow-beam "coverage holes" and how they shrink
%              as K (probing overhead) or theta_div grows.
%   Figure 2 : coverage vs height z (one curve per theta_div, fixed K) — the
%              vertical structure that the single percentage hides.
%
% The coverage criterion is IDENTICAL to sim02 (evaluate_codebook):
%   covered <=> isfinite(PEB) AND PEB <= PEB_max_cov AND peakSNR_dB >= SNR_min_dB
%
% Author: Kevin Acuna-Condori
% Project: VCSEL Gaussian OWP (target IEEE TWC)

clear; clc; close all;

%% Paths + params
project_root = fileparts(pwd);
addpath(fullfile(project_root, 'core'));
system_params_VCSEL;

% =========================== CONFIGURATION ===========================
codebook_type = 'dense';  % 'symmetric' (D4, symmetric maps) | 'sunflower' | ...
theta_rows  = [10, 15, 20];   % divergence angles (map rows) [deg]
K_cols      = [9, 17, 25];    % probing overhead (map columns); C4-compatible (4m+1)
z_analysis  = 0.8;            % height for the coverage maps [m]
step_hm     = 0.05;           % fine floor grid [m]
K_zprofile  = 17;             % K used for the coverage-vs-height curves (C4-compatible)
SAVE_FIGS   = false;
% =====================================================================
%
% NOTE ON SYMMETRY: 'sunflower' is a golden-angle spiral (area-uniform but
% aperiodic) so its coverage maps are NOT symmetric. 'symmetric' uses a
% D4-symmetric codebook (90-deg rotation + mirror), giving symmetric maps on
% the square room. C4 orbits have size 4 (+1 optional nadir), so K must be
% 4m or 4m+1 for exact symmetry (otherwise generate_codebook rounds + warns).

params = struct('T', T, 'Pt', P_t, 'A_det', A_det, 'Psi_FOV', deg2rad(FOV), ...
    'sigma2', sigma2, 'N', N_samples, 'nr', n_r, ...
    'SNR_min_dB', SNR_min_dB, 'PEB_max_cov', PEB_max_cov);

results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

x_range = -L/2:step_hm:L/2;
y_range = -W/2:step_hm:W/2;
Nx = numel(x_range); Ny = numel(y_range);
[Xg, Yg] = meshgrid(x_range, y_range);   % [Ny x Nx]

nR = numel(theta_rows); nC = numel(K_cols);
fprintf('Coverage maps: %dx%d grid, %d points/panel, z=%.1f m\n', nR, nC, Nx*Ny, z_analysis);

%% Compute coverage masks for every (theta, K) panel
masks = cell(nR, nC);
covpc = zeros(nR, nC);
for ir = 1:nR
    theta_div = deg2rad(theta_rows(ir));
    for ic = 1:nC
        K  = K_cols(ic);
        nt = generate_codebook(K, theta_cap, codebook_type);
        positions = [Xg(:), Yg(:), z_analysis*ones(Nx*Ny,1)]';
        r = evaluate_codebook(nt, theta_div, positions, params);
        masks{ir, ic} = reshape(r.covered, [Ny, Nx]);
        covpc(ir, ic) = 100 * mean(r.covered);
        fprintf('  theta=%2d K=%2d : coverage@z=%.1f = %.1f%%\n', ...
            theta_rows(ir), K, z_analysis, covpc(ir, ic));
    end
end

%% Figure 1: tiled binary coverage maps
cmap2 = [0.93 0.93 0.93;    % 0 = uncovered (light grey)
         0.16 0.52 0.74];   % 1 = covered   (blue)

fig1 = figure('Units','inches', 'Position',[0.5 0.5 1.7*nC 1.85*nR], 'Color','w');
tl = tiledlayout(fig1, nR, nC, 'TileSpacing','compact', 'Padding','compact');
for ir = 1:nR
    for ic = 1:nC
        ax = nexttile(tl);
        imagesc(ax, x_range*100, y_range*100, double(masks{ir, ic}));
        set(ax, 'YDir','normal'); colormap(ax, cmap2); clim(ax, [0 1]);
        axis(ax, 'equal', 'tight'); hold(ax, 'on');
        plot(ax, 0, 0, 'p', 'MarkerSize', 7, 'MarkerFaceColor', [1 0.85 0], ...
            'MarkerEdgeColor', 'k', 'LineWidth', 0.5);   % TX (nadir)
        text(ax, -L/2*100+8, W/2*100-14, sprintf('%.0f\\%%', covpc(ir,ic)), ...
            'Interpreter','latex', 'FontSize', 7, 'FontWeight','bold', ...
            'Color','k', 'BackgroundColor',[1 1 1 0.6]);
        hold(ax, 'off');
        set(ax, 'FontName','Times New Roman', 'FontSize', 6, ...
            'TickLabelInterpreter','latex', 'Box','on', 'LineWidth', 0.5, ...
            'XTick', [-150 0 150], 'YTick', [-150 0 150]);
        if ir == 1
            title(ax, sprintf('$K{=}%d$', K_cols(ic)), 'Interpreter','latex', 'FontSize', 8);
        end
        if ic == 1
            ylabel(ax, sprintf('$\\theta_{\\mathrm{div}}{=}%d^\\circ$\\quad $y$ [cm]', theta_rows(ir)), ...
                'Interpreter','latex', 'FontSize', 7);
        end
        if ir == nR
            xlabel(ax, '$x$ [cm]', 'Interpreter','latex', 'FontSize', 7);
        end
    end
end
title(tl, sprintf('Localization coverage @ $z=%.1f$ m --- %s codebook (blue = covered)', ...
    z_analysis, codebook_type), 'Interpreter','latex', 'FontSize', 9);

%% Figure 2: coverage vs height z (fixed K)
z_vals = 0:0.1:Hmax;
cov_z  = zeros(numel(theta_rows), numel(z_vals));
nt_z   = generate_codebook(K_zprofile, theta_cap, codebook_type);
for ir = 1:numel(theta_rows)
    theta_div = deg2rad(theta_rows(ir));
    for iz = 1:numel(z_vals)
        positions = [Xg(:), Yg(:), z_vals(iz)*ones(Nx*Ny,1)]';
        r = evaluate_codebook(nt_z, theta_div, positions, params);
        cov_z(ir, iz) = 100 * r.coverage;
    end
end

fig2 = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w'); hold on;
colors = lines(numel(theta_rows));
h = gobjects(numel(theta_rows),1);
for ir = 1:numel(theta_rows)
    h(ir) = plot(z_vals*100, cov_z(ir,:), '-o', 'LineWidth', 1.0, ...
        'MarkerSize', 4, 'Color', colors(ir,:), 'MarkerFaceColor', colors(ir,:));
end
xlabel('Height $z$ [cm]', 'Interpreter','latex', 'FontSize', 8);
ylabel('Coverage [\%]', 'Interpreter','latex', 'FontSize', 8);
ylim([0 100]); grid on; box on; set(gca, 'FontSize', 7, 'LineWidth', 0.5);
legend(h, arrayfun(@(t) sprintf('$\\theta_{\\mathrm{div}}{=}%d^\\circ$', t), ...
    theta_rows, 'UniformOutput', false), 'Interpreter','latex', 'FontSize', 6, 'Location','southwest');
title(sprintf('$K=%d$', K_zprofile), 'Interpreter','latex', 'FontSize', 8);

%% Figure 3: per-beam footprint contours (overlap diagnostics)
% Same (theta_div x K) grid as Fig. 1, but instead of only the thresholded
% UNION (coverage mask), it overlays the SNR>=SNR_min contour of EACH steered
% beam. Every beam illuminates the z-plane with a footprint; drawing K contours
% shows how the reorientations are placed and whether they overlap too much.
% The union of these K footprints is exactly the peak-SNR gate of the coverage
% criterion in evaluate_codebook.m.
mu_min = sqrt((sigma2 / N_samples) * 10^(SNR_min_dB/10));   % per-beam power threshold

fig3 = figure('Units','inches', 'Position',[0.5 0.5 1.7*nC 1.85*nR], 'Color','w');
tl3 = tiledlayout(fig3, nR, nC, 'TileSpacing','compact', 'Padding','compact');
for ir = 1:nR
    theta_div = deg2rad(theta_rows(ir));
    for ic = 1:nC
        K  = K_cols(ic);
        nt = generate_codebook(K, theta_cap, codebook_type);
        Kb = size(nt, 2);
        ax = nexttile(tl3);
        imagesc(ax, x_range*100, y_range*100, double(masks{ir, ic}));   % faint union background
        set(ax, 'YDir','normal'); colormap(ax, [1 1 1; 0.90 0.94 0.98]); clim(ax, [0 1]);
        axis(ax, 'equal', 'tight'); hold(ax, 'on');
        cols = turbo(max(Kb, 2));
        for i = 1:Kb
            MU = beam_power_grid(Xg, Yg, z_analysis, nt(:,i), T, P_t, ...
                theta_div, A_det, deg2rad(FOV), n_r);
            if any(MU(:) >= mu_min)
                contour(ax, x_range*100, y_range*100, MU, [mu_min mu_min], ...
                    'LineWidth', 0.6, 'LineColor', cols(i,:));
            end
        end
        plot(ax, 0, 0, 'p', 'MarkerSize', 7, 'MarkerFaceColor', [1 0.85 0], ...
            'MarkerEdgeColor', 'k', 'LineWidth', 0.5);   % TX (nadir)
        hold(ax, 'off');
        xlim(ax, [-L/2 L/2]*100); ylim(ax, [-W/2 W/2]*100);
        set(ax, 'FontName','Times New Roman', 'FontSize', 6, ...
            'TickLabelInterpreter','latex', 'Box','on', 'LineWidth', 0.5, ...
            'XTick', [-150 0 150], 'YTick', [-150 0 150]);
        if ir == 1
            title(ax, sprintf('$K{=}%d$', K_cols(ic)), 'Interpreter','latex', 'FontSize', 8);
        end
        if ic == 1
            ylabel(ax, sprintf('$\\theta_{\\mathrm{div}}{=}%d^\\circ$\\quad $y$ [cm]', theta_rows(ir)), ...
                'Interpreter','latex', 'FontSize', 7);
        end
        if ir == nR
            xlabel(ax, '$x$ [cm]', 'Interpreter','latex', 'FontSize', 7);
        end
    end
end
title(tl3, sprintf('Per-beam footprints ($\\mathrm{SNR}\\geq %g$ dB) @ $z=%.1f$ m --- %s codebook', ...
    SNR_min_dB, z_analysis, codebook_type), 'Interpreter','latex', 'FontSize', 9);

if SAVE_FIGS
    exportgraphics(fig1, fullfile(results_dir, 'Fig02b_coverage_maps.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig1, fullfile(results_dir, 'Fig02b_coverage_maps.png'), 'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig2, fullfile(results_dir, 'Fig02b_coverage_vs_height.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig2, fullfile(results_dir, 'Fig02b_coverage_vs_height.png'), 'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig3, fullfile(results_dir, 'Fig02b_beam_footprints.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig3, fullfile(results_dir, 'Fig02b_beam_footprints.png'), 'Resolution',600,'BackgroundColor','white');
    fprintf('Figures saved (pdf/png) to %s\n', results_dir);
end

%% Summary
fprintf('\n=== Coverage @ z=%.1f m [%%] ===\n', z_analysis);
fprintf('%-10s', 'theta\\K'); fprintf('%8d', K_cols); fprintf('\n');
for ir = 1:nR
    fprintf('%-10d', theta_rows(ir)); fprintf('%8.1f', covpc(ir,:)); fprintf('\n');
end

%% ------------------------- local functions -------------------------
function MU = beam_power_grid(Xg, Yg, z, nt_i, T, Pt, theta_div, A_det, Psi_FOV, nr)
% BEAM_POWER_GRID  Vectorized noiseless received power for ONE Gaussian beam
% over a horizontal z-plane grid. Mirrors core/gaussian_channel.m exactly
% (far-field fixed-emitted-power model), returning a matrix the size of Xg.
    nt_i = nt_i(:); T = T(:); nr = nr(:);
    P    = numel(Xg);
    Rx   = [Xg(:)'; Yg(:)'; z*ones(1, P)];        % 3xP receiver positions
    dvec = Rx - T;                                % 3xP
    d    = sqrt(sum(dvec.^2, 1));                 % 1xP
    d(d < 1e-10) = 1e-10;
    nd   = dvec ./ d;                             % 3xP unit TX->RX
    cos_psi = -(nr' * nd);                        % 1xP incidence cosine
    Q       = nt_i' * nd;                         % 1xP = cos(phi)
    phi     = acos(min(1, max(-1, Q)));           % 1xP beam angular offset
    C_opt   = 2 * Pt * A_det / pi;
    R_G     = exp(-2 * (phi ./ theta_div).^2);
    mu      = C_opt ./ (theta_div^2 * d.^2) .* R_G .* cos_psi;   % 1xP
    gate    = (cos_psi > 0) & (cos_psi >= cos(Psi_FOV)) & (Q > 0);
    mu(~gate) = 0;
    MU = reshape(mu, size(Xg));
end
