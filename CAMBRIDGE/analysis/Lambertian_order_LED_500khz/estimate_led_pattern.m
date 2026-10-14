% Experimental radiation pattern of one LED and its equivalent Lambertian order m.
% The PD scanned a horizontal XY grid (fixed height, PD facing up) under the LED (facing down). Model:
%   RSS = A * R(psi) * L(phi) / d^2,   L(phi) = cos(phi)^m,  L(0) = R(0) = 1
% A gathers every constant (power, area, gains). Both planes are parallel, so psi = phi and
% cos(phi) = h/d. The data only fix the product R*L: the LED pattern is obtained by dividing by the
% assumed PD response R (Bastiaens et al., IEEE Access 2020, PDA100A2), selected with pd_model.
% Stage 1: A from the point(s) right below the LED, RSS(0) = A/h^2.
% Stage 2: L(phi) = RSS * d^2 / (A * R(phi)) at every measured position.
% Stage 3: m from a least-squares fit of log L = m log cos(phi).
% Two more robust alternatives are also computed (fit_method): A and m fitted together with every
% point ('joint'), and additionally the LED XY position ('joint_xy').
close all

%% Hyperparameters
csv_file        = fullfile(fileparts(mfilename('fullpath')), 'points.csv');
led_freq_khz    = 500;                % LED studied (column <f>kHz_<source>_Vrms)
rss_source      = 'fft';             % 'wave' (lock-in on the raw waveform) | 'fft' (scope FFT peak)
led_xy_mm       = [270 890];          % LED position in gantry coordinates (mm)
% led_xy_mm       = [281.1,  904.8];          % LED position in gantry coordinates (mm)
H_led_m         = 3;                  % height of the LED plane (m)
H_pd_m          = (103.8 + 9.696)/100;% height of the PD plane (m)
pd_model        = 'cosine_mR';               % 'SQ' (1 - C psi^2) | 'cosine_mR' (cos^m_R psi) | 'cosine' (cos psi)
psi_3db_rad     = 0.61;               % SQ: angle where R = 1/sqrt(2) (PDA100A2, paper Table 1)
m_R             = 1.9;                % cosine_mR: receiver order (PDA100A2, paper)
pd_fov_deg      = 64;                 % FOV of the cosine models (SQ uses its own zero, 64.58 deg)
fit_method      = 'staged';           % 'staged' (stages 1-3 above) | 'joint' (A, m) | 'joint_xy' (A, m, LED XY)
axis_radius_mm  = 0;                  % stage 1: points within this horizontal distance of the LED (0 = only
                                      % the grid point right below it)
max_phi_deg     = 90;                 % ignore points beyond this emission angle in the fits
bin_width_deg   = 1;                  % width of the angular bins of the experimental pattern
min_bin_count   = 3;                  % bins with fewer points are not drawn
app_orientation = true;               % deviation map: same top view as the acquisition tool
export_figures  = false;              % PNG (300 dpi) + FIG in output_dir (overwritten at every run)
output_dir      = fullfile(fileparts(csv_file), 'figures');

%% Load
data = readtable(csv_file, 'VariableNamingRule', 'preserve');
column = sprintf('%dkHz_%s_Vrms', led_freq_khz, rss_source);
if numel(unique(data.z_cmd_mm)) > 1 || numel(unique(data.angle_cmd_deg)) > 1 || ...
        numel(unique(data.mtrs_tilt_cmd_deg)) > 1 || any(data.pd_tilt_deg ~= 0)
    error('This script expects a single height and a single horizontal PD orientation.');
end
x_mm = data.x_cmd_mm;
y_mm = data.y_cmd_mm;
rss = data.(column);
h = H_led_m - H_pd_m;
pd = struct('model', pd_model, 'psi_3db_rad', psi_3db_rad, 'm_R', m_R, 'fov_deg', pd_fov_deg);
[~, k_max] = max(rss);
fprintf('%s: %d points, z = %g mm, h = %.4f m, PD model %s\n', column, numel(rss), data.z_cmd_mm(1), h, pd_model);
fprintf('Maximum RSS %.4g mVrms at (%g, %g) mm; LED assumed at (%g, %g) mm\n', 1e3*rss(k_max), ...
    x_mm(k_max), y_mm(k_max), led_xy_mm);

%% Fits (all methods, selected PD model)
fits = struct();
fits.staged = fit_staged(x_mm, y_mm, rss, led_xy_mm, h, pd, axis_radius_mm, max_phi_deg);
fits.joint = fit_joint(x_mm, y_mm, rss, led_xy_mm, h, pd, max_phi_deg);
fits.joint_xy = fit_joint_xy(x_mm, y_mm, rss, led_xy_mm, h, pd, max_phi_deg);
fit = fits.(fit_method);

fprintf('\nStage 1 (staged): %d point(s) within %g mm of the LED, RSS(0) = %.4g mVrms, A = %.4g V m^2\n', ...
    fits.staged.n_axis, axis_radius_mm, 1e3*fits.staged.A/h^2, fits.staged.A);
fprintf('%-9s %10s %10s %12s %16s %10s\n', 'method', 'm', 'phi_1/2', 'RSS(0) mV', 'LED XY (mm)', 'rms err');
for name = {'staged', 'joint', 'joint_xy'}
    r = fits.(name{1});
    fprintf('%-9s %10.3f %8.2f d %12.4g %7.1f, %6.1f %8.2f %%\n', name{1}, r.m, half_angle(r.m), ...
        1e3*r.A/h^2, r.led_xy_mm, r.rms_pct);
end

fprintf('\nSensitivity of m to the PD model (%s):\n', fit_method);
for model = {'SQ', 'cosine_mR', 'cosine'}
    q = pd;
    q.model = model{1};
    switch fit_method
        case 'staged'
            r = fit_staged(x_mm, y_mm, rss, led_xy_mm, h, q, axis_radius_mm, max_phi_deg);
        case 'joint'
            r = fit_joint(x_mm, y_mm, rss, led_xy_mm, h, q, max_phi_deg);
        case 'joint_xy'
            r = fit_joint_xy(x_mm, y_mm, rss, led_xy_mm, h, q, max_phi_deg);
    end
    fprintf('  %-10s m = %6.3f (phi_1/2 = %5.2f deg)\n', model{1}, r.m, half_angle(r.m));
end

%% Experimental pattern (stage 2) with the selected fit
g = geometry(x_mm, y_mm, fit.led_xy_mm, h);
pattern = rss.*g.d.^2./(fit.A*pd_response(g.phi, pd));
used = g.phi <= deg2rad(max_phi_deg) & isfinite(pattern) & pattern > 0;
phi_deg = rad2deg(g.phi(used));
L = pattern(used);
edges = 0:bin_width_deg:ceil(max(phi_deg)/bin_width_deg)*bin_width_deg;
bin = discretize(phi_deg, edges);
nb = numel(edges) - 1;
count = accumarray(bin, 1, [nb 1]);
bin_mean = accumarray(bin, L, [nb 1], @mean, NaN);
bin_std = accumarray(bin, L, [nb 1], @std, NaN);
bin_phi = accumarray(bin, phi_deg, [nb 1], @mean, NaN);
keep = count >= min_bin_count;
fprintf('\nExperimental pattern: %d points, phi = 0-%.1f deg, %d bins of %g deg\n', numel(L), ...
    max(phi_deg), nnz(keep), bin_width_deg);
phi_model = linspace(0, 90, 361);
label_fit = sprintf('Lambertian m = %.2f (\\Phi_{1/2} = %.1f^\\circ)', fit.m, half_angle(fit.m));

fig_pattern = figure('Name', 'LED pattern', 'Color', 'w', 'Position', [80 80 950 560]);
ax = axes(fig_pattern);
hold(ax, 'on');
scatter(ax, phi_deg, L, 6, rad2deg(g.azimuth(used)), 'filled', 'MarkerFaceAlpha', 0.35, ...
    'DisplayName', 'Measured points');
colormap(ax, hsv(360));
clim(ax, [-180 180]);
cb = colorbar(ax);
cb.Label.String = 'Azimuth around the LED (deg)';
errorbar(ax, bin_phi(keep), bin_mean(keep), bin_std(keep), 'ko', 'MarkerFaceColor', 'k', ...
    'MarkerSize', 4, 'CapSize', 3, 'DisplayName', sprintf('Mean \\pm std (%g^\\circ bins)', bin_width_deg));
plot(ax, phi_model, cosd(phi_model).^fit.m, 'r-', 'LineWidth', 1.8, 'DisplayName', label_fit);
plot(ax, phi_model, cosd(phi_model), 'k--', 'LineWidth', 1, 'DisplayName', 'Lambertian m = 1');
xlim(ax, [0 min(90, 5*ceil(1.15*max(phi_deg)/5))]);
ylim(ax, [0 1.1]);
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Emission angle \phi (deg)');
ylabel(ax, 'Normalized LED pattern L(\phi)');
legend(ax, 'Location', 'southwest');

fig_polar = figure('Name', 'LED pattern (polar)', 'Color', 'w', 'Position', [120 80 650 560]);
pax = polaraxes(fig_polar);
hold(pax, 'on');
polarplot(pax, deg2rad([-fliplr(phi_model) phi_model]), cosd([fliplr(phi_model) phi_model]).^fit.m, ...
    'r-', 'LineWidth', 1.8, 'DisplayName', label_fit);
polarplot(pax, deg2rad([-fliplr(phi_model) phi_model]), cosd([fliplr(phi_model) phi_model]), 'k--', ...
    'DisplayName', 'Lambertian m = 1');
polarplot(pax, deg2rad([-flipud(bin_phi(keep)); bin_phi(keep)]), [flipud(bin_mean(keep)); bin_mean(keep)], ...
    'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 4, 'DisplayName', 'Measured (bin mean)');
set(pax, 'ThetaZeroLocation', 'bottom', 'ThetaLim', [-90 90], 'RLim', [0 1.05]);
legend(pax, 'Location', 'southoutside');

%% Deviation map: measured RSS / fitted model - 1
model_rss = fit.A*pd_response(g.phi, pd).*cos(g.phi).^fit.m./g.d.^2;
deviation = 100*(rss./model_rss - 1);
step = min(diff(unique([x_mm; y_mm])));
gx = min(x_mm):step:max(x_mm);
gy = min(y_mm):step:max(y_mm);
map = accumarray([round((y_mm - gy(1))/step) + 1, round((x_mm - gx(1))/step) + 1], deviation, ...
    [numel(gy) numel(gx)], @mean, NaN);
fig_map = figure('Name', 'Deviation from the fitted model', 'Color', 'w', 'Position', [160 80 800 650]);
ax = axes(fig_map);
if app_orientation
    img = imagesc(ax, gy, gx, map');
    set(ax, 'XDir', 'reverse', 'YDir', 'normal');
    xlabel(ax, 'Y (mm)');
    ylabel(ax, 'X (mm)');
    led_hv = fit.led_xy_mm([2 1]);
else
    img = imagesc(ax, gx, gy, map);
    set(ax, 'YDir', 'normal');
    xlabel(ax, 'X (mm)');
    ylabel(ax, 'Y (mm)');
    led_hv = fit.led_xy_mm;
end
img.AlphaData = isfinite(img.CData);
set(ax, 'Color', [0.85 0.85 0.85], 'Box', 'on');
axis(ax, 'equal', 'tight');
limit = max(abs(deviation(used)));
clim(ax, [-limit limit]);
colormap(ax, diverging_map(256));
cb = colorbar(ax);
cb.Label.String = 'RSS / model - 1 (%)';
hold(ax, 'on');
plot(ax, led_hv(1), led_hv(2), 'kp', 'MarkerFaceColor', 'y', 'MarkerSize', 12);

%% Export
if export_figures
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
    names = {'led_pattern', 'led_pattern_polar', 'led_model_deviation'};
    figures = [fig_pattern fig_polar fig_map];
    for i = 1:numel(figures)
        name = sprintf('%s_%dkHz_%s_%s', names{i}, led_freq_khz, pd_model, fit_method);
        exportgraphics(figures(i), fullfile(output_dir, [name '.png']), 'Resolution', 300);
        savefig(figures(i), fullfile(output_dir, [name '.fig']));
    end
    fprintf('Figures saved in %s\n', output_dir);
end

%% Local functions
function g = geometry(x_mm, y_mm, led_xy_mm, h)
% Horizontal offset PD - LED, distance d (m), emission angle phi = incidence angle psi (rad)
dx = (x_mm - led_xy_mm(1))/1e3;
dy = (y_mm - led_xy_mm(2))/1e3;
g.r = hypot(dx, dy);
g.d = sqrt(g.r.^2 + h^2);
g.phi = atan2(g.r, h);
g.azimuth = atan2(dy, dx);
end

function R = pd_response(psi, pd)
% Normalized angular response of the PD, R(0) = 1 (Bastiaens et al. 2020)
switch pd.model
    case 'SQ'
        C = (1 - 1/sqrt(2))/pd.psi_3db_rad^2;
        R = max(0, 1 - C*psi.^2);
    case 'cosine_mR'
        R = cos(psi).^pd.m_R.*(psi <= deg2rad(pd.fov_deg));
    case 'cosine'
        R = cos(psi).*(psi <= deg2rad(pd.fov_deg));
    otherwise
        error('pd_model must be ''SQ'', ''cosine_mR'' or ''cosine''.');
end
end

function [y, c, ok] = linearized(x_mm, y_mm, rss, led_xy_mm, h, pd, max_phi_deg)
% log(RSS d^2 / R) = log A + m log cos(phi)
g = geometry(x_mm, y_mm, led_xy_mm, h);
R = pd_response(g.phi, pd);
ok = R > 0 & rss > 0 & g.phi <= deg2rad(max_phi_deg);
y = log(rss(ok).*g.d(ok).^2./R(ok));
c = log(cos(g.phi(ok)));
end

function fit = finish(fit, y, c)
residual = y - log(fit.A) - fit.m*c;
fit.rms_pct = 100*sqrt(mean(expm1(residual).^2));
end

function fit = fit_staged(x_mm, y_mm, rss, led_xy_mm, h, pd, axis_radius_mm, max_phi_deg)
g = geometry(x_mm, y_mm, led_xy_mm, h);
on_axis = g.r*1e3 <= max(axis_radius_mm, 0) + 1e-6;
if ~any(on_axis)
    [~, k] = min(g.r);
    on_axis = false(size(g.r));
    on_axis(k) = true;
end
% Stage 1: near the axis L ~ 1, so A = RSS d^2 / R
A = mean(rss(on_axis).*g.d(on_axis).^2./pd_response(g.phi(on_axis), pd));
% Stages 2-3: log L = log(RSS d^2 / (A R)) = m log cos(phi), least squares through the origin
[y, c] = linearized(x_mm, y_mm, rss, led_xy_mm, h, pd, max_phi_deg);
m = sum((y - log(A)).*c)/sum(c.^2);
fit = finish(struct('A', A, 'm', m, 'led_xy_mm', led_xy_mm, 'n_axis', nnz(on_axis)), y, c);
end

function fit = fit_joint(x_mm, y_mm, rss, led_xy_mm, h, pd, max_phi_deg)
[y, c] = linearized(x_mm, y_mm, rss, led_xy_mm, h, pd, max_phi_deg);
coef = [ones(size(c)) c] \ y;
fit = finish(struct('A', exp(coef(1)), 'm', coef(2), 'led_xy_mm', led_xy_mm), y, c);
end

function fit = fit_joint_xy(x_mm, y_mm, rss, led_xy_mm, h, pd, max_phi_deg)
% LED XY by Nelder-Mead; A and m solved linearly for every candidate position
cost = @(xy) joint_cost(x_mm, y_mm, rss, xy, h, pd, max_phi_deg);
xy = fminsearch(cost, led_xy_mm, optimset('TolX', 1e-3, 'TolFun', 1e-12, 'Display', 'off'));
fit = fit_joint(x_mm, y_mm, rss, xy, h, pd, max_phi_deg);
end

function value = joint_cost(x_mm, y_mm, rss, xy, h, pd, max_phi_deg)
[y, c] = linearized(x_mm, y_mm, rss, xy, h, pd, max_phi_deg);
M = [ones(size(c)) c];
value = mean((y - M*(M \ y)).^2);
end

function angle = half_angle(m)
% Half-power semi-angle of cos^m
angle = acosd(2^(-1/m));
end

function map = diverging_map(n)
t = linspace(-1, 1, n)';
blue = [0.23 0.30 0.75];
red = [0.71 0.02 0.15];
map = (t < 0).*((1 + t).*[1 1 1] - t.*blue) + (t >= 0).*((1 - t).*[1 1 1] + t.*red);
end
