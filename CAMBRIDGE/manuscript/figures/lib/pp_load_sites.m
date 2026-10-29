function D = pp_load_sites(dirs, cfg, keep)
% Complete sites (all K orientations) of acquisition sessions (points.csv).
% D.truth 3 x S (m, Z up), D.theta K x S (measured MTRS angles, deg), D.rss K x S x 4 (lock-in RSS, V, LEDs
% cfg.led_freqs_khz), D.tilt_read K x S (MTRS tilt reading), D.z_mm, D.xy_mm, D.campaign, D.site, D.time (s).
if nargin < 3
    keep = inf(1, numel(dirs));
end
cols = [{'site_id', 'k', 'x_cmd_mm', 'y_cmd_mm', 'z_cmd_mm', 'angle_deg', 'mtrs_tilt_deg', 'unix_time_s'}, ...
        arrayfun(@(f) sprintf('%dkHz_wave_Vrms', f), cfg.led_freqs_khz, 'UniformOutput', false)];
parts = cell(1, numel(dirs));
for c = 1:numel(dirs)
    opts = detectImportOptions(fullfile(dirs{c}, 'points.csv'), 'VariableNamingRule', 'preserve');
    opts.SelectedVariableNames = cols;
    t = readtable(fullfile(dirs{c}, 'points.csv'), opts);
    t = t(t.site_id <= keep(c), :);
    t.campaign = repmat(c, height(t), 1);
    parts{c} = t;
end
t = vertcat(parts{:});
K = numel(unique(t.k));
[ids, ~, group] = unique([t.campaign t.site_id], 'rows');
complete = find(accumarray(group, 1) == K);
S = numel(complete);
D = struct('K', K, 'truth', zeros(3, S), 'theta', zeros(K, S), 'rss', zeros(K, S, numel(cfg.led_freqs_khz)), ...
    'tilt_read', zeros(K, S), 'z_mm', zeros(1, S), 'xy_mm', zeros(2, S), 'campaign', ids(complete, 1)', ...
    'site', ids(complete, 2)', 'time', zeros(1, S));
for i = 1:S
    rows = sortrows(t(group == complete(i), :), 'k');
    D.z_mm(i) = rows.z_cmd_mm(1);
    D.xy_mm(:, i) = [rows.x_cmd_mm(1); rows.y_cmd_mm(1)];
    D.truth(:, i) = [rows.x_cmd_mm(1)/1e3; rows.y_cmd_mm(1)/1e3; cfg.H_base0 + rows.z_cmd_mm(1)/1e3 + cfg.pd_elev];
    D.theta(:, i) = rows.angle_deg;
    D.tilt_read(:, i) = rows.mtrs_tilt_deg;
    D.time(i) = mean(rows.unix_time_s);
    for j = 1:numel(cfg.led_freqs_khz)
        D.rss(:, i, j) = rows.(cols{8 + j});
    end
end
D.levels = unique(D.z_mm);
D.level = arrayfun(@(z) find(D.levels == z), D.z_mm);
end
