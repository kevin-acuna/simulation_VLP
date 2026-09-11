function plot_parameter_design(r, output_dir)
p = r.parameters;
colors_fov = lines(numel(p.design.fov_values_deg));
colors_half = lines(numel(p.design.half_angles_deg));
for ih = 1:numel(r.best)
    fig = new_figure(p, [100 100 940 740]);
    layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact');
    ax = nexttile(layout);
    hold(ax, 'on');
    handles = gobjects(numel(p.design.fov_values_deg), 1);
    for jf = 1:numel(p.design.fov_values_deg)
        handles(jf) = plot_bound(ax, p.design.tilt_values_deg, ...
            r.tilt.rms_conditional_m(:, jf, ih)*100, r.tilt.rms_full_m(:, jf, ih)*100, colors_fov(jf, :));
    end
    b = r.best(ih);
    plot(ax, b.cone_tilt_deg, b.reference_rms_m*100, 'kp', 'MarkerFaceColor', 'y', 'MarkerSize', 11);
    ylabel(ax, 'Spatial RMS-PEB [cm]');
    xlim(ax, [min(p.design.tilt_values_deg), max(p.design.tilt_values_deg)]);
    limits = ylim(ax);
    ylim(ax, [min(limits(1), b.reference_rms_m*100/1.15), limits(2)]);
    title(ax, {sprintf('\\Phi_{1/2} = %g deg, K = %d, A_{PD} = %.1f mm^2', b.half_angle_deg, p.design.reference_K, p.receiver.area_m2*1e6), ...
        'Solid: full-volume RMS; dotted: conditional RMS (outages excluded)'});
    labels = arrayfun(@(f) sprintf('FOV = %g deg', f), p.design.fov_values_deg, 'UniformOutput', false);
    legend(ax, handles, labels, 'Location', 'best', 'NumColumns', 2);
    format_axes(ax);
    ax = nexttile(layout);
    hold(ax, 'on');
    for jf = 1:numel(p.design.fov_values_deg)
        plot(ax, p.design.tilt_values_deg, 100*r.tilt.coverage(:, jf, ih), 'Color', colors_fov(jf, :), 'LineWidth', 1.5);
    end
    ylabel(ax, 'Regular 3D coverage [%]');
    xlabel(ax, 'Common PD inclination from +z [deg]');
    ylim(ax, [0 101]);
    xlim(ax, [min(p.design.tilt_values_deg), max(p.design.tilt_values_deg)]);
    format_axes(ax);
    export_figure(fig, output_dir, sprintf('PEB_vs_inclination_Phi%g', b.half_angle_deg), p);
end
fig = new_figure(p, [100 50 1100 950]);
layout = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact');
for budget = 1:2
    ax = nexttile(layout);
    hold(ax, 'on');
    handles = gobjects(numel(r.best), 1);
    for ih = 1:numel(r.best)
        handles(ih) = plot_bound(ax, p.design.K_values, r.K.rms_conditional_m(:, ih, budget)*100, ...
            r.K.rms_full_m(:, ih, budget)*100, colors_half(ih, :));
        if budget==1
            ik = find(p.design.K_values==r.best(ih).K_recommended, 1);
            plot(ax, p.design.K_values(ik), r.K.rms_full_m(ik, ih, budget)*100, 'o', ...
                'Color', colors_half(ih, :), 'MarkerFaceColor', colors_half(ih, :));
        end
    end
    ylabel(ax, 'Spatial RMS-PEB [cm]');
    if budget==1
        title(ax, {sprintf('Fixed N_i = %d; markers: smallest K within %.0f%% of minimum full-volume PEB', ...
            p.acquisition.samples_per_orientation, p.design.K_relative_tolerance*100), ...
            'Solid: full-volume RMS; dotted: conditional RMS (outages excluded)'});
        labels = arrayfun(@(b) sprintf('\\Phi=%g, FOV=%g, \\theta=%.2f deg', b.half_angle_deg, b.fov_deg, b.cone_tilt_deg), ...
            r.best, 'UniformOutput', false);
        legend(ax, handles, labels, 'Location', 'best', 'NumColumns', 2);
    else
        title(ax, sprintf('Fixed total M = %d samples; integer allocation across K orientations', p.acquisition.total_samples));
    end
    format_axes(ax);
    xlim(ax, [min(p.design.K_values), max(p.design.K_values)]);
end
ax = nexttile(layout);
hold(ax, 'on');
for ih = 1:numel(r.best)
    plot(ax, p.design.K_values, 100*r.K.coverage(:, ih, 1), '-o', 'Color', colors_half(ih, :), 'LineWidth', 1.5, 'MarkerSize', 4);
end
xlabel(ax, 'Number of orientations K (uniform cones are not nested)');
ylabel(ax, 'Regular 3D coverage [%]');
title(ax, 'Cone tilt/FOV frozen from inclination sweep; same coverage under both budgets');
xlim(ax, [min(p.design.K_values), max(p.design.K_values)]);
xticks(ax, p.design.K_values);
ylim(ax, [0 101]);
format_axes(ax);
export_figure(fig, output_dir, 'PEB_vs_K', p);
fig = new_figure(p, [100 100 1020 650]);
ax = axes(fig);
hold(ax, 'on');
handles = gobjects(numel(r.best), 1);
for ih = 1:numel(r.best)
    b = r.best(ih);
    handles(ih) = loglog(ax, p.design.area_values_mm2, 100*r.area.rms_full_m(:, ih), ...
        'Color', colors_half(ih, :), 'LineWidth', 1.8);
    if isfinite(b.area_target_mm2)
        ia = find(p.design.area_values_mm2==b.area_target_mm2, 1);
        plot(ax, b.area_target_mm2, 100*r.area.rms_full_m(ia, ih), 'o', ...
            'Color', colors_half(ih, :), 'MarkerFaceColor', colors_half(ih, :));
    end
end
set(ax, 'XScale', 'log', 'YScale', 'log');
yline(ax, p.design.target_rms_peb_m*100, 'k--', 'RMS-PEB target', 'LabelHorizontalAlignment', 'left');
xline(ax, p.receiver.area_m2*1e6, 'k:', 'Nominal area');
labels = arrayfun(@(b) sprintf('\\Phi=%g deg, FOV=%g deg, K=%d (2DoF)', ...
    b.half_angle_deg, b.fov_deg, b.K_recommended), r.best, 'UniformOutput', false);
legend(ax, handles, labels, 'Location', 'northeast');
xlabel(ax, 'Photodiode area A_{PD} [mm^2]');
ylabel(ax, 'Full-volume RMS-PEB [cm]');
title(ax, {'Locally refined 2DoF orientations; constant optical noise', ...
    'PEB scales as 1/A_{PD}: no interior area optimum in this model'});
format_axes(ax);
export_figure(fig, output_dir, 'PEB_vs_A_PD', p);
fig = new_figure(p, [100 50 1050 900]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact');
limits = finite_limits(r.heatmap.comparison_peb_m*100);
for ih = 1:numel(r.best)
    ax = nexttile(layout);
    draw_map(ax, r.heatmap.x_m, r.heatmap.y_m, r.heatmap.comparison_peb_m(:, :, ih)*100, limits, p);
    b = r.best(ih);
    title(ax, sprintf('\\Phi=%g deg, FOV=%g deg, K=%d', b.half_angle_deg, b.fov_deg, b.K_recommended));
end
title(layout, sprintf('3D PEB [cm] at z=%.2f m, nominal A_{PD}=%.1f mm^2; shared logarithmic scale', ...
    r.heatmap.comparison_height_m, p.receiver.area_m2*1e6));
export_figure(fig, output_dir, 'PEB_heatmap_best_configurations', p);
fig = new_figure(p, [100 50 1350 830]);
layout = tiledlayout(fig, 2, numel(r.heatmap.heights_m), 'TileSpacing', 'compact');
limits = finite_limits(r.heatmap.best_peb_m*100);
for ia = 1:2
    for iz = 1:numel(r.heatmap.heights_m)
        ax = nexttile(layout);
        draw_map(ax, r.heatmap.x_m, r.heatmap.y_m, r.heatmap.best_peb_m(:, :, iz, ia)*100, limits, p);
        title(ax, sprintf('z=%.2f m, A_{PD}=%.1f mm^2', r.heatmap.heights_m(iz), r.heatmap.areas_mm2(ia)));
    end
end
b = r.best(r.best_half_index);
title(layout, sprintf('Best sampled design: \\Phi=%g deg, FOV=%g deg, K=%d; 3D PEB [cm], shared log scale', ...
    b.half_angle_deg, b.fov_deg, b.K_recommended));
export_figure(fig, output_dir, 'PEB_heatmap_best_heights_and_area', p);
end

function fig = new_figure(p, position)
fig = figure('Color', 'w', 'Visible', p.output.visible, 'Position', position);
end

function handle = plot_bound(ax, x, conditional, full, color)
conditional(~isfinite(conditional)) = NaN;
full(~isfinite(full)) = NaN;
semilogy(ax, x, conditional, ':', 'Color', color, 'LineWidth', 1.2);
handle = semilogy(ax, x, full, '-', 'Color', color, 'LineWidth', 2.0);
set(ax, 'YScale', 'log');
end

function format_axes(ax)
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 11, 'LineWidth', 0.8);
end

function limits = finite_limits(values)
values = values(isfinite(values) & values>0);
if isempty(values)
    limits = [1 10];
else
    limits = [min(values), max(values)];
    if limits(1)==limits(2)
        limits = limits.*[0.9 1.1];
    end
end
end

function draw_map(ax, x, y, values, limits, p)
image = imagesc(ax, x, y, values);
set(image, 'AlphaData', isfinite(values));
set(ax, 'YDir', 'normal', 'Color', [0.7 0.7 0.7], 'ColorScale', 'log', 'FontSize', 10);
axis(ax, 'equal');
axis(ax, 'tight');
clim(ax, limits);
colormap(ax, parula(256));
cb = colorbar(ax);
cb.Label.String = '3D PEB [cm]';
hold(ax, 'on');
plot(ax, p.transmitter.position_m(1), p.transmitter.position_m(2), 'wp', 'MarkerFaceColor', 'k', 'MarkerSize', 10);
xlabel(ax, 'x [m]');
ylabel(ax, 'y [m]');
end

function export_figure(fig, output_dir, name, p)
exportgraphics(fig, fullfile(output_dir, [name '.png']), 'Resolution', p.output.resolution_dpi);
exportgraphics(fig, fullfile(output_dir, [name '.pdf']), 'ContentType', 'vector');
savefig(fig, fullfile(output_dir, [name '.fig']));
close(fig);
end
