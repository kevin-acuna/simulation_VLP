function fig = plot_tilt_fov_K_map(r, style)
e = r.spec;
nb = numel(e.budgets);
values = inf(numel(e.fov_values_deg), numel(e.K_values), nb);
t = r.base_table;
for ib = 1:nb
    for jf = 1:numel(e.fov_values_deg)
        for ik = 1:numel(e.K_values)
            rows = t.FOV_deg==e.fov_values_deg(jf) & t.K==e.K_values(ik) & t.Budget==string(e.budgets{ib});
            values(jf, ik, ib) = min(t.RequiredArea_mm2(rows));
        end
    end
end
finite = values(isfinite(values) & values>0);
limits = [1 max(e.area_values_mm2)];
if ~isempty(finite)
    limits = [min(finite)*0.95, max(finite)*1.05];
end
fig = rx_ieee_figure('Tilt_FOV_K_feasibility', style, 3.7);
layout = tiledlayout(fig, 1, nb, 'TileSpacing', 'compact', 'Padding', 'loose');
for ib = 1:nb
    ax = nexttile(layout);
    rx_discrete_map(ax, e.K_values, e.fov_values_deg, values(:, :, ib), limits, 'log', style);
    hold(ax, 'on');
    [row, col] = find(isfinite(values(:, :, ib)) & values(:, :, ib)>max(e.area_values_mm2));
    plot(ax, col, row, 'kx', 'MarkerSize', 5, 'LineWidth', 0.8);
    xlabel(ax, 'K (discrete candidates)');
    ylabel(ax, 'FOV half-angle (deg)');
    title(ax, strrep(e.budgets{ib}, '_', ' '));
end
cb = colorbar(ax);
cb.Layout.Tile = 'east';
cb.Label.String = 'Minimum required area (mm^2)';
cb.FontSize = style.font_size;
title(layout, sprintf('Tilt <= %g deg; gray: no full coverage; x: required area exceeds %g mm^2', ...
    e.tilt_deg, max(e.area_values_mm2)), 'FontName', style.font_name, 'FontSize', style.font_size, 'FontWeight', 'normal');
end
