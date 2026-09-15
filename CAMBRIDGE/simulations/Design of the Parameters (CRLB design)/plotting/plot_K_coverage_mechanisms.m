function fig = plot_K_coverage_mechanisms(r, style)
e = r.spec;
fig = rx_ieee_figure('K_coverage_mechanisms', style, 5.2);
layout = tiledlayout(fig, 2, numel(e.fov_values_deg), 'TileSpacing', 'compact', 'Padding', 'loose');
for jf = 1:numel(e.fov_values_deg)
    ax = nexttile(layout, jf);
    handles = gobjects(1, numel(e.patterns));
    for ip = 1:numel(e.patterns)
        handles(ip) = rx_design_line(ax, e.K_values, 100*r.coverage(:, ip, jf, 1), ip, style);
        h = rx_design_line(ax, e.K_values, 100*r.light_coverage(:, ip, jf, 1), ip, style, ':');
        h.HandleVisibility = 'off';
    end
    ylim(ax, [0 103]);
    ylabel(ax, 'Grid coverage (%)');
    title(ax, sprintf('FOV=%g deg: solid 3D, dotted LOS', e.fov_values_deg(jf)));
    rx_ieee_axes(ax, style);
    if jf==1
        lg = legend(ax, handles, strrep(e.patterns, '_', ' '), 'NumColumns', 3, 'Box', 'off');
        lg.Layout.Tile = 'north';
    end
    ax = nexttile(layout, numel(e.fov_values_deg)+jf);
    for ip = 1:numel(e.patterns)
        rx_design_line(ax, e.K_values, 100*r.target_coverage(:, ip, jf, 1), ip, style);
        if numel(e.budgets)>1
            rx_design_line(ax, e.K_values, 100*r.target_coverage(:, ip, jf, 2), ip, style, '--');
        end
    end
    ylim(ax, [0 103]);
    ylabel(ax, sprintf('PEB <= %g cm coverage (%%)', 100*e.target_peb_m));
    xlabel(ax, 'Acquisition slots K');
    title(ax, 'Solid: per-slot N; dashed: total M');
    rx_ieee_axes(ax, style);
end
end
