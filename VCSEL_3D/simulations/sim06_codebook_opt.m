%% sim06_codebook_opt.m — Optimized codebook vs baselines (coverage & P90 PEB)
%
% Compares the GA-optimized VCSEL codebook against the sunflower / rings / random /
% dense baselines, at a fixed divergence, as a function of K (probing overhead).
% This is the design-contribution figure (paper_plan Fig. 6).
%
% Optimized codebooks are loaded from optimization/results/opt_codebooks.mat
% (run optimize_codebook_GA.m first). If absent, only baselines are shown.
%
% Author: Kevin Acuna-Condori
% Project: VCSEL Gaussian OWP (target IEEE TWC)

clear; clc; close all;
rng('default');

%% Paths + params
project_root = fileparts(pwd);
addpath(fullfile(project_root, 'core'));
system_params_VCSEL;

% =========================== CONFIGURATION ===========================
theta_div_deg = 15;              % divergence to display [deg]
K_list        = [7, 9, 13, 19];  % overhead values to compare
N_rand        = 20;              % random-baseline draws to average
SAVE_FIGS     = true;
% =====================================================================

theta_div = deg2rad(theta_div_deg);
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

params = struct('T', T, 'Pt', P_t, 'A_det', A_det, 'Psi_FOV', deg2rad(FOV), ...
    'sigma2', sigma2, 'N', N_samples, 'nr', n_r, ...
    'SNR_min_dB', SNR_min_dB, 'PEB_max_cov', PEB_max_cov);

[X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
positions = [X(:), Y(:), Z(:)]';
fprintf('Testbed: %d positions | theta_div=%d deg\n', size(positions,2), theta_div_deg);

%% Load optimized codebooks if available
opt_file = fullfile(project_root, 'optimization', 'results', 'opt_codebooks.mat');
have_opt = exist(opt_file, 'file');
if have_opt
    Lopt = load(opt_file, 'OPT');
    OPT = Lopt.OPT;
    fprintf('Loaded optimized codebooks from %s\n', opt_file);
else
    OPT = [];
    fprintf('[note] %s not found — showing baselines only.\n', opt_file);
end

methods = {'sunflower', 'rings', 'dense', 'random', 'optimized'};
markers = {'-o', '-s', '-^', '-d', '-p'};
colors  = lines(numel(methods));

cov = nan(numel(methods), numel(K_list));
p90 = nan(numel(methods), numel(K_list));

for ik = 1:numel(K_list)
    K = K_list(ik);
    for im = 1:numel(methods)
        m = methods{im};
        switch m
            case 'random'
                cc = zeros(1, N_rand); pp = zeros(1, N_rand);
                for s = 1:N_rand
                    rng(100 + s);
                    nt = generate_codebook(K, theta_cap, 'random');
                    r = evaluate_codebook(nt, theta_div, positions, params);
                    cc(s) = r.coverage;
                    pp(s) = r.p90_peb;
                end
                cov(im, ik) = mean(cc);
                p90(im, ik) = mean(pp(isfinite(pp)));
            case 'optimized'
                nt = get_opt_codebook(OPT, theta_div_deg, K);
                if isempty(nt), continue; end
                r = evaluate_codebook(nt, theta_div, positions, params);
                cov(im, ik) = r.coverage; p90(im, ik) = r.p90_peb;
            otherwise
                nt = generate_codebook(K, theta_cap, m);
                r = evaluate_codebook(nt, theta_div, positions, params);
                cov(im, ik) = r.coverage; p90(im, ik) = r.p90_peb;
        end
    end
end

%% Figure 1: coverage vs K
fig1 = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w'); hold on;
h = gobjects(numel(methods),1);
for im = 1:numel(methods)
    h(im) = plot(K_list, 100*cov(im,:), markers{im}, 'LineWidth', 1.0, ...
        'MarkerSize', 4, 'Color', colors(im,:), 'MarkerFaceColor', colors(im,:));
end
xlabel('Probing overhead $K$', 'Interpreter','latex', 'FontSize', 8);
ylabel('Coverage [\%]', 'Interpreter','latex', 'FontSize', 8);
ylim([0 100]); grid on; box on; set(gca, 'XTick', K_list, 'FontSize', 7, 'LineWidth', 0.5);
legend(h, methods, 'Interpreter','none', 'FontSize', 6, 'Location','southeast');
title(sprintf('$\\theta_{\\mathrm{div}}=%d^\\circ$', theta_div_deg), 'Interpreter','latex', 'FontSize', 8);

%% Figure 2: P90 PEB vs K
fig2 = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w'); hold on;
h2 = gobjects(numel(methods),1);
for im = 1:numel(methods)
    h2(im) = plot(K_list, 100*p90(im,:), markers{im}, 'LineWidth', 1.0, ...
        'MarkerSize', 4, 'Color', colors(im,:), 'MarkerFaceColor', colors(im,:));
end
xlabel('Probing overhead $K$', 'Interpreter','latex', 'FontSize', 8);
ylabel('P90 $\mathrm{PEB}$ over covered [cm]', 'Interpreter','latex', 'FontSize', 8);
grid on; box on; set(gca, 'XTick', K_list, 'FontSize', 7, 'LineWidth', 0.5);
legend(h2, methods, 'Interpreter','none', 'FontSize', 6, 'Location','northeast');
title(sprintf('$\\theta_{\\mathrm{div}}=%d^\\circ$', theta_div_deg), 'Interpreter','latex', 'FontSize', 8);

if SAVE_FIGS
    exportgraphics(fig1, fullfile(results_dir, 'Fig06_coverage_vs_K_methods.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig1, fullfile(results_dir, 'Fig06_coverage_vs_K_methods.png'), 'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig2, fullfile(results_dir, 'Fig06_p90PEB_vs_K_methods.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig2, fullfile(results_dir, 'Fig06_p90PEB_vs_K_methods.png'), 'Resolution',600,'BackgroundColor','white');
    fprintf('Figures saved to %s\n', results_dir);
end

%% Summary
fprintf('\n=== Coverage [%%] / P90 PEB [cm]  (theta_div=%d deg) ===\n', theta_div_deg);
fprintf('%-10s', 'K'); fprintf('%8d', K_list); fprintf('\n');
for im = 1:numel(methods)
    fprintf('%-10s', methods{im});
    for ik = 1:numel(K_list)
        fprintf(' %5.0f/%4.1f', 100*cov(im,ik), 100*p90(im,ik));
    end
    fprintf('\n');
end

%% --- local: fetch optimized codebook for (theta_deg, K) ---
function nt = get_opt_codebook(OPT, theta_deg, K)
    nt = [];
    if isempty(OPT), return; end
    for e = 1:numel(OPT)
        if OPT(e).theta_deg == theta_deg && OPT(e).K == K
            nt = OPT(e).nt; return;
        end
    end
end
