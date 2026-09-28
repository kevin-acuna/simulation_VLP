function figures = plot_K5_target_design(r, style, part)
if nargin<3, part='all'; end
assert(any(strcmp(part,{'all','maps'})), 'cambridge:TargetPlotPart', 'Choose all or maps.');
e = r.spec;
sigma_label='\sigma_{orient}';
if isfield(e,'orientation_structure') && strcmp(e.orientation_structure,'common_rotation')
    sigma_label='\sigma_{attitude}';
end
dense = r.grid_results{2};
coarse = r.grid_results{1};
sigmas = r.orientation_std_values_deg;
ns = numel(sigmas);
figures=gobjects(1,0);
if strcmp(part,'all')
figures = rx_ieee_figure('Target_tilt_coverage', style, 3.9);
layout = tiledlayout(figures(1), 1, ns, 'TileSpacing', 'compact', 'Padding', 'loose');
for is = 1:ns
    ax = nexttile(layout); hold(ax, 'on');
    a = rx_design_line(ax, e.tilt_values_deg, 100*dense.coverage(:, is), is, style);
    b = plot(ax, e.tilt_values_deg, 100*coarse.coverage(:, is), ':', 'Color', style.colors(is, :), 'LineWidth', 1);
    c = plot(ax, e.tilt_values_deg, 100*dense.regular_coverage(:, is), '--', 'Color', [.4 .4 .4], 'LineWidth', 1);
    yline(ax, e.minimum_coverage_percent, 'k:', 'HandleVisibility', 'off');
    selected = dense.selections{is};
    if isfinite(selected.optimal_tilt_deg)
        plot(ax, selected.optimal_tilt_deg, 100*selected.maximum_coverage, 'kp', 'MarkerSize', 10, 'MarkerFaceColor', 'w', 'HandleVisibility', 'off');
        index = find(e.tilt_values_deg==selected.minimum_near_peak_tilt_deg, 1);
        plot(ax, selected.minimum_near_peak_tilt_deg, 100*dense.coverage(index, is), 'ko', 'MarkerSize', 6, 'HandleVisibility', 'off');
    end
    xlabel(ax, 'Common PD inclination (deg)');
    ylabel(ax, 'Fraction of all grid positions (%)');
    title(ax, sprintf('%s = %g deg/component', sigma_label, sigmas(is)));
    legend(ax, [a b c], {sprintf('PEB <= %g cm: validation', rx_coverage_threshold(r.parameters)), ...
        'PEB threshold: design grid', 'Finite regular PEB: validation'}, 'Location', 'south', 'Box', 'off');
    xlim(ax, [0 min(max(e.tilt_values_deg), max(e.plot_max_tilt_deg, selected.optimal_tilt_deg+2))]);
    ylim(ax, [0 103]); rx_ieee_axes(ax, style);
end
figures(2) = rx_ieee_figure('Minimum_tilt_for_coverage', style, 3.4);
ax = axes(figures(2)); hold(ax, 'on');
labels = cell(1, ns);
for is = 1:ns
    peak = 100*dense.selections{is}.maximum_coverage;
    fractions = unique([50:0.5:100 peak]);
    minimum = nan(size(fractions));
    for i = 1:numel(fractions)
        eligible = find(100*dense.coverage(:, is)>=fractions(i)-1e-10, 1);
        if ~isempty(eligible)
            minimum(i) = e.tilt_values_deg(eligible);
        end
    end
    rx_design_line(ax, fractions, minimum, is, style);
    labels{is} = sprintf('sigma = %g deg; peak %.2f%%', sigmas(is), peak);
end
xline(ax, e.minimum_coverage_percent, 'k:', 'HandleVisibility', 'off');
xlabel(ax, sprintf('Required coverage of PEB <= %g cm (%%)', rx_coverage_threshold(r.parameters)));
ylabel(ax, 'Minimum tested tilt (deg)');
legend(ax, labels, 'Location', 'northwest', 'Box', 'off');
title(ax, 'Missing segments mean the required coverage is unattainable in this sweep');
rx_ieee_axes(ax, style);
end
map_index=numel(figures)+1;
figures(map_index) = rx_ieee_figure('Selected_tilt_spatial_coverage', style, 2.3*ns+0.5);
layout = tiledlayout(figures(map_index), ns, numel(e.map_heights_m), 'TileSpacing', 'compact', 'Padding', 'loose');
colormap(figures(map_index), [.65 .65 .65; .95 .65 .25; .15 .62 .48; .15 .15 .15]);
for is = 1:ns
    tilt = dense.selections{is}.optimal_tilt_deg;
    index = find(e.tilt_values_deg==tilt, 1);
    for iz = 1:numel(e.map_heights_m)
        ax = nexttile(layout);
        if isempty(index)
            title(ax, 'No covered configuration'); axis(ax, 'off'); continue;
        end
        [~, height_index] = min(abs(dense.grid.z_m-e.map_heights_m(iz)));
        values = dense.peb_m(:, index, is);
        classes = zeros(size(values));
        classes(isfinite(values)) = 1;
        classes(isfinite(values) & values<=rx_coverage_threshold(r.parameters)/100) = 2;
        classes(isnan(values)) = 3;
        maps = reshape(classes, numel(dense.grid.x_m), numel(dense.grid.y_m), numel(dense.grid.z_m));
        imagesc(ax, dense.grid.x_m, dense.grid.y_m, maps(:, :, height_index)');
        set(ax, 'YDir', 'normal'); axis(ax, 'image'); clim(ax, [-0.5 3.5]);
        xlabel(ax, 'x (m)'); ylabel(ax, 'y (m)');
        title(ax, {sprintf('%s=%g deg/component', sigma_label, sigmas(is)), ...
            sprintf('tilt=%g deg; z=%g m', tilt, dense.grid.z_m(height_index))});
        rx_ieee_axes(ax, style);
    end
end
cb = colorbar(ax); cb.Layout.Tile = 'east'; cb.Ticks = 0:3;
cb.TickLabels = {'Rank deficient', 'Finite, above target', 'Meets target', 'Boundary excluded'};
cb.FontSize = style.font_size;
end
