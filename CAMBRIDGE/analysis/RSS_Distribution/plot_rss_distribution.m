% RSS distribution of the PD over the testbed at a fixed height.
% Reads points.csv (Database Acquisition Tool, XY grid at one Z and one MTRS angle) and draws, for every
% LED frequency, a heatmap and the 3D surface RSS(x, y). Works with an incomplete campaign: grid cells
% that were not measured yet stay empty (NaN). Re-run it after updating points.csv.

%% Hyperparameters
csv_file        = fullfile(fileparts(mfilename('fullpath')), 'points.csv');
frequencies_khz = [300 500 700 900];  % columns <f>kHz_<source>_Vrms of points.csv
rss_source      = 'fft';             % 'wave' (lock-in on the raw waveform) | 'fft' (scope FFT peak)
rss_scale       = 'linear';           % 'linear' (mVrms) | 'dB' (20 log10(V / db_reference_v))
db_reference_v  = 1;                  % reference amplitude of the dB scale (Vrms)
workspace_mm    = [0 1400];           % X and Y extent of the testbed (mm)
grid_step_mm    = [10];                 % [] = inferred from the commanded positions
z_mm            = [];                 % [] = the only height in the file
common_clim     = false;              % true: same color/Z limits for the 4 frequencies
app_orientation = true;               % true: same top view as the acquisition tool (Y horizontal, growing
                                      % to the left; X vertical, growing upwards); false: standard X-Y axes
mark_maximum    = true;               % mark the position of the maximum RSS
surface_view    = [-37.5 30];         % [azimuth elevation] of the 3D plots (deg)
grid_lines_heatmap = true;            % draw grid lines over the measured part of the heatmaps
grid_lines_surface = true;            % draw grid lines (wireframe) over the 3D surfaces
grid_lines_step_mm = 40;              % spacing of the grid lines (rounded to a multiple of grid_step_mm)
grid_lines_color   = [0.1 0.1 0.1];         % RGB color of the grid lines
grid_lines_width   = 0.01;             % line width of the grid lines (pt)
export_figures  = true;               % PNG (300 dpi) + FIG in output_dir (overwritten at every run)
output_dir      = fullfile(fileparts(csv_file), 'figures');

%% Load
data = readtable(csv_file, 'VariableNamingRule', 'preserve');
heights = unique(data.z_cmd_mm);
if isempty(z_mm)
    if numel(heights) > 1
        error('Several heights in the file (%s mm): set z_mm.', mat2str(heights'));
    end
    z_mm = heights;
end
data = data(abs(data.z_cmd_mm - z_mm) < 1e-6, :);
if isempty(data)
    error('No measurement at z = %g mm.', z_mm);
end
if numel(unique(data.angle_cmd_deg)) > 1 || numel(unique(data.mtrs_tilt_cmd_deg)) > 1
    error('Several MTRS orientations at z = %g mm: this script expects a single orientation.', z_mm);
end

if isempty(grid_step_mm)
    steps = [diff(unique(data.x_cmd_mm)); diff(unique(data.y_cmd_mm))];
    grid_step_mm = min(steps(steps > 1e-6));
end
grid_mm = workspace_mm(1):grid_step_mm:workspace_mm(2);
n = numel(grid_mm);
ix = round((data.x_cmd_mm - workspace_mm(1))/grid_step_mm) + 1;
iy = round((data.y_cmd_mm - workspace_mm(1))/grid_step_mm) + 1;
inside = ix >= 1 & ix <= n & iy >= 1 & iy <= n;
ix = ix(inside);
iy = iy(inside);
data = data(inside, :);

% rss(:, :, f) is indexed (iy, ix); repeated passes over a cell are averaged
nf = numel(frequencies_khz);
rss = nan(n, n, nf);
for f = 1:nf
    column = sprintf('%dkHz_%s_Vrms', frequencies_khz(f), rss_source);
    if ~ismember(column, data.Properties.VariableNames)
        error('Column %s not found in %s.', column, csv_file);
    end
    rss(:, :, f) = accumarray([iy ix], data.(column), [n n], @mean, NaN);
end
switch rss_scale
    case 'linear'
        rss = 1e3*rss;
        rss_label = 'RSS (mV_{rms})';
    case 'dB'
        rss = 20*log10(rss/db_reference_v);
        rss_label = 'RSS (dB)';
    otherwise
        error('rss_scale must be ''linear'' or ''dB''.');
end

measured = isfinite(rss(:, :, 1));
coverage = sprintf('%d/%d grid points (%.1f %%)', nnz(measured), n^2, 100*nnz(measured)/n^2);
header = sprintf('RSS (%s) at z = %g mm, MTRS angle %g deg, step %g mm - %s', rss_source, z_mm, ...
    data.angle_cmd_deg(1), grid_step_mm, coverage);
fprintf('%s\n', header);
fprintf('%8s %10s %10s %10s %18s\n', 'f (kHz)', 'min', 'mean', 'max', 'max at (x, y) mm');
limits = [min(rss(:)) max(rss(:))];
lines_every = max(1, round(grid_lines_step_mm/grid_step_mm));
% shown(r, c, f): value drawn at horizontal axis grid_mm(c), vertical axis grid_mm(r)
if app_orientation
    shown = permute(rss, [2 1 3]);
    axis_names = {'Y (mm)', 'X (mm)'};
else
    shown = rss;
    axis_names = {'X (mm)', 'Y (mm)'};
end

%% Heatmaps
fig_map = figure('Name', 'RSS heatmaps', 'Color', 'w', 'Position', [80 80 1100 950]);
layout = tiledlayout(fig_map, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for f = 1:nf
    values = rss(:, :, f);
    [peak, k] = max(values(:));
    [ky, kx] = ind2sub([n n], k);
    fprintf('%8d %10.4g %10.4g %10.4g %8g, %g\n', frequencies_khz(f), min(values(:)), ...
        mean(values(:), 'omitnan'), peak, grid_mm(kx), grid_mm(ky));
    [kv, kh] = ind2sub([n n], find(shown(:, :, f) == peak, 1));

    ax = nexttile(layout);
    img = imagesc(ax, grid_mm, grid_mm, shown(:, :, f));
    set(ax, 'YDir', 'normal');
    if app_orientation
        set(ax, 'XDir', 'reverse');
    end
    xlabel(ax, axis_names{1});
    ylabel(ax, axis_names{2});
    img.AlphaData = isfinite(img.CData);
    set(ax, 'Color', [0.85 0.85 0.85], 'Layer', 'top', 'Box', 'on');
    axis(ax, 'equal');
    xlim(ax, workspace_mm);
    ylim(ax, workspace_mm);
    colormap(ax, parula(256));
    if common_clim
        clim(ax, limits);
    end
    cb = colorbar(ax);
    cb.Label.String = rss_label;
    hold(ax, 'on');
    if grid_lines_heatmap
        draw_grid_lines(ax, grid_mm, shown(:, :, f), lines_every, false, grid_lines_color, grid_lines_width);
    end
    if mark_maximum && isfinite(peak)
        plot(ax, grid_mm(kh), grid_mm(kv), 'wp', 'MarkerFaceColor', 'k', 'MarkerSize', 10);
    end
    title(ax, sprintf('%d kHz (max %.4g at x = %g, y = %g mm)', frequencies_khz(f), peak, ...
        grid_mm(kx), grid_mm(ky)), 'FontWeight', 'normal');
end

%% 3D surfaces
fig_surf = figure('Name', 'RSS surfaces', 'Color', 'w', 'Position', [120 60 1100 950]);
layout = tiledlayout(fig_surf, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for f = 1:nf
    values = shown(:, :, f);
    [peak, k] = max(values(:));
    [kv, kh] = ind2sub([n n], k);

    ax = nexttile(layout);
    surf(ax, grid_mm, grid_mm, values, 'EdgeColor', 'none', 'FaceColor', 'interp');
    if app_orientation
        set(ax, 'XDir', 'reverse');
    end
    xlabel(ax, axis_names{1});
    ylabel(ax, axis_names{2});
    zlabel(ax, rss_label);
    xlim(ax, workspace_mm);
    ylim(ax, workspace_mm);
    colormap(ax, parula(256));
    if common_clim
        clim(ax, limits);
        zlim(ax, limits);
    end
    hold(ax, 'on');
    if grid_lines_surface
        draw_grid_lines(ax, grid_mm, values, lines_every, true, grid_lines_color, grid_lines_width);
    end
    if mark_maximum && isfinite(peak)
        plot3(ax, grid_mm(kh), grid_mm(kv), peak, 'wp', 'MarkerFaceColor', 'k', 'MarkerSize', 10);
    end
    view(ax, surface_view);
    grid(ax, 'on');
    box(ax, 'on');
    title(ax, sprintf('%d kHz', frequencies_khz(f)), 'FontWeight', 'normal');
end

%% Export
if export_figures
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
    names = {sprintf('rss_heatmaps_%s_%s', rss_source, rss_scale), ...
        sprintf('rss_surfaces_%s_%s', rss_source, rss_scale)};
    figures = [fig_map fig_surf];
    for i = 1:2
        exportgraphics(figures(i), fullfile(output_dir, [names{i} '.png']), 'Resolution', 300);
        savefig(figures(i), fullfile(output_dir, [names{i} '.fig']));
    end
    fprintf('Figures saved in %s\n', output_dir);
end

function draw_grid_lines(ax, grid_mm, values, every, in_3d, color, width)
% Lines along both axes every `every` grid nodes, following values(r, c) (horizontal grid_mm(c),
% vertical grid_mm(r)); unmeasured (NaN) cells break the lines.
n = numel(grid_mm);
picked = unique([1:every:n n]);
[h, v] = meshgrid(grid_mm);
gap_r = nan(numel(picked), 1);
gap_c = nan(1, numel(picked));
hl = [reshape([h(picked, :) gap_r]', [], 1); reshape([h(:, picked); gap_c], [], 1)];
vl = [reshape([v(picked, :) gap_r]', [], 1); reshape([v(:, picked); gap_c], [], 1)];
zl = [reshape([values(picked, :) gap_r]', [], 1); reshape([values(:, picked); gap_c], [], 1)];
if in_3d
    plot3(ax, hl, vl, zl, '-', 'Color', color, 'LineWidth', width);
else
    hl(isnan(zl)) = NaN;
    plot(ax, hl, vl, '-', 'Color', color, 'LineWidth', width);
end
end
