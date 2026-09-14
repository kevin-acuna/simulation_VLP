function [figures, output_dir] = replot_experiment(mat_file, style, component)
cambridge_setup();
if nargin < 2
    style = ieee_plot_style();
end
if nargin < 3
    component = 'all';
end
assert(isfile(mat_file), 'cambridge:DatasetNotFound', 'Select an existing MAT dataset.');
saved = load(mat_file);
file_info = dir(mat_file);
parent = file_info.folder;
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
output_dir = fullfile(parent, ['replot_' stamp]);
assert(~isfolder(output_dir), 'cambridge:ExistingResults', 'Refusing to overwrite a rendering directory.');
if style.export
    mkdir(output_dir);
end
fprintf('Plot-only mode: %s\nNo channel, FIM, optimization or parameter sweep is executed.\n', mat_file);
if isfield(saved, 'result')
    r = saved.result;
    assert(strcmp(component, 'all') || strcmp(component, r.kind), ...
        'cambridge:ComponentMismatch', 'This dataset does not contain the requested experiment.');
elseif isfield(saved, 'results')
    if strcmp(component, 'all')
        figures = plot_parameter_design(saved.results, output_dir, style);
        return;
    end
    r = rx_study_from_design(saved.results, component);
else
    error('cambridge:DatasetFormat', 'Expected result (experiment) or results (complete design).');
end
plotters = struct('inclination', @plot_PEB_vs_inclination, 'K', @plot_PEB_vs_K, ...
    'area', @plot_PEB_vs_area, 'heatmap', @plot_PEB_heatmap);
plotter = plotters.(r.kind);
figures = plotter(r, style);
rx_export_figures(figures, output_dir, style);
end
