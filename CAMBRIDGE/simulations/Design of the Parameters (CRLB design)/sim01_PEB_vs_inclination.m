clc, close all
addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();
p.receiver.m_R = 1;

p.transmitter.power_W = 0.65;
p.receiver.area_m2 = 75.4e-6;
p.acquisition.samples_per_orientation = 1000;
p.noise.variance_W2 = 3e-14;

experiment = struct();
experiment.K = 8;
experiment.half_angles_deg = 45; %[30 45 60];
experiment.fov_values_deg = 46; %[45 60 75 85]
experiment.tilt_values_deg = 0:1:85;
experiment.azimuth_offset_deg = 0;

style = ieee_plot_style();
style.width_inches = 7.16;
style.font_size = 8;
style.visible = 'on';
style.keep_open = true;
style.export = true;

result = run_rx_experiment('inclination', p, experiment);
figures = plot_PEB_vs_inclination(result, style);
rx_export_figures(figures, result.output_directory, style);
