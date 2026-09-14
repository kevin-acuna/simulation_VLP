function figures = plot_PEB_vs_inclination(r, style)
if nargin < 2
    style = ieee_plot_style();
end
e = r.spec;
figures = gobjects(1, numel(e.half_angles_deg));
for ih = 1:numel(e.half_angles_deg)
    figures(ih) = rx_ieee_figure(sprintf('PEB_vs_inclination_Phi%g', e.half_angles_deg(ih)), style, 4.15);
    layout = tiledlayout(figures(ih), 2, 1, 'TileSpacing', 'compact', 'Padding', 'loose');
    ax = nexttile(layout);
    handles = gobjects(1, numel(e.fov_values_deg));
    for jf = 1:numel(e.fov_values_deg)
        handles(jf) = rx_plot_bound(ax, e.tilt_values_deg, r.rms_conditional_m(:, jf, ih), ...
            r.rms_full_m(:, jf, ih), jf, style);
    end
    if numel(e.tilt_values_deg)>1
        xlim(ax, [min(e.tilt_values_deg), max(e.tilt_values_deg)]);
    end
    ylabel(ax, 'Spatial RMS PEB (cm)');
    labels = arrayfun(@(v) sprintf('\\Psi = %g deg', v), e.fov_values_deg, 'UniformOutput', false);
    lg = legend(ax, handles, labels, 'NumColumns', min(3, numel(labels)), 'Box', 'off');
    lg.Layout.Tile = 'north';
    if style.show_titles
        title(ax, sprintf('(a) \\Phi_{1/2} = %g deg, K = %d; solid: full grid, dotted: finite subset', e.half_angles_deg(ih), e.K));
    end
    rx_ieee_axes(ax, style, true);
    ax = nexttile(layout);
    rx_plot_coverage(ax, e.tilt_values_deg, r.coverage(:, :, ih), style);
    xlabel(ax, 'PD inclination from +z (deg)');
    if style.show_titles
        title(ax, '(b) Coverage on the same evaluation grid');
    end
end
end
