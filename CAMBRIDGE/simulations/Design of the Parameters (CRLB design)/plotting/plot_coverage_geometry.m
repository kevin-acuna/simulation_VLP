function figures = plot_coverage_geometry(r, style)
if nargin < 2
    style = ieee_plot_style();
end
e = r.spec;
figures = rx_ieee_figure('Tilt_FOV_coverage_geometry', style, 3.7);
layout = tiledlayout(figures(1), 1, 2, 'TileSpacing', 'compact', 'Padding', 'loose');
ax = nexttile(layout);
rx_discrete_map(ax, e.tilt_values_deg, e.fov_values_deg, 100*r.coverage', [0 100], 'linear', style);
annotate_partial_coverage(ax, 100*r.coverage', style);
xlabel(ax, 'Tilt (deg)');
ylabel(ax, 'FOV half-angle (deg)');
title(ax, sprintf('Regular 3D coverage, K=%d', e.K));
ax = nexttile(layout);
rx_discrete_map(ax, e.tilt_values_deg, e.fov_values_deg, 100*r.potential_coverage', [0 100], 'linear', style);
annotate_partial_coverage(ax, 100*r.potential_coverage', style);
xlabel(ax, 'Tilt limit (deg)');
ylabel(ax, 'FOV half-angle (deg)');
title(ax, 'Optimistic geometric coverage envelope');
cb = colorbar(ax);
cb.Layout.Tile = 'east';
cb.Label.String = 'Fraction of evaluation grid (%)';
cb.FontSize = style.font_size;
figures(2) = rx_ieee_figure('Tilt_FOV_necessary_and_sufficient', style, 3.4);
ax = axes(figures(2));
a = rx_design_line(ax, e.tilt_values_deg, r.necessary_fov_deg, 1, style);
b = rx_design_line(ax, e.tilt_values_deg, r.all_visible_fov_deg, 2, style);
yline(ax, 90, 'k:', 'Physical FOV limit', 'FontSize', style.font_size);
xlabel(ax, 'Allowed tilt (deg)');
ylabel(ax, 'FOV half-angle (deg)');
legend(ax, [a b], {'Necessary: at least one admissible ray everywhere', 'Sufficient: every cone orientation visible everywhere'}, ...
    'Location', 'northoutside', 'Box', 'off');
rx_ieee_axes(ax, style);
title(ax, sprintf('Largest receiver-to-LED polar angle = %.3f deg; strict inequalities at boundaries', r.max_polar_angle_deg));
end

function annotate_partial_coverage(ax, values, style)
[rows, cols] = find(values>0 & values<100);
for i = 1:numel(rows)
    value = values(rows(i), cols(i));
    color = 'k';
    if value<40
        color = 'w';
    end
    text(ax, cols(i), rows(i), sprintf('%.1f', value), 'HorizontalAlignment', 'center', ...
        'Color', color, 'FontName', style.font_name, 'FontSize', style.font_size-1);
end
end
