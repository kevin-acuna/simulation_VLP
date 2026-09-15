clc, close all
addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();

p.transmitter.power_W = 0.65;
p.receiver.fov_deg = 85;
p.receiver.area_m2 = 75.4e-6;
p.acquisition.samples_per_orientation = 1000;
p.acquisition.total_samples = 9000;
p.noise.variance_W2 = 3e-14;
fixed_tilt_deg = 3;
half_angles_deg = [30 45 60];

experiment = struct();
experiment.cases = rx_cone_cases(p, half_angles_deg, fixed_tilt_deg, 9);
experiment.K_values = 1:30;
experiment.budgets = {'per_orientation'}; %, 'fixed_total'

style = ieee_plot_style();
style.width_inches = 7.16;
style.font_size = 8;
style.visible = 'on';
style.keep_open = true;
style.export = true;

result = run_rx_experiment('K', p, experiment);
figures = plot_PEB_vs_K(result, style);
rx_export_figures(figures, result.output_directory, style);
