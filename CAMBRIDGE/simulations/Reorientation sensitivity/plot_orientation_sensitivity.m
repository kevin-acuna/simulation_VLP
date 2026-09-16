function figures = plot_orientation_sensitivity(r, style)
e = r.experiment;
nc = numel(e.cases);
figures = rx_ieee_figure(['Orientation_sensitivity_' e.mode '_' e.structure], style, 3.8);
layout = tiledlayout(figures(1), 1, nc, 'TileSpacing', 'compact', 'Padding', 'loose');
for ic = 1:nc
    ax = nexttile(layout);
    hold(ax, 'on');
    handles = gobjects(1, numel(e.methods)+2);
    for im = 1:numel(e.methods)
        values = cellfun(@(x) x.table.RMSE_success_cm(im), r.runs(:, ic));
        handles(im) = rx_design_line(ax, e.orientation_variances_deg2, values, im, style);
    end
    bound = cellfun(@(x) 100*sqrt(mean(x.peb_m.^2)), r.runs(:, ic));
    nominal = 100*sqrt(mean(r.runs{1, ic}.nominal_peb_m.^2));
    handles(end-1) = plot(ax, e.orientation_variances_deg2, bound, 'k-', 'LineWidth', 1.5);
    handles(end) = plot(ax, e.orientation_variances_deg2, nominal*ones(size(e.orientation_variances_deg2)), 'k--', 'LineWidth', 1.0);
    xlabel(ax, 'Orientation-error variance per component (deg^2)');
    ylabel(ax, '3D RMSE / PEB (cm)');
    title(ax, e.cases(ic).label);
    rx_ieee_axes(ax, style);
    if ic==1
        lg = legend(ax, handles, [e.methods {r.runs{1, ic}.bound_label, 'Perfect-pose PEB'}], 'NumColumns', 3, 'Box', 'off');
        lg.Layout.Tile = 'north';
    end
end
figures(2) = rx_ieee_figure(['Orientation_failures_' e.mode '_' e.structure], style, 3.5);
layout = tiledlayout(figures(2), 1, nc, 'TileSpacing', 'compact', 'Padding', 'loose');
for ic = 1:nc
    ax = nexttile(layout);
    hold(ax, 'on');
    for im = 1:numel(e.methods)
        values = cellfun(@(x) x.table.Failure_percent(im), r.runs(:, ic));
        rx_design_line(ax, e.orientation_variances_deg2, values, im, style);
    end
    masks = cellfun(@(x) 100*x.visibility_disagreement_fraction, r.runs(:, ic));
    plot(ax, e.orientation_variances_deg2, masks, 'k--', 'LineWidth', 1.2);
    xlabel(ax, 'Orientation-error variance (deg^2)');
    ylabel(ax, 'Fraction of trials (%)');
    ylim(ax, [0 max(1, 1.1*max([masks(:); cellfun(@(x) max(x.table.Failure_percent), r.runs(:, ic))]))]);
    title(ax, e.cases(ic).label);
    legend(ax, [e.methods {'Visibility disagreement'}], 'Location', 'best', 'Box', 'off');
    rx_ieee_axes(ax, style);
end
end
