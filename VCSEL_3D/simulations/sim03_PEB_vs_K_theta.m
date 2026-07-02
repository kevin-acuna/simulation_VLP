%% sim03_PEB_vs_K_theta.m — PEB over covered region vs K, per divergence angle
%
% Plots mean and P90 broadcast PEB (evaluated over COVERED positions only) as a
% function of K, one curve per theta_div. Loads the cached sweep from sim02;
% recomputes it if the cache is missing.
%
% Message: small divergence gives strong local accuracy where covered, but
% coverage (sim02) must be read jointly — see the tradeoff in sim04.
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

colors = lines(numel(S.theta_deg));

%% Figure 1: mean PEB over covered region
fig1 = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w'); hold on;
h = gobjects(numel(S.theta_deg),1);
for it = 1:numel(S.theta_deg)
    h(it) = plot(S.K, 100*S.mean_peb(it,:), '-o', 'LineWidth', 1.0, ...
        'MarkerSize', 4, 'Color', colors(it,:), 'MarkerFaceColor', colors(it,:));
end
xlabel('Number of orientations $K$', 'Interpreter','latex', 'FontSize', 8);
ylabel('Mean $\mathrm{PEB}$ over covered [cm]', 'Interpreter','latex', 'FontSize', 8);
grid on; box on; set(gca, 'XTick', S.K, 'FontSize', 7, 'LineWidth', 0.5);
legend(h, arrayfun(@(t) sprintf('$\\theta_{\\mathrm{div}}{=}%d^\\circ$', t), ...
    S.theta_deg, 'UniformOutput', false), 'Interpreter','latex', 'FontSize', 6, 'Location','northeast');

%% Figure 2: P90 PEB over covered region
fig2 = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w'); hold on;
h2 = gobjects(numel(S.theta_deg),1);
for it = 1:numel(S.theta_deg)
    h2(it) = plot(S.K, 100*S.p90_peb(it,:), '-s', 'LineWidth', 1.0, ...
        'MarkerSize', 4, 'Color', colors(it,:), 'MarkerFaceColor', colors(it,:));
end
xlabel('Number of orientations $K$', 'Interpreter','latex', 'FontSize', 8);
ylabel('P90 $\mathrm{PEB}$ over covered [cm]', 'Interpreter','latex', 'FontSize', 8);
grid on; box on; set(gca, 'XTick', S.K, 'FontSize', 7, 'LineWidth', 0.5);
legend(h2, arrayfun(@(t) sprintf('$\\theta_{\\mathrm{div}}{=}%d^\\circ$', t), ...
    S.theta_deg, 'UniformOutput', false), 'Interpreter','latex', 'FontSize', 6, 'Location','northeast');

if SAVE_FIGS
    exportgraphics(fig1, fullfile(results_dir, 'Fig03_meanPEB_vs_K.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig1, fullfile(results_dir, 'Fig03_meanPEB_vs_K.png'), 'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig2, fullfile(results_dir, 'Fig03_p90PEB_vs_K.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig2, fullfile(results_dir, 'Fig03_p90PEB_vs_K.png'), 'Resolution',600,'BackgroundColor','white');
    fprintf('Figures saved (pdf/png) to %s\n', results_dir);
end

%% Summary table
fprintf('\n=== Mean / P90 PEB over covered region [cm] ===\n');
for it = 1:numel(S.theta_deg)
    fprintf('theta=%2d deg:\n', S.theta_deg(it));
    for ik = 1:numel(S.K)
        fprintf('   K=%2d : mean=%6.2f  P90=%6.2f  (cov=%5.1f%%)\n', ...
            S.K(ik), 100*S.mean_peb(it,ik), 100*S.p90_peb(it,ik), 100*S.coverage(it,ik));
    end
end
