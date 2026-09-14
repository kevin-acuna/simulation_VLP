function fig = plot_PEB_vs_area(r, style)
if nargin < 2
    style = ieee_plot_style();
end
e = r.spec;
fig = rx_ieee_figure('PEB_vs_A_PD', style, 4.15);
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'loose');
ax = nexttile(layout);
handles = gobjects(1, numel(e.cases));
for ic = 1:numel(e.cases)
    handles(ic) = rx_plot_bound(ax, e.area_values_mm2, r.rms_conditional_m(:, ic), r.rms_full_m(:, ic), ic, style);
end
set(ax, 'XScale', 'log');
if numel(e.area_values_mm2)>1
    xlim(ax, [min(e.area_values_mm2), max(e.area_values_mm2)]);
end
ylabel(ax, 'Spatial RMS PEB (cm)');
lg = legend(ax, handles, {e.cases.label}, 'NumColumns', min(2, numel(e.cases)), 'Box', 'off');
lg.Layout.Tile = 'north';
yline(ax, 100*r.parameters.design.target_rms_peb_m, '--', 'Target', ...
    'Color', [0.3 0.3 0.3], 'LabelHorizontalAlignment', 'left', 'FontSize', style.font_size);
if style.show_titles
    title(ax, '(a) Frozen orientations and noise; PEB proportional to 1/A_{PD}');
end
rx_ieee_axes(ax, style, true);
ax = nexttile(layout);
rx_plot_coverage(ax, e.area_values_mm2, r.coverage, style);
set(ax, 'XScale', 'log');
xlabel(ax, 'Photodiode area, A_{PD} (mm^2)');
if style.show_titles
    title(ax, '(b) Coverage; solid PEB: full grid, dotted PEB: finite subset');
end
end
