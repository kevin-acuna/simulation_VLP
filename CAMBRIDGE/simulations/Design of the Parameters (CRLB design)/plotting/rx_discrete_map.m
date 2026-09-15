function rx_discrete_map(ax, x, y, values, limits, scale, style)
image = imagesc(ax, 1:numel(x), 1:numel(y), values);
valid = isfinite(values);
if strcmp(scale, 'log')
    valid = valid & values>0;
end
image.AlphaData = valid;
set(ax, 'YDir', 'normal', 'Color', [0.84 0.84 0.84], 'ColorScale', scale, ...
    'XTick', 1:numel(x), 'XTickLabel', compose('%g', x), ...
    'YTick', 1:numel(y), 'YTickLabel', compose('%g', y));
clim(ax, limits);
colormap(ax, parula(256));
rx_ieee_axes(ax, style);
grid(ax, 'off');
end
