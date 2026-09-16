addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();
p.receiver.m_R = 1;

p.transmitter.power_W = 0.65;
p.receiver.fov_deg = 46;
p.receiver.area_m2 = 75.4e-6;
p.acquisition.samples_per_orientation = 1000;
p.noise.variance_W2 = 3e-14;
fixed_K = 8;
fixed_tilt_deg = 10;
half_angles_deg = 45;

experiment = struct();
experiment.cases = rx_cone_cases(p, half_angles_deg, fixed_tilt_deg, fixed_K);
experiment.heights_m = [0 0.6 1.2];
experiment.grid_step_m = 0.05;

style = ieee_plot_style();
style.width_inches = 7.16;
style.font_size = 8;
style.color_scale = 'log';
style.color_limits_cm = [];
style.visible = 'on';
style.keep_open = true;
style.export = true;

result = run_rx_experiment('heatmap', p, experiment);
figures = plot_PEB_heatmap(result, style);
rx_export_figures(figures, result.output_directory, style);
