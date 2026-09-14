function rx_plot_coverage(ax, x, coverage, style)
hold(ax, 'on');
for i = 1:size(coverage, 2)
    color = style.colors(mod(i-1, size(style.colors, 1))+1, :);
    marker = style.markers{mod(i-1, numel(style.markers))+1};
    indices = unique(round(linspace(1, numel(x), min(style.marker_count, numel(x)))));
    plot(ax, x, 100*coverage(:, i), '-', 'Color', color, 'LineWidth', style.line_width, ...
        'Marker', marker, 'MarkerSize', style.marker_size, 'MarkerIndices', indices);
end
ylabel(ax, 'Regular 3D coverage (%)');
ylim(ax, [0 103]);
if numel(x)>1
    xlim(ax, [min(x), max(x)]);
end
rx_ieee_axes(ax, style);
end
