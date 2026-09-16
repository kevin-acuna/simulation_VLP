clc, close all
addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();
p.receiver.m_R = 1;

p.transmitter.power_W = 0.65;
p.receiver.fov_deg = 85;
p.acquisition.samples_per_orientation = 1000;
p.noise.variance_W2 = 3e-14;
p.design.target_rms_peb_m = 0.02;
fixed_K = 9;
fixed_tilt_deg = 10;
half_angles_deg = [30 45 60];

experiment = struct();
experiment.cases = rx_cone_cases(p, half_angles_deg, fixed_tilt_deg, fixed_K);
experiment.area_values_mm2 = unique([logspace(log10(5), log10(100), 41), 26.4]);

style = ieee_plot_style();
style.width_inches = 7.16;
style.font_size = 8;
style.visible = 'on';
style.keep_open = true;
style.export = true;

result = run_rx_experiment('area', p, experiment);
figures = plot_PEB_vs_area(result, style);
rx_export_figures(figures, result.output_directory, style);
