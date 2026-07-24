%% compare_orientations_PEB.m
% Compare TWO orientation sets under the SAME K for the broadcast (K-only) OWP.
%
% Fixes the hyperparameter K and evaluates the broadcast Position Error Bound
% PEB_B (via core/PEB_Konly.m) over the full 3D testbed for two user-chosen
% orientation sets. Produces:
%     (1) a CDF plot of PEB_B comparing both sets
%     (2) a console table comparing RMSE / MEAN / MEDIAN (plus P90 and the
%         localizable fraction, for context)
%
% Parameters come from the COVERAGE-ONLY file (SFH4725S Phi_half=36.7, BPX61
% PD, FOV=60, N=1000). Editing it affects ONLY this folder.
%
% Author: Cascade (for Kevin Acuna-Condori) -- Project F, Broadcast OWP

clear; clc; close all;

%% Paths
this_dir     = fileparts(mfilename('fullpath'));   % .../Coverage
project_root = fileparts(this_dir);                % .../F_broadcast_Konly
addpath(fullfile(project_root, 'core'));           % PEB_Konly
addpath(this_dir);                                 % system_params_coverage + orient_to_vectors
system_params_coverage;                            % *** COVERAGE-ONLY parameters ***

% =====================================================================
%                          CONFIGURATION
% =====================================================================
% --- Hyperparameter (fixed) ---
K = 9;                          % number of orientations/measurements

% --- The TWO orientation sets to compare (each must have K entries) ---
%   Pick any vector defined in system_params_coverage.m, or paste your own
%   [theta1,phi1, theta2,phi2, ...] in degrees. Both must match K above.
setA.label  = 'DEB_K9';
setA.orient = orientations_experiment;
setB.label  = 'PEB QoS=10 cm';
setB.orient = orientations_PEB_K9_QoS10;
% Other examples at K=5:
%   setA.orient = orientations_DEB_K5;             setA.label = 'DEB 45 deg';
%   setB.orient = orientations_DEB_K5_Phi30;       setB.label = 'DEB 30 deg';
%   setB.orient = orientations_PEB_K5_QoS10_fine;  setB.label = 'PEB QoS10 (fine)';

% --- Plot options ---
SAVE_FIGS   = true;             % export PDF/PNG/EPS to Coverage/results/
qos_ref_cm  = 10;                % draw a QoS reference line at this PEB [cm]; [] to disable
cdf_xmax_cm = [];               % x-axis upper limit [cm]; [] -> auto (P99 of both)
% =====================================================================

sets = [setA, setB];
for s = 1:2
    assert(mod(numel(sets(s).orient), 2) == 0 && numel(sets(s).orient)/2 == K, ...
        'Set "%s" has %d orientations, expected K=%d.', ...
        sets(s).label, numel(sets(s).orient)/2, K);
end

%% 3D Testbed grid (same room/step as the coverage analysis)
x_range = -L/2:step:L/2;
y_range = -W/2:step:W/2;
z_range = 0:stepH:Hmax;
[X, Y, Z] = meshgrid(x_range, y_range, z_range);
positions = [X(:), Y(:), Z(:)]';
N_pos = size(positions, 2);
fprintf('Testbed: %d positions | K=%d\n', N_pos, K);

%% Evaluate PEB_B over the testbed for each orientation set
res = struct('label', {}, 'peb', {}, 'v', {}, 'rmse', {}, 'mean', {}, ...
             'median', {}, 'p90', {}, 'loc', {}, 'nfin', {});
for s = 1:2
    nt  = orient_to_vectors(sets(s).orient);       % 3 x K unit vectors
    peb = inf(1, N_pos);
    for ip = 1:N_pos
        p = PEB_Konly(positions(:, ip), nt, T(:), P_t, m_t, A_det, ...
                      deg2rad(FOV), sigma2, N_samples, n_r(:));
        if isfinite(p) && p > 0
            peb(ip) = p;                            % else stays Inf (not localizable)
        end
    end
    fin = isfinite(peb);
    v   = peb(fin);                                 % localizable PEB values [m]

    res(s).label  = sets(s).label;
    res(s).peb    = peb;
    res(s).v      = v;
    res(s).rmse   = sqrt(mean(v.^2));
    res(s).mean   = mean(v);
    res(s).median = median(v);
    res(s).p90    = prctile(v, 90);
    res(s).loc    = mean(fin);                      % localizable fraction
    res(s).nfin   = sum(fin);

    fprintf('%-14s: RMSE=%.2f cm, mean=%.2f cm, median=%.2f cm, localizable=%.1f%%\n', ...
        res(s).label, 100*res(s).rmse, 100*res(s).mean, 100*res(s).median, 100*res(s).loc);
end

%% Figure: CDF of PEB_B for both sets
fig = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w');
colors = [0 0.45 0.74; 0.85 0.33 0.10];
styles = {'-', '--'};
hold on;
for s = 1:2
    xs = sort(res(s).v) * 100;                      % cm
    ys = (1:numel(xs)) / numel(xs);
    plot(xs, ys, styles{s}, 'LineWidth', 1.2, 'Color', colors(s,:));
end

% Axis limits
allv = [res(1).v, res(2).v] * 100;
if isempty(cdf_xmax_cm), xmax = prctile(allv, 99); else, xmax = cdf_xmax_cm; end
ylim([0, 1]);

% Optional QoS reference line
if ~isempty(qos_ref_cm)
    xline(qos_ref_cm, ':', sprintf('QoS %g cm', qos_ref_cm), ...
        'Color', [0.4 0.4 0.4], 'LineWidth', 0.8, 'FontSize', 6, ...
        'LabelVerticalAlignment', 'bottom', 'LabelOrientation', 'horizontal');
end

xlabel('$\mathrm{PEB}_\mathrm{B}$ [cm]', 'Interpreter', 'latex', 'FontSize', 8);
ylabel('CDF', 'Interpreter', 'latex', 'FontSize', 8);
legend({res(1).label, res(2).label}, 'Location', 'southeast', ...
    'Interpreter', 'none', 'FontSize', 6);
grid on;
set(gca, 'FontSize', 7, 'LineWidth', 0.5);
title(sprintf('PEB$_\\mathrm{B}$ CDF ($K=%d$)', K), 'Interpreter', 'latex', 'FontSize', 8);

%% Save
results_dir = fullfile(this_dir, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
if SAVE_FIGS
    base = fullfile(results_dir, sprintf('Fig_compare_orientations_K%d', K));
    exportgraphics(fig, [base '.pdf'], 'ContentType','vector', 'BackgroundColor','white');
    exportgraphics(fig, [base '.png'], 'Resolution',600, 'BackgroundColor','white');
    exportgraphics(fig, [base '.eps'], 'ContentType','vector', 'BackgroundColor','white');
    fprintf('Figures saved to: %s\n', results_dir);
end

%% Comparison table (RMSE / MEAN / MEDIAN + context)
fprintf('\n=== PEB_B comparison (K=%d, testbed=%d pts) ===\n', K, N_pos);
fprintf('%-16s | %-16s | %-16s\n', 'Metric', res(1).label, res(2).label);
fprintf('%s\n', repmat('-', 1, 56));
fprintf('%-16s | %14.2f   | %14.2f\n', 'RMSE [cm]',        100*res(1).rmse,   100*res(2).rmse);
fprintf('%-16s | %14.2f   | %14.2f\n', 'Mean [cm]',        100*res(1).mean,   100*res(2).mean);
fprintf('%-16s | %14.2f   | %14.2f\n', 'Median [cm]',      100*res(1).median, 100*res(2).median);
fprintf('%-16s | %14.2f   | %14.2f\n', 'P90 [cm]',         100*res(1).p90,    100*res(2).p90);
fprintf('%-16s | %14.1f   | %14.1f\n', 'Localizable [%]',  100*res(1).loc,    100*res(2).loc);
fprintf('%-16s | %14d   | %14d\n',     'N (finite)',       res(1).nfin,       res(2).nfin);

[~, best] = min([res(1).rmse, res(2).rmse]);
fprintf('\nLower RMSE: %s\n', res(best).label);

%% Orientation geometry figure (3D quiver, like optimization/PEB_Konly_monitor.m)
figOri = figure('Units','inches', 'Position',[1 1 7.0 3.2], 'Color','w');
for s = 1:2
    ax = subplot(1, 2, s);
    plot_orientation_set(ax, sets(s).orient, res(s).label);
end
sgtitle(sprintf('LED orientation geometry (K=%d, top view)', K));
if SAVE_FIGS
    baseO = fullfile(results_dir, sprintf('Fig_orientation_sets_K%d', K));
    exportgraphics(figOri, [baseO '.pdf'], 'ContentType','image', 'Resolution',600, 'BackgroundColor','white');  % raster: 3D scene
    exportgraphics(figOri, [baseO '.png'], 'Resolution',600, 'BackgroundColor','white');
    fprintf('Orientation figure saved: %s.(pdf/png)\n', baseO);
end

fprintf('Done.\n');

%% ===================== local functions =====================
function plot_orientation_set(ax, orient, ttl)
%PLOT_ORIENTATION_SET  3D quiver of LED orientation unit vectors (nadir-referenced).
    K = numel(orient) / 2;
    colors = lines(K);
    hold(ax, 'on');
    for i = 1:K
        th = deg2rad(orient(2*i-1));               % elevation (tilt from nadir)
        rh = deg2rad(orient(2*i));                 % azimuth
        nt = [sin(th)*cos(rh); sin(th)*sin(rh); -cos(th)];
        quiver3(ax, 0, 0, 0, nt(1), nt(2), nt(3), 0.85, ...
            'Color', colors(i,:), 'LineWidth', 2, 'MaxHeadSize', 0.5);
        text(ax, nt(1)*0.95, nt(2)*0.95, nt(3)*0.95, sprintf(' %d', i), ...
            'FontSize', 7, 'Color', colors(i,:), 'FontWeight', 'bold');
    end
    [Xs, Ys, Zs] = sphere(20);
    Zs = -abs(Zs);                                  % lower hemisphere (downward beams)
    surf(ax, Xs*0.3, Ys*0.3, Zs*0.3, 'FaceAlpha',0.08, 'EdgeAlpha',0.1, ...
        'FaceColor', [0.7 0.7 0.7], 'HandleVisibility','off');
    xlabel(ax, 'X'); ylabel(ax, 'Y'); zlabel(ax, 'Z');
    title(ax, ttl, 'Interpreter', 'none', 'FontSize', 8);
    axis(ax, 'equal'); grid(ax, 'on');
    view(ax, 90, 90);                               % top-down view (as in the monitor)
    xlim(ax, [-1 1]); ylim(ax, [-1 1]); zlim(ax, [-1 0.2]);
    hold(ax, 'off');
end
