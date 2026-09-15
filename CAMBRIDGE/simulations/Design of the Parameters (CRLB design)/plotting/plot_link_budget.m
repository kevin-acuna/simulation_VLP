function figures = plot_link_budget(r, style)
if nargin < 2
    style = ieee_plot_style();
end
e = r.spec;
nc = numel(e.cases);
figures = rx_ieee_figure('Power_samples_required_budget', style, 3.6);
layout = tiledlayout(figures(1), 1, nc, 'TileSpacing', 'compact', 'Padding', 'loose');
for ic = 1:nc
    ax = nexttile(layout);
    handles = gobjects(1, numel(e.noise_std_scales));
    for is = 1:numel(e.noise_std_scales)
        required = r.required_N_at_reference_power(is, ic)*(r.parameters.transmitter.power_W./e.power_values_W).^2;
        handles(is) = rx_design_line(ax, e.power_values_W, required, is, style);
    end
    set(ax, 'XScale', 'log', 'YScale', 'log');
    yline(ax, max(e.sample_values), 'k--', 'N cap', 'FontSize', style.font_size);
    xlabel(ax, 'Transmitted optical power (W)');
    ylabel(ax, 'Required samples per orientation');
    title(ax, e.cases(ic).label);
    rx_ieee_axes(ax, style);
    if ic==1
        labels = arrayfun(@(x) sprintf('Noise std. x%g', x), e.noise_std_scales, 'UniformOutput', false);
        lg = legend(ax, handles, labels, 'NumColumns', 3, 'Box', 'off');
        lg.Layout.Tile = 'north';
    end
end
[~, is] = min(abs(e.noise_std_scales-1));
values = 100*r.rms_full_m(:, :, is, :);
finite = values(isfinite(values) & values>0);
limits = [0.1 10];
if ~isempty(finite)
    limits = [min(finite)*0.95, max(finite)*1.05];
end
figures(2) = rx_ieee_figure('Power_samples_PEB_map', style, 3.6);
layout = tiledlayout(figures(2), 1, nc, 'TileSpacing', 'compact', 'Padding', 'loose');
for ic = 1:nc
    ax = nexttile(layout);
    rx_discrete_map(ax, e.power_values_W, e.sample_values, r.rms_full_m(:, :, is, ic)'*100, limits, 'log', style);
    xlabel(ax, 'Optical power (W)');
    ylabel(ax, 'Samples per orientation');
    title(ax, e.cases(ic).label);
end
cb = colorbar(ax);
cb.Layout.Tile = 'east';
cb.Label.String = 'Full-domain RMS PEB (cm)';
cb.FontSize = style.font_size;
end
