function h = rx_design_line(ax, x, y, index, style, line_style)
if nargin < 6
    line_style = '-';
end
color = style.colors(mod(index-1, size(style.colors, 1))+1, :);
marker = style.markers{mod(index-1, numel(style.markers))+1};
y(~isfinite(y)) = NaN;
indices = unique(round(linspace(1, numel(x), min(numel(x), style.marker_count))));
hold(ax, 'on');
h = plot(ax, x, y, 'LineStyle', line_style, 'Color', color, 'LineWidth', style.line_width, ...
    'Marker', marker, 'MarkerSize', style.marker_size, 'MarkerIndices', indices);
end
