% 3D position estimation, experiment 01 (one or several campaigns analysed together).
% A fixed LED (500 kHz) on the ceiling; the PD is moved by the gantry and, at every position, the MTRS
% turns it to K azimuths. The PD sits on a 15 deg adapter, so its normal describes a cone around the
% vertical. Positions are estimated with the estimators of CAMBRIDGE/simulations (no new algorithm):
%   cos / cos^mR : GLS and WLS = ratio eigenvector of TCOM, NLS = NLS-TCOM      (Estimators/rx_estimate)
%   SQ           : GLS and WLS = nonlinear ratio fits, NLS = joint NLS        (Bastiaens 2020/pd_fit_estimate)
% Stage 1 (direction) only uses the RSS ratios of the K orientations. Stage 2 (range) is the dual of
% F_broadcast_Konly/core/broadcast_distance.m (there the LED is reoriented and the PD is fixed):
%   eta = sum(y_i h_i) / sum(h_i^2),  h_i = R(n_i' u_hat),  d = sqrt(A L(phi_hat) / eta),  L = cos(phi)^m
% where RSS = A R(psi) L(phi) / d^2. A and m are fitted here from the calibration scan
% (Lambertian_order_LED_500khz/points.csv) with the SAME PD model and LED position, so every PD model has
% its own coherent A, m.
%
% Coordinates: X, Y of the gantry (m) and Z = height above the floor (m, up). The PD centre is
%   Z_pd = H_base_cal + gantry_z_scale (z_cal - z_gantry) + pd_elevation    (the gantry z axis points down)
% where pd_elevation is the gantry base -> PD centre distance (MTRS + adapter). LED at (led_xy, H_led),
% normal [0 0 -1]. PD normal at MTRS angle theta:
%   n = [sin(t) sin(a), sin(t) cos(a), cos(t)],  a = mtrs_direction*(theta - mtrs_offset),  t = pd_tilt
% i.e. at theta = mtrs_offset the PD is tilted towards +Y (lowest edge of the adapter on +Y).
% The orientation check compares this convention with the data at the true positions; the MTRS offset
% and the adapter tilt can also be calibrated from the RSS shape over the K angles (orientation_fit).
close all

%% Hyperparameters
here               = fileparts(mfilename('fullpath'));
% campaign_dirs      = {'campaign_20261014_185628', ...   % campaign folders (points.csv) analysed together
%                       'campaign_20261015_000723'};
campaign_dirs      = {'campaign_20261014_185628'}
calibration_csv    = fullfile(here, '..', 'Lambertian_order_LED_500khz', 'points.csv');
simulations_dir    = fullfile(here, '..', '..', 'simulations');
led_freq_khz       = 500;                  % LED used for positioning (column <f>kHz_<source>_Vrms)
rss_source         = 'wave';               % 'wave' (lock-in on the raw waveform) | 'fft' (FFT peak)
led_xy_mm          = [270 890];            % LED XY in gantry coordinates (mm); [281.1 904.8] = joint_xy fit
                                           % with SQ; 'fit' = joint_xy fit for every PD model
H_led_m            = 3;                    % height of the LED plane above the floor (m)
H_base_cal_m       = 1.038;                % height of the gantry base at z = z_cal_mm (m)
z_cal_mm           = -300;                 % gantry Z of the calibration scan (mm)
pd_elevation_cal_m = 0.09696;              % gantry base -> PD centre in the calibration scan (0 deg adapter)
pd_elevation_m     = 0.09696;              % gantry base -> PD centre in the campaign (MTRS + 15 deg adapter)
gantry_z_scale     = 1;                  % real vertical travel per commanded mm of gantry z (1 = nominal;
                                           % 0.6 measured with a tape on 2026-10-15)
pd_tilt_deg        = 15;                   % nominal tilt of the adapter (deg from the vertical)
mtrs_offset_deg    = 65;                   % nominal MTRS angle that points the tilt towards +Y (set by eye)
mtrs_direction     = 1;                    % +1: increasing MTRS angle turns the tilt from +Y towards +X
orientation_fit    = 'offset';             % 'none' (nominal offset/tilt) | 'offset' | 'offset_tilt': fitted
                                           % from the RSS shape over the K angles at the true positions
orientation_sites  = 'cross_height';       % sites used for that fit: 'all' (in-sample) | 'cross_height'
                                           % (each height uses the values fitted on the other heights)
% pd_models          = {'SQ', 'cosine_mR', 'cosine'};  % PD responses evaluated (Bastiaens 2020, PDA100A2)
pd_models          = {'SQ'};
psi_3db_rad        = 0.61;                 % SQ: R(psi_3dB) = 1/sqrt(2)
m_R                = 1.9;                  % cosine_mR order
pd_fov_deg         = 64;                   % FOV of the cosine models (SQ uses its own zero, 64.58 deg)
calibration_method = 'staged';             % 'staged' (A from the point below the LED) | 'joint' (A, m together)
methods            = {'GLS', 'WLS', 'NLS'};
k_study            = false;                % error vs K with subsets of the measured angles (one PD model/method)
k_study_values     = 3:10;                 % K values; every K uses the near-uniform subsets of the K angles
                                           % (round((0:K-1) Kfull/K)) and all their rotations
k_study_model      = 'SQ';
k_study_method     = 'NLS';
plot_models        = pd_models;            % PD models with a positions figure
app_orientation    = true;                 % top views as in the acquisition tool (Y horizontal, X vertical)
cdf_xlim_cm        = [];                   % x limits of the error CDF (cm), [] = automatic
export_figures     = true;                % PNG (300 dpi) + FIG in output_dir (overwritten at every run)
output_dir         = fullfile(here, 'figures');

%% Setup
addpath(simulations_dir);
cambridge_setup();
column = sprintf('%dkHz_%s_Vrms', led_freq_khz, rss_source);
pd_height = @(z_gantry_mm, elevation_m) H_base_cal_m + gantry_z_scale*(z_cal_mm - z_gantry_mm)/1e3 + elevation_m;
h_cal = H_led_m - pd_height(z_cal_mm, pd_elevation_cal_m);
labels = struct('SQ', '1 - C\psi^2 (SQ)', 'cosine_mR', sprintf('cos^{%g}\\psi', m_R), 'cosine', 'cos\psi');

%% Campaign: one site = one PD position with its K orientations
data = cell(numel(campaign_dirs), 1);
for c = 1:numel(campaign_dirs)
    data{c} = readtable(fullfile(here, campaign_dirs{c}, 'points.csv'), 'VariableNamingRule', 'preserve');
    data{c}.campaign = repmat(c, height(data{c}), 1);
    fprintf('%s: %d rows, gantry z = %s mm, %s to %s\n', campaign_dirs{c}, height(data{c}), ...
        mat2str(unique(data{c}.z_cmd_mm)'), string(data{c}.iso_time(1)), string(data{c}.iso_time(end)));
end
data = vertcat(data{:});
K = numel(unique(data.k));
if any(data.mtrs_tilt_cmd_deg ~= 0) || numel(unique(data.pd_tilt_deg)) > 1
    error('Expected MTRS tilt 0 and a single adapter in every row.');
end
[ids, ~, group] = unique([data.campaign data.site_id], 'rows');
complete = find(accumarray(group, 1) == K & accumarray(group, data.k, [], @(k) numel(unique(k))) == K);
S = numel(complete);
truth = zeros(3, S);
gantry_z_mm = zeros(1, S);
site_campaign = zeros(1, S);
theta = zeros(K, S);
rss = zeros(K, S);
for i = 1:S
    rows = sortrows(data(group == complete(i), :), 'k');
    gantry_z_mm(i) = rows.z_cmd_mm(1);
    site_campaign(i) = rows.campaign(1);
    truth(:, i) = [rows.x_cmd_mm(1)/1e3; rows.y_cmd_mm(1)/1e3; pd_height(gantry_z_mm(i), pd_elevation_m)];
    theta(:, i) = rows.angle_deg;
    rss(:, i) = rows.(column);
end
levels = unique(gantry_z_mm);
level = arrayfun(@(z) find(levels == z), gantry_z_mm);
fprintf('Campaigns: %d complete sites of %d (K = %d), %s, adapter %g deg\n', S, size(ids, 1), K, column, ...
    data.pd_tilt_deg(1));
for i = setdiff(1:size(ids, 1), complete')
    fprintf('  %s site %d skipped (%d of %d orientations)\n', campaign_dirs{ids(i, 1)}, ids(i, 2), ...
        nnz(group == i), K);
end
fprintf('PD centre heights: %s m (gantry z = %s mm); LED plane at %g m\n', ...
    mat2str(arrayfun(@(z) pd_height(z, pd_elevation_m), levels), 5), mat2str(levels), H_led_m);

%% Calibration (Lambertian scan) and parameters of every PD model
cal = readtable(calibration_csv, 'VariableNamingRule', 'preserve');
if any(cal.pd_tilt_deg ~= 0) || numel(unique(cal.z_cmd_mm)) > 1 || cal.z_cmd_mm(1) ~= z_cal_mm
    error('The calibration scan must be horizontal (pd_tilt 0) at z = %g mm.', z_cal_mm);
end
base = system_parameters();
base.acquisition.samples_per_orientation = 1;
nm = numel(pd_models);
params = cell(1, nm);
fprintf('\nCalibration (%s, h = %.5f m from the LED plane to the calibration PD):\n', calibration_method, h_cal);
fprintf('  %-10s %10s %8s %9s %18s\n', 'PD model', 'A (V m^2)', 'm', 'phi_1/2', 'LED XY (mm)');
for im = 1:nm
    p = receiver_parameters(base, pd_models{im}, psi_3db_rad, m_R, pd_fov_deg);
    [A, m, xy] = calibrate(cal.x_cmd_mm, cal.y_cmd_mm, cal.(column), led_xy_mm, h_cal, p, calibration_method);
    p.transmitter.position_m = [xy(:)/1e3; H_led_m];
    p.transmitter.normal = [0; 0; -1];
    p.transmitter.half_angle_power_deg = acosd(2^(-1/m));
    p.transmitter.pattern_asymmetry = 0;
    % rx_channel / rx_optical_position use C = P (m+1) A_PD T g / (2 pi): choose P so that C = A
    p.transmitter.power_W = 2*pi*A/((m + 1)*p.receiver.area_m2*p.receiver.filter_transmission ...
        *p.receiver.optical_gain);
    p.calibration = struct('A', A, 'm', m, 'led_xy_mm', xy);
    params{im} = p;
    fprintf('  %-10s %10.4g %8.3f %7.2f d %8.1f, %7.1f\n', pd_models{im}, A, m, acosd(2^(-1/m)), xy);
end

%% Orientation: convention check and calibration of the MTRS offset / adapter tilt
fprintf('\nOrientation check (rms of RSS_k/R(psi_k) around its mean per site, true positions, nominal values):\n');
fprintf('  %-10s %16s %16s %16s %16s\n', 'PD model', '[sin t..] dir +1', '[sin t..] dir -1', ...
    '[cos t..] dir +1', '[cos t..] dir -1');
conventions = {'vertical', 'vertical', 'horizontal', 'horizontal'};
directions = [1 -1 1 -1];
for im = 1:nm
    values = arrayfun(@(c) orientation_rms(truth, theta, rss, true(1, S), [mtrs_offset_deg pd_tilt_deg], ...
        directions(c), conventions{c}, params{im}), 1:4);
    fprintf('  %-10s %14.2f %% %14.2f %% %14.2f %% %14.2f %%\n', pd_models{im}, values);
end
fprintf('Offset, tilt (deg) fitted from the RSS shape on each gantry level and on all sites (rms):\n');
fprintf('  %-10s%s%s\n', 'PD model', sprintf('%22s', string(compose('z = %g', levels))), sprintf('%22s', 'all'));
fits = cell(1, nm);
for im = 1:nm
    fits{im} = zeros(2, numel(levels) + 1);
    text = '';
    for set_index = 1:numel(levels) + 1
        sel = true(1, S);
        if set_index <= numel(levels)
            sel = level == set_index;
        end
        fits{im}(:, set_index) = fit_orientation(truth, theta, rss, sel, 'offset_tilt', ...
            [mtrs_offset_deg pd_tilt_deg], mtrs_direction, params{im});
        text = [text sprintf('  %5.2f, %5.2f (%4.2f%%)', fits{im}(:, set_index), orientation_rms( ...
            truth, theta, rss, sel, fits{im}(:, set_index)', mtrs_direction, 'vertical', params{im}))]; %#ok<AGROW>
    end
    fprintf('  %-10s%s\n', pd_models{im}, text);
end

% offset/tilt used for every site and PD model
orientation = repmat([mtrs_offset_deg; pd_tilt_deg], 1, S, nm);
if ~strcmp(orientation_fit, 'none')
    for im = 1:nm
        for set_index = 1:numel(levels)
            target = level == set_index;
            train = true(1, S);
            if strcmp(orientation_sites, 'cross_height') && numel(levels) > 1
                train = ~target;
            end
            orientation(:, target, im) = repmat(fit_orientation(truth, theta, rss, train, orientation_fit, ...
                [mtrs_offset_deg pd_tilt_deg], mtrs_direction, params{im}), 1, nnz(target));
        end
    end
end
fprintf('Orientation used: %s (%s)\n', orientation_fit, orientation_sites);

%% In-situ check of the calibration: A, m refitted from the campaign itself (true positions)
fprintf('\nCampaign vs calibration (true positions and the orientation used):\n');
fprintf('  %-10s %8s %22s %10s %8s\n', 'PD model', 'height', 'RSS meas/model', 'A_campaign', 'm');
for im = 1:nm
    p = params{im};
    for set_index = 1:numel(levels)
        sel = find(level == set_index);
        Y = [];
        X = [];
        ratio = [];
        for i = sel
            N = pd_normals(theta(:, i), orientation(:, i, im), mtrs_direction);
            v = p.transmitter.position_m - truth(:, i);
            R = rx_receiver_response(N'*(v/norm(v)), p);
            ratio = [ratio; rss(:, i)./rx_channel(truth(:, i), N, p)]; %#ok<AGROW>
            Y = [Y; log(rss(:, i)*norm(v)^2./R)]; %#ok<AGROW>
            X = [X; repmat(log(v(3)/norm(v)), K, 1)]; %#ok<AGROW>
        end
        coef = [ones(size(X)) X] \ Y;
        fprintf('  %-10s %6.3f m %13.4f +/- %.4f %10.4g %8.3f\n', pd_models{im}, truth(3, sel(1)), ...
            mean(ratio), std(ratio), exp(coef(1)), coef(2));
    end
end

%% Estimation
nmeth = numel(methods);
estimate = nan(3, S, nm, nmeth);
direction = nan(3, S, nm, nmeth);
distance = nan(S, nm, nmeth);
status = strings(S, nm, nmeth);
range_check = 0;
for im = 1:nm
    p = params{im};
    for j = 1:nmeth
        name = estimator_name(pd_models{im}, methods{j});
        for i = 1:S
            N = pd_normals(theta(:, i), orientation(:, i, im), mtrs_direction);
            if strcmp(pd_models{im}, 'SQ')
                [r, info] = pd_fit_estimate(name, rss(:, i), N, p, 1);
            else
                [r, info] = rx_estimate(name, rss(:, i), N, p, 1);
            end
            estimate(:, i, im, j) = r;
            direction(:, i, im, j) = info.direction;
            distance(i, im, j) = info.distance_m;
            status(i, im, j) = info.status;
            if info.success
                range_check = max(range_check, abs(broadcast_range(rss(:, i), N, info.direction, p) ...
                    - info.distance_m));
            end
        end
    end
end
fprintf('\nRange recovery = dual of broadcast_distance: max |d_simulations - d_broadcast| = %.2e m\n', range_check);

%% Direction-only check: LED triangulated from the estimated directions (independent of A, m and range)
% unknowns: LED position and a vertical offset of every gantry level except the calibration one
reference = find(levels == z_cal_mm, 1);
if isempty(reference)
    reference = 1;
end
fprintf('\nLED triangulated from the estimated directions (vertical offsets of the levels vs gantry z = %g):\n', ...
    levels(reference));
others = setdiff(1:numel(levels), reference);
fprintf('  %-10s %-4s %24s %s %8s %10s\n', 'PD model', 'est', 'LED (mm, mm, m)', ...
    sprintf('%9s', string(compose('z=%g', levels(others)))), 'rays', 'z scale');
for im = 1:nm
    for j = 1:nmeth
        [position, offsets, ray_rms] = triangulate(direction(:, :, im, j), truth, level, reference);
        % offsets are linear in the commanded travel if the gantry z scale differs from gantry_z_scale
        travel = (z_cal_mm - levels(others))'/1e3;
        scale = gantry_z_scale + (travel \ offsets);
        fprintf('  %-10s %-4s (%6.1f, %6.1f, %6.3f) %s %5.1f mm %10.3f\n', pd_models{im}, methods{j}, ...
            1e3*position(1:2), position(3), sprintf('%+6.1f mm', 1e3*offsets), 1e3*ray_rms, scale);
    end
end

%% Errors
led = cellfun(@(p) p.transmitter.position_m, params, 'UniformOutput', false);
fprintf('\nPosition errors over %d sites (cm; vertical > 0 = estimate above the truth):\n', S);
fprintf('  %-10s %-4s %5s %8s %8s %8s %8s %9s %9s %9s %9s\n', 'PD model', 'est', 'ok', 'mean', 'RMSE', ...
    'median', 'P90', 'horiz', 'vert bias', 'range b.', 'dir (deg)');
error_3d = nan(S, nm, nmeth);
for im = 1:nm
    for j = 1:nmeth
        e = estimate(:, :, im, j) - truth;
        u_true = (led{im} - truth)./vecnorm(led{im} - truth);
        range_error = distance(:, im, j)' - vecnorm(led{im} - truth);
        angle_error = acosd(min(1, sum(direction(:, :, im, j).*u_true)));
        error_3d(:, im, j) = vecnorm(e)';
        ok = isfinite(error_3d(:, im, j));
        d3 = 100*error_3d(ok, im, j);
        fprintf('  %-10s %-4s %2d/%2d %8.2f %8.2f %8.2f %8.2f %9.2f %9.2f %9.2f %9.2f\n', pd_models{im}, ...
            methods{j}, nnz(ok), S, mean(d3), sqrt(mean(d3.^2)), median(d3), prctile(d3, 90), ...
            100*mean(vecnorm(e(1:2, ok))), 100*mean(e(3, ok)), 100*mean(range_error(ok)), mean(angle_error(ok)));
        failed = unique(status(~ok, im, j));
        if ~isempty(failed)
            fprintf('      failures: %s\n', strjoin(failed, ', '));
        end
    end
end
fprintf('Per gantry level (cm): mean 3D error / vertical bias; and real vertical travel per commanded mm\n');
fprintf('estimated from the mean estimated heights of the levels (independent of gantry_z_scale):\n');
fprintf('  %-10s %-4s%s %8s\n', 'PD model', 'est', sprintf('%16s', string(compose('z = %g', levels))), 'z scale');
for im = 1:nm
    for j = 1:nmeth
        text = '';
        heights = zeros(numel(levels), 1);
        for set_index = 1:numel(levels)
            sel = level == set_index;
            heights(set_index) = mean(estimate(3, sel, im, j), 'omitnan');
            text = [text sprintf('  %6.2f / %+6.2f', 100*mean(error_3d(sel, im, j), 'omitnan'), ...
                100*mean(estimate(3, sel, im, j) - truth(3, sel), 'omitnan'))]; %#ok<AGROW>
        end
        coef = [ones(numel(levels), 1) -levels(:)/1e3] \ heights;
        fprintf('  %-10s %-4s%s %8.3f\n', pd_models{im}, methods{j}, text, coef(2));
    end
end

%% Error vs K (subsets of the measured angles)
% two orientations: the nominal one (mtrs_offset_deg, pd_tilt_deg) and the one used above, fitted ONCE
% with all K angles (orientation_fit) and kept fixed for every subset
if k_study
    im = find(strcmp(pd_models, k_study_model));
    p = params{im};
    name = estimator_name(k_study_model, k_study_method);
    cases = {repmat([mtrs_offset_deg; pd_tilt_deg], 1, S), orientation(:, :, im)};
    case_names = {sprintf('nominal offset %g deg', mtrs_offset_deg), ...
        sprintf('offset fitted once with K = %d (%s)', K, strrep(orientation_sites, '_', ' '))};
    if strcmp(orientation_fit, 'none')
        cases = cases(1);
        case_names = case_names(1);
    end
    nk = numel(k_study_values);
    k_stats = nan(nk, 6, numel(cases));   % mean, median, P90, failures (%), mean z_cal level, subsets
    k_errors = cell(nk, numel(cases));
    for ik = 1:nk
        subsets = angle_subsets(K, k_study_values(ik));
        for ic = 1:numel(cases)
            e = nan(size(subsets, 1), S);
            for is = 1:size(subsets, 1)
                sub = subsets(is, :);
                for i = 1:S
                    N = pd_normals(theta(sub, i), cases{ic}(:, i), mtrs_direction);
                    if strcmp(k_study_model, 'SQ')
                        r = pd_fit_estimate(name, rss(sub, i), N, p, 1);
                    else
                        r = rx_estimate(name, rss(sub, i), N, p, 1);
                    end
                    e(is, i) = norm(r - truth(:, i));
                end
            end
            k_errors{ik, ic} = e;
            ok = isfinite(e);
            at_cal = ok & repmat(gantry_z_mm == z_cal_mm, size(e, 1), 1);
            k_stats(ik, :, ic) = [100*mean(e(ok)), 100*median(e(ok)), 100*prctile(e(ok), 90), ...
                100*mean(~ok(:)), 100*mean(e(at_cal)), size(subsets, 1)];
        end
    end
    for ic = 1:numel(cases)
        fprintf('\nError vs K, %s + %s, %s (cm; subsets x %d sites):\n', k_study_model, k_study_method, ...
            case_names{ic}, S);
        fprintf('  %3s %8s %8s %8s %8s %8s %12s\n', 'K', 'subsets', 'mean', 'median', 'P90', 'fail %', ...
            sprintf('mean z=%g', z_cal_mm));
        fprintf('  %3d %8d %8.2f %8.2f %8.2f %8.2f %12.2f\n', [k_study_values(:) k_stats(:, 6, ic) ...
            k_stats(:, [1 2 3 4 5], ic)]');
    end
    fig = figure('Name', 'Error vs K', 'Color', 'w', 'Position', [120 120 1100 450]);
    layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    case_colors = lines(numel(cases));
    for panel = 1:2
        ax = nexttile(layout);
        hold(ax, 'on');
        for ic = 1:numel(cases)
            if panel == 1
                values = k_stats(:, 1, ic);
                spread = k_stats(:, 3, ic);
            else
                values = k_stats(:, 5, ic);
                spread = arrayfun(@(ik) 100*prctile(k_errors{ik, ic}(:, gantry_z_mm == z_cal_mm), 90, 'all'), 1:nk)';
            end
            plot(ax, k_study_values, values, 'o-', 'Color', case_colors(ic, :), 'LineWidth', 1.6, ...
                'MarkerFaceColor', case_colors(ic, :), 'DisplayName', ['Mean, ' case_names{ic}]);
            plot(ax, k_study_values, spread, '--', 'Color', case_colors(ic, :), 'LineWidth', 1.2, ...
                'DisplayName', ['P90, ' case_names{ic}]);
        end
        grid(ax, 'on');
        box(ax, 'on');
        xticks(ax, k_study_values);
        xlabel(ax, 'Number of orientations K');
        ylabel(ax, '3D position error (cm)');
        if panel == 1
            title(ax, sprintf('All %d sites', S), 'FontWeight', 'normal');
            legend(ax, 'Location', 'northeast');
        else
            title(ax, sprintf('Sites at the calibration height (gantry z = %g)', z_cal_mm), 'FontWeight', 'normal');
        end
    end
    title(layout, sprintf('%s + %s, LED (%.1f, %.1f) mm, gantry z scale %g', k_study_model, k_study_method, ...
        p.calibration.led_xy_mm, gantry_z_scale), 'FontSize', 11);
end

%% Figures: true vs estimated positions
colors = lines(numel(levels));
figures = gobjects(0);
names = {};
if k_study
    figures(end + 1) = fig;
    names{end + 1} = 'error_vs_K';
end
for model = plot_models
    im = find(strcmp(pd_models, model{1}));
    fig = figure('Name', ['Positions - ' model{1}], 'Color', 'w', 'Position', [60 60 1500 900]);
    layout = tiledlayout(fig, 2, nmeth, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout, sprintf('PD model %s, LED (%.1f, %.1f) mm, A = %.4g, m = %.2f, K = %d', ...
        labels.(model{1}), params{im}.calibration.led_xy_mm, params{im}.calibration.A, ...
        params{im}.calibration.m, K), 'FontSize', 11);
    for view_index = 1:2
        for j = 1:nmeth
            ax = nexttile(layout);
            hold(ax, 'on');
            E = 1e3*estimate(:, :, im, j);
            T = 1e3*truth;
            segments = reshape([T; E; nan(3, S)], 3, []);
            if view_index == 1
                plot3(ax, segments(1, :), segments(2, :), segments(3, :), '-', 'Color', [0.5 0.5 0.5], ...
                    'HandleVisibility', 'off');
                plot3(ax, T(1, :), T(2, :), T(3, :), 'ko', 'MarkerSize', 6, 'DisplayName', 'True');
                for iz = 1:numel(levels)
                    sel = level == iz;
                    plot3(ax, E(1, sel), E(2, sel), E(3, sel), 'o', 'MarkerFaceColor', colors(iz, :), ...
                        'MarkerEdgeColor', 'none', 'MarkerSize', 5, ...
                        'DisplayName', sprintf('Estimated (Z = %.0f mm)', T(3, find(sel, 1))));
                end
                view(ax, -35, 25);
                xlabel(ax, 'X (mm)');
                ylabel(ax, 'Y (mm)');
                zlabel(ax, 'Z, height (mm)');
                ok = isfinite(error_3d(:, im, j));
                title(ax, sprintf('%s: mean %.1f cm, RMSE %.1f cm', methods{j}, ...
                    100*mean(error_3d(ok, im, j)), 100*sqrt(mean(error_3d(ok, im, j).^2))), 'FontWeight', 'normal');
            else
                [hh, vv, h_label, v_label] = top_view(segments, app_orientation);
                plot(ax, hh, vv, '-', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
                [hh, vv] = top_view(T, app_orientation);
                plot(ax, hh, vv, 'ko', 'MarkerSize', 6, 'DisplayName', 'True');
                for iz = 1:numel(levels)
                    sel = level == iz;
                    [hh, vv] = top_view(E(:, sel), app_orientation);
                    plot(ax, hh, vv, 'o', 'MarkerFaceColor', colors(iz, :), 'MarkerEdgeColor', 'none', ...
                        'MarkerSize', 5, 'DisplayName', sprintf('Estimated (Z = %.0f mm)', T(3, find(sel, 1))));
                end
                [hh, vv] = top_view(1e3*led{im}, app_orientation);
                plot(ax, hh, vv, 'kp', 'MarkerFaceColor', 'y', 'MarkerSize', 12, 'DisplayName', 'LED');
                if app_orientation
                    set(ax, 'XDir', 'reverse');
                end
                axis(ax, 'equal');
                xlim(ax, [0 1400]);
                ylim(ax, [0 1400]);
                xlabel(ax, h_label);
                ylabel(ax, v_label);
                title(ax, sprintf('%s: top view', methods{j}), 'FontWeight', 'normal');
            end
            grid(ax, 'on');
            box(ax, 'on');
            if j == 1
                legend(ax, 'Location', 'best');
            end
        end
    end
    figures(end + 1) = fig; %#ok<SAGROW>
    names{end + 1} = sprintf('positions_%s', model{1}); %#ok<SAGROW>
end

%% Figure: CDF of the 3D error
fig = figure('Name', '3D error CDF', 'Color', 'w', 'Position', [100 100 800 520]);
ax = axes(fig);
hold(ax, 'on');
model_colors = lines(nm);
styles = {'-', '--', ':', '-.'};
for im = 1:nm
    for j = 1:nmeth
        values = sort(100*error_3d(isfinite(error_3d(:, im, j)), im, j));
        stairs(ax, [0; values], (0:numel(values))'/S, styles{mod(j - 1, 4) + 1}, 'Color', model_colors(im, :), ...
            'LineWidth', 1.4, 'DisplayName', sprintf('%s, %s', labels.(pd_models{im}), methods{j}));
    end
end
grid(ax, 'on');
box(ax, 'on');
ylim(ax, [0 1]);
if ~isempty(cdf_xlim_cm)
    xlim(ax, cdf_xlim_cm);
end
xlabel(ax, '3D position error (cm)');
ylabel(ax, 'Empirical CDF');
legend(ax, 'Location', 'southeast');
figures(end + 1) = fig;
names{end + 1} = 'error_cdf';

%% Export
if export_figures
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
    for i = 1:numel(figures)
        exportgraphics(figures(i), fullfile(output_dir, [names{i} '.png']), 'Resolution', 300);
        savefig(figures(i), fullfile(output_dir, [names{i} '.fig']));
    end
    fprintf('Figures saved in %s\n', output_dir);
end

%% Local functions
function N = pd_normals(theta_deg, orientation, direction, convention)
% PD normals (3 x K, Z up) for the MTRS angles theta_deg; orientation = [offset; tilt] (deg)
if nargin < 4
    convention = 'vertical';
end
a = direction*(theta_deg(:)' - orientation(1));
t = orientation(2);
if strcmp(convention, 'vertical')    % tilt measured from the vertical (normal t deg off the zenith)
    N = [sind(t)*sind(a); sind(t)*cosd(a); cosd(t)*ones(size(a))];
else                                 % literal [0, cos(t), -sin(t)] of the gantry frame (90 - t deg off the zenith)
    N = [cosd(t)*sind(a); cosd(t)*cosd(a); sind(t)*ones(size(a))];
end
end

function p = receiver_parameters(base, model, psi_3db_rad, m_R, fov_deg)
switch model
    case 'SQ'
        p = bastiaens2020_parameters(base, 'PDA100A2', 'SQ', 90);
        p.receiver.response_parameters.psi_3db_rad = psi_3db_rad;
    case 'cosine_mR'
        p = bastiaens2020_parameters(base, 'PDA100A2', 'cosine', fov_deg, m_R);
    case 'cosine'
        p = bastiaens2020_parameters(base, 'PDA100A2', 'cosine_1', fov_deg);
    otherwise
        error('Unknown PD model %s.', model);
end
end

function name = estimator_name(model, method)
if strcmp(model, 'SQ')
    name = struct('GLS', 'ratio_gls', 'WLS', 'ratio_wls', 'NLS', 'joint_nls').(method);
else
    name = struct('GLS', 'GLS', 'WLS', 'WLS', 'NLS', 'NLS_TCOM').(method);
end
end

function d = broadcast_range(y, N, u, p)
% Dual of F_broadcast_Konly/core/broadcast_distance.m for a reoriented PD and a fixed LED
h = rx_receiver_response(N'*u, p);
eta = sum(y.*h)/sum(h.^2);
c = -p.transmitter.normal'*u;
d = sqrt(p.calibration.A*c^p.calibration.m/eta);
end

function subsets = angle_subsets(K_full, K)
% Near-uniform subsets of K of the K_full equally spaced angles (indices), with all their rotations
base = round((0:K - 1)*K_full/K);
subsets = unique(sort(mod(base + (0:K_full - 1)', K_full), 2) + 1, 'rows');
end

function [position, offsets, ray_rms] = triangulate(U, truth, level, reference)
% Least-squares intersection of the rays truth_i + offset_level + t u_i (perpendicular distances)
others = setdiff(unique(level), reference);
ok = find(all(isfinite(U)));
M = zeros(3*numel(ok), 3 + numel(others));
b = zeros(3*numel(ok), 1);
for k = 1:numel(ok)
    i = ok(k);
    P = eye(3) - U(:, i)*U(:, i)';
    rows = 3*k - 2:3*k;
    M(rows, 1:3) = P;
    if level(i) ~= reference
        M(rows, 3 + find(others == level(i))) = -P(:, 3);
    end
    b(rows) = P*truth(:, i);
end
x = M \ b;
position = x(1:3);
offsets = x(4:end);
ray_rms = sqrt(mean(sum(reshape(M*x - b, 3, []).^2, 1)));
end

function [A, m, xy] = calibrate(x_mm, y_mm, rss, xy, h, p, method)
% A and m of RSS = A R(phi) cos(phi)^m / d^2 for a horizontal PD (psi = phi), as in
% Lambertian_order_LED_500khz/estimate_led_pattern.m but with the response of the simulations
if ischar(xy)
    cost = @(c) calibration_fit(x_mm, y_mm, rss, c, h, p, 'joint');
    xy = fminsearch(cost, [270 890], optimset('TolX', 1e-3, 'TolFun', 1e-12, 'Display', 'off'));
    method = 'joint';
end
[~, A, m] = calibration_fit(x_mm, y_mm, rss, xy, h, p, method);
end

function [value, A, m] = calibration_fit(x_mm, y_mm, rss, xy, h, p, method)
r = hypot(x_mm - xy(1), y_mm - xy(2))/1e3;
d = sqrt(r.^2 + h^2);
c = h./d;
R = rx_receiver_response(c, p);
ok = R > 0 & rss > 0;
Y = log(rss(ok).*d(ok).^2./R(ok));
X = log(c(ok));
switch method
    case 'staged'
        [~, k] = min(r(ok));
        logA = Y(k);
        m = sum((Y - logA).*X)/sum(X.^2);
    case 'joint'
        coef = [ones(size(X)) X] \ Y;
        logA = coef(1);
        m = coef(2);
    otherwise
        error('calibration_method must be ''staged'' or ''joint''.');
end
A = exp(logA);
value = mean((Y - logA - m*X).^2);
end

function value = orientation_rms(truth, theta, rss, sel, orientation, direction, convention, p)
% rms (%) of RSS_k / R(psi_k) around its per-site mean: independent of A, m and the LED pattern
deviation = [];
for i = find(sel)
    N = pd_normals(theta(:, i), orientation, direction, convention);
    v = p.transmitter.position_m - truth(:, i);
    R = rx_receiver_response(N'*(v/norm(v)), p);
    if any(R <= 0)
        value = Inf;
        return;
    end
    ratio = rss(:, i)./R;
    deviation = [deviation; ratio/mean(ratio) - 1]; %#ok<AGROW>
end
value = 100*sqrt(mean(deviation.^2));
end

function orientation = fit_orientation(truth, theta, rss, sel, mode, nominal, direction, p)
options = optimset('TolX', 1e-4, 'TolFun', 1e-10, 'Display', 'off');
switch mode
    case 'offset'
        cost = @(v) orientation_rms(truth, theta, rss, sel, [v nominal(2)], direction, 'vertical', p);
        orientation = [fminsearch(cost, nominal(1), options); nominal(2)];
    case 'offset_tilt'
        cost = @(v) orientation_rms(truth, theta, rss, sel, v, direction, 'vertical', p);
        orientation = fminsearch(cost, nominal, options)';
    otherwise
        error('orientation_fit must be ''none'', ''offset'' or ''offset_tilt''.');
end
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
