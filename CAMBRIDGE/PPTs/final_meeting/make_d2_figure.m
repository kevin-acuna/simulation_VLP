function make_d2_figure()
% D2 of the TIM paper (regular grid): 5 x 5 positions at five PD heights, K = 10 orientations each.
% Same axes and view as the 3-D panel of the paper's blind-test figure. Writes assets/d2_grid.png.
% Run from this folder: matlab -batch "make_d2_figure"

% ---- hyperparameters -----------------------------------------------------------------------------
xy = 0.1:0.3:1.3;                               % gantry X, Y of the grid (m)
heights = [0.955 1.015 1.075 1.135 1.315];      % PD heights (m), Table II of the paper
out = fullfile(fileparts(mfilename('fullpath')), 'assets', 'd2_grid.png');
% --------------------------------------------------------------------------------------------------

[X, Y, Z] = ndgrid(xy, xy, heights);
fig = figure('Units', 'centimeters', 'Position', [2 2 11 8.5], 'Color', 'w');
if exist('theme', 'file')
    theme(fig, 'light');
end
ax = axes(fig);
hold(ax, 'on');
scatter3(ax, X(:), Y(:), Z(:), 22, Z(:), 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.4);
colormap(ax, parula(256));
clim(ax, [0.9 1.35]);
xlim(ax, [0 1.4]); ylim(ax, [0 1.4]); zlim(ax, [0.9 1.4]);
set(ax, 'TickLabelInterpreter', 'latex', 'FontSize', 10);
xlabel(ax, '$X$ (m)', 'Interpreter', 'latex');
ylabel(ax, '$Y$ (m)', 'Interpreter', 'latex');
zlabel(ax, '$Z$ (m)', 'Interpreter', 'latex');
view(ax, -50, 22);
daspect(ax, [1 1 0.6]);
grid(ax, 'on');
exportgraphics(fig, out, 'Resolution', 300, 'BackgroundColor', 'white');
fprintf('%s\n', out);
end
