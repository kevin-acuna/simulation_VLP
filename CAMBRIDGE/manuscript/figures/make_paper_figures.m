function make_paper_figures(parts)
% Figures and numbers of the manuscript, computed directly from the acquired datasets.
%   make_paper_figures                      % every part
%   make_paper_figures({'grid', 'random'})  % selected parts: grid | random | noise | peb | calib | leds | sim | axis | zero | nine
%   (on request only: 'response', whose figure is no longer in the manuscript; 'redraw' = figures from saved results)
% Numbers are merged into paper_numbers.json (read when writing the manuscript); figures are vector PDF
% (PNG previews in png/). Run with MATLAB R2026a or later.
if nargin < 1 || isempty(parts)
    parts = {'grid', 'random', 'noise', 'peb', 'calib', 'leds', 'sim', 'axis', 'zero', 'nine'};
end
parts = cellstr(parts);
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'lib'));
cfg = pp_config();
addpath(cfg.sim);
cambridge_setup();
if ~isfolder(fullfile(cfg.figdir, 'png'))
    mkdir(fullfile(cfg.figdir, 'png'));
end
numbers_file = fullfile(cfg.figdir, 'paper_numbers.json');
NUM = struct();
if isfile(numbers_file)
    NUM = jsondecode(fileread(numbers_file));
end
for k = 1:numel(parts)
    fprintf('\n=== %s ===\n', parts{k});
    t0 = tic;
    out = feval(['part_' parts{k}], cfg);
    if ~isempty(out)
        NUM.(parts{k}) = out;
    end
    fprintf('    (%.0f s)\n', toc(t0));
    fid = fopen(numbers_file, 'w');
    fprintf(fid, '%s', jsonencode(NUM, 'PrettyPrint', true));
    fclose(fid);
end
end

%% ------------------------------------------------------------------------------------------------------
function R = part_grid(cfg)
% D2: 125 sites, K = 10. Calibration of every receiver model on D1, MTRS offset from the RSS shape,
% ablation path, estimator and model comparison, per-height results and error versus K.
D = pp_load_sites(cfg.grid_dirs, cfg);
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
rss = D.rss(:, :, jf);
fprintf('D2: %d sites, K = %d, levels %s mm\n', size(rss, 2), D.K, mat2str(D.levels));
[cal, h_cal] = load_calibration_scan(cfg);
models = {'cosine', 'cosine_mR', 'SQ'};
leds = struct('max', cfg.led_xy_max_mm, 'fit', cfg.led_xy_mm);
% LED XY from the joint fit of D1 (SQ)
p0 = pp_params(cfg, 'SQ', 1, 6, cfg.led_xy_max_mm);
[A_xy, m_xy, xy_fit] = pp_calibrate(cal.x, cal.y, cal.rss(:, jf), cfg.led_xy_max_mm, h_cal, p0, 'joint_xy');
R.led_xy_fit_mm = xy_fit;
R.led_xy_fit_A = A_xy;
R.led_xy_fit_m = m_xy;
fprintf('LED XY joint fit (SQ): (%.1f, %.1f) mm, A %.5g, m %.3f\n', xy_fit, A_xy, m_xy);
P = struct();
for im = 1:numel(models)
    for led = fieldnames(leds)'
        pm = pp_params(cfg, models{im}, 1, 6, leds.(led{1}));
        [A, m, ~, info] = pp_calibrate(cal.x, cal.y, cal.rss(:, jf), leds.(led{1}), h_cal, pm, 'staged');
        P.(models{im}).(led{1}) = pp_params(cfg, models{im}, A, m, leds.(led{1}));
        R.calibration.(models{im}).(led{1}) = struct('A', A, 'm', m, 'rms_log_pct', 100*info.rms_log, ...
            'phi_max_deg', info.phi_max_deg);
        fprintf('  %-10s LED %-3s: A %.5g V m^2, m %.4f (rms %.2f %%)\n', models{im}, led{1}, A, m, 100*info.rms_log);
    end
end
% MTRS offset from the RSS shape: all sites, and cross-height (each height from the other four)
nominal = cfg.nominal_offset_deg;
OFF = struct();
for im = 1:numel(models)
    for led = fieldnames(leds)'
        p = P.(models{im}).(led{1});
        [rms_nom] = pp_shape('rms', D.truth, D.theta, rss, true(1, size(rss, 2)), nominal, cfg.tilt_deg, p);
        [rms_all, off_all] = pp_shape('fit', D.truth, D.theta, rss, true(1, size(rss, 2)), nominal, cfg.tilt_deg, p);
        cross = zeros(1, size(rss, 2));
        per_level = zeros(1, numel(D.levels));
        for l = 1:numel(D.levels)
            [~, per_level(l)] = pp_shape('fit', D.truth, D.theta, rss, D.level ~= l, nominal, cfg.tilt_deg, p);
            cross(D.level == l) = per_level(l);
        end
        % one stage zero per model and LED position, fitted on all of D2 (66.5 deg for SQ), used at every height
        OFF.(models{im}).(led{1}) = struct('all', off_all, 'cross', repmat(off_all, 1, numel(cross)));
        R.shape.(models{im}).(led{1}) = struct('rms_nominal_pct', rms_nom, 'rms_fitted_pct', rms_all, ...
            'offset_all_deg', off_all, 'offset_cross_deg', per_level);
        fprintf('  shape %-10s LED %-3s: nominal %.2f %%, fitted %.2f %% at %.2f deg; cross %s\n', models{im}, ...
            led{1}, rms_nom, rms_all, off_all, mat2str(per_level, 4));
    end
end
% estimates
run = @(model, led, method, offset) site_errors(pp_estimate(model, method, rss, D.theta, offset, ...
    cfg.tilt_deg, P.(model).(led)), D, P.(model).(led));
steps = {'cosine', 'max', 'nominal'; 'cosine_mR', 'max', 'nominal'; 'SQ', 'max', 'nominal'; ...
         'SQ', 'max', 'cross'; 'SQ', 'fit', 'cross'};
step_names = {'cos_nominal', 'cosmR_nominal', 'SQ_nominal', 'SQ_offset', 'SQ_offset_ledxy'};
for s = 1:size(steps, 1)
    off = offset_value(OFF, steps{s, 1}, steps{s, 2}, steps{s, 3}, nominal);
    e = run(steps{s, 1}, steps{s, 2}, 'NLS', off);
    R.ablation.(step_names{s}) = e.summary;
    fprintf('  ablation %-16s mean %.2f cm (ok %d/%d)\n', step_names{s}, e.summary.err3d.mean, ...
        e.summary.err3d.n_ok, e.summary.err3d.n);
end
% models x estimators (final LED, cross-height offsets)
for im = 1:numel(models)
    for meth = {'GLS', 'WLS', 'NLS'}
        e = run(models{im}, 'fit', meth{1}, OFF.(models{im}).fit.cross);
        R.methods.(models{im}).(meth{1}) = e.summary;
        fprintf('  %-10s %s: mean %.2f, RMSE %.2f, P90 %.2f, ok %d\n', models{im}, meth{1}, ...
            e.summary.err3d.mean, e.summary.err3d.rmse, e.summary.err3d.p90, e.summary.err3d.n_ok);
    end
end
% final configuration: SQ + NLS, LED fit; offset cross-height (reported) and the demo value 66.5 (all sites)
pf = P.SQ.fit;
Ef = pp_estimate('SQ', 'NLS', rss, D.theta, OFF.SQ.fit.cross, cfg.tilt_deg, pf);
ef = site_errors(Ef, D, pf);
R.final = ef.summary;
R.final_per_level = ef.per_level;
Ed = pp_estimate('SQ', 'NLS', rss, D.theta, cfg.offset_deg, cfg.tilt_deg, pf);
ed = site_errors(Ed, D, pf);
R.final_demo_offset = ed.summary;
fprintf('  final (cross offsets): mean %.2f cm; with offset %.1f: %.2f cm\n', ef.summary.err3d.mean, ...
    cfg.offset_deg, ed.summary.err3d.mean);
R.final_sites = struct('err3d_cm', ef.err3d, 'eh_cm', ef.eh, 'ev_cm', ef.ev, 'dir_deg', ef.dir, ...
    'z_mm', D.z_mm, 'xy_mm', D.xy_mm, 'shape_rms_pct', Ef.shape_rms);
% error versus K (near-uniform subsets of the 10 angles, all rotations), offsets fixed from K = 10
Kv = 3:10;
for k = 1:numel(Kv)
    sub = angle_subsets(D.K, Kv(k));
    e = [];
    for s = 1:size(sub, 1)
        Es = pp_estimate('SQ', 'NLS', rss(sub(s, :), :), D.theta(sub(s, :), :), OFF.SQ.fit.cross, cfg.tilt_deg, pf);
        es = site_errors(Es, D, pf);
        e = [e es.err3d]; %#ok<AGROW>
    end
    R.K.(sprintf('K%d', Kv(k))) = pp_stats(e);
    R.K.(sprintf('K%d', Kv(k))).subsets = size(sub, 1);
    fprintf('  K = %2d: %2d subsets, mean %.2f, P90 %.2f, failures %d\n', Kv(k), size(sub, 1), ...
        mean(e(isfinite(e))), prctile(e(isfinite(e)), 90), nnz(~isfinite(e)));
end
save(fullfile(cfg.figdir, 'grid_results.mat'), 'D', 'Ef', 'ef', 'pf', 'OFF', 'R', 'cfg');
figure_grid(cfg, D, ef, R);
end

function off = offset_value(OFF, model, led, kind, nominal)
switch kind
    case 'nominal'
        off = nominal;
    case 'cross'
        off = OFF.(model).(led).cross;
    case 'all'
        off = OFF.(model).(led).all;
end
end

function out = site_errors(E, D, p)
% 3D, horizontal and vertical errors (cm), direction error (deg), summary and per-height statistics
e = E.r - D.truth;
out.err3d = 100*vecnorm(e);
out.eh = 100*vecnorm(e(1:2, :));
out.ev = 100*e(3, :);
t = p.transmitter.position_m;
u = (t - D.truth)./vecnorm(t - D.truth);
out.dir = acosd(min(1, sum(E.u.*u)));
out.summary = struct('err3d', pp_stats(out.err3d), 'horizontal_mean', mean(out.eh, 'omitnan'), ...
    'vertical_bias', mean(out.ev, 'omitnan'), 'direction_mean_deg', mean(out.dir, 'omitnan'));
for l = 1:numel(D.levels)*(numel(D.levels) <= 10)
    sel = D.level == l;
    out.per_level(l) = struct('z_mm', D.levels(l), 'pd_height_m', D.truth(3, find(sel, 1)), ...
        'err3d', pp_stats(out.err3d(sel)), 'horizontal_mean', mean(out.eh(sel), 'omitnan'), ...
        'vertical_bias', mean(out.ev(sel), 'omitnan'), 'direction_mean_deg', mean(out.dir(sel), 'omitnan'));
end
end

function subsets = angle_subsets(K_full, K)
% Near-uniform subsets of K of the K_full equally spaced angles (row indices), with all their rotations
base = round((0:K - 1)*K_full/K);
subsets = unique(sort(mod(base + (0:K_full - 1)', K_full), 2) + 1, 'rows');
end

function [cal, h] = load_calibration_scan(cfg)
% D1 calibration subset: the first cfg.cal_n points of the flat-PD scan (as used by the demo)
opts = detectImportOptions(fullfile(cfg.scan_dir, 'points.csv'), 'VariableNamingRule', 'preserve');
cols = [{'meas_id', 'x_cmd_mm', 'y_cmd_mm'}, arrayfun(@(f) sprintf('%dkHz_wave_Vrms', f), cfg.led_freqs_khz, ...
    'UniformOutput', false)];
opts.SelectedVariableNames = cols;
t = readtable(fullfile(cfg.scan_dir, 'points.csv'), opts);
t = t(t.meas_id <= cfg.cal_n, :);
cal.x = t.x_cmd_mm;
cal.y = t.y_cmd_mm;
cal.rss = t{:, 4:end};
h = cfg.H_led - (cfg.H_base0 + cfg.scan_z_mm/1e3 + cfg.pd_elev);
end

function figure_grid(cfg, D, ef, R) %#ok<INUSL>
% mean error per height of D2: 3D, horizontal and signed vertical (ticks at the five heights, curves labelled
% directly in the gap between the two highest levels)
fig = pp_figure(3.5, 1.45);
H = arrayfun(@(s) s.pd_height_m, R.final_per_level);
m3 = arrayfun(@(s) s.err3d.mean, R.final_per_level);
mh = arrayfun(@(s) s.horizontal_mean, R.final_per_level);
vb = arrayfun(@(s) s.vertical_bias, R.final_per_level);
col = [0 0.32 0.62; 0.85 0.33 0.1; 0.38 0.58 0.12];
ax = axes(fig);
hold(ax, 'on');
yline(ax, 0, 'k-', 'LineWidth', 0.4);
plot(ax, H, m3, 'o-', 'Color', col(1, :), 'MarkerFaceColor', col(1, :), 'MarkerSize', 3.5);
plot(ax, H, mh, '^-', 'Color', col(2, :), 'MarkerFaceColor', col(2, :), 'MarkerSize', 3.5);
plot(ax, H, vb, 'v-', 'Color', col(3, :), 'MarkerFaceColor', col(3, :), 'MarkerSize', 3.5);
xt = 1.235;
label = @(y, s, k, va) text(ax, xt, y, s, 'Color', col(k, :), 'FontSize', 7, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', va);
label(interp1(H, m3, xt) + 0.3, '3-D', 1, 'bottom');
label(interp1(H, mh, xt) - 0.3, 'Horizontal', 2, 'top');
label(interp1(H, vb, xt) - 1.0, 'Vertical (signed)', 3, 'top');
xlabel(ax, 'PD height above the floor (m)');
ylabel(ax, 'Mean error (cm)');
xlim(ax, [0.93 1.34]);
xticks(ax, sort(H));
xticklabels(ax, compose('%.3f', sort(H)));
ylim(ax, [-3.2 5.2]);
yticks(ax, -2:2:4);
pp_export(fig, cfg, 'fig_grid_height');
end

%% ------------------------------------------------------------------------------------------------------
function R = part_random(cfg)
% D3: blind random positions of the live demo (K = 5), calibration fixed before the test. Integrity: the
% session hit by the rotation-stage tilt fault (points 48-91 of 16/10, excluded from D3). Timing.
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
p = pp_params(cfg, 'SQ', cfg.A, cfg.m, cfg.led_xy_mm);
D = pp_load_sites(cfg.random_dirs, cfg, cfg.random_keep);
E = pp_estimate('SQ', 'NLS', D.rss(:, :, jf), D.theta, cfg.offset_deg, cfg.tilt_deg, p);
e = site_errors(E, D, p);
R.test = e.summary;
R.test_pd_height_range_m = [min(D.truth(3, :)) max(D.truth(3, :))];
R.test_xy_range_m = [min(D.truth(1:2, :), [], 'all') max(D.truth(1:2, :), [], 'all')];
border = min([D.truth(1:2, :) - 0.1; 1.3 - D.truth(1:2, :)]) < 0.15;   % within 0.15 m of the border of [0.1, 1.3] m
R.test_border = struct('width_m', 0.15, 'n_border', nnz(border), 'mean_border_cm', mean(e.err3d(border)), ...
    'mean_interior_cm', mean(e.err3d(~border)));
live = [];
for c = 1:numel(cfg.random_dirs)
    t = readtable(fullfile(cfg.random_dirs{c}, 'estimates.csv'), 'VariableNamingRule', 'preserve');
    live = [live; t.err_3d_cm(t.point_id <= cfg.random_keep(c))]; %#ok<AGROW>
end
R.max_abs_diff_vs_live_cm = max(abs(live(:)' - e.err3d));
fprintf('D3: %d points, mean %.2f, median %.2f, RMSE %.2f, P90 %.2f, max %.2f cm; horizontal %.2f, vertical %.2f; |MATLAB - live| <= %.2g cm\n', ...
    numel(e.err3d), e.summary.err3d.mean, e.summary.err3d.median, e.summary.err3d.rmse, e.summary.err3d.p90, ...
    e.summary.err3d.max, e.summary.horizontal_mean, e.summary.vertical_bias, R.max_abs_diff_vs_live_cm);
% integrity: the whole 16/10 session (91 points) and the residual of the valid data
F = pp_load_sites(cfg.random_dirs(1), cfg, Inf);
EF = pp_estimate('SQ', 'NLS', F.rss(:, :, jf), F.theta, cfg.offset_deg, cfg.tilt_deg, p);
eF = site_errors(EF, F, p);
before = F.site <= cfg.random_keep(1);
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
threshold = ceil(10*max(G.Ef.shape_rms))/10;   % largest residual of the fault-free grid data, rounded up
R.integrity = struct('threshold_pct', threshold, 'shape_D2_max_pct', max(G.Ef.shape_rms), ...
    'shape_D3_max_pct', max(E.shape_rms), 'shape_before_max_pct', max(EF.shape_rms(before)), ...
    'shape_before_median_pct', median(EF.shape_rms(before)), 'shape_before_p95_pct', prctile(EF.shape_rms(before), 95), ...
    'shape_after_median_pct', median(EF.shape_rms(~before)), 'shape_after_min_pct', min(EF.shape_rms(~before)), ...
    'err_before_mean_cm', mean(eF.err3d(before)), 'err_after_mean_cm', mean(eF.err3d(~before)), ...
    'err_after_max_cm', max(eF.err3d(~before)), 'n_after', nnz(~before), ...
    'tilt_reading_after_max_deg', max(abs(F.tilt_read(:, ~before)), [], 'all'), ...
    'tilt_reading_before_max_deg', max(abs(F.tilt_read(:, before)), [], 'all'), ...
    'flag_rate_after', mean(EF.shape_rms(~before) > threshold), 'flag_rate_D3', mean(E.shape_rms > threshold), ...
    'flag_rate_D2', mean(G.Ef.shape_rms > threshold), 'shape_D2_median_pct', median(G.Ef.shape_rms), ...
    'shape_D2_p95_pct', prctile(G.Ef.shape_rms, 95), 'shape_D3_median_pct', median(E.shape_rms));
% operational rule: alarm after r consecutive residuals above the threshold (per session, acquisition order)
for r = 2:3
    after_flags = EF.shape_rms(~before) > threshold;
    delay = find(movsum(after_flags, [r - 1 0]) == r, 1);
    false_alarms = 0;
    for c = 1:numel(cfg.random_dirs)
        fl = E.shape_rms(D.campaign == c) > threshold;
        false_alarms = false_alarms + nnz(movsum(fl, [r - 1 0]) == r);
    end
    R.integrity.(sprintf('run%d_detection_point', r)) = 47 + delay;
    R.integrity.(sprintf('run%d_false_alarms_D3', r)) = false_alarms;
end
fprintf('integrity: shape before %.2f %% / after %.2f %% (median), error %.2f -> %.2f cm, flags after %.0f %%, D3 %.1f %%, D2 %.1f %%\n', ...
    R.integrity.shape_before_median_pct, R.integrity.shape_after_median_pct, R.integrity.err_before_mean_cm, ...
    R.integrity.err_after_mean_cm, 100*R.integrity.flag_rate_after, 100*R.integrity.flag_rate_D3, 100*R.integrity.flag_rate_D2);
R.timing = timing(cfg);
% CDF of the grid (K = 10, 5, 3) and of the blind test
pf = G.pf;
cdf = struct('K10', G.ef.err3d, 'K5', [], 'K3', [], 'D3', e.err3d);
for K = [5 3]
    sub = angle_subsets(G.D.K, K);
    for s = 1:size(sub, 1)
        Es = pp_estimate('SQ', 'NLS', G.D.rss(sub(s, :), :, jf), G.D.theta(sub(s, :), :), G.OFF.SQ.fit.cross, cfg.tilt_deg, pf);
        es = site_errors(Es, G.D, pf);
        cdf.(sprintf('K%d', K)) = [cdf.(sprintf('K%d', K)) es.err3d];
    end
end
save(fullfile(cfg.figdir, 'random_results.mat'), 'D', 'E', 'e', 'F', 'EF', 'eF', 'cdf', 'cfg');
figure_cdf(cfg, cdf);
figure_random(cfg, D, E, e);
figure_integrity(cfg, F, EF, eF, threshold);
end

function T = timing(cfg)
% acquisition time per position from the session records
T = struct();
total = 0; sites = 0; rot = 0; est = 0;
for c = 1:numel(cfg.grid_dirs)
    txt = fileread(fullfile(cfg.grid_dirs{c}, 'session.json'));
    s = jsondecode(txt);
    stamp = @(key) datetime(regexp(txt, ['"' key '":\s*"([^"]+)"'], 'tokens', 'once'), ...
        'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSSSS');
    total = total + seconds(stamp('end') - stamp('start'));
    sites = sites + s.n_sites;
    rot = rot + s.estimate_breakdown.mtrs_rotation_s;
    est = est + s.estimated_total_s;
end
T.grid_min_per_site = total/sites/60;
T.grid_rotation_share = rot/est;
m = [];
for c = 1:numel(cfg.random_dirs)
    s = jsondecode(fileread(fullfile(cfg.random_dirs{c}, 'session.json')));
    m(end + 1) = s.summary.mean_time_s; %#ok<AGROW>
end
T.random_min_per_point = mean(m)/60;
fprintf('timing: grid %.2f min/site (rotation %.0f %%), random %.2f min/point\n', T.grid_min_per_site, ...
    100*T.grid_rotation_share, T.random_min_per_point);
end

function figure_cdf(cfg, cdf)
fig = pp_figure(3.5, 2.3);
ax = axes(fig);
hold(ax, 'on');
% short labels (the caption gives the details) so that the legend does not cover the curves
specs = {'K10', '-', [0 0.32 0.62], 'D2, $K=10$'; ...
         'K5', '-', [0.85 0.33 0.1], 'D2, $K=5$'; ...
         'K3', '-', [0.47 0.67 0.19], 'D2, $K=3$'; ...
         'D3', '--', [0 0 0], 'D3, $K=5$'};
for s = 1:size(specs, 1)
    v = sort(cdf.(specs{s, 1})(isfinite(cdf.(specs{s, 1}))));
    stairs(ax, [0 v], (0:numel(v))/numel(v), specs{s, 2}, 'Color', specs{s, 3}, 'LineWidth', 1.1, ...
        'DisplayName', sprintf('%s: %.2f cm', specs{s, 4}, mean(v)));
end
xlim(ax, [0 12]);
ylim(ax, [0 1]);
xlabel(ax, '3-D position error (cm)');
ylabel(ax, 'Empirical CDF');
legend(ax, 'Location', 'southeast');
pp_export(fig, cfg, 'fig_cdf');
end

function figure_random(cfg, D, E, e)
% true (hollow) and estimated (colour = 3D error) positions of the blind test: 3D view and top view
fig = pp_figure(7.16, 2.75);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
vmax = 8;
cmap = parula(256);
col = @(err) cmap(max(1, min(256, round(err/vmax*255) + 1)), :);
ax = nexttile(tl);
hold(ax, 'on');
for i = 1:size(D.truth, 2)
    plot3(ax, [D.truth(1, i) E.r(1, i)], [D.truth(2, i) E.r(2, i)], [D.truth(3, i) E.r(3, i)], '-', ...
        'Color', col(e.err3d(i)), 'LineWidth', 0.8);
end
scatter3(ax, D.truth(1, :), D.truth(2, :), D.truth(3, :), 7, 'k', 'LineWidth', 0.4);
scatter3(ax, E.r(1, :), E.r(2, :), E.r(3, :), 6, e.err3d, 'filled');
colormap(ax, cmap);
clim(ax, [0 vmax]);
xlim(ax, [0 1.4]); ylim(ax, [0 1.4]); zlim(ax, [0.9 1.4]);
xlabel(ax, '$X$ (m)'); ylabel(ax, '$Y$ (m)'); zlabel(ax, '$Z$ (m)');
view(ax, -50, 22);
daspect(ax, [1 1 0.6]);
grid(ax, 'on');
title(ax, '(a) 3-D view', 'FontWeight', 'normal');
ax2 = nexttile(tl);
hold(ax2, 'on');
for i = 1:size(D.truth, 2)
    plot(ax2, [D.truth(1, i) E.r(1, i)], [D.truth(2, i) E.r(2, i)], '-', 'Color', col(e.err3d(i)), 'LineWidth', 0.9);
end
scatter(ax2, D.truth(1, :), D.truth(2, :), 8, 'k', 'LineWidth', 0.4);
scatter(ax2, E.r(1, :), E.r(2, :), 7, e.err3d, 'filled');
plot(ax2, cfg.led_xy_mm(1)/1e3, cfg.led_xy_mm(2)/1e3, 'kp', 'MarkerSize', 7, 'MarkerFaceColor', 'w');
colormap(ax2, cmap);
clim(ax2, [0 vmax]);
axis(ax2, 'equal');
xlim(ax2, [0 1.4]); ylim(ax2, [0 1.4]);
xlabel(ax2, '$X$ (m)'); ylabel(ax2, '$Y$ (m)');
title(ax2, '(b) Top view (star: LED)', 'FontWeight', 'normal');
cb = colorbar(ax2);
cb.Label.String = '3-D error (cm)';
cb.Label.Interpreter = 'latex';
pp_export(fig, cfg, 'fig_random');
end

function figure_integrity(cfg, F, EF, eF, threshold)
% Profile residual of every point of the 16/10 session: the rotation-stage tilt fault appears at point 48
fig = pp_figure(3.5, 2.9);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
k = F.site;
onset = 47.5;
ax = nexttile(tl);
hold(ax, 'on');
plot(ax, k, EF.shape_rms, 'o-', 'Color', [0 0.32 0.62], 'MarkerSize', 2.5, 'MarkerFaceColor', [0 0.32 0.62], ...
    'LineWidth', 0.7, 'DisplayName', 'Profile residual');
yline(ax, threshold, 'k--', 'LineWidth', 0.6, 'DisplayName', sprintf('Threshold %g\\,\\%%', threshold));
xline(ax, onset, ':', 'Color', [0.6 0 0], 'LineWidth', 0.9, 'HandleVisibility', 'off');
ylabel(ax, 'Residual (\%)');
yyaxis(ax, 'right');
plot(ax, k, max(abs(F.tilt_read), [], 1), '-', 'Color', [0.85 0.33 0.1], 'LineWidth', 0.8, ...
    'DisplayName', 'Max. $|$tilt reading$|$');
ylabel(ax, 'Tilt reading ($^\circ$)');
ax.YAxis(2).Color = [0.85 0.33 0.1];
xlim(ax, [0 max(k) + 1]);
legend(ax, 'Location', 'northwest');
ax.XTickLabel = [];
ax2 = nexttile(tl);
hold(ax2, 'on');
plot(ax2, k, eF.err3d, 's-', 'Color', [0.2 0.2 0.2], 'MarkerSize', 2.5, 'MarkerFaceColor', [0.2 0.2 0.2], 'LineWidth', 0.7);
xline(ax2, onset, ':', 'Color', [0.6 0 0], 'LineWidth', 0.9);
xlim(ax2, [0 max(k) + 1]);
xlabel(ax2, 'Point index (acquisition order)');
ylabel(ax2, '3-D error (cm)');
pp_export(fig, cfg, 'fig_integrity');
end

%% ------------------------------------------------------------------------------------------------------
function R = part_noise(cfg)
% Noise of the lock-in RSS: standard deviation over consecutive 100-ms records at the same pose (the value
% used in the paper), check of the stored D2 RSS, spectrum figure; the off-tone floor of the D2 records
% (DFT bins 20-40 kHz away from every tone) is kept as a diagnostic only.
freqs = cfg.led_freqs_khz*1e3;
band = [20e3 40e3];
nrec = 0;
for c = 1:numel(cfg.grid_dirs)
    nrec = nrec + height(readtable(fullfile(cfg.grid_dirs{c}, 'points.csv'), 'VariableNamingRule', 'preserve'));
end
sigma = zeros(nrec, 4); rss_dft = zeros(nrec, 4); rss_csv = zeros(nrec, 4);
row = 0;
best = struct('rss', -Inf);
for c = 1:numel(cfg.grid_dirs)
    t = readtable(fullfile(cfg.grid_dirs{c}, 'points.csv'), 'VariableNamingRule', 'preserve');
    for i = 1:height(t)
        row = row + 1;
        z = pp_read_npz(fullfile(cfg.grid_dirs{c}, t.wave_file{i}));
        v = (double(z.codes(1, :)) - double(z.y_reference(1)))*double(z.y_increment(1)) + double(z.y_origin(1));
        N = numel(v);
        df = double(z.fs)/N;
        a = sqrt(2)*abs(fft(v))/N;
        for j = 1:4
            k = round(freqs(j)/df) + 1;
            off = [k - round(band(2)/df):k - round(band(1)/df), k + round(band(1)/df):k + round(band(2)/df)];
            sigma(row, j) = sqrt(mean(a(off).^2)/2);
            rss_dft(row, j) = a(k);
            rss_csv(row, j) = t.(sprintf('%dkHz_wave_Vrms', cfg.led_freqs_khz(j)))(i);
        end
        if rss_dft(row, 2) > best.rss
            best = struct('rss', rss_dft(row, 2), 'a', a, 'df', df);
        end
    end
    fprintf('  %s: %d records\n', fileparts(t.wave_file{1}), height(t));
end
R.n_records = nrec;
R.sigma_median_uV = 1e6*median(sigma);
R.sigma_p95_uV = 1e6*prctile(sigma, 95);
R.rss_check_max_rel = max(abs(rss_dft(:) - rss_csv(:))./rss_csv(:));
R.rss500_mV = 1e3*[min(rss_dft(:, 2)) median(rss_dft(:, 2)) max(rss_dft(:, 2))];
fprintf('off-tone floor (median, uV, diagnostic only): %s; RSS check max rel diff %.2g\n', ...
    mat2str(R.sigma_median_uV, 3), R.rss_check_max_rel);
% repeatability: consecutive records at the same pose (n_samples > 1, flat PD)
rel = [];
for c = 1:numel(cfg.repeat_dirs)
    t = readtable(fullfile(cfg.repeat_dirs{c}, 'points.csv'), 'VariableNamingRule', 'preserve');
    rel = [rel; t.('500kHz_wave_Vrms_std')./t.('500kHz_wave_Vrms')]; %#ok<AGROW>
end
R.repeat_rel_median_pct = 100*median(rel);
R.repeat_rel_p90_pct = 100*prctile(rel, 90);
R.repeat_n = numel(rel);
fprintf('repeatability (500 kHz, %d poses): relative std median %.3f %%, P90 %.3f %%\n', numel(rel), ...
    R.repeat_rel_median_pct, R.repeat_rel_p90_pct);
sigma_med = median(sigma);
rel_med = median(rel);
% noise of the RSS used in the paper: standard deviation over consecutive 100-ms records at the same pose
% (2-10 records at each pose of cfg.repeat_dirs), RSS of every record from the projection (8), pooled over poses
ss = zeros(1, 4); dof = 0; mrep = []; srep = []; nrep = [];
for c = 1:numel(cfg.repeat_dirs)
    t = readtable(fullfile(cfg.repeat_dirs{c}, 'points.csv'), 'VariableNamingRule', 'preserve');
    for i = 1:height(t)
        z = pp_read_npz(fullfile(cfg.repeat_dirs{c}, t.wave_file{i}));
        ns = size(z.codes, 1);
        x = zeros(ns, 4);
        for s = 1:ns
            q = min(s, numel(z.y_reference));
            v = (double(z.codes(s, :)) - double(z.y_reference(q)))*double(z.y_increment(q)) + double(z.y_origin(q));
            a = sqrt(2)*abs(fft(v))/numel(v);
            x(s, :) = a(round(freqs/(double(z.fs)/numel(v))) + 1);
        end
        ss = ss + (ns - 1)*var(x, 0, 1);
        dof = dof + ns - 1;
        mrep(end + 1, :) = mean(x, 1); srep(end + 1, :) = std(x, 0, 1); nrep(end + 1, 1) = ns; %#ok<AGROW>
    end
end
sigma_rep = sqrt(ss/dof);
[~, order] = sort(mrep(:, 2));
h = {order(1:floor(end/2)), order(floor(end/2) + 1:end)};
R.sigma_rep_uV = 1e6*sigma_rep;
R.sigma_rep_poses = numel(nrep);
R.sigma_rep_records = sum(nrep);
R.sigma_rep_dof = dof;
R.sigma_rep_ci95_uV = 1e6*sigma_rep(2)*sqrt(dof./(2*gammaincinv([0.975 0.025], dof/2)));
R.sigma_rep_halves_uV = 1e6*cellfun(@(k) sqrt(sum((nrep(k) - 1).*srep(k, 2).^2)/sum(nrep(k) - 1)), h);
R.sigma_rep_halves_rss_mV = 1e3*cellfun(@(k) median(mrep(k, 2)), h);
snr = rss_dft(:, 2)./sigma_rep(2);
R.snr500 = struct('min', min(snr), 'median', median(snr), 'max', max(snr), ...
    'dB', 20*log10([min(snr) median(snr) max(snr)]));
fprintf('RSS noise, repeated records (%d poses, %d records, dof %d): %s uV; 500 kHz CI95 %s uV; halves %s uV\n', ...
    R.sigma_rep_poses, R.sigma_rep_records, dof, mat2str(R.sigma_rep_uV, 3), mat2str(R.sigma_rep_ci95_uV, 3), ...
    mat2str(R.sigma_rep_halves_uV, 3));
fprintf('SNR500 over D2 with this noise (min / median / max): %s dB\n', mat2str(R.snr500.dB, 3));
save(fullfile(cfg.figdir, 'noise_results.mat'), 'sigma', 'rss_dft', 'sigma_med', 'rel_med', 'rel', 'sigma_rep');
% spectrum of the record with the strongest 500 kHz tone (maximum over 1 kHz groups)
group = round(1e3/best.df);
n = floor(numel(best.a)/2/group)*group;
env = max(reshape(best.a(1:n), group, []), [], 1);
fk = ((0:numel(env) - 1) + 0.5)*group*best.df/1e3;
fig = pp_figure(3.5, 2.1);
ax = axes(fig);
semilogy(ax, fk, env, '-', 'Color', [0 0.32 0.62], 'LineWidth', 0.6);
hold(ax, 'on');
for j = 1:4
    text(ax, cfg.led_freqs_khz(j), 2.2*max(env(abs(fk - cfg.led_freqs_khz(j)) < 2)), sprintf('%d kHz', ...
        cfg.led_freqs_khz(j)), 'HorizontalAlignment', 'center', 'FontSize', 7);
end
xlim(ax, [0 1000]);
ylim(ax, [1e-6 1]);
xlabel(ax, 'Frequency (kHz)');
ylabel(ax, 'Amplitude (V rms per 10 Hz bin)');
pp_export(fig, cfg, 'fig_spectrum');
end

%% ------------------------------------------------------------------------------------------------------
function R = part_peb(cfg)
% Position error bound of the real testbed (calibrated SQ model, measured noise) at the D2 sites, with and
% without orientation uncertainty, and versus the adapter tilt (K = 5 uniform cone).
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
Nz = load(fullfile(cfg.figdir, 'noise_results.mat'));
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
sigma = Nz.sigma_rep(jf);
p = G.pf;
p.noise.variance_W2 = sigma^2;
S = size(G.D.truth, 2);
sth = [0.1 0.5 1];
peb10 = zeros(1, S); peb_rel = zeros(1, S); pebo = zeros(numel(sth), S); peb5 = [];
sub5 = angle_subsets(G.D.K, 5);
for i = 1:S
    N = pp_normals(G.D.theta(:, i), G.OFF.SQ.fit.cross(i), cfg.tilt_deg);
    peb10(i) = rx_peb(G.D.truth(:, i), N, p, 1);
    [mu, J] = rx_channel(G.D.truth(:, i), N, p);
    J = reshape(J, [], 3);
    I = J'*diag(1./(sigma^2 + (Nz.rel_med*mu(:)).^2))*J;
    peb_rel(i) = sqrt(trace(inv(I)));
    for q = 1:numel(sth)
        pebo(q, i) = rx_pose_error_peb(G.D.truth(:, i), N, p, 1, sth(q)^2, 'independent');
    end
    for s = 1:size(sub5, 1)
        peb5(end + 1) = rx_peb(G.D.truth(:, i), N(:, sub5(s, :)), p, 1); %#ok<AGROW>
    end
end
R.sigma_uV = 1e6*sigma;
R.rel_noise_pct = 100*Nz.rel_med;
R.peb10_mm = 1e3*[median(peb10) prctile(peb10, 90) max(peb10)];
R.peb5_mm = 1e3*[median(peb5) prctile(peb5, 90) max(peb5)];
R.peb10_rel_mm = 1e3*[median(peb_rel) prctile(peb_rel, 90) max(peb_rel)];
for q = 1:numel(sth)
    R.(sprintf('peb10_orient_%gdeg_mm', sth(q)*10)) = 1e3*[median(pebo(q, :)) prctile(pebo(q, :), 90)];
end
R.err_over_peb_median = median(G.ef.err3d/100./peb10);
fprintf('PEB K=10 (sigma %.2f uV): median %.3f mm, P90 %.3f mm; K=5 median %.3f mm; with relative noise %.2f %%: %.3f mm\n', ...
    1e6*sigma, R.peb10_mm(1), R.peb10_mm(2), R.peb5_mm(1), R.rel_noise_pct, R.peb10_rel_mm(1));
for q = 1:numel(sth)
    fprintf('  orientation %.1f deg: PEB median %.2f mm, P90 %.2f mm\n', sth(q), 1e3*median(pebo(q, :)), ...
        1e3*prctile(pebo(q, :), 90));
end
% PEB versus adapter tilt, K = 5 uniform cone (offset 0), at the 125 D2 positions
tilts = 1:1:45;
sv = [0 0.25 0.5 1];
curve = nan(numel(sv), numel(tilts));
curve90 = nan(numel(sv), numel(tilts));
for it = 1:numel(tilts)
    N = pp_normals(0:72:288, 0, tilts(it));
    for q = 1:numel(sv)
        if sv(q) == 0
            b = rx_peb(G.D.truth, N, p, 1);
        else
            b = rx_pose_error_peb(G.D.truth, N, p, 1, sv(q)^2, 'independent');
        end
        curve(q, it) = median(b);
        curve90(q, it) = prctile(b, 90);
    end
end
[~, ib] = min(curve(end, :));
R.tilt_best_1deg = tilts(ib);
R.tilt_curve = struct('tilt_deg', tilts, 'sigma_deg', sv, 'median_mm', 1e3*curve, 'p90_mm', 1e3*curve90);
fprintf('  tilt minimising the median PEB with 1 deg orientation uncertainty: %g deg\n', R.tilt_best_1deg);
% tilt window of the testbed geometry (uniform cones of K = 5 and 10, D2 positions): largest tilt at which every
% orientation still sees the LED, and coverage (PEB <= 10 cm) with orientation uncertainty
led = p.transmitter.position_m;
tw = 1:0.5:45;
sw = [0.5 1];
Kw = [5 10];
lit = false(numel(Kw), numel(tw));
cw = nan(numel(Kw), numel(sw), numel(tw));
for ik = 1:numel(Kw)
    for it = 1:numel(tw)
        N = pp_normals((0:Kw(ik) - 1)*360/Kw(ik), 0, tw(it));
        [~, ~, info] = rx_channel(G.D.truth, N, p);
        lit(ik, it) = all(info.visible, 'all');
        for q = 1:numel(sw)
            cw(ik, q, it) = 100*mean(rx_pose_error_peb(G.D.truth, N, p, 1, sw(q)^2, 'independent') <= 0.1);
        end
    end
end
offaxis = max(atand(hypot(G.D.truth(1, :) - led(1), G.D.truth(2, :) - led(2))./(led(3) - G.D.truth(3, :))));
support = p.receiver.response_parameters.psi_3db_rad/sqrt(1 - 1/sqrt(2))*180/pi;
R.tilt_window = struct('led_half_power_deg', p.transmitter.half_angle_power_deg, 'offaxis_max_deg', offaxis, ...
    'support_minus_offaxis_deg', support - offaxis, 'K', Kw, 'sigma_deg', sw, ...
    'all_lit_max_tilt_deg', arrayfun(@(ik) max(tw(lit(ik, :))), 1:numel(Kw)), ...
    'full_coverage_from_deg', arrayfun(@(i) min([tw(cw(mod(i - 1, numel(Kw)) + 1, ceil(i/numel(Kw)), :) >= 100 - 1e-9) NaN]), ...
        reshape(1:numel(Kw)*numel(sw), numel(Kw), numel(sw))), ...
    'coverage_pct_at_15deg', cw(:, :, tw == 15));
fprintf('  testbed tilt window: LED half-power %.1f deg seen up to %.1f deg (support - off-axis %.1f deg), all lit up to %s deg (K = %s)\n', ...
    R.tilt_window.led_half_power_deg, offaxis, support - offaxis, mat2str(R.tilt_window.all_lit_max_tilt_deg), mat2str(Kw));
for ik = 1:numel(Kw)
    fprintf('    K = %2d: full coverage from %s deg, coverage at 15 deg %s %% (sigma_theta %s deg)\n', Kw(ik), ...
        mat2str(R.tilt_window.full_coverage_from_deg(ik, :)), mat2str(R.tilt_window.coverage_pct_at_15deg(ik, :), 4), mat2str(sw));
end
save(fullfile(cfg.figdir, 'peb_results.mat'), 'peb10', 'peb5', 'peb_rel', 'pebo', 'sth', 'tilts', 'sv', 'curve', 'curve90');
% figure: CDF of the measured error and of the bounds at the D2 sites
fig = pp_figure(3.5, 2.25);
ax = axes(fig);
hold(ax, 'on');
cdfline = @(v, ls, c, name) stairs(ax, [min(v) sort(v)], (0:numel(v))/numel(v), ls, 'Color', c, ...
    'LineWidth', 1.0, 'DisplayName', name);
cdfline(100*peb10, '-', [0.5 0.5 0.5], 'PEB, $\sigma_\theta=0^\circ$');   % same naming as fig_sim (exactly known normals)
colors = [0.47 0.67 0.19; 0.85 0.33 0.1; 0.49 0.18 0.56];
for q = 1:numel(sth)
    cdfline(100*pebo(q, :), '-', colors(q, :), sprintf('PEB, $\\sigma_\\theta=%g^\\circ$', sth(q)));
end
cdfline(G.ef.err3d, '-', [0 0.32 0.62], 'Measured error');
set(ax, 'XScale', 'log');
xlim(ax, [1e-2 20]);
ylim(ax, [0 1]);
xlabel(ax, '3-D error or bound (cm)');
ylabel(ax, 'Empirical CDF');
legend(ax, 'Location', 'northoutside', 'NumColumns', 3, 'FontSize', 6.5);
pp_export(fig, cfg, 'fig_bound');
end

%% ------------------------------------------------------------------------------------------------------
function R = part_window(cfg)
% Observation window: the lock-in RSS of every D2 record is recomputed over shorter windows cut from the
% recorded 100 ms waveforms (same sample rate and vertical scale as the acquisition). Ten segments per window
% length: 'spread' starts evenly over the record (all phases of the 100 Hz flicker), 'synced' starts every
% 10 ms (one flicker phase). The calibration of Table II (100-ms records) is used unchanged for every window.
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
D = G.D;
freqs = cfg.led_freqs_khz*1e3;
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
Tms = [0.01 0.02 0.05 0.1 0.2 0.5 1 2 5 10 20 50 100];
nseg = 10;
[K, S] = size(D.theta);
blank = nan(K, S, numel(Tms), nseg);
rss = struct('spread', blank, 'synced', blank, 'hann', blank);
dfreq = nan(K, S, 4);
files = strings(K, S);
for c = 1:numel(cfg.grid_dirs)
    t = readtable(fullfile(cfg.grid_dirs{c}, 'points.csv'), 'VariableNamingRule', 'preserve');
    for i = find(D.campaign == c)
        for k = 1:K
            files(k, i) = fullfile(cfg.grid_dirs{c}, t.wave_file{t.site_id == D.site(i) & t.k == k - 1});
        end
    end
end
for i = 1:S
    for k = 1:K
        z = pp_read_npz(files(k, i));
        v = (double(z.codes(1, :)) - double(z.y_reference(1)))*double(z.y_increment(1)) + double(z.y_origin(1));
        fs = double(z.fs);
        N = numel(v);
        for j = 1:4
            p = v.*exp(-2i*pi*freqs(j)*(0:N - 1)/fs);
            X = sum(reshape(p, [], 100), 1);
            slope = polyfit((0:99)*N/fs/100, unwrap(angle(X)), 1);
            dfreq(k, i, j) = slope(1)/(2*pi);
            if j ~= jf
                continue;
            end
            for it = 1:numel(Tms)
                n = round(Tms(it)*1e-3*fs);
                ns = min(nseg, floor(N/n));
                start = round((0:ns - 1)*(N - n)/max(ns - 1, 1));
                P = reshape(p(start + (1:n)'), n, ns);
                w = 0.5 - 0.5*cos(2*pi*(0:n - 1)/n);
                rss.spread(k, i, it, 1:ns) = sqrt(2)*abs(sum(P, 1))/n;
                rss.hann(k, i, it, 1:ns) = sqrt(2)*abs(w*P)/sum(w);
                if Tms(it) <= 10
                    P = reshape(p((0:nseg - 1)*round(10e-3*fs) + (1:n)'), n, nseg);
                    rss.synced(k, i, it, :) = sqrt(2)*abs(sum(P, 1))/n;
                end
            end
        end
    end
    if mod(i, 25) == 0
        fprintf('  %d / %d sites\n', i, S);
    end
end
R.window_ms = Tms;
R.check_100ms_max_rel = max(abs(rss.spread(:, :, end, 1) - D.rss(:, :, jf))./D.rss(:, :, jf), [], 'all');
% coherent gain of the projection at the nominal frequency (rectangular and Hann windows), measured offsets
df = squeeze(median(dfreq, [1 2]))';
R.freq_offset_Hz = df;
gain = @(n, w, f) abs(sum(w.*exp(2i*pi*f*(0:n - 1)/fs)))/sum(w);
R.coherent_loss_100ms_pct = arrayfun(@(f) 100*(1 - gain(round(0.1*fs), ones(1, round(0.1*fs)), f)), df);
g_rect = zeros(1, numel(Tms));
g_hann = g_rect;
for it = 1:numel(Tms)
    n = round(Tms(it)*1e-3*fs);
    g_rect(it) = gain(n, ones(1, n), df(jf));
    g_hann(it) = gain(n, 0.5 - 0.5*cos(2*pi*(0:n - 1)/n), df(jf));
end
scaled = @(g) setfield(G.pf, 'transmitter', setfield(G.pf.transmitter, 'power_W', G.pf.transmitter.power_W*g/g_rect(end)));
% RSS deviation from the true amplitude (100 ms record, frequency-corrected) and white-noise prediction
ref = rss.spread(:, :, end, 1)/g_rect(end);
sig100 = load(fullfile(cfg.figdir, 'noise_results.mat'), 'sigma_med').sigma_med(jf);
for it = 1:numel(Tms)
    for name = ["spread", "synced"]
        x = squeeze(rss.(name)(:, :, it, :))/g_rect(it)./ref - 1;
        R.rss.([char(name) '_spread_pct'])(it) = 100*median(std(x, 0, 3, 'omitnan'), 'all');
        R.rss.([char(name) '_bias_pct'])(it) = 100*median(x, 'all', 'omitnan');
    end
    R.rss.white_pct(it) = 100*median(sig100*sqrt(100/Tms(it))./ref, 'all');
end
% positioning for every window length and segment: K = 10, the two uniform K = 5 subsets, Hann, synced
run = @(x, p, sel) site_errors(pp_estimate('SQ', 'NLS', x(sel, :), D.theta(sel, :), G.OFF.SQ.fit.cross, ...
    cfg.tilt_deg, p), D, p);
sub5 = angle_subsets(K, 5);
all10 = 1:K;
err = struct('spread10', nan(numel(Tms), nseg), 'spread10_v', nan(numel(Tms), nseg), ...
    'spread5', nan(numel(Tms), nseg, size(sub5, 1)), 'hann10', nan(numel(Tms), nseg), 'synced10', nan(numel(Tms), nseg));
for it = 1:numel(Tms)
    pr = G.pf;                                   % calibration of Table II, unchanged for every window
    ph = G.pf;
    for s = 1:nseg
        x = rss.spread(:, :, it, s);
        if any(isnan(x), 'all')
            continue;
        end
        e = run(x, pr, all10);
        err.spread10(it, s) = mean(e.err3d);
        err.spread10_v(it, s) = mean(e.ev);
        for q = 1:size(sub5, 1)
            err.spread5(it, s, q) = mean(run(x, pr, sub5(q, :)).err3d);
        end
        err.hann10(it, s) = mean(run(rss.hann(:, :, it, s), ph, all10).err3d);
        if Tms(it) <= 10
            err.synced10(it, s) = mean(run(rss.synced(:, :, it, s), pr, all10).err3d);
        end
    end
    fprintf('  T = %6.2f ms: K=10 %.2f cm (%.2f-%.2f), synced %.2f, Hann %.2f, K=5 %.2f; RSS spread %.3f %% (synced %.3f, white %.3f)\n', ...
        Tms(it), mean(err.spread10(it, :), 'omitnan'), min(err.spread10(it, :)), max(err.spread10(it, :)), ...
        mean(err.synced10(it, :), 'omitnan'), mean(err.hann10(it, :), 'omitnan'), mean(err.spread5(it, :, :), 'all', 'omitnan'), ...
        R.rss.spread_spread_pct(it), R.rss.synced_spread_pct(it), R.rss.white_pct(it));
end
R.err = struct('K10_mean_cm', mean(err.spread10, 2, 'omitnan')', 'K10_min_cm', min(err.spread10, [], 2)', ...
    'K10_max_cm', max(err.spread10, [], 2)', 'K10_vbias_cm', mean(err.spread10_v, 2, 'omitnan')', ...
    'K5_mean_cm', reshape(mean(err.spread5, [2 3], 'omitnan'), 1, []), 'hann_K10_mean_cm', mean(err.hann10, 2, 'omitnan')', ...
    'synced_K10_mean_cm', mean(err.synced10, 2, 'omitnan')', 'segments', arrayfun(@(T) min(nseg, floor(100/T)), Tms));
fprintf('frequency offsets %s Hz, coherent loss at 100 ms %s %%\n', mat2str(df, 3), mat2str(R.coherent_loss_100ms_pct, 3));
save(fullfile(cfg.figdir, 'window_results.mat'), 'Tms', 'rss', 'err', 'R', 'g_rect', 'g_hann', 'dfreq');
figure_window(cfg, R);
end

function figure_window(cfg, R)
% Mean 3D error versus the observation window: K = 10 (range over the segments shaded) and K = 5
T = R.window_ms;
blue = [0 0.32 0.62];
orange = [0.85 0.33 0.1];
fig = pp_figure(3.5, 2.2);
ax = axes(fig);
hold(ax, 'on');
fill(ax, [T fliplr(T)], [R.err.K10_min_cm fliplr(R.err.K10_max_cm)], blue, 'FaceAlpha', 0.15, ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');
if isfield(R.err, 'K5_min_cm')
    fill(ax, [T fliplr(T)], [R.err.K5_min_cm fliplr(R.err.K5_max_cm)], orange, 'FaceAlpha', 0.15, ...
        'EdgeColor', 'none', 'HandleVisibility', 'off');
end
plot(ax, T, R.err.K10_mean_cm, '-o', 'Color', blue, 'MarkerSize', 3, 'MarkerFaceColor', blue, 'DisplayName', '$K=10$');
plot(ax, T, R.err.K5_mean_cm, '-s', 'Color', orange, 'MarkerSize', 3, 'DisplayName', '$K=5$');
set(ax, 'XScale', 'log');
xlim(ax, [0.01 100]);
xticks(ax, 10.^(-2:2));
xticklabels(ax, {'0.01', '0.1', '1', '10', '100'});
xlabel(ax, 'Observation window (ms)');
ylabel(ax, 'Mean 3-D error (cm)');
legend(ax, 'Location', 'northeast', 'FontSize', 6.5);
pp_export(fig, cfg, 'fig_window');
end

function R = part_window_fig(cfg)
% Redraws fig_window from window_results.mat (no recomputation); returns the stored numbers unchanged
S = load(fullfile(cfg.figdir, 'window_results.mat'), 'R', 'err');
R = S.R;
e5 = mean(S.err.spread5, 3);                         % K = 5: mean of the two uniform subsets, per segment
R.err.K5_min_cm = min(e5, [], 2, 'omitnan')';
R.err.K5_max_cm = max(e5, [], 2, 'omitnan')';
figure_window(cfg, R);
end

function R = part_window_cal(cfg)
% Observation window with a calibration made in the same acquisition configuration: for every window length,
% A and m come from the D1 calibration subset processed with that window (staged fit, LED XY of Table II),
% and D2 is evaluated with that calibration. D2 window RSS from window_results.mat (run 'window' first); the
% D1 window RSS are cached in window_d1_rss.mat.
W = load(fullfile(cfg.figdir, 'window_results.mat'), 'Tms', 'rss', 'R');
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
D = G.D;
Tms = W.Tms;
f0 = cfg.freq_khz*1e3;
[cal, h_cal] = load_calibration_scan(cfg);
cache = fullfile(cfg.figdir, 'window_d1_rss.mat');
if isfile(cache)
    rssT = load(cache, 'rssT').rssT;
else
    t = readtable(fullfile(cfg.scan_dir, 'points.csv'), 'VariableNamingRule', 'preserve');
    t = t(t.meas_id <= cfg.cal_n, :);
    rssT = nan(height(t), numel(Tms));
    for i = 1:height(t)
        z = pp_read_npz(fullfile(cfg.scan_dir, t.wave_file{i}));
        v = (double(z.codes(1, :)) - double(z.y_reference(1)))*double(z.y_increment(1)) + double(z.y_origin(1));
        fs = double(z.fs);
        cs = cumsum(v.*exp(-2i*pi*f0*(0:numel(v) - 1)/fs));
        n = round(Tms*1e-3*fs);
        rssT(i, :) = sqrt(2)*abs(cs(n))./n;
        if mod(i, 2000) == 0
            fprintf('  D1: %d / %d records\n', i, height(t));
        end
    end
    save(cache, 'rssT', 'Tms');
end
pm = pp_params(cfg, 'SQ', 1, 6, cfg.led_xy_mm);
[K, ~] = size(D.theta);
sub5 = angle_subsets(K, 5);
nseg = size(W.rss.spread, 4);
run = @(x, p, sel) site_errors(pp_estimate('SQ', 'NLS', x(sel, :), D.theta(sel, :), G.OFF.SQ.fit.cross, ...
    cfg.tilt_deg, p), D, p);
err = struct('spread10', nan(numel(Tms), nseg), 'spread5', nan(numel(Tms), nseg, size(sub5, 1)));
A = nan(1, numel(Tms));
m = A;
for it = 1:numel(Tms)
    [A(it), m(it)] = pp_calibrate(cal.x, cal.y, rssT(:, it), cfg.led_xy_mm, h_cal, pm, 'staged');
    p = pp_params(cfg, 'SQ', A(it), m(it), cfg.led_xy_mm);
    for s = 1:nseg
        x = W.rss.spread(:, :, it, s);
        if any(isnan(x), 'all')
            continue;
        end
        err.spread10(it, s) = mean(run(x, p, 1:K).err3d);
        for q = 1:size(sub5, 1)
            err.spread5(it, s, q) = mean(run(x, p, sub5(q, :)).err3d);
        end
    end
    fprintf('  T = %6.2f ms: A %.5g, m %.4f | K=10 %.2f cm (%.2f-%.2f), K=5 %.2f cm\n', Tms(it), A(it), m(it), ...
        mean(err.spread10(it, :), 'omitnan'), min(err.spread10(it, :)), max(err.spread10(it, :)), ...
        mean(err.spread5(it, :, :), 'all', 'omitnan'));
end
e5 = mean(err.spread5, 3);
R = W.R;
R.window_ms = Tms;
R.calibration = struct('A', A, 'm', m);
R.err = struct('K10_mean_cm', mean(err.spread10, 2, 'omitnan')', 'K10_min_cm', min(err.spread10, [], 2)', ...
    'K10_max_cm', max(err.spread10, [], 2)', 'K5_mean_cm', mean(e5, 2, 'omitnan')', ...
    'K5_min_cm', min(e5, [], 2, 'omitnan')', 'K5_max_cm', max(e5, [], 2, 'omitnan')');
save(fullfile(cfg.figdir, 'window_cal_results.mat'), 'Tms', 'err', 'R', 'A', 'm');
figure_window(cfg, R);
end

%% ------------------------------------------------------------------------------------------------------
function R = part_subsets(cfg)
% Irregular orientation sets: every subset of K = 4, 5, 6 of the ten D2 angles (non-uniform azimuths), NLS
% with the measured angles and the cross-height stage zero. Irregularity = largest azimuth gap of the subset.
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
D = G.D;
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
rss = D.rss(:, :, jf);
for K = [4 5 6]
    sub = nchoosek(1:D.K, K);
    gap = zeros(1, size(sub, 1));
    err = zeros(1, size(sub, 1));
    fails = zeros(1, size(sub, 1));
    for s = 1:size(sub, 1)
        e = site_errors(pp_estimate('SQ', 'NLS', rss(sub(s, :), :), D.theta(sub(s, :), :), G.OFF.SQ.fit.cross, ...
            cfg.tilt_deg, G.pf), D, G.pf);
        err(s) = mean(e.err3d, 'omitnan');
        fails(s) = nnz(~isfinite(e.err3d));
        gap(s) = 36*max(diff([sub(s, :) sub(s, 1) + D.K]));
    end
    gaps = unique(gap);
    R.(sprintf('K%d', K)) = struct('subsets', size(sub, 1), 'mean_cm', mean(err), 'median_cm', median(err), ...
        'min_cm', min(err), 'max_cm', max(err), 'failures', sum(fails), 'gap_deg', gaps, ...
        'mean_by_gap_cm', arrayfun(@(g) mean(err(gap == g)), gaps), 'count_by_gap', arrayfun(@(g) nnz(gap == g), gaps), ...
        'max_by_gap_cm', arrayfun(@(g) max(err(gap == g)), gaps));
    fprintf('  K = %d: %d subsets, mean %.2f cm (median %.2f, %.2f-%.2f), failures %d\n', K, size(sub, 1), mean(err), ...
        median(err), min(err), max(err), sum(fails));
    for g = gaps
        fprintf('     largest gap %3d deg: %3d subsets, mean %.2f cm, worst %.2f cm\n', g, nnz(gap == g), ...
            mean(err(gap == g)), max(err(gap == g)));
    end
end
end

%% ------------------------------------------------------------------------------------------------------
function R = part_orient(cfg)
% Sensitivity to orientation errors on D2 (K = 10): the recorded normals given to the estimators are
% perturbed by Gaussian errors with standard deviation sigma_theta per tangent component, either independent
% for each orientation or common to the K orientations of a position (one random rotation), M draws per
% site, for NLS, GLS and WLS. The RMS shift of the estimates is compared with the PEB of Section III-D
% (same error model, measured noise) at the same sites.
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
Nz = load(fullfile(cfg.figdir, 'noise_results.mat'));
D = G.D;
p = G.pf;
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
S = size(D.theta, 2);
sv = [0.1 0.2 0.5 1 2];
M = 20;
methods = {'NLS', 'GLS', 'WLS'};
names = struct('NLS', 'joint_nls', 'GLS', 'ratio_gls', 'WLS', 'ratio_wls');
types = {'independent', 'common_rotation'};
N0 = arrayfun(@(i) pp_normals(D.theta(:, i), G.OFF.SQ.fit.cross(i), cfg.tilt_deg), 1:S, 'UniformOutput', false);
r0 = nan(3, S, numel(methods));
for im = 1:numel(methods)
    for i = 1:S
        r0(:, i, im) = pd_fit_estimate(names.(methods{im}), D.rss(:, i, jf), N0{i}, p, 1);
    end
end
pn = p;
pn.noise.variance_W2 = Nz.sigma_rep(jf)^2;
rng(7);
R.sigma_deg = sv;
R.draws = M;
for it = 1:numel(types)
    for is = 1:numel(sv)
        s = sv(is)*pi/180;
        est = nan(3, S, M, numel(methods));
        for q = 1:M
            for i = 1:S
                Np = perturb_normals(N0{i}, s, types{it});
                for im = 1:numel(methods)
                    est(:, i, q, im) = pd_fit_estimate(names.(methods{im}), D.rss(:, i, jf), Np, p, 1);
                end
            end
        end
        for im = 1:numel(methods)
            e = 100*squeeze(vecnorm(est(:, :, :, im) - D.truth));
            shift = 100*squeeze(vecnorm(est(:, :, :, im) - r0(:, :, im)));
            R.(types{it}).(methods{im}).mean_cm(is) = mean(e, 'all', 'omitnan');
            R.(types{it}).(methods{im}).rms_shift_cm(is) = sqrt(mean(shift.^2, 'all', 'omitnan'));
            R.(types{it}).(methods{im}).failures(is) = nnz(isnan(e));
        end
        b = arrayfun(@(i) rx_pose_error_peb(D.truth(:, i), N0{i}, pn, 1, sv(is)^2, types{it}), 1:S);
        R.(types{it}).peb_rms_cm(is) = 100*sqrt(mean(b.^2));
        fprintf('  %-15s sigma %.1f deg: mean error NLS %.2f / GLS %.2f / WLS %.2f cm; RMS shift NLS %.2f cm, PEB %.2f cm; failures %d/%d/%d\n', ...
            types{it}, sv(is), R.(types{it}).NLS.mean_cm(is), R.(types{it}).GLS.mean_cm(is), R.(types{it}).WLS.mean_cm(is), ...
            R.(types{it}).NLS.rms_shift_cm(is), R.(types{it}).peb_rms_cm(is), R.(types{it}).NLS.failures(is), ...
            R.(types{it}).GLS.failures(is), R.(types{it}).WLS.failures(is));
    end
end
for im = 1:numel(methods)
    R.unperturbed_mean_cm.(methods{im}) = 100*mean(vecnorm(r0(:, :, im) - D.truth), 'omitnan');
end
save(fullfile(cfg.figdir, 'orient_results.mat'), 'R');
figure_orient(cfg, R);
end

function N = perturb_normals(N, s, type)
% Gaussian orientation errors, s rad per tangent component: independent rotation of every normal, or one
% common rotation (rotation vector with s per component) of the K normals.
if strcmp(type, 'independent')
    for i = 1:size(N, 2)
        w = s*randn(2, 1);
        a = norm(w);
        N(:, i) = cos(a)*N(:, i) + sin(a)/a*rx_tangent_basis(N(:, i))*w;
    end
else
    w = s*randn(3, 1);
    a = norm(w);
    k = w/a;
    X = [0 -k(3) k(2); k(3) 0 -k(1); -k(2) k(1) 0];
    N = (eye(3) + sin(a)*X + (1 - cos(a))*X^2)*N;
end
N = N./vecnorm(N);
end

function figure_orient(cfg, R)
% (a) mean 3D error versus sigma_theta for the three estimators and both error structures, (b) RMS shift of
% the NLS estimates versus the PEB with the same orientation uncertainty
s = [0 R.sigma_deg];
colors = struct('NLS', [0 0.32 0.62], 'GLS', [0.85 0.33 0.1], 'WLS', [0.47 0.67 0.19]);
fig = pp_figure(3.5, 3.6);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);
hold(ax, 'on');
for m = {'NLS', 'WLS'}
    plot(ax, s, [R.unperturbed_mean_cm.(m{1}) R.independent.(m{1}).mean_cm], '-o', 'Color', colors.(m{1}), ...
        'MarkerSize', 3, 'MarkerFaceColor', colors.(m{1}), 'DisplayName', [m{1} ', independent']);
    plot(ax, s, [R.unperturbed_mean_cm.(m{1}) R.common_rotation.(m{1}).mean_cm], '--s', 'Color', colors.(m{1}), ...
        'MarkerSize', 3, 'DisplayName', [m{1} ', common']);
end
xlim(ax, [0 2]);
ylim(ax, [3 15]);
xlabel(ax, 'Orientation error $\sigma_\theta$ ($^\circ$)');
ylabel(ax, 'Mean 3-D error (cm)');
legend(ax, 'Location', 'northwest', 'NumColumns', 2, 'FontSize', 6.5);
title(ax, '(a) Estimates on D2, $K=10$', 'FontWeight', 'normal');
ax = nexttile(tl);
hold(ax, 'on');
plot(ax, R.sigma_deg, R.independent.NLS.rms_shift_cm, '-o', 'Color', colors.NLS, 'MarkerSize', 3, ...
    'MarkerFaceColor', colors.NLS, 'DisplayName', 'NLS, independent');
plot(ax, R.sigma_deg, R.common_rotation.NLS.rms_shift_cm, '--s', 'Color', colors.NLS, 'MarkerSize', 3, ...
    'DisplayName', 'NLS, common');
plot(ax, R.sigma_deg, R.independent.peb_rms_cm, '-', 'Color', [0.5 0.5 0.5], 'DisplayName', 'PEB, independent');
plot(ax, R.sigma_deg, R.common_rotation.peb_rms_cm, '--', 'Color', [0.5 0.5 0.5], 'DisplayName', 'PEB, common');
set(ax, 'XScale', 'log', 'YScale', 'log');
xlim(ax, [0.1 2]);
ylim(ax, [0.2 20]);
xticks(ax, [0.1 0.2 0.5 1 2]);
xticklabels(ax, {'0.1', '0.2', '0.5', '1', '2'});
xlabel(ax, 'Orientation error $\sigma_\theta$ ($^\circ$)');
ylabel(ax, 'RMS shift or PEB (cm)');
legend(ax, 'Location', 'southeast', 'FontSize', 6.5);
title(ax, '(b) Shift of the NLS estimates and bound', 'FontWeight', 'normal');
pp_export(fig, cfg, 'fig_orient');
end

%% ------------------------------------------------------------------------------------------------------
function R = part_proc(cfg)
% Processing time once the K records of a position are available: amplitude of the tones from a raw record
% (uint8 codes -> volts -> projection at the tone frequency, or full FFT), for 100 ms and 10 ms records, with
% all and with one computational thread; position estimation (NLS, GLS, WLS) on the D2 sites, K = 10 and 5.
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
D = G.D;
S = size(D.theta, 2);
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
[~, cpu] = system('powershell -NoProfile -Command "(Get-CimInstance Win32_Processor).Name"');
R.machine = struct('cpu', strtrim(cpu), 'matlab', version, 'threads', maxNumCompThreads);
t = readtable(fullfile(cfg.grid_dirs{1}, 'points.csv'), 'VariableNamingRule', 'preserve');
z = pp_read_npz(fullfile(cfg.grid_dirs{1}, t.wave_file{1}));
codes = z.codes(1, :);
fs = double(z.fs);
q = double(z.y_increment(1));
c0 = double(z.y_reference(1));
v0 = double(z.y_origin(1));
freqs = cfg.led_freqs_khz*1e3;
threads = maxNumCompThreads;
for Tms = [100 10]
    n = round(Tms*1e-3*fs);
    x = codes(1:n);
    E = exp(-2i*pi*(0:n - 1)'*freqs/fs);
    k = round(freqs*n/fs) + 1;
    volts = @() (double(x) - c0)*q + v0;
    f1 = @() sqrt(2)*abs(volts()*E(:, jf))/n;
    f4 = @() sqrt(2)*abs(volts()*E)/n;
    ff = @() fft_bins(volts(), k, n);
    assert(max(abs(f4() - ff())./ff()) < 1e-9);
    for nt = [threads 1]
        maxNumCompThreads(nt);
        R.amplitude.(sprintf('T%gms_threads%d', Tms, nt)) = struct('projection_1tone_ms', 1e3*timeit(f1), ...
            'projection_4tones_ms', 1e3*timeit(f4), 'fft_4tones_ms', 1e3*timeit(ff));
    end
    maxNumCompThreads(threads);
end
% estimators: median over repetitions per site, then median / P95 / max over the 125 sites
sub5 = angle_subsets(D.K, 5);
methods = {'NLS', 'GLS', 'WLS'};
names = struct('NLS', 'joint_nls', 'GLS', 'ratio_gls', 'WLS', 'ratio_wls');
reps = 5;
for nt = [threads 1]
    maxNumCompThreads(nt);
    for K = [10 5]
        sel = 1:D.K;
        if K == 5
            sel = sub5(1, :);
        end
        for im = 1:numel(methods)
            tt = zeros(1, S);
            for i = 1:S
                y = D.rss(sel, i, jf);
                run = @() pd_fit_estimate(names.(methods{im}), y, ...
                    pp_normals(D.theta(sel, i), G.OFF.SQ.fit.cross(i), cfg.tilt_deg), G.pf, 1);
                run();
                r = zeros(1, reps);
                for k = 1:reps
                    t0 = tic;
                    run();
                    r(k) = toc(t0);
                end
                tt(i) = median(r);
            end
            R.estimator.(sprintf('K%d_threads%d', K, nt)).(methods{im}) = struct('median_ms', 1e3*median(tt), ...
                'p95_ms', 1e3*prctile(tt, 95), 'max_ms', 1e3*max(tt));
            fprintf('  %s K = %2d, %2d threads: median %.2f ms, P95 %.2f ms, max %.2f ms\n', methods{im}, K, nt, ...
                1e3*median(tt), 1e3*prctile(tt, 95), 1e3*max(tt));
        end
    end
end
maxNumCompThreads(threads);
for name = fieldnames(R.amplitude)'
    a = R.amplitude.(name{1});
    fprintf('  amplitude %s: projection 1 tone %.3f ms, 4 tones %.3f ms, FFT %.3f ms\n', name{1}, ...
        a.projection_1tone_ms, a.projection_4tones_ms, a.fft_4tones_ms);
end
for m = methods
    R.accuracy.(m{1}) = G.R.methods.SQ.(m{1}).err3d;
end
end

function a = fft_bins(v, k, n)
X = fft(v);
a = sqrt(2)*abs(X(k))/n;
end

%% ------------------------------------------------------------------------------------------------------
function R = part_sim(cfg)
% Nominal numerical study of the bound (Section III-E), independent of the testbed: LED 3 m above the floor
% pointing down (half-power angle 45 deg), PD anywhere over X, Y in [-1, 1] m (0.1 m grid) at heights 0-1.8 m
% (0.3 m), published SQ response of a commercial PD without aperture, K normals uniformly spaced on a cone of
% tilt theta. The link budget is fixed by the reference SNR alone (untilted PD on the floor below the LED,
% 50 dB): power, PD area and noise enter the bound only through it. Coverage = % positions, PEB <= 10 cm.
base = system_parameters();
H = 3;
half = 45;
snr_ref_db = 50;
cnt = base.acquisition.samples_per_orientation;
p = sim_params(base, H, half);
p.noise.variance_W2 = cnt*(rx_channel([0; 0; 0], [0; 0; 1], p)/10^(snr_ref_db/20))^2;
[X, Y, Z] = ndgrid(-1:0.1:1, -1:0.1:1, 0:0.3:1.8);
P = [X(:) Y(:) Z(:)]';
sigma = sqrt(p.noise.variance_W2/cnt);
cone = @(K, t) pp_normals((0:K-1)*360/K, 0, t);
bnd = @(q, K, t, s) rx_pose_error_peb(P, cone(K, t), q, cnt, s^2, 'independent');
covg = @(b) 100*mean(b <= 0.1);
medb = @(b) median(b(~isnan(b)));
full_at = @(x, c) min([x(c >= 100 - 1e-9) NaN]);
flat = rx_channel(P, [0; 0; 1], p);
R.scenario = struct('led_height_m', H, 'half_power_deg', half, 'lambertian_order', -log(2)/log(cosd(half)), ...
    'psi3db_rad', p.receiver.response_parameters.psi_3db_rad, ...
    'snr_ref_db', 20*log10(rx_channel([0; 0; 0], [0; 0; 1], p)/sigma), ...
    'snr_flat_range_db', 20*log10([min(flat(flat > 0)) max(flat)]/sigma), ...
    'positions', size(P, 2), 'coverage_threshold_cm', 10, ...
    'offaxis_max_deg', max(atand(hypot(P(1, :), P(2, :))./(H - P(3, :)))));
fprintf('nominal scenario: %d positions, reference SNR %.1f dB (flat PD over the volume %.1f-%.1f dB), LED off-axis max %.1f deg\n', ...
    size(P, 2), R.scenario.snr_ref_db, R.scenario.snr_flat_range_db, R.scenario.offaxis_max_deg);
% (1) tilt sweep for several K and orientation uncertainties, and visibility of the K = 5 cone
tilts = 0:0.5:45;
Ks = [3 4 5 6 8 10];
sv = [0 0.5 1 2];
med_t = nan(numel(Ks), numel(sv), numel(tilts));
cov_t = med_t;
for iK = 1:numel(Ks)
    for is = 1:numel(sv)
        for it = 1:numel(tilts)
            b = bnd(p, Ks(iK), tilts(it), sv(is));
            med_t(iK, is, it) = medb(b);
            cov_t(iK, is, it) = covg(b);
        end
    end
end
vis_t = nan(1, numel(tilts));
for it = 1:numel(tilts)
    [~, ~, info] = rx_channel(P, cone(5, tilts(it)), p);
    vis_t(it) = 100*mean(all(info.visible, 1));
end
R.tilt.K = Ks;
R.tilt.sigma_theta_deg = sv;
R.tilt.full_coverage_tilt_deg = nan(numel(Ks), numel(sv));
R.tilt.full_coverage_tilt_max_deg = nan(numel(Ks), numel(sv));
R.tilt.max_coverage_pct = nan(numel(Ks), numel(sv));
for iK = 1:numel(Ks)
    for is = 1:numel(sv)
        c = squeeze(cov_t(iK, is, :))';
        R.tilt.full_coverage_tilt_deg(iK, is) = full_at(tilts, c);
        R.tilt.full_coverage_tilt_max_deg(iK, is) = max([tilts(c >= 100 - 1e-9) NaN]);
        R.tilt.max_coverage_pct(iK, is) = max(c);
    end
end
k5 = Ks == 5;
m5 = squeeze(med_t(k5, :, :));
[mn, imn] = min(m5(sv == 1, :));
R.tilt.K5_median_cm_at_5_15_30_45 = 100*m5(:, ismember(tilts, [5 15 30 45]));
R.tilt.K5_s1_min_median_cm = 100*mn;
R.tilt.K5_s1_min_median_tilt_deg = tilts(imn);
R.tilt.K5_s1_coverage_pct_at_30_45 = squeeze(cov_t(k5, sv == 1, ismember(tilts, [30 45])))';
R.tilt.all_lit_max_tilt_deg = max(tilts(vis_t >= 100 - 1e-9));
R.tilt.all_lit_pct_at_20_30_45 = vis_t(ismember(tilts, [20 30 45]));
b = bnd(p, 5, 15, 1);
R.tilt.K5_s1_15deg_max_cm = 100*max(b);
R.tilt.K5_s1_15deg_by_height = zeros(0, 3);
for z = unique(P(3, :))
    sel = abs(P(3, :) - z) < 1e-9;
    R.tilt.K5_s1_15deg_by_height(end + 1, :) = [z 100*medb(b(sel)) 100*max(b(sel))];
end
fprintf('full coverage (sigma_theta 1 deg) from tilt: %s deg for K = %s\n', mat2str(R.tilt.full_coverage_tilt_deg(:, sv == 1)'), mat2str(Ks));
fprintf('K = 5, sigma_theta 1 deg: median %.2f cm at 15 deg, minimum %.2f cm at %g deg; all orientations lit up to %g deg\n', ...
    100*m5(sv == 1, tilts == 15), R.tilt.K5_s1_min_median_cm, R.tilt.K5_s1_min_median_tilt_deg, R.tilt.all_lit_max_tilt_deg);
% (2) LED half-power angle and (3) reference SNR, at theta = 15 deg, K = 5. The LED power and the noise level
% of the scenario are kept in (2); in (3) the noise level is scaled, which is equivalent to scaling the power
% or the PD area.
halves = 10:2.5:70;
snrs = 20:1:70;
cov_h = nan(numel(sv), numel(halves));
med_s = nan(numel(sv), numel(snrs));
for is = 1:numel(sv)
    for ih = 1:numel(halves)
        q = p;
        q.transmitter.half_angle_power_deg = halves(ih);
        cov_h(is, ih) = covg(bnd(q, 5, 15, sv(is)));
    end
    for j = 1:numel(snrs)
        q = p;
        q.noise.variance_W2 = p.noise.variance_W2*10^((snr_ref_db - snrs(j))/10);
        med_s(is, j) = medb(bnd(q, 5, 15, sv(is)));
    end
end
R.led.half_power_deg = halves;
R.led.coverage_pct = cov_h;
R.led.full_coverage_half_deg = arrayfun(@(is) full_at(halves, cov_h(is, :)), 1:numel(sv));
R.snr.snr_db = snrs;
R.snr.median_cm = 100*med_s;
R.snr.median_cm_at_30_40_50_60_70 = 100*med_s(:, ismember(snrs, 30:10:70));
fprintf('full coverage from LED half-power angle %s deg (sigma_theta %s)\n', mat2str(R.led.full_coverage_half_deg), mat2str(sv));
fprintf('median PEB (cm) at 30/40/50/60/70 dB, sigma_theta 1 deg: %s\n', mat2str(R.snr.median_cm_at_30_40_50_60_70(sv == 1, :), 3));
save(fullfile(cfg.figdir, 'sim_results.mat'), 'tilts', 'Ks', 'sv', 'med_t', 'cov_t', 'vis_t', 'halves', 'cov_h', 'snrs', 'med_s');
% figure: (a) median PEB vs tilt (K = 5), (b) coverage vs tilt (sigma_theta = 1 deg) and lit positions,
% (c) coverage vs LED half-power angle, (d) median PEB vs reference SNR (theta = 15 deg, K = 5)
colors = [0.5 0.5 0.5; 0.47 0.67 0.19; 0.85 0.33 0.1; 0.49 0.18 0.56];
names = arrayfun(@(s) sprintf('$\\sigma_\\theta=%g^\\circ$', s), sv, 'UniformOutput', false);
fig = pp_figure(7.16, 2.15);
tl = tiledlayout(fig, 1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);
hold(ax, 'on');
for is = 1:numel(sv)
    plot(ax, tilts, 100*m5(is, :), '-', 'Color', colors(is, :), 'DisplayName', names{is});
end
yline(ax, 10, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.5, 'HandleVisibility', 'off');
xline(ax, 15, 'k:', 'LineWidth', 0.8, 'HandleVisibility', 'off');
set(ax, 'YScale', 'log');
xlim(ax, [0 45]);
ylim(ax, [0.1 100]);
xticks(ax, 0:15:45);
xlabel(ax, 'Tilt $\theta$ ($^\circ$)');
ylabel(ax, 'Median PEB (cm)');
title(ax, '(a) $K=5$', 'FontWeight', 'normal');
lg = legend(ax, names, 'NumColumns', numel(sv), 'FontSize', 7);
lg.Layout.Tile = 'north';
ax = nexttile(tl);
hold(ax, 'on');
styles = {':', '-', '--'};
kk = [3 5 10];
for j = 1:numel(kk)
    plot(ax, tilts, squeeze(cov_t(Ks == kk(j), sv == 1, :)), styles{j}, 'Color', colors(sv == 1, :), ...
        'DisplayName', sprintf('$K=%d$', kk(j)));
end
plot(ax, tilts, vis_t, '-.', 'Color', [0.3 0.3 0.3], 'DisplayName', 'All lit');
xline(ax, 15, 'k:', 'LineWidth', 0.8, 'HandleVisibility', 'off');
xlim(ax, [0 45]);
ylim(ax, [0 102]);
xticks(ax, 0:15:45);
xlabel(ax, 'Tilt $\theta$ ($^\circ$)');
ylabel(ax, 'Positions (\%)');
lg = legend(ax, 'Location', 'southeast', 'FontSize', 6.5);
if isprop(lg, 'IconColumnWidth')
    lg.IconColumnWidth = 14;
end
title(ax, '(b) $\sigma_\theta=1^\circ$', 'FontWeight', 'normal');
ax = nexttile(tl);
hold(ax, 'on');
for is = 1:numel(sv)
    plot(ax, halves, cov_h(is, :), '-', 'Color', colors(is, :));
end
xline(ax, half, 'k:', 'LineWidth', 0.8);
xlim(ax, [10 70]);
ylim(ax, [0 102]);
xticks(ax, 10:20:70);
xlabel(ax, 'LED half-power angle ($^\circ$)');
ylabel(ax, 'Coverage (\%)');
title(ax, '(c) $\theta=15^\circ$, $K=5$', 'FontWeight', 'normal');
ax = nexttile(tl);
hold(ax, 'on');
for is = 1:numel(sv)
    plot(ax, snrs, 100*med_s(is, :), '-', 'Color', colors(is, :), 'DisplayName', names{is});
end
yline(ax, 10, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.5, 'HandleVisibility', 'off');
xline(ax, snr_ref_db, 'k:', 'LineWidth', 0.8, 'HandleVisibility', 'off');
set(ax, 'YScale', 'log');
xlim(ax, [20 70]);
ylim(ax, [0.1 100]);
xticks(ax, 20:10:70);
xlabel(ax, 'Reference SNR (dB)');
ylabel(ax, 'Median PEB (cm)');
title(ax, '(d) $\theta=15^\circ$, $K=5$', 'FontWeight', 'normal');
pp_export(fig, cfg, 'fig_sim');
end

function p = sim_params(base, H, half_power_deg)
% Nominal scenario: published SQ response of a commercial PD (psi_3dB of the PDA100A2, no aperture), LED at
% height H pointing down.
p = bastiaens2020_parameters(base, 'PDA100A2', 'SQ', 90);
p.transmitter.position_m = [0; 0; H];
p.transmitter.normal = [0; 0; -1];
p.transmitter.half_angle_power_deg = half_power_deg;
end

%% ------------------------------------------------------------------------------------------------------
function R = part_response(cfg)
% Receiver response models of Section VI (cos, cos^m_R and SQ with the published parameters) and RSS of D2 divided
% by the amplitude of its position (true positions, calibrated stage zero).
% The amplitudes are estimated WITHOUT a response model: ln y_ik = b_i + r(psi_ik), where r is a free piecewise-
% linear function of the incidence angle (nodes every 5 degrees); the amplitudes b_i and r are obtained together by
% linear least squares. D2 has almost no data within 2 degrees of normal incidence, so this fixes the measured
% response only up to ONE common factor (125 amplitudes -> 1). The figure sets it by a least-squares match to the
% SQ curve; the deviations are reported for every model with its own best factor.
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
D = G.D;
p = G.pf;
S = size(D.truth, 2);
Y = D.rss(:, :, jf);
psi = zeros(D.K, S);
beta_sq = zeros(1, S);
for i = 1:S
    N = pp_normals(D.theta(:, i), G.OFF.SQ.fit.cross(i), cfg.tilt_deg);
    v = p.transmitter.position_m - D.truth(:, i);
    c = N'*(v/norm(v));
    Rs = rx_receiver_response(c, p);
    psi(:, i) = acosd(c);
    beta_sq(i) = (Y(:, i)'*Rs)/(Rs'*Rs);              % amplitude fitted with the SQ response (comparison only)
end
step = 5;
nodes = 0:step:55;
n = numel(psi);
j = min(floor(psi(:)/step) + 1, numel(nodes) - 1);
w = (psi(:) - nodes(j)')/step;
site = reshape(repmat(1:S, D.K, 1), [], 1);
M = sparse([(1:n)'; (1:n)'; (1:n)'], [site; S + j; S + j + 1], [ones(n, 1); 1 - w; w], n, S + numel(nodes));
M(:, S + 1) = [];                                      % gauge of the fit: r(0) = 0
sol = M \ log(Y(:));
beta0 = exp(sol(1:S))';
free0 = exp([0; sol(S + 1:end)])';
q0 = Y./beta0;
a = (1 - 1/sqrt(2))/cfg.psi3db^2;
sq = @(x) max(1 - a*(x*pi/180).^2, 0);
cmr = @(x) cosd(x).^cfg.m_R;
factor = @(f) exp(-mean(log(q0(:)./f(psi(:)))));       % common factor that best matches a model
dev = @(f) 100*std(log(q0(:)./f(psi(:))), 1);          % rms deviation from the model with that factor (%)
c_sq = factor(sq);
q = c_sq*q0;
ratio = c_sq*beta_sq./beta0;                           % SQ-fitted amplitude over the model-free one (same factor)
R.incidence_deg = struct('min', min(psi(:)), 'median', median(psi(:)), 'max', max(psi(:)));
R.support_deg = 1/sqrt(a)*180/pi;
R.common_factor = struct('SQ', c_sq, 'cos_mR', factor(cmr), 'cos', factor(@cosd));
R.deviation_pct = struct('free', 100*std(log(q0(:)./interp1(nodes, free0, psi(:))), 1), 'SQ', dev(sq), 'cos_mR', dev(cmr), ...
    'cos', dev(@cosd), 'SQ_max_abs', 100*max(abs(q(:)./sq(psi(:)) - 1)));
R.free_response = struct('nodes_deg', nodes, 'value', c_sq*free0, 'SQ', sq(nodes), 'cos_mR', cmr(nodes), 'cos', cosd(nodes));
R.sq_fitted_amplitude_vs_free_pct = struct('rms', 100*sqrt(mean((ratio - 1).^2)), 'max_abs', 100*max(abs(ratio - 1)));
fprintf('incidence angles of D2: %.1f to %.1f deg (median %.1f)\n', R.incidence_deg.min, R.incidence_deg.max, R.incidence_deg.median);
fprintf('points vs model with the best common factor (rms): SQ %.2f %% (factor %.4f, max %.2f %%), cos^%g %.2f %% (%.4f), cos %.2f %% (%.4f); free fit %.2f %%\n', ...
    R.deviation_pct.SQ, R.common_factor.SQ, R.deviation_pct.SQ_max_abs, cfg.m_R, R.deviation_pct.cos_mR, R.common_factor.cos_mR, ...
    R.deviation_pct.cos, R.common_factor.cos, R.deviation_pct.free);
fprintf('amplitudes fitted with SQ vs model-free amplitudes (same common factor): rms %.2f %%, max %.2f %%\n', ...
    R.sq_fitted_amplitude_vs_free_pct.rms, R.sq_fitted_amplitude_vs_free_pct.max_abs);
% measured points in front, model curves fainter and wider behind them
x = linspace(0, 90, 721);
tint = @(c) c + 0.55*(1 - c);
fig = pp_figure(3.5, 1.85);
ax = axes(fig);
hold(ax, 'on');
plot(ax, x, cosd(x), ':', 'Color', tint([0.47 0.67 0.19]), 'LineWidth', 1.4, 'DisplayName', '$\cos\psi$');
plot(ax, x, cmr(x), '--', 'Color', tint([0.85 0.33 0.1]), 'LineWidth', 1.4, 'DisplayName', ['$\cos^{' num2str(cfg.m_R) '}\psi$']);
plot(ax, x, sq(x), '-', 'Color', tint([0 0.32 0.62]), 'LineWidth', 2.0, 'DisplayName', 'SQ');
plot(ax, psi(:), q(:), '.', 'Color', [0.05 0.05 0.05], 'MarkerSize', 3.5, 'DisplayName', 'Measured (D2)');
xlim(ax, [0 90]);
ylim(ax, [0 1.05]);
xticks(ax, 0:15:90);
xlabel(ax, 'Incidence angle $\psi$ ($^\circ$)');
ylabel(ax, 'Response $R(\psi)$');
legend(ax, 'Location', 'northeast');
pp_export(fig, cfg, 'fig_response');
end

%% ------------------------------------------------------------------------------------------------------
function R = part_axis(cfg)
% Error on D2 against the angle at which the LED is seen (Section VI-D): 3D / horizontal / vertical / direction
% errors, contrast of the normalized RSS profile, and deviation of the LED pattern from the calibrated cosine
% power, seen by the tilted PD on D2 (fitted amplitude over the model at the true position) and by the flat PD
% on D1 (same emission angles). Needs grid_results.mat and peb_results.mat.
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
D = G.D; E = G.Ef; p = G.pf;
A = p.calibration.A; m = p.calibration.m;
t = p.transmitter.position_m;
v = t - D.truth;
d = vecnorm(v);
u = v./d;
phi = acosd(-p.transmitter.normal'*u);
e = E.r - D.truth;
err = 100*vecnorm(e);
eh = 100*vecnorm(e(1:2, :));
ev = 100*e(3, :);
dir = acosd(min(1, sum(E.u.*u)));
range_err = 100*(E.d - d);
amp = E.beta./(A*cosd(phi).^m./d.^2);                      % fitted amplitude / LED model at the true position
range_pattern = 100*d.*(1./sqrt(amp) - 1);                 % range error that this deviation alone would cause
contrast = zeros(1, numel(d));
for i = 1:numel(d)
    Rs = rx_receiver_response(pp_normals(D.theta(:, i), G.OFF.SQ.fit.cross(i), cfg.tilt_deg)'*u(:, i), p);
    contrast(i) = 100*(max(Rs) - min(Rs))/mean(Rs);
end
% flat scan D1: measured pattern over the calibrated model, median per emission angle
[x, y, rss, h] = load_full_scan(cfg);
r1 = hypot(x - cfg.led_xy_mm(1), y - cfg.led_xy_mm(2))/1e3;
c1 = h./hypot(r1, h);
ratio1 = rss(:, jf).*hypot(r1, h).^2./rx_receiver_response(c1, p)./(A*c1.^m);
pe = 0:2.5:40;
ctr = (pe(1:end - 1) + pe(2:end))/2;
med1 = arrayfun(@(k) median(ratio1(acosd(c1) >= pe(k) & acosd(c1) < pe(k + 1))), 1:numel(ctr));
amp1 = interp1(ctr, med1, min(max(phi, ctr(1)), ctr(end)), 'pchip');   % D1 deviation at the D2 emission angles
stat = @(s) struct('n', nnz(s), 'err3d_cm', mean(err(s)), 'horizontal_cm', mean(eh(s)), 'vertical_cm', mean(ev(s)), ...
    'direction_deg', mean(dir(s)), 'range_cm', mean(range_err(s)), 'contrast_pct', mean(contrast(s)), ...
    'pattern_dev_D2_pct', 100*(mean(amp(s)) - 1), 'pattern_dev_D1_pct', 100*(mean(amp1(s)) - 1), ...
    'range_from_pattern_cm', mean(range_pattern(s)));
edges = [0 10 15 20 25 30 40];
R.edges_deg = edges;
fprintf(' phi (deg)    n  err3D  horiz   vert  dir(deg)  range  contrast  pattern D2 / D1 (%%)  range from pattern\n');
for k = 1:numel(edges) - 1
    b = stat(phi >= edges(k) & phi < edges(k + 1));
    R.bins(k) = b;
    fprintf('  %2d-%2d    %3d  %5.2f  %5.2f  %+5.2f   %5.2f   %+5.2f   %5.1f     %+5.2f / %+5.2f        %+5.2f cm\n', edges(k), edges(k + 1), b.n, ...
        b.err3d_cm, b.horizontal_cm, b.vertical_cm, b.direction_deg, b.range_cm, b.contrast_pct, b.pattern_dev_D2_pct, ...
        b.pattern_dev_D1_pct, b.range_from_pattern_cm);
end
R.near = stat(phi < 15);
R.far = stat(phi >= 20);
R.heights_m = arrayfun(@(l) D.truth(3, find(D.level == l, 1)), 1:numel(D.levels));
R.positions_within_15deg_by_height = arrayfun(@(l) nnz(phi(D.level == l) < 15), 1:numel(D.levels));
% noise-limited bound (K = 10, measured noise) in the same two regions, from part 'peb'
B = load(fullfile(cfg.figdir, 'peb_results.mat'), 'peb10');
R.peb_noise_mm = struct('near', 1e3*median(B.peb10(phi < 15)), 'far', 1e3*median(B.peb10(phi >= 20)));
fprintf('noise-limited bound (median): %.2f mm within 15 deg of the axis, %.2f mm beyond 20 deg\n', R.peb_noise_mm.near, R.peb_noise_mm.far);
R.pattern_dev_corr_D1_D2 = corr(amp(:), amp1(:));
R.err_direction_only_cm = mean(100*vecnorm((t - d.*E.u) - D.truth));     % true distance, estimated direction
R.err_range_only_cm = mean(100*abs(E.d - d));                            % estimated distance, true direction
fprintf('within 15 deg of the LED axis: %.2f cm (horizontal %.2f, direction %.2f deg, contrast %.1f %%); beyond 20 deg: %.2f cm (%.2f, %.2f deg, %.1f %%)\n', ...
    R.near.err3d_cm, R.near.horizontal_cm, R.near.direction_deg, R.near.contrast_pct, R.far.err3d_cm, R.far.horizontal_cm, ...
    R.far.direction_deg, R.far.contrast_pct);
fprintf('pattern deviation D2 against D1 at the same emission angles: correlation %.2f; direction alone %.2f cm, range alone %.2f cm\n', ...
    R.pattern_dev_corr_D1_D2, R.err_direction_only_cm, R.err_range_only_cm);
end

%% ------------------------------------------------------------------------------------------------------
function R = part_zero(cfg)
% Calibration budget of the stage zero (Section VI-F): the zero fitted with the profile-consistency test on a
% few known positions of D2 instead of all of them, and the mean error that this value gives on the blind test
% D3 (K = 5, all the other parameters as in the paper). Needs grid_results.mat and random_results.mat.
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
Rn = load(fullfile(cfg.figdir, 'random_results.mat'));
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
D = G.D;
rss = D.rss(:, :, jf);
S = size(D.truth, 2);
p3 = pp_params(cfg, 'SQ', cfg.A, cfg.m, cfg.led_xy_mm);
fit = @(sel) zero_fit(D, rss, sel, cfg, G.pf);
err3 = @(a) zero_d3_error(a, Rn.D, jf, cfg, p3);
R.all_deg = fit(true(1, S));
R.d3_mean_cm_paper_zero = err3(cfg.offset_deg);
% (1) nine positions: the 3 x 3 grid X, Y = 0.1, 0.7, 1.3 m at one height
xy = round(D.truth(1:2, :)*1e3);
g3 = ismember(xy(1, :), [100 700 1300]) & ismember(xy(2, :), [100 700 1300]);
for l = 1:numel(D.levels)
    sel = D.level == l & g3;
    R.grid3x3.height_m(l) = D.truth(3, find(sel, 1));
    R.grid3x3.positions(l) = nnz(sel);
    R.grid3x3.zero_deg(l) = fit(sel);
    R.grid3x3.d3_mean_cm(l) = err3(R.grid3x3.zero_deg(l));
    fprintf('  3 x 3 grid at %.3f m (%d positions): stage zero %.2f deg, D3 mean error %.2f cm\n', R.grid3x3.height_m(l), ...
        R.grid3x3.positions(l), R.grid3x3.zero_deg(l), R.grid3x3.d3_mean_cm(l));
end
R.grid3x3.max_abs_dev_deg = max(abs(R.grid3x3.zero_deg - cfg.offset_deg));
% (2) N positions drawn at random (300 draws); D3 error interpolated on a 0.1-deg grid of the stage zero
grid = 64:0.1:69;
e3 = arrayfun(err3, grid);
R.sensitivity = struct('zero_deg', grid, 'd3_mean_cm', e3);
rng(11);
M = 300;
Ns = [5 9 25];
for k = 1:numel(Ns)
    a = zeros(1, M);
    for q = 1:M
        sel = false(1, S);
        sel(randperm(S, Ns(k))) = true;
        a(q) = fit(sel);
    end
    d3 = interp1(grid, e3, min(max(a, grid(1)), grid(end)));
    R.random(k) = struct('positions', Ns(k), 'draws', M, 'zero_std_deg', std(a), ...
        'zero_abs_dev_p95_deg', prctile(abs(a - cfg.offset_deg), 95), 'zero_abs_dev_max_deg', max(abs(a - cfg.offset_deg)), ...
        'd3_median_cm', median(d3), 'd3_p95_cm', prctile(d3, 95), 'd3_max_cm', max(d3));
    fprintf('  %2d random positions: stage zero std %.2f deg, |deviation| P95 %.2f deg (max %.2f); D3 mean error median %.2f, P95 %.2f, max %.2f cm\n', ...
        Ns(k), R.random(k).zero_std_deg, R.random(k).zero_abs_dev_p95_deg, R.random(k).zero_abs_dev_max_deg, ...
        R.random(k).d3_median_cm, R.random(k).d3_p95_cm, R.random(k).d3_max_cm);
end
fprintf('  all %d positions: %.2f deg; D3 with the stage zero of the paper (%.1f deg): %.2f cm; D3 at +/-0.5 deg: %.2f / %.2f cm\n', S, R.all_deg, ...
    cfg.offset_deg, R.d3_mean_cm_paper_zero, interp1(grid, e3, cfg.offset_deg - 0.5), interp1(grid, e3, cfg.offset_deg + 0.5));
end

function a = zero_fit(D, rss, sel, cfg, p)
[~, a] = pp_shape('fit', D.truth, D.theta, rss, sel, cfg.nominal_offset_deg, cfg.tilt_deg, p);
end

function e = zero_d3_error(a, D3, jf, cfg, p3)
E = pp_estimate('SQ', 'NLS', D3.rss(:, :, jf), D3.theta, a, cfg.tilt_deg, p3);
e = mean(100*vecnorm(E.r - D3.truth), 'omitnan');
end

%% ------------------------------------------------------------------------------------------------------
function R = part_redraw(cfg)
% Redraws fig_grid_height, fig_window and fig_orient from the saved results (no recomputation, no numbers).
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
figure_grid(cfg, G.D, G.ef, G.R);
W = load(fullfile(cfg.figdir, 'window_cal_results.mat'), 'R');
figure_window(cfg, W.R);
O = load(fullfile(cfg.figdir, 'orient_results.mat'), 'R');
figure_orient(cfg, O.R);
R = [];
end

%% ------------------------------------------------------------------------------------------------------
function R = part_nine(cfg)
% Complete calibration of the positioning LED (LED XY, A and m by the joint fit) from nine points of D1 (3 x 3
% grid, X, Y = 0.1, 0.7, 1.3 m): error on D2 (same number as part 'leds', pattern centre, 3 x 3) and, recomputed
% offline, on the blind test D3 (stage zero of the paper). Needs grid_results.mat and random_results.mat.
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
Rn = load(fullfile(cfg.figdir, 'random_results.mat'));
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
[x, y, rss, h] = load_full_scan(cfg);
v = linspace(100, 1300, 3);
[X, Y] = meshgrid(v, v);
idx = arrayfun(@(a, b) find_nearest(x, y, a, b), X(:), Y(:));
[~, k] = max(rss(idx, jf));
start = [x(idx(k)) y(idx(k))];                 % strongest of the nine points: no prior knowledge of the LED position
p0 = pp_params(cfg, 'SQ', 1, 6, start);
[A, m, xy] = pp_calibrate(x(idx), y(idx), rss(idx, jf), start, h, p0, 'joint_xy');
p = pp_params(cfg, 'SQ', A, m, xy);
e2 = site_errors(pp_estimate('SQ', 'NLS', G.D.rss(:, :, jf), G.D.theta, G.OFF.SQ.fit.cross, cfg.tilt_deg, p), G.D, p);
e3 = site_errors(pp_estimate('SQ', 'NLS', Rn.D.rss(:, :, jf), Rn.D.theta, cfg.offset_deg, cfg.tilt_deg, p), Rn.D, p);
R = struct('start_xy_mm', start, 'led_xy_mm', xy, 'A', A, 'm', m, 'D2', e2.summary, 'D3', e3.summary);
fprintf('nine-point calibration: LED (%.1f, %.1f) mm, A %.5f, m %.3f; D2 mean %.2f cm, D3 mean %.2f cm\n', xy, A, m, ...
    e2.summary.err3d.mean, e3.summary.err3d.mean);
end

%% ------------------------------------------------------------------------------------------------------
function R = part_calib(cfg)
% D1: apparent Lambertian order versus emission angle (500 kHz) and calibration budget: error on the D2
% sites when A and m come from N points of D1 (the direction and amplitude of every site do not depend on
% A and m, so the error is exact for any calibration).
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
[x, y, rss, h] = load_full_scan(cfg);
y500 = rss(:, jf);
pSQ = pp_params(cfg, 'SQ', cfg.A, cfg.m, cfg.led_xy_mm);
r = hypot(x - cfg.led_xy_mm(1), y - cfg.led_xy_mm(2))/1e3;
d = sqrt(r.^2 + h^2);
c = h./d;
phi = acosd(c);
Rr = rx_receiver_response(c, pSQ);
[~, k0] = min(r);
A0 = y500(k0)*d(k0)^2/Rr(k0);
m_app = log(y500.*d.^2./(A0*Rr))./log(c);
edges = 0:1:ceil(max(phi));
centre = edges(1:end - 1) + 0.5;
med = nan(size(centre)); q1 = med; q3 = med;
for b = 1:numel(centre)
    sel = phi >= edges(b) & phi < edges(b + 1) & phi > 1.5;
    if nnz(sel) >= 5
        med(b) = median(m_app(sel)); q1(b) = prctile(m_app(sel), 25); q3(b) = prctile(m_app(sel), 75);
    end
end
[A_all, m_all] = pp_calibrate(x, y, y500, cfg.led_xy_mm, h, pSQ, 'joint');
R.full_map = struct('A', A_all, 'm', m_all, 'phi_max_deg', max(phi));
R.apparent_m = struct('phi_deg', centre, 'median', med, 'q25', q1, 'q75', q3);
% the order is a property of the LED: beyond about 20 degrees the apparent order is stable, and the staged
% calibration (A on the axis, m from the scan points up to a maximum emission angle) must not depend on the
% extent of the scan once it reaches those angles
far = centre > 20 & isfinite(med);
ext = [20 25 30 35 ceil(max(phi))];
m_ext = arrayfun(@(pm) staged_order(x(phi <= pm), y(phi <= pm), y500(phi <= pm), cfg.led_xy_mm, h, pSQ), ext);
R.apparent_m_beyond_20deg = struct('min', min(med(far)), 'max', max(med(far)), 'phi_max_deg', max(phi));
R.staged_m_vs_extent = struct('phi_max_deg', ext, 'm', m_ext, 'calibration_subset_m', cfg.m);
fprintf('apparent m beyond 20 deg: %.2f to %.2f (scan up to %.1f deg); staged m with the scan limited to %s deg: %s (subset of the paper: %.3f)\n', ...
    R.apparent_m_beyond_20deg.min, R.apparent_m_beyond_20deg.max, max(phi), mat2str(ext), mat2str(m_ext, 4), cfg.m);
fprintf('full-map joint calibration: A %.5g, m %.3f; apparent m %.1f (phi 2-3 deg) -> %.1f (phi 25-35 deg)\n', ...
    A_all, m_all, med(3), median(med(centre > 25 & centre < 35), 'omitnan'));
% calibration budget
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
t = G.pf.transmitter.position_m;
uz = G.Ef.u(3, :);
err_of = @(A, m) mean(100*vecnorm(t - sqrt(A*uz.^m./G.Ef.beta).*G.Ef.u - G.D.truth));
cal_err = @(idx) err_of_cal(x(idx), y(idx), y500(idx), cfg.led_xy_mm, h, pSQ, err_of);
R.reference = struct('demo_cal_cm', err_of(cfg.A, cfg.m), 'full_map_cm', err_of(A_all, m_all));
best = fminsearch(@(v) err_of(exp(v(1)), v(2)), [log(cfg.A) cfg.m], optimset('Display', 'off'));
R.reference.oracle_cm = err_of(exp(best(1)), best(2));
R.reference.oracle_A = exp(best(1));
R.reference.oracle_m = best(2);
nearest = @(xs, ys) arrayfun(@(a, b) find_nearest(x, y, a, b), xs, ys);
n_grid = 2:10;
grid_err = zeros(size(n_grid));
for g = 1:numel(n_grid)
    v = linspace(100, 1300, n_grid(g));
    [X, Y] = meshgrid(v, v);
    grid_err(g) = cal_err(nearest(X(:), Y(:)));
end
Nv = [2 3 4 5 6 8 10 15 20 30 50 100];
draws = 400;
rng(1);
area = find(x >= 100 & x <= 1300 & y >= 100 & y <= 1300);
near = find(r <= 0.6);
rand_area = zeros(numel(Nv), 3); rand_near = rand_area;
for k = 1:numel(Nv)
    ea = zeros(1, draws); en = ea;
    for s = 1:draws
        ea(s) = cal_err(area(randperm(numel(area), Nv(k))));
        en(s) = cal_err(near(randperm(numel(near), Nv(k))));
    end
    rand_area(k, :) = prctile(ea, [10 50 90]);
    rand_near(k, :) = prctile(en, [10 50 90]);
end
steps = [0.1 0.2 0.4];
clustered = zeros(size(steps));
for s = 1:numel(steps)
    v = (-1:1)*steps(s)*1e3;
    [X, Y] = meshgrid(cfg.led_xy_mm(1) + v, cfg.led_xy_mm(2) + v);
    clustered(s) = cal_err(nearest(X(:), Y(:)));
end
R.budget = struct('n_grid', n_grid, 'grid_cm', grid_err, 'N', Nv, 'random_area_p10_50_90', rand_area, ...
    'random_near_p10_50_90', rand_near, 'clustered_step_m', steps, 'clustered_cm', clustered);
fprintf('budget: grids %s cm; clustered 3x3 %s cm; random area N=10 median %.2f; oracle %.2f cm\n', ...
    mat2str(grid_err, 3), mat2str(clustered, 3), rand_area(Nv == 10, 2), R.reference.oracle_cm);
% figure: (a) apparent m, (b) calibration budget
fig = pp_figure(3.5, 3.9);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);
hold(ax, 'on');
ok = isfinite(med);
fill(ax, [centre(ok) fliplr(centre(ok))], [q1(ok) fliplr(q3(ok))], [0 0.32 0.62], 'FaceAlpha', 0.15, ...
    'EdgeColor', 'none', 'DisplayName', 'Interquartile range');
plot(ax, centre(ok), med(ok), '-', 'Color', [0 0.32 0.62], 'LineWidth', 1.1, 'DisplayName', 'Apparent order (median)');
yline(ax, cfg.m, 'k--', 'LineWidth', 0.7, 'DisplayName', sprintf('Calibrated $m=%.2f$', cfg.m));
xlabel(ax, 'Emission angle $\phi$ ($^\circ$)');
ylabel(ax, 'Apparent order $m$');
xlim(ax, [0 ceil(max(phi))]);
legend(ax, 'Location', 'northeast');
title(ax, '(a) 500 kHz LED, flat-PD scan', 'FontWeight', 'normal');
ax2 = nexttile(tl);
hold(ax2, 'on');
fill(ax2, [Nv fliplr(Nv)], [rand_area(:, 1)' fliplr(rand_area(:, 3)')], [0.85 0.33 0.1], 'FaceAlpha', 0.15, ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax2, Nv, rand_area(:, 2), '-', 'Color', [0.85 0.33 0.1], 'LineWidth', 1.0, 'DisplayName', 'Random, whole area');
plot(ax2, Nv, rand_near(:, 2), '--', 'Color', [0.47 0.67 0.19], 'LineWidth', 1.0, 'DisplayName', 'Random, $\le 0.6$ m from LED');
plot(ax2, n_grid.^2, grid_err, 's-', 'Color', [0 0.32 0.62], 'MarkerSize', 3.5, 'MarkerFaceColor', [0 0.32 0.62], ...
    'LineWidth', 1.0, 'DisplayName', 'Regular $n\times n$ grid');
plot(ax2, [9 9 9], clustered, 'kx', 'MarkerSize', 5, 'LineWidth', 0.9, 'DisplayName', '$3\times3$ around LED');
text(ax2, 8, clustered(1), sprintf('%.1f m', steps(1)), 'FontSize', 6.5, 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'right');
text(ax2, 8, clustered(2), sprintf('%.1f m', steps(2)), 'FontSize', 6.5, 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'right');
text(ax2, 10, clustered(3), sprintf('%.1f m', steps(3)), 'FontSize', 6.5, 'VerticalAlignment', 'bottom');
yline(ax2, R.reference.full_map_cm, 'k:', 'LineWidth', 0.7, 'HandleVisibility', 'off');
yline(ax2, R.reference.oracle_cm, 'k-.', 'LineWidth', 0.6, 'HandleVisibility', 'off');
text(ax2, 98, R.reference.full_map_cm, 'full map', 'FontSize', 6.5, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
text(ax2, 98, R.reference.oracle_cm, 'best $(A,m)$', 'FontSize', 6.5, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
set(ax2, 'XScale', 'log', 'YScale', 'log', 'YTick', [3 4 5 7 10 15 20 30]);
xlim(ax2, [2 100]);
ylim(ax2, [2.8 30]);
xlabel(ax2, 'Number of calibration points $N$');
ylabel(ax2, 'Mean 3-D error on the grid (cm)');
legend(ax2, 'Location', 'northeast', 'FontSize', 6.5);
title(ax2, '(b) Calibration budget', 'FontWeight', 'normal');
pp_export(fig, cfg, 'fig_calibration');
end

function m = staged_order(x, y, rss, xy, h, p)
[~, m] = pp_calibrate(x, y, rss, xy, h, p, 'staged');
end

function e = err_of_cal(x, y, rss, xy, h, p, err_of)
[A, m] = pp_calibrate(x, y, rss, xy, h, p, 'joint');
e = err_of(A, m);
end

function k = find_nearest(x, y, a, b)
[~, k] = min((x - a).^2 + (y - b).^2);
end

function [x, y, rss, h] = load_full_scan(cfg)
opts = detectImportOptions(fullfile(cfg.scan_dir, 'points.csv'), 'VariableNamingRule', 'preserve');
opts.SelectedVariableNames = [{'x_cmd_mm', 'y_cmd_mm'}, arrayfun(@(f) sprintf('%dkHz_wave_Vrms', f), ...
    cfg.led_freqs_khz, 'UniformOutput', false)];
t = readtable(fullfile(cfg.scan_dir, 'points.csv'), opts);
x = t.x_cmd_mm; y = t.y_cmd_mm; rss = t{:, 3:end};
h = cfg.H_led - (cfg.H_base0 + cfg.scan_z_mm/1e3 + cfg.pd_elev);
end

%% ------------------------------------------------------------------------------------------------------
function R = part_leds(cfg)
% Every LED as an independent single-LED system: pattern centre from D1 vs geometric position from that
% LED's own directions at the known D2 positions; positioning of the 125 D2 sites with each LED alone.
G = load(fullfile(cfg.figdir, 'grid_results.mat'));
[x, y, rss, h] = load_full_scan(cfg);
D = G.D;
S = size(D.truth, 2);
nearest = @(xs, ys) arrayfun(@(a, b) find_nearest(x, y, a, b), xs, ys);
sets = struct('g3', [], 'g4', [], 'all', (1:numel(x))');
for n = [3 4]
    v = linspace(100, 1300, n);
    [X, Y] = meshgrid(v, v);
    sets.(sprintf('g%d', n)) = nearest(X(:), Y(:));
end
names = fieldnames(sets);
for j = 1:numel(cfg.led_freqs_khz)
    f = cfg.led_freqs_khz(j);
    [~, kmax] = max(rss(:, j));
    p0 = pp_params(cfg, 'SQ', 1, 6, [x(kmax) y(kmax)]);
    [A_pc, m_pc, xy_pc] = pp_calibrate(x, y, rss(:, j), [x(kmax) y(kmax)], h, p0, 'joint_xy');
    % directions of this LED at the known positions (independent of A, m and of the LED position)
    U = pp_estimate('SQ', 'NLS', D.rss(:, :, j), D.theta, G.OFF.SQ.fit.cross, cfg.tilt_deg, p0).u;
    geo_all = triangulate_rays(D.truth, U, true(1, S));
    geo_cross = zeros(3, S);
    for l = 1:numel(D.levels)
        geo_cross(:, D.level == l) = repmat(triangulate_rays(D.truth, U, D.level ~= l), 1, nnz(D.level == l));
    end
    shift = norm(xy_pc(:) - geo_all(1:2)*1e3);
    L = struct('freq_khz', f, 'pattern_xy_mm', xy_pc, 'pattern_A', A_pc, 'pattern_m', m_pc, ...
        'geometric_xyz_m', geo_all, 'shift_cm', shift/10, 'tilt_deg', atand(shift/1e3/h));
    for s = 1:numel(names)
        idx = sets.(names{s});
        % (a) first-time calibration: LED XY, A and m from the points of the set
        [A, m, xy] = pp_calibrate(x(idx), y(idx), rss(idx, j), xy_pc, h, p0, 'joint_xy');
        p = pp_params(cfg, 'SQ', A, m, xy);
        e = site_errors(pp_estimate('SQ', 'NLS', D.rss(:, :, j), D.theta, G.OFF.SQ.fit.cross, cfg.tilt_deg, p), D, p);
        L.(['pattern_' names{s}]) = struct('err3d', e.summary.err3d, 'vertical_bias', e.summary.vertical_bias, 'A', A, 'm', m, 'xy_mm', xy);
        % (b) geometric LED XY (cross-height, from the other heights) with A and m from the set
        eg = nan(1, S); ev = nan(1, S);
        for l = 1:numel(D.levels)
            sel = D.level == l;
            xyg = geo_cross(1:2, find(sel, 1))'*1e3;
            [A, m] = pp_calibrate(x(idx), y(idx), rss(idx, j), xyg, h, p0, 'joint');
            p = pp_params(cfg, 'SQ', A, m, xyg);
            Es = pp_estimate('SQ', 'NLS', D.rss(:, sel, j), D.theta(:, sel), G.OFF.SQ.fit.cross(sel), cfg.tilt_deg, p);
            es = Es.r - D.truth(:, sel);
            eg(sel) = 100*vecnorm(es);
            ev(sel) = 100*es(3, :);
        end
        L.(['geometric_' names{s}]) = struct('err3d', pp_stats(eg), 'vertical_bias', mean(ev, 'omitnan'));
    end
    fprintf('%d kHz: pattern (%.0f, %.0f) mm, m %.2f; geometric (%.0f, %.0f, %.3f m); shift %.1f cm, tilt %.1f deg\n', ...
        f, xy_pc, m_pc, 1e3*geo_all(1:2), geo_all(3), L.shift_cm, L.tilt_deg);
    fprintf('     pattern XY: 3x3 %.2f, 4x4 %.2f, all %.2f cm | geometric XY: 3x3 %.2f, 4x4 %.2f, all %.2f cm\n', ...
        L.pattern_g3.err3d.mean, L.pattern_g4.err3d.mean, L.pattern_all.err3d.mean, ...
        L.geometric_g3.err3d.mean, L.geometric_g4.err3d.mean, L.geometric_all.err3d.mean);
    L.nine = nine_point_system(cfg, D, x, y, rss(:, j), D.rss(:, :, j), sets.g3, h);
    R.(sprintf('led%d', f)) = L;
end
figure_maps(cfg, x, y, rss, R);
end

function N = nine_point_system(cfg, D, x, y, rss, rss2, idx, h)
% One LED calibrated from scratch as a single-LED system (Section VI-E): LED XY, A and m by the joint fit on the nine
% points idx of D1, search started at the strongest of them; receiver as calibrated (SQ, stage zero cfg.offset_deg);
% positions of D2 (rss2, K x S) estimated with NLS. Diagnosis: geometric position of the LED from the estimated
% directions at the known positions (all heights; from the other heights when it is used to evaluate a height).
S = size(D.truth, 2);
[~, k] = max(rss(idx));
start = [x(idx(k)) y(idx(k))];
p0 = pp_params(cfg, 'SQ', 1, 6, start);
[A, m, xy] = pp_calibrate(x(idx), y(idx), rss(idx), start, h, p0, 'joint_xy');
p = pp_params(cfg, 'SQ', A, m, xy);
E = pp_estimate('SQ', 'NLS', rss2, D.theta, cfg.offset_deg, cfg.tilt_deg, p);
e = site_errors(E, D, p);
t = p.transmitter.position_m;
u = (t - D.truth)./vecnorm(t - D.truth);
geo = triangulate_rays(D.truth, E.u, true(1, S));
geo_cross = zeros(3, S);
for l = 1:numel(D.levels)
    geo_cross(:, D.level == l) = repmat(triangulate_rays(D.truth, E.u, D.level ~= l), 1, nnz(D.level == l));
end
ug = (geo_cross - D.truth)./vecnorm(geo_cross - D.truth);
shift = norm(xy(:) - 1e3*geo(1:2));
Eg = E;
for l = 1:numel(D.levels)
    sel = D.level == l;
    xyg = 1e3*geo_cross(1:2, find(sel, 1))';
    [Ag, mg] = pp_calibrate(x(idx), y(idx), rss(idx), xyg, h, p0, 'joint');
    pg = pp_params(cfg, 'SQ', Ag, mg, xyg);
    Es = pp_estimate('SQ', 'NLS', rss2(:, sel), D.theta(:, sel), cfg.offset_deg, cfg.tilt_deg, pg);
    Eg.r(:, sel) = Es.r;
    Eg.u(:, sel) = Es.u;
end
eg = site_errors(Eg, D, p);
far = acosd(u(3, :)) >= 35;
N = struct('start_xy_mm', start, 'led_xy_mm', xy, 'A', A, 'm', m, 'D2', e.summary, 'failures', nnz(~E.ok), ...
    'irradiance_deg', [min(acosd(u(3, :))) max(acosd(u(3, :)))], 'rss_mV', 1e3*[min(rss2, [], 'all') max(rss2, [], 'all')], ...
    'geometric_xyz_m', geo, 'shift_cm', shift/10, 'tilt_deg', atand(shift/1e3/h), ...
    'direction_from_calibrated_deg', mean(acosd(min(1, sum(E.u.*u))), 'omitnan'), ...
    'direction_from_geometric_deg', mean(acosd(min(1, sum(E.u.*ug))), 'omitnan'), ...
    'geometric', struct('err3d', eg.summary.err3d, 'horizontal_mean', eg.summary.horizontal_mean, ...
        'vertical_bias', eg.summary.vertical_bias), ...
    'beyond_35deg', struct('n', nnz(far), 'mean_cm', mean(e.err3d(far)), 'mean_geometric_cm', mean(eg.err3d(far)), ...
        'mean_within_cm', mean(e.err3d(~far)), 'mean_geometric_within_cm', mean(eg.err3d(~far))));
fprintf('     nine points from scratch: LED (%.1f, %.1f) mm, A %.5f, m %.3f; D2 mean %.2f cm (horizontal %.2f, vertical %+.2f); geometric (%.1f, %.1f) mm, %.3f m, shift %.1f cm, tilt %.2f deg; directions %.2f deg from it; LED at the geometric position %.2f cm\n', ...
    xy, A, m, e.summary.err3d.mean, e.summary.horizontal_mean, e.summary.vertical_bias, 1e3*geo(1:2), geo(3), shift/10, N.tilt_deg, ...
    N.direction_from_geometric_deg, eg.summary.err3d.mean);
end

function c = triangulate_rays(truth, U, sel)
% Least-squares point closest to the rays truth_i + s u_i (perpendicular distances)
M = zeros(3); b = zeros(3, 1);
for i = find(sel & all(isfinite(U)))
    P = eye(3) - U(:, i)*U(:, i)';
    M = M + P;
    b = b + P*truth(:, i);
end
c = M \ b;
end

function figure_maps(cfg, x, y, rss, R)
% flat-PD RSS maps of the four LEDs: pattern centre (+) and geometric position (x)
fig = pp_figure(7.16, 1.95);
tl = tiledlayout(fig, 1, 4, 'TileSpacing', 'tight', 'Padding', 'compact');
xs = unique(x); ys = unique(y);
for j = 1:numel(cfg.led_freqs_khz)
    L = R.(sprintf('led%d', cfg.led_freqs_khz(j)));
    M = nan(numel(ys), numel(xs));
    [~, ix] = ismember(x, xs); [~, iy] = ismember(y, ys);
    M(sub2ind(size(M), iy, ix)) = rss(:, j)/max(rss(:, j));
    ax = nexttile(tl);
    imagesc(ax, xs/1e3, ys/1e3, M);
    set(ax, 'YDir', 'normal');
    axis(ax, 'equal', 'tight');
    hold(ax, 'on');
    plot(ax, L.pattern_xy_mm(1)/1e3, L.pattern_xy_mm(2)/1e3, 'w+', 'MarkerSize', 6, 'LineWidth', 1.1);
    plot(ax, L.geometric_xyz_m(1), L.geometric_xyz_m(2), 'kx', 'MarkerSize', 6, 'LineWidth', 1.1);
    colormap(ax, parula);
    clim(ax, [0 1]);
    if j == numel(cfg.led_freqs_khz)
        cb = colorbar(ax, 'eastoutside');
        cb.Label.String = 'RSS / max';
        cb.Label.Interpreter = 'latex';
    end
    title(ax, sprintf('%d kHz', cfg.led_freqs_khz(j)), 'FontWeight', 'normal');
    xlabel(ax, '$X$ (m)');
    if j == 1
        ylabel(ax, '$Y$ (m)');
    else
        ax.YTickLabel = [];
    end
    ax.XGrid = 'off'; ax.YGrid = 'off';
end
pp_export(fig, cfg, 'fig_maps');
end
