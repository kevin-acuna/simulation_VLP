function fig = plot_PEB_vs_K(r, style)
if nargin < 2
    style = ieee_plot_style();
end
e = r.spec;
nb = numel(e.budgets);
fig = rx_ieee_figure('PEB_vs_K', style, 1.7*(nb+1)+0.5);
layout = tiledlayout(fig, nb+1, 1, 'TileSpacing', 'compact', 'Padding', 'loose');
for ib = 1:nb
    ax = nexttile(layout);
    handles = gobjects(1, numel(e.cases));
    for ic = 1:numel(e.cases)
        handles(ic) = rx_plot_bound(ax, e.K_values, r.rms_conditional_m(:, ic, ib), r.rms_full_m(:, ic, ib), ic, style);
    end
    if numel(e.K_values)>1
        xlim(ax, [min(e.K_values), max(e.K_values)]);
    end
    ylabel(ax, 'Spatial RMS PEB (cm)');
    if ib==1
        lg = legend(ax, handles, {e.cases.label}, 'NumColumns', min(2, numel(e.cases)), 'Box', 'off');
        lg.Layout.Tile = 'north';
    end
    if style.show_titles
        if strcmp(e.budgets{ib}, 'fixed_total')
            title(ax, sprintf('(%c) Fixed total: M = %d samples', 'a'+ib-1, r.parameters.acquisition.total_samples));
        else
            title(ax, sprintf('(%c) Fixed N_i = %d samples per orientation', 'a'+ib-1, r.parameters.acquisition.samples_per_orientation));
        end
    end
    rx_ieee_axes(ax, style, true);
end
ax = nexttile(layout);
rx_plot_coverage(ax, e.K_values, r.coverage(:, :, 1), style);
xticks(ax, e.K_values);
xlabel(ax, 'Number of orientations, K');
if style.show_titles
    title(ax, sprintf('(%c) Fixed cone tilts; solid PEB: full grid, dotted PEB: finite subset', 'a'+nb));
end
end
