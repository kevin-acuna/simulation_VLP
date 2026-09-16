function fig = plot_LED_calibration(r, style)
e = r.experiment;
fig = rx_ieee_figure('LED_pattern_calibration', style, 3.7);
layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'loose');
for calibrated = 0:1
    ax = nexttile(layout);
    hold(ax, 'on');
    for im = 1:numel(e.methods)
        values = cellfun(@(x) x.table.RMSE_success_cm(im), r.runs(:, calibrated+1));
        rx_design_line(ax, e.true_asymmetries, values, im, style);
    end
    peb = cellfun(@(x) 100*sqrt(mean(x.peb_m.^2)), r.runs(:, calibrated+1));
    plot(ax, e.true_asymmetries, peb, 'k--', 'LineWidth', 1.3);
    xlabel(ax, 'True LED angular asymmetry');
    ylabel(ax, '3D RMSE / matched PEB (cm)');
    if calibrated
        title(ax, 'Calibrated LED pattern');
    else
        title(ax, 'Assumed Lambertian LED');
    end
    legend(ax, [e.methods {'Matched 3D PEB'}], 'Location', 'best', 'Box', 'off');
    rx_ieee_axes(ax, style);
end
end
