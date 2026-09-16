clc, close all
addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();
p.receiver.m_R = 1;

experiment = struct();
experiment.tilt_values_deg = [0 0.5 1 2 3 5 10 20 30 40];
experiment.fov_values_deg = [30 45 60 65 70 75 85];
experiment.K = 3;
experiment.half_angle_deg = 60;
experiment.azimuth_offset_deg = 0;
experiment.target_peb_m = 0.05; %No se usa!!

style = ieee_plot_style();
style.font_size = 8;
style.width_inches = 7.16;

result = run_rx_experiment('coverage_geometry', p, experiment);
figures = plot_coverage_geometry(result, style);
rx_export_figures(figures, result.output_directory, style);
