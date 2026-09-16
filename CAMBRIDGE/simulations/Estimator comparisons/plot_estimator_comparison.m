function figures = plot_estimator_comparison(r, style)
if nargin < 2
    style = ieee_plot_style();
end
methods = r.experiment.methods;
figures = rx_ieee_figure('Estimator_RMSE_vs_3D_PEB', style, 4.2);
layout = tiledlayout(figures(1), 2, 1, 'TileSpacing', 'compact', 'Padding', 'loose');
ax = nexttile(layout);
y = r.table.RMSE_success_cm;
bar(ax, 1:numel(methods), y, 0.55, 'FaceColor', 'flat', 'CData', style.colors(1:numel(methods), :));
hold(ax, 'on');
lo = r.table.MC_CI95_low_cm;
hi = r.table.MC_CI95_high_cm;
errorbar(ax, 1:numel(methods), y, y-lo, hi-y, 'k.', 'LineWidth', 0.8);
yline(ax, 100*sqrt(mean(r.peb_m.^2)), 'k--', 'Matched 3D PEB', 'FontSize', style.font_size);
xticks(ax, 1:numel(methods));
xticklabels(ax, methods);
ylabel(ax, 'RMSE of successful estimates (cm)');
title(ax, '95% Monte Carlo intervals; not positioning confidence regions');
rx_ieee_axes(ax, style);
ax = nexttile(layout);
bar(ax, 1:numel(methods), r.table.Failure_percent, 0.55);
xticks(ax, 1:numel(methods));
xticklabels(ax, methods);
ylabel(ax, 'Failed estimates (%)');
ylim(ax, [0 max(1, 1.15*max(r.table.Failure_percent))]);
rx_ieee_axes(ax, style);
figures(2) = rx_ieee_figure('Estimator_error_CDF', style, 3.5);
ax = axes(figures(2));
hold(ax, 'on');
for im = 1:numel(methods)
    [x, probability] = rx_empirical_cdf(100*r.errors_m(:, :, im));
    stairs(ax, x, probability, ...
        'Color', style.colors(im, :), 'LineWidth', style.line_width);
end
xlabel(ax, '3D position error (cm)');
ylabel(ax, 'Empirical CDF (all trials)');
ylim(ax, [0 1]);
legend(ax, methods, 'Location', 'southeast', 'Box', 'off');
title(ax, 'Failure mass is retained; PEB is not a pointwise error quantile');
rx_ieee_axes(ax, style);
figures(3) = rx_ieee_figure('Estimator_spatial_RMSE_CDF', style, 3.5);
ax = axes(figures(3));
hold(ax, 'on');
for im = 1:numel(methods)
    [x, probability] = rx_empirical_cdf(100*r.rmse_per_position_m(:, im));
    stairs(ax, x, probability, ...
        'Color', style.colors(im, :), 'LineWidth', style.line_width);
end
values = sort(r.peb_m(:))*100;
stairs(ax, [0; values], [0; (1:numel(values))'/numel(values)], 'k--', 'LineWidth', 1.3);
legend(ax, [methods {'3D PEB'}], 'Location', 'southeast', 'Box', 'off');
xlabel(ax, 'Per-position RMSE or PEB (cm)');
ylabel(ax, 'Fraction of evaluation positions');
ylim(ax, [0 1]);
title(ax, 'Spatial distributions on the same ROI');
rx_ieee_axes(ax, style);
end
