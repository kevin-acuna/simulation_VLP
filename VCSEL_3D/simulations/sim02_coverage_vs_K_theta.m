%% sim02_coverage_vs_K_theta.m — Coverage vs number of orientations K
%
% For each divergence angle theta_div, evaluates uniform spherical-cap codebooks
% of increasing K over the full 3D testbed and reports the covered fraction.
%
% Message: narrow VCSEL beams need more orientations to cover the same room.
%
% Runs the full (K x theta) sweep ONCE and caches it to
%   results/sweep_K_theta.mat   (reused by sim03 and sim04).
%
% Author: Kevin Acuna-Condori
% Project: VCSEL Gaussian OWP

clear; clc; close all;

%% Paths + params
project_root = fileparts(pwd);
addpath(fullfile(project_root, 'core'));
system_params_VCSEL;

SAVE_FIGS = true;

params = struct('T', T, 'Pt', P_t, 'A_det', A_det, 'Psi_FOV', deg2rad(FOV), ...
    'sigma2', sigma2, 'N', N_samples, 'nr', n_r, ...
    'SNR_min_dB', SNR_min_dB, 'PEB_max_cov', PEB_max_cov);

%% 3D testbed
x_range = -L/2:step:L/2;
y_range = -W/2:step:W/2;
z_range = 0:stepH:Hmax;
[X, Y, Z] = meshgrid(x_range, y_range, z_range);
positions = [X(:), Y(:), Z(:)]';
fprintf('Testbed: %d positions | theta_div=[%s] deg | K=[%s]\n', ...
    size(positions,2), num2str(theta_div_values), num2str(K_values));

%% Run the (K x theta) sweep
t0 = tic;
S = run_sweep_K_theta(theta_div_values, K_values, positions, params, theta_cap, 'sunflower');
fprintf('Sweep done in %.1f s\n', toc(t0));

%% Cache results (used by sim03/sim04)
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
save(fullfile(results_dir, 'sweep_K_theta.mat'), 'S', 'params', 'theta_cap');
write_sweep_csv(fullfile(results_dir, 'sweep_K_theta.csv'), S);

%% Figure: coverage vs K, one curve per theta_div
fig = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w');
colors = lines(numel(theta_div_values));
hold on;
h = gobjects(numel(theta_div_values), 1);
for it = 1:numel(theta_div_values)
    h(it) = plot(S.K, 100*S.coverage(it,:), '-o', 'LineWidth', 1.0, ...
        'MarkerSize', 4, 'Color', colors(it,:), 'MarkerFaceColor', colors(it,:));
end
xlabel('Number of orientations $K$', 'Interpreter','latex', 'FontSize', 8);
ylabel('Coverage [\%]', 'Interpreter','latex', 'FontSize', 8);
ylim([0 100]); grid on; box on;
set(gca, 'XTick', S.K, 'FontSize', 7, 'LineWidth', 0.5);
legend(h, arrayfun(@(t) sprintf('$\\theta_{\\mathrm{div}}{=}%d^\\circ$', t), ...
    theta_div_values, 'UniformOutput', false), ...
    'Interpreter','latex', 'FontSize', 6, 'Location','southeast');

if SAVE_FIGS
    exportgraphics(fig, fullfile(results_dir, 'Fig02_coverage_vs_K.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig, fullfile(results_dir, 'Fig02_coverage_vs_K.png'), 'Resolution',600,'BackgroundColor','white');
    fprintf('Figure saved (pdf/png) to %s\n', results_dir);
end

%% Summary table
fprintf('\n=== Coverage [%%] ===\n');
fprintf('%-10s', 'theta\\K');
fprintf('%8d', S.K); fprintf('\n');
for it = 1:numel(theta_div_values)
    fprintf('%-10d', theta_div_values(it));
    fprintf('%8.1f', 100*S.coverage(it,:)); fprintf('\n');
end

%% --- Local: dump the sweep to CSV ---
function write_sweep_csv(fname, S)
    fid = fopen(fname, 'w');
    fprintf(fid, 'theta_div_deg,K,coverage,outage,mean_peb_cm,p90_peb_cm,median_peb_cm,mean_snr_db\n');
    for it = 1:numel(S.theta_deg)
        for ik = 1:numel(S.K)
            fprintf(fid, '%d,%d,%.4f,%.4f,%.3f,%.3f,%.3f,%.2f\n', ...
                S.theta_deg(it), S.K(ik), S.coverage(it,ik), S.outage(it,ik), ...
                100*S.mean_peb(it,ik), 100*S.p90_peb(it,ik), 100*S.median_peb(it,ik), ...
                S.mean_snr_dB(it,ik));
        end
    end
    fclose(fid);
end
