% SCENARIO 1 - KNOWN YAW (the MTRS offset is known): 3D position from the DIRECTIONS of two (or more) LEDs,
% with the reorientable PD of experiment 01. Results in results_known_yaw/ (also read by
% estimate_position_unknown_yaw.m: LED positions and errors for the comparison).
% Every campaign row already contains the RSS of the four LEDs (FDM at 300, 500, 700 and 900 kHz). For every
% LED the direction PD -> LED is estimated from the shape of its K RSS (stage 1 of experiment 01, ratios or
% a free amplitude, SQ response of the PDA100A2), and the position is the point closest to the rays
%     r = argmin sum_j |P_j (r - L_j)|^2,  P_j = I - u_j u_j'                  (rays_intersection)
% where L_j is the position of LED j and u_j its estimated direction. No range is estimated: the method does
% NOT use the LED power, the receiver gain, the calibration constant A nor the Lambertian order m. It needs the
% LED positions and the PD orientation (MTRS offset and adapter tilt), as stage 1 of experiment 01.
% The 500 kHz LED is always used; it is paired with each of the other LEDs (and optionally all together).
% Reference: the single-LED method of experiment 01 (direction + range with the calibrated A, m).
%
% Coordinates: X, Y of the gantry (m), Z = height above the floor (m, up). The PD centre is
%   Z_pd = H_base_cal + gantry_z_scale (z_cal - z_gantry) + pd_elevation
% LED positions: given (mm) or fitted from the flat-PD scan of RSS_Distribution (calibration data, not the
% campaign): joint fit of XY, A and m of RSS = A R(phi) cos(phi)^m / d^2, horizontal PD (psi = phi).
close all

%% Hyperparameters
here               = fileparts(mfilename('fullpath'));
campaign_dirs      = {'campaign_20261014-185628_grid5x5x2-xy100to1300-s300-z-600to-300_K10-off65_pd15_tilt0_100ms'};
simulations_dir    = fullfile(here, '..', '..', 'simulations');
rss_source         = 'wave';               % 'wave' (lock-in on the raw waveform) | 'fft' (FFT peak)
% LEDs: frequency, XY in gantry coordinates (mm, or 'fit' = fitted from the flat-PD scan) and height (m)
led_freqs_khz      = [300 500 700 900];
led_xy_mm          = {'fit', [281.1 904.8], 'fit', 'fit'};   % 500 kHz: final value of experiment 01 / demo
led_height_m       = [3 3 3 3];            % LED plane above the floor
led_scan_csv       = fullfile(here, '..', 'RSS_Distribution', 'points.csv');   % flat PD, z = z_cal_mm, 4 LEDs
led_positions      = 'rays_cross_height';  % 'given' (led_xy_mm / led_height_m above) | 'rays_cross_height':
                                           % LED 3D position = intersection of its estimated directions from the
                                           % TRUE PD positions of the OTHER gantry levels (calibration with known
                                           % positions; each level is estimated with LEDs fitted on the others).
                                           % The flat-scan fit gives the centre of the radiation PATTERN, which is
                                           % not the geometric LED position if the LED is tilted (700 kHz: 18 cm)
reference_led_khz  = 500;                  % always used
partner_leds_khz   = [300 700 900];        % paired one by one with the reference
include_all_leds   = true;                 % also the position from all the LEDs together
% PD geometry and orientation (final values of experiment 01 / demo/config/demo.toml)
H_base_cal_m       = 1.038;                % height of the gantry base at z = z_cal_mm (m)
z_cal_mm           = -300;
pd_elevation_cal_m = 0.09696;              % gantry base -> PD centre in the flat scan (0 deg adapter)
pd_elevation_m     = 0.09696;              % gantry base -> PD centre in the campaign (MTRS + 15 deg adapter)
gantry_z_scale     = 0.6;                  % real vertical travel per commanded mm (tape, 2026-10-15)
pd_tilt_deg        = 15;                   % adapter tilt from the vertical
mtrs_offset_deg    = 66.5;                 % real MTRS offset (calibrated with LED 500 at (281.1, 904.8))
mtrs_direction     = 1;
% PD response and direction estimator
psi_3db_rad        = 0.61;                 % SQ response, R(psi_3dB) = 1/sqrt(2)
direction_method   = 'joint_nls';          % 'joint_nls' | 'ratio_gls' | 'ratio_wls' (pd_fit_estimate)
ray_weights        = 'equal';              % 'equal' | 'range' (1/d^2, from a first equal-weight solution)
% single-LED reference (experiment 01: direction + range, needs A and m)
baseline           = true;
baseline_A         = 0.062707;             % V m^2 (tools/calibrate.py, SQ, LED (281.1, 904.8))
baseline_m         = 6.0918;
% figures
k_study            = true;                 % error vs K with near-uniform subsets of the measured angles
k_study_values     = 3:10;
app_orientation    = true;                 % top views as in the acquisition tool (Y horizontal, X vertical)
export_figures     = true;                 % PNG (300 dpi) + FIG + CSV in output_dir (overwritten)
output_dir         = fullfile(here, 'results_known_yaw');

%% Setup
addpath(simulations_dir);
cambridge_setup();
pd_height = @(z_gantry_mm, elevation_m) H_base_cal_m + gantry_z_scale*(z_cal_mm - z_gantry_mm)/1e3 + elevation_m;
column = @(f) sprintf('%gkHz_%s_Vrms', f, rss_source);
base = system_parameters();
base.acquisition.samples_per_orientation = 1;
p = bastiaens2020_parameters(base, 'PDA100A2', 'SQ', 90);
p.receiver.response_parameters.psi_3db_rad = psi_3db_rad;
nL = numel(led_freqs_khz);
ref = find(led_freqs_khz == reference_led_khz);
assert(~isempty(ref), 'The reference LED must be in led_freqs_khz.');

%% Campaign: one site = one PD position with its K orientations (RSS of every LED)
data = cell(numel(campaign_dirs), 1);
for c = 1:numel(campaign_dirs)
    data{c} = readtable(fullfile(here, campaign_dirs{c}, 'points.csv'), 'VariableNamingRule', 'preserve');
    data{c}.campaign = repmat(c, height(data{c}), 1);
    fprintf('%s: %d rows, gantry z = %s mm\n', campaign_dirs{c}, height(data{c}), mat2str(unique(data{c}.z_cmd_mm)'));
end
data = vertcat(data{:});
K = numel(unique(data.k));
if any(data.mtrs_tilt_cmd_deg ~= 0) || numel(unique(data.pd_tilt_deg)) > 1
    error('Expected MTRS tilt 0 and a single adapter in every row.');
end
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
    truth(:, i) = [rows.x_cmd_mm(1)/1e3; rows.y_cmd_mm(1)/1e3; pd_height(gantry_z_mm(i), pd_elevation_m)];
    theta(:, i) = rows.angle_deg;
    for j = 1:nL
        rss(:, i, j) = rows.(column(led_freqs_khz(j)));
    end
end
levels = unique(gantry_z_mm);
level = arrayfun(@(z) find(levels == z), gantry_z_mm);
fprintf('%d sites, K = %d, %s, PD heights %s m\n', S, K, rss_source, ...
    mat2str(arrayfun(@(z) pd_height(z, pd_elevation_m), levels), 4));

%% LED positions (given, or fitted from the flat-PD scan: calibration data, independent of the campaign)
leds = zeros(3, nL);
scan = [];
fprintf('\nLED positions (gantry mm, height m):\n');
for j = 1:nL
    source = 'given';
    if ischar(led_xy_mm{j})
        if isempty(scan)
            scan = readtable(led_scan_csv, 'VariableNamingRule', 'preserve');
            assert(all(scan.pd_tilt_deg == 0) && all(scan.z_cmd_mm == z_cal_mm), ...
                'The LED scan must be horizontal (pd_tilt 0) at z = %g mm.', z_cal_mm);
        end
        h = led_height_m(j) - pd_height(z_cal_mm, pd_elevation_cal_m);
        [xy, A, m] = fit_led(scan.x_cmd_mm, scan.y_cmd_mm, scan.(column(led_freqs_khz(j))), h, p);
        source = sprintf('fitted from the flat scan (A = %.4g, m = %.2f, not used)', A, m);
    else
        xy = led_xy_mm{j};
    end
    leds(:, j) = [xy(:)/1e3; led_height_m(j)];
    fprintf('  %4g kHz: (%7.1f, %7.1f) mm, %.2f m  %s\n', led_freqs_khz(j), 1e3*leds(1:2, j), leds(3, j), source);
end
for j = setdiff(1:nL, ref)
    fprintf('  baseline %g-%g kHz: %.0f mm\n', reference_led_khz, led_freqs_khz(j), 1e3*norm(leds(:, j) - leds(:, ref)));
end

%% Stage 1: direction of every LED at every site (shape of its K RSS only)
U = nan(3, S, nL);
direction_status = strings(S, nL);
for i = 1:S
    N = pd_normals(theta(:, i), mtrs_offset_deg, pd_tilt_deg, mtrs_direction);
    for j = 1:nL
        [U(:, i, j), direction_status(i, j)] = led_direction(rss(:, i, j), N, p, direction_method);
    end
end
for j = 1:nL
    failed = unique(direction_status(~all(isfinite(U(:, :, j))), j));
    if ~isempty(failed)
        fprintf('  %g kHz direction failures: %s\n', led_freqs_khz(j), strjoin(failed, ', '));
    end
end

% Diagnostic only (uses the true PD positions, so it is NOT used by the estimator): the LED position implied
% by its estimated directions = intersection of the rays truth_i + t u_i. A large shift from the LED position
% used above means that this LED position (or its height) is wrong, not that the directions are noisy.
fprintf('LED implied by its directions (diagnostic, true PD positions; rms miss of the rays):\n');
for j = 1:nL
    ok = all(isfinite(U(:, :, j)));
    [implied, info] = rays_intersection(truth(:, ok), U(:, ok, j));
    fprintf('  %5g kHz: (%7.1f, %7.1f) mm, %.3f m   shift from the LED used: (%+6.1f, %+6.1f) mm, %+5.0f mm   rays %.1f mm\n', ...
        led_freqs_khz(j), 1e3*implied(1:2), implied(3), 1e3*(implied - leds(:, j)), 1e3*sqrt(mean(info.miss_m.^2)));
end

% LED positions used at every site (3 x nL x S)
site_leds = repmat(leds, 1, 1, S);
if strcmp(led_positions, 'rays_cross_height')
    assert(numel(levels) > 1, 'rays_cross_height needs at least two gantry levels.');
    fprintf('LED positions from the rays of the other levels (used by the estimator):\n');
    for iz = 1:numel(levels)
        for j = 1:nL
            train = level ~= iz & all(isfinite(U(:, :, j)));
            L = rays_intersection(truth(:, train), U(:, train, j));
            site_leds(:, j, level == iz) = repmat(L, 1, 1, nnz(level == iz));
            fprintf('  level z = %g, %5g kHz: (%7.1f, %7.1f) mm, %.3f m\n', levels(iz), led_freqs_khz(j), ...
                1e3*L(1:2), L(3));
        end
    end
elseif ~strcmp(led_positions, 'given')
    error('led_positions must be ''given'' or ''rays_cross_height''.');
end

% direction error of every LED, with respect to the LED positions used by the estimator
fprintf('\nDirection error per LED (%s; angle between the estimated and the true direction, deg):\n', direction_method);
fprintf('  %8s %6s %8s %8s %8s %10s %12s\n', 'LED', 'ok', 'mean', 'median', 'P90', 'RSS (mV)', 'zenith (deg)');
direction_error = nan(S, nL);
for j = 1:nL
    v = squeeze(site_leds(:, j, :)) - truth;
    u_true = v./vecnorm(v);
    direction_error(:, j) = acosd(min(1, sum(U(:, :, j).*u_true)))';
    ok = isfinite(direction_error(:, j));
    fprintf('  %5g kHz %2d/%2d %8.3f %8.3f %8.3f %10.2f %12.1f\n', led_freqs_khz(j), nnz(ok), S, ...
        mean(direction_error(ok, j)), median(direction_error(ok, j)), prctile(direction_error(ok, j), 90), ...
        1e3*median(rss(:, :, j), 'all'), mean(acosd(u_true(3, :))));
end

%% Stage 2: position from the rays of every LED combination
combos = arrayfun(@(f) [ref find(led_freqs_khz == f)], partner_leds_khz, 'UniformOutput', false);
if include_all_leds && nL > 2
    combos{end + 1} = [ref setdiff(1:nL, ref)];
end
nc = numel(combos);
combo_names = strings(1, nc);
for c = 1:nc
    combo_names(c) = strjoin(compose('%g', led_freqs_khz(combos{c})), ' + ') + " kHz";
end
estimate = nan(3, S, nc);
ray_angle = nan(S, nc);
ray_miss = nan(S, nc);
for c = 1:nc
    for i = 1:S
        [estimate(:, i, c), info] = locate(site_leds(:, combos{c}, i), reshape(U(:, i, combos{c}), 3, []), ray_weights);
        ray_angle(i, c) = info.min_angle_deg;
        ray_miss(i, c) = sqrt(mean(info.miss_m.^2));
    end
end

%% Single-LED reference (experiment 01): direction + range with the calibrated A and m
names = combo_names;
if baseline
    pb = p;
    pb.transmitter.position_m = leds(:, ref);
    pb.transmitter.normal = [0; 0; -1];
    pb.transmitter.half_angle_power_deg = acosd(2^(-1/baseline_m));
    pb.transmitter.pattern_asymmetry = 0;
    pb.transmitter.power_W = 2*pi*baseline_A/((baseline_m + 1)*pb.receiver.area_m2 ...
        *pb.receiver.filter_transmission*pb.receiver.optical_gain);
    single_led = nan(3, S);
    for i = 1:S
        N = pd_normals(theta(:, i), mtrs_offset_deg, pd_tilt_deg, mtrs_direction);
        single_led(:, i) = pd_fit_estimate(direction_method, rss(:, i, ref), N, pb, 1);
    end
    estimate(:, :, end + 1) = single_led;
    names(end + 1) = sprintf("%g kHz only (range with A, m)", reference_led_khz);
end
nr = numel(names);

%% Errors
error_3d = squeeze(vecnorm(estimate - truth, 2, 1));        % S x nr
error_h = squeeze(vecnorm(estimate(1:2, :, :) - truth(1:2, :), 2, 1));
error_v = squeeze(estimate(3, :, :) - truth(3, :));
fprintf('\nPosition errors over %d sites (cm; vertical > 0 = estimate above the truth):\n', S);
fprintf('  %-34s %5s %7s %7s %7s %7s %7s %9s %10s %9s\n', 'LEDs', 'ok', 'mean', 'RMSE', 'median', 'P90', ...
    'horiz', 'vert bias', 'ray angle', 'ray miss');
summary = table();
for c = 1:nr
    ok = isfinite(error_3d(:, c));
    e = 100*error_3d(ok, c);
    angle_text = '';
    miss_text = '';
    if c <= nc
        angle_text = sprintf('%8.1f d', mean(ray_angle(ok, c)));
        miss_text = sprintf('%7.2f cm', 100*mean(ray_miss(ok, c)));
    end
    fprintf('  %-34s %2d/%2d %7.2f %7.2f %7.2f %7.2f %7.2f %+9.2f %10s %9s\n', names(c), nnz(ok), S, mean(e), ...
        sqrt(mean(e.^2)), median(e), prctile(e, 90), 100*mean(error_h(ok, c)), 100*mean(error_v(ok, c)), ...
        angle_text, miss_text);
    summary = [summary; table(names(c), nnz(ok), mean(e), sqrt(mean(e.^2)), median(e), prctile(e, 90), ...
        100*mean(error_h(ok, c)), 100*mean(error_v(ok, c)), 'VariableNames', {'leds', 'ok', 'mean_cm', ...
        'rmse_cm', 'median_cm', 'p90_cm', 'horizontal_cm', 'vertical_bias_cm'})]; %#ok<AGROW>
end
fprintf('Per gantry level (cm): mean 3D error / vertical bias\n');
fprintf('  %-34s%s\n', 'LEDs', sprintf('%18s', string(compose('z = %g', levels))));
for c = 1:nr
    text = '';
    for iz = 1:numel(levels)
        sel = level == iz;
        text = [text sprintf('  %7.2f / %+6.2f', 100*mean(error_3d(sel, c), 'omitnan'), ...
            100*mean(error_v(sel, c), 'omitnan'))]; %#ok<AGROW>
    end
    fprintf('  %-34s%s\n', names(c), text);
end

%% Error vs K (subsets of the measured angles; same subsets for every LED)
if k_study
    nk = numel(k_study_values);
    k_mean = nan(nk, nr);
    k_p90 = nan(nk, nr);
    for ik = 1:nk
        subsets = angle_subsets(K, k_study_values(ik));
        e = nan(size(subsets, 1), S, nr);
        for is = 1:size(subsets, 1)
            sub = subsets(is, :);
            for i = 1:S
                N = pd_normals(theta(sub, i), mtrs_offset_deg, pd_tilt_deg, mtrs_direction);
                u = nan(3, nL);
                for j = 1:nL
                    u(:, j) = led_direction(rss(sub, i, j), N, p, direction_method);
                end
                for c = 1:nc
                    e(is, i, c) = norm(locate(site_leds(:, combos{c}, i), u(:, combos{c}), ray_weights) - truth(:, i));
                end
                if baseline
                    e(is, i, nr) = norm(pd_fit_estimate(direction_method, rss(sub, i, ref), N, pb, 1) - truth(:, i));
                end
            end
        end
        for c = 1:nr
            values = e(:, :, c);
            values = values(isfinite(values));
            k_mean(ik, c) = 100*mean(values);
            k_p90(ik, c) = 100*prctile(values, 90);
        end
    end
    fprintf('\nError vs K (mean 3D error, cm; all subsets x %d sites):\n', S);
    fprintf('  %3s%s\n', 'K', sprintf('%33s', names));
    fprintf(['  %3d' repmat('%33.2f', 1, nr) '\n'], [k_study_values(:) k_mean]');
end

%% Figures
colors = lines(nr);
figures = gobjects(0);
fig_names = {};

% CDF of the 3D error
fig = figure('Name', '3D error CDF', 'Color', 'w', 'Position', [100 100 820 520]);
light_theme(fig);
ax = axes(fig);
hold(ax, 'on');
for c = 1:nr
    values = sort(100*error_3d(isfinite(error_3d(:, c)), c));
    style = '-';
    if baseline && c == nr
        style = '--';
    end
    stairs(ax, [0; values], (0:numel(values))'/S, style, 'Color', colors(c, :), 'LineWidth', 1.6, ...
        'DisplayName', sprintf('%s: mean %.1f cm', names(c), mean(values)));
end
grid(ax, 'on');
box(ax, 'on');
ylim(ax, [0 1]);
xlabel(ax, '3D position error (cm)');
ylabel(ax, 'Empirical CDF');
title(ax, sprintf('Position from LED directions only (%s, K = %d, %d sites)', strrep(direction_method, '_', '\_'), ...
    K, S), 'FontWeight', 'normal');
legend(ax, 'Location', 'southeast');
figures(end + 1) = fig;
fig_names{end + 1} = 'error_cdf';

% true vs estimated positions: 3D and top view for every combination
fig = figure('Name', 'Positions', 'Color', 'w', 'Position', [40 40 380*nr 820]);
light_theme(fig);
layout = tiledlayout(fig, 2, nr, 'TileSpacing', 'compact', 'Padding', 'compact');
level_colors = lines(numel(levels));
T = 1e3*truth;
for view_index = 1:2
    for c = 1:nr
        ax = nexttile(layout);
        hold(ax, 'on');
        E = 1e3*estimate(:, :, c);
        segments = reshape([T; E; nan(3, S)], 3, []);
        used = ref;
        if c <= nc
            used = combos{c};
        end
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
            title(ax, sprintf('%s\nmean %.1f cm, RMSE %.1f cm', names(c), 100*mean(error_3d(ok, c)), ...
                100*sqrt(mean(error_3d(ok, c).^2))), 'FontWeight', 'normal');
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
            leds_used = mean(site_leds, 3);       % LED positions used (mean over the levels)
            [hh, vv] = top_view(1e3*leds_used, app_orientation);
            plot(ax, hh, vv, 'p', 'Color', [0.6 0.6 0.6], 'MarkerSize', 10, 'HandleVisibility', 'off');
            [hh, vv] = top_view(1e3*leds_used(:, used), app_orientation);
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
title(layout, sprintf('True vs estimated positions (LED directions only, %s, LED positions: %s)', ...
    strrep(direction_method, '_', '\_'), strrep(led_positions, '_', ' ')), 'FontSize', 11);
figures(end + 1) = fig;
fig_names{end + 1} = 'positions';

% direction error per LED and error vs K
fig = figure('Name', 'Direction error and K', 'Color', 'w', 'Position', [120 120 1150 450]);
light_theme(fig);
layout = tiledlayout(fig, 1, 1 + k_study, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(layout);
hold(ax, 'on');
labels = compose('%g kHz', led_freqs_khz);
boxchart(ax, direction_error, 'MarkerStyle', '.');
xticks(ax, 1:nL);
xticklabels(ax, labels);
ylabel(ax, 'Direction error (deg)');
title(ax, sprintf('Direction of every LED (%s, K = %d)', strrep(direction_method, '_', '\_'), K), 'FontWeight', 'normal');
grid(ax, 'on');
box(ax, 'on');
if k_study
    ax = nexttile(layout);
    hold(ax, 'on');
    for c = 1:nr
        style = 'o-';
        if baseline && c == nr
            style = 's--';
        end
        plot(ax, k_study_values, k_mean(:, c), style, 'Color', colors(c, :), 'LineWidth', 1.6, ...
            'MarkerFaceColor', colors(c, :), 'DisplayName', names(c));
    end
    xticks(ax, k_study_values);
    xlabel(ax, 'Number of orientations K');
    ylabel(ax, 'Mean 3D position error (cm)');
    title(ax, 'Error vs K', 'FontWeight', 'normal');
    legend(ax, 'Location', 'northeast');
    grid(ax, 'on');
    box(ax, 'on');
end
figures(end + 1) = fig;
fig_names{end + 1} = 'direction_error_and_K';

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
    for c = 1:nr
        tag = char(matlab.lang.makeValidName("err_cm_" + replace(names(c), ' ', '')));
        per_site.(tag) = 100*error_3d(:, c);
    end
    for j = 1:nL
        per_site.(sprintf('dir_err_deg_%gkHz', led_freqs_khz(j))) = direction_error(:, j);
    end
    writetable(per_site, fullfile(output_dir, 'errors_per_site.csv'));
    % LED positions used at every gantry level (read by estimate_position_unknown_yaw.m)
    led_table = table();
    for iz = 1:numel(levels)
        L = site_leds(:, :, find(level == iz, 1));
        led_table = [led_table; table(repmat(levels(iz), nL, 1), led_freqs_khz(:), 1e3*L(1, :)', 1e3*L(2, :)', ...
            L(3, :)', 'VariableNames', {'gantry_z_mm', 'freq_khz', 'x_mm', 'y_mm', 'height_m'})]; %#ok<AGROW>
    end
    writetable(led_table, fullfile(output_dir, 'led_positions.csv'));
    if k_study
        writetable(array2table([k_study_values(:) k_mean], 'VariableNames', ['K', cellstr(names)]), ...
            fullfile(output_dir, 'error_vs_K.csv'));
    end
    fprintf('Figures and tables saved in %s\n', output_dir);
end

%% Local functions
function [r, info] = locate(L, U, weights_mode)
% Position from the rays of the LEDs L (3 x N) with the estimated directions U (3 x N)
info = struct('min_angle_deg', nan, 'miss_m', nan);
r = nan(3, 1);
if any(~isfinite(U), 'all')
    return;
end
[r, info] = rays_intersection(L, U);
if strcmp(weights_mode, 'range') && all(info.range_m > 0)
    [r, info] = rays_intersection(L, U, 1./info.range_m.^2);   % perpendicular error grows with the range
end
end

function [xy, A, m] = fit_led(x_mm, y_mm, rss, h, p)
% Joint fit of the LED XY, A and m of RSS = A R(phi) cos(phi)^m / d^2 (horizontal PD, psi = phi)
[~, k] = max(rss);
xy = fminsearch(@(c) led_cost(x_mm, y_mm, rss, c, h, p), [x_mm(k) y_mm(k)], ...
    optimset('TolX', 1e-3, 'TolFun', 1e-12, 'Display', 'off'));
[~, A, m] = led_cost(x_mm, y_mm, rss, xy, h, p);
end

function [value, A, m] = led_cost(x_mm, y_mm, rss, xy, h, p)
d = sqrt((hypot(x_mm - xy(1), y_mm - xy(2))/1e3).^2 + h^2);
c = h./d;
R = rx_receiver_response(c, p);
ok = R > 0 & rss > 0;
Y = log(rss(ok).*d(ok).^2./R(ok));
X = log(c(ok));
coef = [ones(size(X)) X] \ Y;
A = exp(coef(1));
m = coef(2);
value = mean((Y - coef(1) - m*X).^2);
end

function light_theme(fig)
% White figures also with the dark desktop theme (theme() exists from R2025a)
try
    theme(fig, 'light');
catch
end
end

function subsets = angle_subsets(K_full, K)
% Near-uniform subsets of K of the K_full equally spaced angles (indices), with all their rotations
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
