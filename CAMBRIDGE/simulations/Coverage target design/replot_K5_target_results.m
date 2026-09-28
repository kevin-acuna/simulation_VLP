function [figures, output_directory] = replot_K5_target_results(mat_file, style)
cambridge_setup();
if nargin<2
    style = ieee_plot_style();
end
saved = load(mat_file, 'result');
source = dir(mat_file);
output_directory = fullfile(source.folder, ['figures_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))]);
assert(~isfolder(output_directory), 'cambridge:ExistingResults', 'Refusing to overwrite a rendering.');
mkdir(output_directory);
figures = plot_K5_target_design(saved.result, style);
rx_export_figures(figures, output_directory, style);
fprintf('Plot-only target design: %s\n', output_directory);
end
