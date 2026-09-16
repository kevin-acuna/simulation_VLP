function fig = plot_estimator_orders(r, style)
e = r.experiment;
fig = rx_ieee_figure('Estimators_vs_receiver_order', style, 3.7);
layout = tiledlayout(fig, 1, numel(e.noise_std_scales), 'TileSpacing', 'compact', 'Padding', 'loose');
for is = 1:numel(e.noise_std_scales)
    ax = nexttile(layout);
    hold(ax, 'on');
    for im = 1:numel(e.methods)
        values = cellfun(@(x) x.table.RMSE_success_cm(im), r.runs(:, is));
        rx_design_line(ax, e.m_R_values, values, im, style);
    end
    peb = cellfun(@(x) 100*sqrt(mean(x.peb_m.^2)), r.runs(:, is));
    plot(ax, e.m_R_values, peb, 'k--', 'LineWidth', 1.3);
    xlabel(ax, 'Receiver angular order m_R');
    ylabel(ax, '3D RMSE / PEB (cm)');
    title(ax, sprintf('Noise standard deviation x%g', e.noise_std_scales(is)));
    legend(ax, [e.methods {'3D PEB'}], 'Location', 'best', 'Box', 'off');
    rx_ieee_axes(ax, style);
end
end
