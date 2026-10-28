% SCENARIO 2 - UNKNOWN YAW: 3D position AND yaw from the directions of two (or more) LEDs, without knowing
% the MTRS offset (the yaw of the receiver). Same data, LEDs and estimators as estimate_position_known_yaw.m
% (scenario 1); nothing is recalibrated: the LED positions are read from results_known_yaw/led_positions.csv.
%
% What is known: the RELATIVE MTRS angles theta_k (encoder), the adapter tilt and the vertical (roll/pitch).
% What is NOT known: the yaw = rotation about the vertical between the receiver frame and the room.
%   1. Direction of every LED in the RECEIVER frame: same estimator, PD normals built with offset 0
%      (n_k = [sin t sin(theta_k), sin t cos(theta_k), cos t]). A rotation about Z does not change the
%      elevation of the directions, only their azimuth: u_j(world) = Rz(yaw) b_j(receiver).
%   2. Position and yaw together: for every yaw, the least-squares intersection of the rays from the LEDs
%      (rays_intersection); the yaw minimises the perpendicular distances (rays_intersection_yaw).
%      Two LEDs give 4 equations for 4 unknowns (x, y, z, yaw); more LEDs are overdetermined.
% The MTRS offset of scenario 1 (66.5 deg) is only used to REPORT the yaw error, never by the estimator.
close all

%% Hyperparameters
here               = fileparts(mfilename('fullpath'));
campaign_dirs      = {'campaign_20261014-185628_grid5x5x2-xy100to1300-s300-z180to360_K10-off65_pd15_tilt0_100ms'};
simulations_dir    = fullfile(here, '..', '..', 'simulations');
rss_source         = 'wave';               % 'wave' (lock-in on the raw waveform) | 'fft' (FFT peak)
led_freqs_khz      = [300 500 700 900];
led_positions_csv  = fullfile(here, 'results_known_yaw', 'led_positions.csv');   % per gantry level (scenario 1)
reference_led_khz  = 500;                  % always used
partner_leds_khz   = [300 700 900];        % paired one by one with the reference
include_all_leds   = true;                 % also all the LEDs together
% PD geometry (same as scenario 1)
H_base_cal_m       = 1.038;                % gantry base height at z = z_cal_mm (m); gantry z in real mm, up
z_cal_mm           = 180;
pd_elevation_m     = 0.09696;
pd_tilt_deg        = 15;                   % adapter tilt (known: it does not depend on the yaw)
mtrs_direction     = 1;
psi_3db_rad        = 0.61;
direction_method   = 'joint_nls';          % 'joint_nls' | 'ratio_gls' | 'ratio_wls'
yaw_grid_deg       = 1;                    % coarse yaw grid of rays_intersection_yaw (then refined)
ambiguity_ratio    = 3;                    % a competing yaw minimum with cost < ratio x best is reported
reference_yaw_deg  = 66.5;                 % MTRS offset of scenario 1: ONLY to report the yaw error
% figures and comparison
compare_known_yaw  = true;                 % overlay the results of scenario 1 (results_known_yaw/)
k_study            = true;
k_study_values     = 3:10;
app_orientation    = true;
export_figures     = true;                 % PNG (300 dpi) + FIG + CSV in output_dir (overwritten)
output_dir         = fullfile(here, 'results_unknown_yaw');

%% Setup
addpath(simulations_dir);
cambridge_setup();
pd_height = @(z_gantry_mm) H_base_cal_m + (z_gantry_mm - z_cal_mm)/1e3 + pd_elevation_m;
column = @(f) sprintf('%gkHz_%s_Vrms', f, rss_source);
base = system_parameters();
base.acquisition.samples_per_orientation = 1;
p = bastiaens2020_parameters(base, 'PDA100A2', 'SQ', 90);
p.receiver.response_parameters.psi_3db_rad = psi_3db_rad;
nL = numel(led_freqs_khz);
ref = find(led_freqs_khz == reference_led_khz);
yaw_true = mod(mtrs_direction*reference_yaw_deg, 360);    % u_world = Rz(direction*offset) u_receiver
wrap180 = @(a) mod(a + 180, 360) - 180;

%% Campaign
data = cell(numel(campaign_dirs), 1);
for c = 1:numel(campaign_dirs)
    data{c} = readtable(fullfile(here, campaign_dirs{c}, 'points.csv'), 'VariableNamingRule', 'preserve');
    data{c}.campaign = repmat(c, height(data{c}), 1);
end
data = vertcat(data{:});
K = numel(unique(data.k));
[~, ~, group] = unique([data.campaign data.site_id], 'rows');
complete = find(accumarray(group, 1) == K);
S = numel(complete);
truth = zeros(3, S);
gantry_z_mm = zeros(1, S);
theta = zeros(K, S);
rss = zeros(K, S, nL);
for i = 1:S
    rows = sortrows(data(group == complete(i), :), 'k');
    gantry_z_mm(i) = rows.z_cmd_mm(1);
    truth(:, i) = [rows.x_cmd_mm(1)/1e3; rows.y_cmd_mm(1)/1e3; pd_height(gantry_z_mm(i))];
    theta(:, i) = rows.angle_deg;
    for j = 1:nL
        rss(:, i, j) = rows.(column(led_freqs_khz(j)));
    end
end
levels = unique(gantry_z_mm);
level = arrayfun(@(z) find(levels == z), gantry_z_mm);
fprintf('%d sites, K = %d, %s; yaw unknown (reference %g deg used only to report the error)\n', S, K, ...
    rss_source, yaw_true);

%% LED positions of scenario 1 (not recalibrated)
leds_table = readtable(led_positions_csv);
site_leds = nan(3, nL, S);
for i = 1:S
    for j = 1:nL
        row = leds_table(leds_table.gantry_z_mm == gantry_z_mm(i) & leds_table.freq_khz == led_freqs_khz(j), :);
        assert(height(row) == 1, 'LED %g kHz missing for gantry z = %g in %s', led_freqs_khz(j), ...
            gantry_z_mm(i), led_positions_csv);
        site_leds(:, j, i) = [row.x_mm/1e3; row.y_mm/1e3; row.height_m];
    end
end
fprintf('LED positions read from %s\n', led_positions_csv);

%% Stage 1: direction of every LED in the RECEIVER frame (offset 0)
B = nan(3, S, nL);
for i = 1:S
    N = pd_normals(theta(:, i), 0, pd_tilt_deg, mtrs_direction);
    for j = 1:nL
        B(:, i, j) = led_direction(rss(:, i, j), N, p, direction_method);
    end
end

%% Stage 2: position + yaw from the rays of every LED combination
combos = arrayfun(@(f) [ref find(led_freqs_khz == f)], partner_leds_khz, 'UniformOutput', false);
if include_all_leds && nL > 2
    combos{end + 1} = [ref setdiff(1:nL, ref)];
end
nc = numel(combos);
names = strings(1, nc);
for c = 1:nc
    names(c) = strjoin(compose('%g', led_freqs_khz(combos{c})), ' + ') + " kHz";
end
estimate = nan(3, S, nc);
yaw = nan(S, nc);
second_ratio = nan(S, nc);
ray_miss = nan(S, nc);
for c = 1:nc
    for i = 1:S
        [estimate(:, i, c), yaw(i, c), info] = locate_yaw(site_leds(:, combos{c}, i), ...
            reshape(B(:, i, combos{c}), 3, []), yaw_grid_deg);
        second_ratio(i, c) = info.second_ratio;
        ray_miss(i, c) = sqrt(mean(info.miss_m.^2));
    end
end

%% Errors
error_3d = squeeze(vecnorm(estimate - truth, 2, 1));
error_h = squeeze(vecnorm(estimate(1:2, :, :) - truth(1:2, :), 2, 1));
error_v = squeeze(estimate(3, :, :) - truth(3, :));
yaw_error = wrap180(yaw - yaw_true);
fprintf('\nUnknown yaw: position and yaw errors over %d sites (cm, deg; vertical > 0 = estimate above):\n', S);
fprintf('  %-28s %5s %7s %7s %7s %7s %7s %9s %10s %10s %9s %10s\n', 'LEDs', 'ok', 'mean', 'RMSE', 'median', ...
    'P90', 'horiz', 'vert bias', 'yaw bias', 'yaw std', 'ray miss', 'ambiguous');
summary = table();
for c = 1:nc
    ok = isfinite(error_3d(:, c));
    e = 100*error_3d(ok, c);
    ye = yaw_error(ok, c);
    n_amb = nnz(second_ratio(ok, c) < ambiguity_ratio);
    fprintf('  %-28s %2d/%2d %7.2f %7.2f %7.2f %7.2f %7.2f %+9.2f %+9.2f d %8.2f d %7.2f cm %7d\n', names(c), ...
        nnz(ok), S, mean(e), sqrt(mean(e.^2)), median(e), prctile(e, 90), 100*mean(error_h(ok, c)), ...
        100*mean(error_v(ok, c)), mean(ye), std(ye), 100*mean(ray_miss(ok, c)), n_amb);
    summary = [summary; table(names(c), nnz(ok), mean(e), sqrt(mean(e.^2)), median(e), prctile(e, 90), ...
        100*mean(error_h(ok, c)), 100*mean(error_v(ok, c)), mean(ye), std(ye), mean(abs(ye)), n_amb, ...
        'VariableNames', {'leds', 'ok', 'mean_cm', 'rmse_cm', 'median_cm', 'p90_cm', 'horizontal_cm', ...
        'vertical_bias_cm', 'yaw_bias_deg', 'yaw_std_deg', 'yaw_mae_deg', 'ambiguous_sites'})]; %#ok<AGROW>
end
fprintf('Per gantry level (cm / deg): mean 3D error / mean yaw error\n');
fprintf('  %-28s%s\n', 'LEDs', sprintf('%20s', string(compose('z = %g', levels))));
for c = 1:nc
    text = '';
    for iz = 1:numel(levels)
        sel = level == iz;
        text = [text sprintf('  %7.2f / %+7.2f d', 100*mean(error_3d(sel, c), 'omitnan'), ...
            mean(yaw_error(sel, c), 'omitnan'))]; %#ok<AGROW>
    end
    fprintf('  %-28s%s\n', names(c), text);
end

% scenario 1 for the comparison
known = [];
known_k = [];
known_cols = matlab.lang.makeValidName("err_cm_" + replace(names, ' ', ''));
if compare_known_yaw && isfile(fullfile(here, 'results_known_yaw', 'errors_per_site.csv'))
    known = readtable(fullfile(here, 'results_known_yaw', 'errors_per_site.csv'));
    fprintf('\nComparison with scenario 1 (known yaw %g deg), mean 3D error (cm):\n', reference_yaw_deg);
    for c = 1:nc
        fprintf('  %-28s known %6.2f   unknown %6.2f\n', names(c), mean(known.(char(known_cols(c))), 'omitnan'), ...
            100*mean(error_3d(:, c), 'omitnan'));
    end
    if isfile(fullfile(here, 'results_known_yaw', 'error_vs_K.csv'))
        known_k = readtable(fullfile(here, 'results_known_yaw', 'error_vs_K.csv'), 'VariableNamingRule', 'preserve');
    end
end

%% Error vs K (subsets of the measured angles)
if k_study
    nk = numel(k_study_values);
    k_mean = nan(nk, nc);
    k_yaw = nan(nk, nc);
    for ik = 1:nk
        subsets = angle_subsets(K, k_study_values(ik));
        e = nan(size(subsets, 1), S, nc);
        ye = nan(size(subsets, 1), S, nc);
        for is = 1:size(subsets, 1)
            sub = subsets(is, :);
            for i = 1:S
                N = pd_normals(theta(sub, i), 0, pd_tilt_deg, mtrs_direction);
                b = nan(3, nL);
                for j = 1:nL
                    b(:, j) = led_direction(rss(sub, i, j), N, p, direction_method);
                end
                for c = 1:nc
                    [r, y] = locate_yaw(site_leds(:, combos{c}, i), b(:, combos{c}), yaw_grid_deg);
                    e(is, i, c) = norm(r - truth(:, i));
                    ye(is, i, c) = abs(wrap180(y - yaw_true));
                end
            end
        end
        for c = 1:nc
            values = e(:, :, c);
            k_mean(ik, c) = 100*mean(values(isfinite(values)));
            values = ye(:, :, c);
            k_yaw(ik, c) = mean(values(isfinite(values)));
        end
    end
    fprintf('\nUnknown yaw, error vs K: mean 3D error (cm) / mean |yaw error| (deg):\n');
    fprintf('  %3s%s\n', 'K', sprintf('%30s', names));
    for ik = 1:nk
        fprintf('  %3d%s\n', k_study_values(ik), sprintf('%19.2f / %6.2f d', [k_mean(ik, :); k_yaw(ik, :)]));
    end
end

%% Figures
colors = lines(nc);
figures = gobjects(0);
fig_names = {};

% CDF: unknown yaw (solid) vs known yaw (dashed, scenario 1)
fig = figure('Name', '3D error CDF', 'Color', 'w', 'Position', [100 100 860 540]);
light_theme(fig);
ax = axes(fig);
hold(ax, 'on');
for c = 1:nc
    values = sort(100*error_3d(isfinite(error_3d(:, c)), c));
    stairs(ax, [0; values], (0:numel(values))'/S, '-', 'Color', colors(c, :), 'LineWidth', 1.8, ...
        'DisplayName', sprintf('%s, unknown yaw: mean %.1f cm', names(c), mean(values)));
    if ~isempty(known) && ismember(known_cols(c), known.Properties.VariableNames)
        values = sort(known.(char(known_cols(c))));
        values = values(isfinite(values));
        stairs(ax, [0; values], (0:numel(values))'/S, '--', 'Color', colors(c, :), 'LineWidth', 1.1, ...
            'DisplayName', sprintf('%s, known yaw: mean %.1f cm', names(c), mean(values)));
    end
end
grid(ax, 'on');
box(ax, 'on');
ylim(ax, [0 1]);
xlabel(ax, '3D position error (cm)');
ylabel(ax, 'Empirical CDF');
title(ax, sprintf('Position from LED directions, yaw estimated (solid) vs known (dashed); K = %d, %d sites', K, S), ...
    'FontWeight', 'normal');
legend(ax, 'Location', 'southeast');
figures(end + 1) = fig;
fig_names{end + 1} = 'error_cdf';

% true vs estimated positions
fig = figure('Name', 'Positions', 'Color', 'w', 'Position', [40 40 400*nc 820]);
light_theme(fig);
layout = tiledlayout(fig, 2, nc, 'TileSpacing', 'compact', 'Padding', 'compact');
level_colors = lines(numel(levels));
T = 1e3*truth;
leds_used = mean(site_leds, 3);
for view_index = 1:2
    for c = 1:nc
        ax = nexttile(layout);
        hold(ax, 'on');
        E = 1e3*estimate(:, :, c);
        segments = reshape([T; E; nan(3, S)], 3, []);
        ok = isfinite(error_3d(:, c));
        if view_index == 1
            plot3(ax, segments(1, :), segments(2, :), segments(3, :), '-', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
            plot3(ax, T(1, :), T(2, :), T(3, :), 'ko', 'MarkerSize', 5, 'DisplayName', 'True');
            for iz = 1:numel(levels)
                sel = level == iz;
                plot3(ax, E(1, sel), E(2, sel), E(3, sel), 'o', 'MarkerFaceColor', level_colors(iz, :), ...
                    'MarkerEdgeColor', 'none', 'MarkerSize', 4, 'DisplayName', sprintf('Estimated (Z = %.0f mm)', ...
                    T(3, find(sel, 1))));
            end
            view(ax, -35, 25);
            xlabel(ax, 'X (mm)');
            ylabel(ax, 'Y (mm)');
            zlabel(ax, 'Z, height (mm)');
            title(ax, sprintf('%s\nmean %.1f cm, |yaw error| %.2f deg', names(c), 100*mean(error_3d(ok, c)), ...
                mean(abs(yaw_error(ok, c)))), 'FontWeight', 'normal');
        else
            [hh, vv, h_label, v_label] = top_view(segments, app_orientation);
            plot(ax, hh, vv, '-', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
            [hh, vv] = top_view(T, app_orientation);
            plot(ax, hh, vv, 'ko', 'MarkerSize', 5, 'DisplayName', 'True');
            for iz = 1:numel(levels)
                sel = level == iz;
                [hh, vv] = top_view(E(:, sel), app_orientation);
                plot(ax, hh, vv, 'o', 'MarkerFaceColor', level_colors(iz, :), 'MarkerEdgeColor', 'none', ...
                    'MarkerSize', 4, 'DisplayName', sprintf('Z = %.0f mm', T(3, find(sel, 1))));
            end
            [hh, vv] = top_view(1e3*leds_used, app_orientation);
            plot(ax, hh, vv, 'p', 'Color', [0.6 0.6 0.6], 'MarkerSize', 10, 'HandleVisibility', 'off');
            [hh, vv] = top_view(1e3*leds_used(:, combos{c}), app_orientation);
            plot(ax, hh, vv, 'kp', 'MarkerFaceColor', 'y', 'MarkerSize', 13, 'DisplayName', 'LEDs used');
            if app_orientation
                set(ax, 'XDir', 'reverse');
            end
            axis(ax, 'equal');
            xlim(ax, [0 1400]);
            ylim(ax, [0 1400]);
            xlabel(ax, h_label);
            ylabel(ax, v_label);
            title(ax, 'Top view', 'FontWeight', 'normal');
        end
        grid(ax, 'on');
        box(ax, 'on');
        if c == 1
            legend(ax, 'Location', 'best');
        end
    end
end
title(layout, sprintf('Unknown yaw: position and yaw from the LED directions (%s)', strrep(direction_method, '_', '\_')), ...
    'FontSize', 11);
figures(end + 1) = fig;
fig_names{end + 1} = 'positions';

% yaw error per combination and error vs K
fig = figure('Name', 'Yaw error and K', 'Color', 'w', 'Position', [120 120 1500 460]);
light_theme(fig);
layout = tiledlayout(fig, 1, 1 + 2*k_study, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(layout);
groups = categorical(repmat(names, S, 1), names);
boxchart(ax, groups(:), yaw_error(:), 'MarkerStyle', '.');
ylabel(ax, sprintf('Yaw error (deg), reference %g deg', yaw_true));
title(ax, sprintf('Estimated yaw (K = %d)', K), 'FontWeight', 'normal');
grid(ax, 'on');
box(ax, 'on');
if k_study
    ax = nexttile(layout);
    hold(ax, 'on');
    for c = 1:nc
        plot(ax, k_study_values, k_mean(:, c), 'o-', 'Color', colors(c, :), 'LineWidth', 1.6, ...
            'MarkerFaceColor', colors(c, :), 'DisplayName', names(c) + ", unknown yaw");
        if ~isempty(known_k) && ismember(names(c), known_k.Properties.VariableNames)
            plot(ax, known_k.K, known_k.(char(names(c))), '--', 'Color', colors(c, :), 'LineWidth', 1.1, ...
                'DisplayName', names(c) + ", known yaw");
        end
    end
    xticks(ax, k_study_values);
    xlabel(ax, 'Number of orientations K');
    ylabel(ax, 'Mean 3D position error (cm)');
    title(ax, 'Position error vs K', 'FontWeight', 'normal');
    legend(ax, 'Location', 'northeast');
    grid(ax, 'on');
    box(ax, 'on');
    ax = nexttile(layout);
    hold(ax, 'on');
    for c = 1:nc
        plot(ax, k_study_values, k_yaw(:, c), 'o-', 'Color', colors(c, :), 'LineWidth', 1.6, ...
            'MarkerFaceColor', colors(c, :), 'DisplayName', names(c));
    end
    xticks(ax, k_study_values);
    xlabel(ax, 'Number of orientations K');
    ylabel(ax, 'Mean |yaw error| (deg)');
    title(ax, 'Yaw error vs K', 'FontWeight', 'normal');
    legend(ax, 'Location', 'northeast');
    grid(ax, 'on');
    box(ax, 'on');
end
figures(end + 1) = fig;
fig_names{end + 1} = 'yaw_error_and_K';

%% Export
if export_figures
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
    for i = 1:numel(figures)
        exportgraphics(figures(i), fullfile(output_dir, [fig_names{i} '.png']), 'Resolution', 300);
        savefig(figures(i), fullfile(output_dir, [fig_names{i} '.fig']));
    end
    writetable(summary, fullfile(output_dir, 'summary.csv'));
    per_site = table(truth(1, :)', truth(2, :)', truth(3, :)', gantry_z_mm', 'VariableNames', ...
        {'true_X_m', 'true_Y_m', 'true_Z_m', 'gantry_z_mm'});
    for c = 1:nc
        tag = char(known_cols(c));
        per_site.(tag) = 100*error_3d(:, c);
        per_site.(strrep(tag, 'err_cm_', 'yaw_deg_')) = yaw(:, c);
    end
    writetable(per_site, fullfile(output_dir, 'errors_per_site.csv'));
    if k_study
        writetable(array2table([k_study_values(:) k_mean k_yaw], 'VariableNames', ['K', cellstr(names), ...
            cellstr(names + " |yaw err| deg")]), fullfile(output_dir, 'error_vs_K.csv'));
    end
    fprintf('Figures and tables saved in %s\n', output_dir);
end

%% Local functions
function [r, yaw_deg, info] = locate_yaw(L, B, grid_step_deg)
info = struct('second_ratio', nan, 'miss_m', nan);
r = nan(3, 1);
yaw_deg = nan;
if any(~isfinite(B), 'all')
    return;
end
[r, yaw_deg, info] = rays_intersection_yaw(L, B, grid_step_deg);
end

function light_theme(fig)
try
    theme(fig, 'light');
catch
end
end

function subsets = angle_subsets(K_full, K)
base = round((0:K - 1)*K_full/K);
subsets = unique(sort(mod(base + (0:K_full - 1)', K_full), 2) + 1, 'rows');
end

function [hh, vv, h_label, v_label] = top_view(xyz, app_orientation)
if app_orientation
    hh = xyz(2, :);
    vv = xyz(1, :);
    h_label = 'Y (mm)';
    v_label = 'X (mm)';
else
    hh = xyz(1, :);
    vv = xyz(2, :);
    h_label = 'X (mm)';
    v_label = 'Y (mm)';
end
end
