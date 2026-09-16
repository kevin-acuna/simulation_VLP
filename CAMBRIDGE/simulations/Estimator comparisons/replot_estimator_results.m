function [figures, output_dir] = replot_estimator_results(mat_file, style)
cambridge_setup();
if nargin<2
    style = ieee_plot_style();
end
saved = load(mat_file, 'result');
r = saved.result;
file = dir(mat_file);
output_dir = fullfile(file.folder, ['figures_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))]);
assert(~isfolder(output_dir), 'cambridge:ExistingResults', 'Refusing to overwrite a rendering.');
mkdir(output_dir);
if isfield(r, 'errors_m')
    figures = plot_estimator_comparison(r, style);
elseif isfield(r.experiment, 'm_R_values')
    figures = plot_estimator_orders(r, style);
elseif isfield(r.experiment, 'true_asymmetries')
    figures = plot_LED_calibration(r, style);
else
    error('cambridge:ComparisonFormat', 'Unknown estimator comparison dataset.');
end
rx_export_figures(figures, output_dir, style);
fprintf('Plot-only output: %s\n', output_dir);
end
