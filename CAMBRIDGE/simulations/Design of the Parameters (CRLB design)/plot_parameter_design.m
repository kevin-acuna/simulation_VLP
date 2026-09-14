function figures = plot_parameter_design(r, output_dir, style)
if nargin < 3
    style = ieee_plot_style();
    style.visible = r.parameters.output.visible;
    style.keep_open = strcmp(style.visible, 'on');
end
figures = plot_PEB_vs_inclination(rx_study_from_design(r, 'inclination'), style);
figures(end+1) = plot_PEB_vs_K(rx_study_from_design(r, 'K'), style);
figures(end+1) = plot_PEB_vs_area(rx_study_from_design(r, 'area'), style);
figures(end+1) = plot_PEB_heatmap(rx_study_from_design(r, 'heatmap'), style, 'PEB_heatmap_best_configurations');
figures(end+1) = plot_PEB_heatmap(rx_study_from_design(r, 'heatmap_best'), style, 'PEB_heatmap_best_heights_and_area');
rx_export_figures(figures, output_dir, style);
end
