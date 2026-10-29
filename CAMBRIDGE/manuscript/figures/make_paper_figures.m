function make_paper_figures(parts)
% Figures and numbers of the manuscript, computed directly from the acquired datasets.
%   make_paper_figures                      % every part
%   make_paper_figures({'grid', 'random'})  % selected parts: grid | random | noise | peb | calib | leds
% Numbers are merged into paper_numbers.json (read when writing the manuscript); figures are vector PDF
% (PNG previews in png/). Run with MATLAB R2026a or later.
if nargin < 1 || isempty(parts)
    parts = {'grid', 'random', 'noise', 'peb', 'calib', 'leds'};
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
    NUM.(parts{k}) = feval(['part_' parts{k}], cfg);
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
        OFF.(models{im}).(led{1}) = struct('all', off_all, 'cross', cross);
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

function figure_grid(cfg, D, ef, R)
% (a) error per height: 3D, horizontal, vertical bias; (b) top view of the horizontal error vectors
fig = pp_figure(3.5, 2.3);
H = arrayfun(@(s) s.pd_height_m, R.final_per_level);
m3 = arrayfun(@(s) s.err3d.mean, R.final_per_level);
p90 = arrayfun(@(s) s.err3d.p90, R.final_per_level);
mh = arrayfun(@(s) s.horizontal_mean, R.final_per_level);
vb = arrayfun(@(s) s.vertical_bias, R.final_per_level);
ax = axes(fig);
hold(ax, 'on');
plot(ax, H, m3, 'o-', 'Color', [0 0.32 0.62], 'MarkerFaceColor', [0 0.32 0.62], 'MarkerSize', 3.5, ...
    'DisplayName', 'Mean 3D error');
plot(ax, H, p90, 's--', 'Color', [0 0.32 0.62], 'MarkerSize', 3.5, 'DisplayName', '90th percentile');
plot(ax, H, mh, '^-', 'Color', [0.85 0.33 0.1], 'MarkerFaceColor', [0.85 0.33 0.1], 'MarkerSize', 3.5, ...
    'DisplayName', 'Mean horizontal error');
plot(ax, H, vb, 'v-', 'Color', [0.47 0.67 0.19], 'MarkerFaceColor', [0.47 0.67 0.19], 'MarkerSize', 3.5, ...
    'DisplayName', 'Mean vertical error');
yline(ax, 0, 'k-', 'LineWidth', 0.4, 'HandleVisibility', 'off');
xlabel(ax, 'PD height above the floor (m)');
ylabel(ax, 'Error (cm)');
xlim(ax, [0.93 1.34]);
legend(ax, 'Location', 'northeast', 'NumColumns', 2);
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
specs = {'K10', '-', [0 0.32 0.62], sprintf('Grid, $K=10$ (%d sites)', numel(cdf.K10)); ...
         'K5', '-', [0.85 0.33 0.1], 'Grid, $K=5$ (subsets)'; ...
         'K3', '-', [0.47 0.67 0.19], 'Grid, $K=3$ (subsets)'; ...
         'D3', '--', [0 0 0], sprintf('Blind random test, $K=5$ (%d points)', numel(cdf.D3))};
for s = 1:size(specs, 1)
    v = sort(cdf.(specs{s, 1})(isfinite(cdf.(specs{s, 1}))));
    stairs(ax, [0 v], (0:numel(v))/numel(v), specs{s, 2}, 'Color', specs{s, 3}, 'LineWidth', 1.1, ...
        'DisplayName', sprintf('%s: %.2f cm', specs{s, 4}, mean(v)));
end
xlim(ax, [0 12]);
ylim(ax, [0 1]);
xlabel(ax, '3D position error (cm)');
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
title(ax, '(a) 3D view', 'FontWeight', 'normal');
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
cb.Label.String = '3D error (cm)';
cb.Label.Interpreter = 'latex';
pp_export(fig, cfg, 'fig_random');
end

function figure_integrity(cfg, F, EF, eF, threshold)
% RSS-shape residual of every point of the 16/10 session: the rotation-stage tilt fault appears at point 48
fig = pp_figure(3.5, 2.9);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
k = F.site;
onset = 47.5;
ax = nexttile(tl);
hold(ax, 'on');
plot(ax, k, EF.shape_rms, 'o-', 'Color', [0 0.32 0.62], 'MarkerSize', 2.5, 'MarkerFaceColor', [0 0.32 0.62], ...
    'LineWidth', 0.7, 'DisplayName', 'RSS-shape residual');
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
ylabel(ax2, '3D error (cm)');
pp_export(fig, cfg, 'fig_integrity');
end

%% ------------------------------------------------------------------------------------------------------
function R = part_noise(cfg)
% Noise of the lock-in RSS from the raw D2 records (100 ms at 10 MSa/s): additive floor from off-tone DFT
% bins 20-40 kHz away from every tone, check of the stored RSS, and record-to-record repeatability.
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
snr = rss_dft(:, 2)./sigma(:, 2);
R.snr500 = struct('min', min(snr), 'median', median(snr), 'max', max(snr));
R.rss500_mV = 1e3*[min(rss_dft(:, 2)) median(rss_dft(:, 2)) max(rss_dft(:, 2))];
fprintf('noise floor (median, uV): %s; RSS check max rel diff %.2g; SNR500 %.0f / %.0f / %.0f\n', ...
    mat2str(R.sigma_median_uV, 3), R.rss_check_max_rel, R.snr500.min, R.snr500.median, R.snr500.max);
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
save(fullfile(cfg.figdir, 'noise_results.mat'), 'sigma', 'rss_dft', 'sigma_med', 'rel_med', 'rel');
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
yline(ax, median(sigma(:, 2))*sqrt(2), 'k--', 'LineWidth', 0.5);
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
sigma = Nz.sigma_med(jf);
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
save(fullfile(cfg.figdir, 'peb_results.mat'), 'peb10', 'peb5', 'peb_rel', 'pebo', 'sth', 'tilts', 'sv', 'curve', 'curve90');
% figure: (a) CDF of measured error and bounds at the D2 sites, (b) median PEB versus tilt
fig = pp_figure(3.5, 3.9);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);
hold(ax, 'on');
cdfline = @(v, ls, c, name) stairs(ax, [min(v) sort(v)], (0:numel(v))/numel(v), ls, 'Color', c, ...
    'LineWidth', 1.0, 'DisplayName', name);
cdfline(100*peb10, '-', [0.5 0.5 0.5], 'PEB, measured noise');
colors = [0.47 0.67 0.19; 0.85 0.33 0.1; 0.49 0.18 0.56];
for q = 1:numel(sth)
    cdfline(100*pebo(q, :), '-', colors(q, :), sprintf('PEB, $\\sigma_\\theta=%g^\\circ$', sth(q)));
end
cdfline(G.ef.err3d, '-', [0 0.32 0.62], 'Measured error');
set(ax, 'XScale', 'log');
xlim(ax, [1e-2 20]);
ylim(ax, [0 1]);
xlabel(ax, '3D error or bound (cm)');
ylabel(ax, 'Empirical CDF');
legend(ax, 'Location', 'northwest', 'FontSize', 6.5);
title(ax, '(a) Grid sites, $K=10$', 'FontWeight', 'normal');
ax2 = nexttile(tl);
hold(ax2, 'on');
lc = [0.5 0.5 0.5; colors];
for q = 1:numel(sv)
    if sv(q) == 0
        name = 'Measured noise only';
    else
        name = sprintf('$\\sigma_\\theta=%g^\\circ$', sv(q));
    end
    plot(ax2, tilts, 100*curve(q, :), '-', 'Color', lc(q, :), 'LineWidth', 1.0, 'DisplayName', name);
end
xline(ax2, cfg.tilt_deg, 'k:', 'LineWidth', 0.8, 'HandleVisibility', 'off');
set(ax2, 'YScale', 'log');
xlim(ax2, [0 45]);
xlabel(ax2, 'Receiver tilt $\theta$ ($^\circ$)');
ylabel(ax2, 'Median PEB (cm)');
legend(ax2, 'Location', 'northeast', 'FontSize', 6.5);
title(ax2, '(b) Uniform cone, $K=5$, grid positions', 'FontWeight', 'normal');
pp_export(fig, cfg, 'fig_peb');
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
ylabel(ax2, 'Mean 3D error on the grid (cm)');
legend(ax2, 'Location', 'northeast', 'FontSize', 6.5);
title(ax2, '(b) Calibration budget', 'FontWeight', 'normal');
pp_export(fig, cfg, 'fig_calibration');
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
    R.(sprintf('led%d', f)) = L;
end
figure_maps(cfg, x, y, rss, R);
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
    title(ax, sprintf('%d kHz (max %.1f mV)', cfg.led_freqs_khz(j), 1e3*max(rss(:, j))), 'FontWeight', 'normal');
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
