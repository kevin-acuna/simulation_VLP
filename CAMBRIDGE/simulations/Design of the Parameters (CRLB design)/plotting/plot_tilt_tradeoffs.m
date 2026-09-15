function fig = plot_tilt_tradeoffs(r, style)
fig = rx_ieee_figure('Tilt_feasible_tradeoffs', style, 3.5);
ax = axes(fig);
t = r.extra_tables.feasible_tradeoffs;
if isempty(t)
    title(ax, 'No tested configuration meets both error and coverage requirements');
    return;
end
rx_design_line(ax, t.TotalSamples, t.Area_mm2, 1, style);
for i = 1:height(t)
    text(ax, t.TotalSamples(i), t.Area_mm2(i), sprintf('  K=%d; RMS=%.3g cm', t.K(i), t.RMS_full_cm(i)), ...
        'FontName', style.font_name, 'FontSize', style.font_size, 'VerticalAlignment', 'bottom');
end
set(ax, 'XScale', 'log');
xlim(ax, [min(t.TotalSamples)*0.8, max(t.TotalSamples)*1.5]);
ylim(ax, [min(t.Area_mm2)*0.8, max(t.Area_mm2)*1.2]);
xlabel(ax, 'Total independent RSS samples per scan');
ylabel(ax, 'PD area (mm^2)');
title(ax, sprintf('Feasible resource tradeoffs: tilt <= %g deg, RMS <= %g cm, target coverage >= %.0f%%', ...
    r.spec.tilt_deg, 100*r.spec.target_peb_m, 100*r.spec.min_target_coverage));
rx_ieee_axes(ax, style);
end
