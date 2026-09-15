function fig = plot_K_normalized_information(r, style)
e = r.spec;
[~, jf] = max(e.fov_values_deg);
reference = find(strcmp(e.patterns, 'uniform_cone'), 1);
has_uniform = ~isempty(reference);
if ~has_uniform
    reference = 1;
end
fig = rx_ieee_figure('K_normalized_information', style, 3.5);
layout = tiledlayout(fig, 1, numel(e.budgets), 'TileSpacing', 'compact', 'Padding', 'loose');
for ib = 1:numel(e.budgets)
    ax = nexttile(layout);
    first = find(e.K_values(:)>=3 & isfinite(r.axis_peb_m(:, reference, jf, ib)), 1);
    if isempty(first)
        title(ax, 'No finite 3D reference bound');
        continue;
    end
    handles = gobjects(1, numel(e.patterns)+has_uniform);
    for ip = 1:numel(e.patterns)
        values = r.axis_peb_m(:, ip, jf, ib)/r.axis_peb_m(first, reference, jf, ib);
        handles(ip) = rx_design_line(ax, e.K_values, values, ip, style);
    end
    labels = cell(size(handles));
    labels(1:numel(e.patterns)) = strrep(e.patterns, '_', ' ');
    if has_uniform
        if strcmp(e.budgets{ib}, 'per_orientation')
            theory = sqrt(e.K_values(first)./e.K_values);
            label = 'Ideal sqrt(K_0/K)';
        else
            theory = ones(size(e.K_values));
            label = 'Ideal constant budget';
        end
        theory(e.K_values<3) = NaN;
        handles(end) = plot(ax, e.K_values, theory, 'k--', 'LineWidth', 1.0);
        labels{end} = label;
    end
    set(ax, 'XScale', 'log', 'YScale', 'log');
    xlabel(ax, 'Acquisition slots K');
    ylabel(ax, sprintf('PEB / reference PEB at K_0=%d', e.K_values(first)));
    title(ax, strrep(e.budgets{ib}, '_', ' '));
    rx_ieee_axes(ax, style);
    legend(ax, handles, labels, 'Location', 'best', 'Box', 'off');
end
title(layout, sprintf('Common reference: %s; position [%g,%g,%g] m; ideal lines: full visibility', ...
    strrep(e.patterns{reference}, '_', ' '), e.reference_position_m), ...
    'FontName', style.font_name, 'FontSize', style.font_size, 'FontWeight', 'normal');
end
