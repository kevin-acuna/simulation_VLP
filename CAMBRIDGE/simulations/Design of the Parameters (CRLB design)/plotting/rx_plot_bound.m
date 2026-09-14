function handle = rx_plot_bound(ax, x, conditional_m, full_m, index, style)
color = style.colors(mod(index-1, size(style.colors, 1))+1, :);
marker = style.markers{mod(index-1, numel(style.markers))+1};
conditional = 100*conditional_m(:);
full = 100*full_m(:);
conditional(~isfinite(conditional)) = NaN;
full(~isfinite(full)) = NaN;
indices = unique(round(linspace(1, numel(x), min(style.marker_count, numel(x)))));
hold(ax, 'on');
if style.show_conditional
    plot(ax, x, conditional, ':', 'Color', color, 'LineWidth', style.line_width, ...
        'Marker', marker, 'MarkerSize', style.marker_size, 'MarkerIndices', indices, 'HandleVisibility', 'off');
end
handle = plot(ax, x, full, '-', 'Color', color, 'LineWidth', style.line_width, ...
    'Marker', marker, 'MarkerSize', style.marker_size, 'MarkerIndices', indices);
set(ax, 'YScale', style.peb_scale);
if ~isempty(style.peb_limits_cm)
    ylim(ax, style.peb_limits_cm);
end
end
