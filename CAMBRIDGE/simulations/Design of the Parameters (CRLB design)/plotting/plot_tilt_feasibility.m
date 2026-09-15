function figures = plot_tilt_feasibility(r, style)
if nargin < 2
    style = ieee_plot_style();
end
figures = [plot_tilt_required_area(r, style), plot_tilt_fov_K_map(r, style), ...
    plot_tilt_patterns(r, style), plot_tilt_tradeoffs(r, style)];
if ~isempty(r.selected)
    figures(end+1) = plot_PEB_heatmap(r.selected.heatmap, style, 'Tilt_selected_PEB_heatmap');
end
end
