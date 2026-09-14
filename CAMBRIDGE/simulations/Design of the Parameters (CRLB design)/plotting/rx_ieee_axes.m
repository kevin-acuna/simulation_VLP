function rx_ieee_axes(ax, style, is_peb)
if nargin < 3
    is_peb = false;
end
set(ax, 'FontName', style.font_name, 'FontSize', style.font_size, ...
    'LineWidth', 0.6, 'Box', 'on', 'TickDir', 'out', 'GridAlpha', 0.14, ...
    'XMinorGrid', 'off', 'YMinorGrid', 'off', 'Layer', 'top');
grid(ax, 'on');
ax.Title.FontWeight = 'normal';
ax.Title.FontSize = style.font_size;
ax.XLabel.FontSize = style.font_size;
ax.YLabel.FontSize = style.font_size;
if is_peb && isempty(style.peb_limits_cm)
    limits = ylim(ax);
    if strcmp(style.peb_scale, 'log')
        ylim(ax, limits.*[0.85 1.15]);
    else
        padding = 0.04*diff(limits);
        ylim(ax, [max(0, limits(1)-padding), limits(2)+padding]);
    end
end
if is_peb && strcmp(style.peb_scale, 'log')
    limits = ylim(ax);
    decades = ceil(log10(limits(1))):floor(log10(limits(2)));
    if numel(decades)>=2
        yticks(ax, 10.^decades);
    end
end
if ~isempty(style.x_limits)
    xlim(ax, style.x_limits);
end
end
