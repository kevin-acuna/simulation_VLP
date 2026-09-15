function fig = plot_tilt_required_area(r, style)
e = r.spec;
nh = numel(e.half_angles_deg);
fig = rx_ieee_figure('Tilt_required_area_vs_K', style, 2.15*ceil(nh/2)+0.7);
layout = tiledlayout(fig, ceil(nh/2), min(2, nh), 'TileSpacing', 'compact', 'Padding', 'loose');
t = r.base_table;
for ih = 1:nh
    ax = nexttile(layout);
    handles = gobjects(1, numel(e.budgets));
    for ib = 1:numel(e.budgets)
        required = inf(size(e.K_values));
        for ik = 1:numel(e.K_values)
            rows = t.HalfAngle_deg==e.half_angles_deg(ih) & t.K==e.K_values(ik) & t.Budget==string(e.budgets{ib});
            required(ik) = min(t.RequiredArea_mm2(rows));
        end
        handles(ib) = rx_design_line(ax, e.K_values, required, ib, style);
    end
    set(ax, 'XScale', 'log', 'YScale', 'log');
    yline(ax, max(e.area_values_mm2), 'k--', 'Area cap', 'FontSize', style.font_size, 'LabelHorizontalAlignment', 'left');
    xlabel(ax, 'K');
    ylabel(ax, 'Minimum required A_{PD} (mm^2)');
    title(ax, sprintf('\\Phi_{1/2} = %g deg', e.half_angles_deg(ih)));
    rx_ieee_axes(ax, style);
    if ih==1
        lg = legend(ax, handles, strrep(e.budgets, '_', ' '), 'Box', 'off', 'NumColumns', 2);
        lg.Layout.Tile = 'north';
    end
end
title(layout, sprintf('Tilt %s %g deg; target %.2g cm; %.0f%% target coverage; separate y scales', ...
    e.tilt_constraint, e.tilt_deg, 100*e.target_peb_m, 100*e.min_target_coverage), ...
    'FontName', style.font_name, 'FontSize', style.font_size, 'FontWeight', 'normal');
end
