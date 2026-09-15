function fig = plot_K_PEB_mechanisms(r, style)
e = r.spec;
[~, jf] = max(e.fov_values_deg);
fig = rx_ieee_figure('K_PEB_mechanisms', style, 3.6);
layout = tiledlayout(fig, 1, numel(e.budgets), 'TileSpacing', 'compact', 'Padding', 'loose');
for ib = 1:numel(e.budgets)
    ax = nexttile(layout);
    handles = gobjects(1, numel(e.patterns));
    for ip = 1:numel(e.patterns)
        handles(ip) = rx_plot_bound(ax, e.K_values, r.rms_conditional_m(:, ip, jf, ib), r.rms_full_m(:, ip, jf, ib), ip, style);
    end
    xlabel(ax, 'Acquisition slots K');
    ylabel(ax, 'Spatial RMS PEB (cm)');
    title(ax, strrep(e.budgets{ib}, '_', ' '));
    rx_ieee_axes(ax, style, true);
    if ib==1
        lg = legend(ax, handles, strrep(e.patterns, '_', ' '), 'Box', 'off', 'NumColumns', 3);
        lg.Layout.Tile = 'north';
    end
end
title(layout, sprintf('Tilt=%g deg, FOV=%g deg; solid: full domain, dotted: finite subset', e.tilt_deg, e.fov_values_deg(jf)), ...
    'FontName', style.font_name, 'FontSize', style.font_size, 'FontWeight', 'normal');
end
