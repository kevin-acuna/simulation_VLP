function [figures, output_dir] = replot_sensitivity_results(mat_file, style)
cambridge_setup();
if nargin<2
    style = ieee_plot_style();
end
saved = load(mat_file, 'result');
file = dir(mat_file);
output_dir = fullfile(file.folder, ['figures_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))]);
assert(~isfolder(output_dir), 'cambridge:ExistingResults', 'Refusing to overwrite a rendering.');
mkdir(output_dir);
figures = plot_orientation_sensitivity(saved.result, style);
rx_export_figures(figures, output_dir, style);
fprintf('Plot-only sensitivity output: %s\n', output_dir);
end
