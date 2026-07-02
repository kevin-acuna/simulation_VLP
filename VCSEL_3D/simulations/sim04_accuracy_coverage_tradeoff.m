%% sim04_accuracy_coverage_tradeoff.m — Accuracy vs coverage Pareto map
%
% Scatter of every (K, theta_div) configuration: coverage on the x-axis, P90 PEB
% over the covered region on the y-axis. Colour encodes theta_div, marker label
% encodes K. Highlights the Pareto frontier (high coverage AND low error).
%
% Loads the cached sweep from sim02; recomputes if the cache is missing.
%
% Author: Kevin Acuna-Condori
% Project: VCSEL Gaussian OWP

clear; clc; close all;

%% Paths + params
project_root = fileparts(pwd);
addpath(fullfile(project_root, 'core'));
system_params_VCSEL;

SAVE_FIGS = true;
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

%% Load cached sweep or recompute
cache = fullfile(results_dir, 'sweep_K_theta.mat');
if exist(cache, 'file')
    load(cache, 'S');
    fprintf('Loaded cached sweep from %s\n', cache);
else
    fprintf('No cache found; running sweep...\n');
    params = struct('T', T, 'Pt', P_t, 'A_det', A_det, 'Psi_FOV', deg2rad(FOV), ...
        'sigma2', sigma2, 'N', N_samples, 'nr', n_r, ...
        'SNR_min_dB', SNR_min_dB, 'PEB_max_cov', PEB_max_cov);
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
    positions = [X(:), Y(:), Z(:)]';
    S = run_sweep_K_theta(theta_div_values, K_values, positions, params, theta_cap, 'sunflower');
    save(cache, 'S');
end

%% Scatter: coverage vs P90 PEB
fig = figure('Units','inches', 'Position',[1 1 3.6 2.8], 'Color','w'); hold on;
colors = lines(numel(S.theta_deg));

pts = [];  % [coverage, p90peb, theta_idx, K]
for it = 1:numel(S.theta_deg)
    for ik = 1:numel(S.K)
        cov = 100*S.coverage(it,ik);
        p90 = 100*S.p90_peb(it,ik);
        if ~isfinite(p90), continue; end
        scatter(cov, p90, 45, colors(it,:), 'filled', ...
            'MarkerEdgeColor','k', 'LineWidth', 0.3);
        text(cov+0.6, p90, sprintf('%d', S.K(ik)), 'FontSize', 5.5, ...
            'Interpreter','latex', 'Color', colors(it,:)*0.7);
        pts = [pts; cov, p90, it, S.K(ik)]; %#ok<AGROW>
    end
end

% Pareto frontier (maximize coverage, minimize P90 PEB)
if ~isempty(pts)
    [~, order] = sortrows([-pts(:,1), pts(:,2)]);  % high cov first, then low err
    frontier = [];
    best_err = inf;
    for i = 1:size(pts,1)
        p = pts(order(i), :);
        if p(2) < best_err
            frontier = [frontier; p]; %#ok<AGROW>
            best_err = p(2);
        end
    end
    frontier = sortrows(frontier, 1);
    plot(frontier(:,1), frontier(:,2), 'k--', 'LineWidth', 0.8, 'HandleVisibility','off');
end

xlabel('Coverage [\%]', 'Interpreter','latex', 'FontSize', 8);
ylabel('P90 $\mathrm{PEB}$ over covered [cm]', 'Interpreter','latex', 'FontSize', 8);
grid on; box on; set(gca, 'FontSize', 7, 'LineWidth', 0.5);

% Legend by theta only
hleg = gobjects(numel(S.theta_deg),1);
for it = 1:numel(S.theta_deg)
    hleg(it) = scatter(nan, nan, 45, colors(it,:), 'filled', 'MarkerEdgeColor','k');
end
legend(hleg, arrayfun(@(t) sprintf('$\\theta_{\\mathrm{div}}{=}%d^\\circ$', t), ...
    S.theta_deg, 'UniformOutput', false), 'Interpreter','latex', 'FontSize', 6, 'Location','northeast');
title('Dashed: Pareto frontier; labels: $K$', 'Interpreter','latex', 'FontSize', 7);

if SAVE_FIGS
    exportgraphics(fig, fullfile(results_dir, 'Fig04_accuracy_coverage_tradeoff.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig, fullfile(results_dir, 'Fig04_accuracy_coverage_tradeoff.png'), 'Resolution',600,'BackgroundColor','white');
    fprintf('Figure saved (pdf/png) to %s\n', results_dir);
end

%% Report best config under a coverage constraint
cov_target = 90;
fprintf('\n=== Best configs with coverage >= %d%% (min P90 PEB) ===\n', cov_target);
mask = pts(:,1) >= cov_target;
if any(mask)
    cand = pts(mask, :);
    [~, bi] = min(cand(:,2));
    b = cand(bi, :);
    fprintf('theta_div=%d deg, K=%d : coverage=%.1f%%, P90 PEB=%.2f cm\n', ...
        S.theta_deg(b(3)), b(4), b(1), b(2));
else
    fprintf('No configuration reaches %d%% coverage in the current sweep.\n', cov_target);
end
