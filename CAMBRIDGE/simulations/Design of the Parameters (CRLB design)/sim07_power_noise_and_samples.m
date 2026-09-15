addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();

experiment = struct();
experiment.cases = rx_cone_cases(p, [45 60 75], 3, 9);
experiment.power_values_W = unique([0.1 0.2 0.4 p.transmitter.power_W 1]);
experiment.sample_values = [100 300 1000 3000 10000];
experiment.noise_std_scales = [0.5 1 2];
experiment.target_peb_m = 0.02;
experiment.min_target_coverage = 0.95;

style = ieee_plot_style();
style.font_size = 8;
style.width_inches = 7.16;

result = run_rx_experiment('link_budget', p, experiment);
figures = plot_link_budget(result, style);
rx_export_figures(figures, result.output_directory, style);
