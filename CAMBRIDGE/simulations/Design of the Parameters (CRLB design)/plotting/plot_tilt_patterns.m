function fig = plot_tilt_patterns(r, style)
e = r.spec;
fig = rx_ieee_figure('Tilt_orientation_patterns', style, 3.8);
layout = tiledlayout(fig, 1, numel(e.budgets), 'TileSpacing', 'compact', 'Padding', 'loose');
if isempty(r.selected)
    title(layout, 'No finite full-domain candidate within the tested tilt/FOV constraints');
    return;
end
half = r.selected.candidate.HalfAngle_deg;
fov = r.selected.candidate.FOV_deg;
t = r.base_table;
for ib = 1:numel(e.budgets)
    ax = nexttile(layout);
    handles = gobjects(1, numel(e.patterns));
    for ip = 1:numel(e.patterns)
        required = inf(size(e.K_values));
        for ik = 1:numel(e.K_values)
            row = t.HalfAngle_deg==half & t.FOV_deg==fov & t.K==e.K_values(ik) ...
                & t.Pattern==string(e.patterns{ip}) & t.Budget==string(e.budgets{ib});
            required(ik) = min(t.RequiredArea_mm2(row));
        end
        handles(ip) = rx_design_line(ax, e.K_values, required, ip, style);
    end
    set(ax, 'XScale', 'log', 'YScale', 'log');
    yline(ax, max(e.area_values_mm2), 'k--', 'Area cap', 'FontSize', style.font_size);
    xlabel(ax, 'K');
    ylabel(ax, 'Required A_{PD} (mm^2)');
    title(ax, strrep(e.budgets{ib}, '_', ' '));
    rx_ieee_axes(ax, style);
    if ib==1
        lg = legend(ax, handles, strrep(e.patterns, '_', ' '), 'Box', 'off', 'NumColumns', 2);
        lg.Layout.Tile = 'north';
    end
end
title(layout, sprintf('All normals within %g deg; \\Phi_{1/2}=%g deg, FOV=%g deg; before local refinement', ...
    e.tilt_deg, half, fov), 'FontName', style.font_name, 'FontSize', style.font_size, 'FontWeight', 'normal');
end
