function fig = plot_PEB_heatmap(r, style, name)
if nargin < 2
    style = ieee_plot_style();
end
if nargin < 3
    name = 'PEB_heatmap';
end
e = r.spec;
nh = numel(e.heights_m);
nc = numel(e.cases);
columns = min(3, max(nh, ceil(sqrt(nh*nc))));
rows = ceil(nh*nc/columns);
fig = rx_ieee_figure(name, style, 2.7*rows+0.5);
layout = tiledlayout(fig, rows, columns, 'TileSpacing', 'compact', 'Padding', 'loose');
finite = 100*r.peb_m(isfinite(r.peb_m) & r.peb_m>0);
limits = style.color_limits_cm;
if isempty(limits)
    if isempty(finite)
        limits = [0.1 10];
    else
        limits = [min(finite), max(finite)];
        if limits(1)==limits(2)
            limits = limits.*[0.9 1.1];
        end
    end
end
for ic = 1:nc
    for iz = 1:nh
        ax = nexttile(layout);
        values = reshape(100*r.peb_m(:, iz, ic), numel(r.y_m), numel(r.x_m));
        image = imagesc(ax, r.x_m, r.y_m, values);
        image.AlphaData = isfinite(values);
        set(ax, 'YDir', 'normal', 'Color', [0.82 0.82 0.82], 'ColorScale', style.color_scale);
        axis(ax, 'equal');
        axis(ax, 'tight');
        clim(ax, limits);
        colormap(ax, parula(256));
        hold(ax, 'on');
        plot(ax, r.parameters.transmitter.position_m(1), r.parameters.transmitter.position_m(2), ...
            'wp', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
        xlabel(ax, 'x (m)');
        ylabel(ax, 'y (m)');
        if style.show_titles
            title(ax, {e.cases(ic).label, sprintf('z = %g m; K = %d; A_{PD} = %.3g mm^2', ...
                e.heights_m(iz), e.cases(ic).K, e.cases(ic).area_m2*1e6)});
        end
        rx_ieee_axes(ax, style);
        grid(ax, 'off');
    end
end
cb = colorbar(ax);
cb.Layout.Tile = 'east';
cb.Label.String = '3D PEB (cm)';
cb.FontName = style.font_name;
cb.FontSize = style.font_size;
if style.show_titles
    title(layout, 'Common color scale; gray: singular or nonregular; star: LED projection', ...
        'FontName', style.font_name, 'FontSize', style.font_size, 'FontWeight', 'normal');
end
end
