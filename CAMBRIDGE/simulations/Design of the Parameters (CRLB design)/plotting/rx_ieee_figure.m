function fig = rx_ieee_figure(name, style, height_inches)
if ~isempty(style.height_inches)
    height_inches = style.height_inches;
end
fig = figure('Color', 'white', 'Units', 'inches', ...
    'Position', [0.5 0.5 style.width_inches height_inches], 'Visible', style.visible, ...
    'Name', name, 'NumberTitle', 'off');
fig.UserData = struct('export_name', name, 'plot_style', style);
end
