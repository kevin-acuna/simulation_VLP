addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();
p.receiver.m_R = 1;

experiment = struct();
experiment.tilt_deg = 30;
experiment.half_angle_deg = 60;
experiment.fov_values_deg = [45 60 85];
experiment.K_values = 1:30;
experiment.patterns = {'uniform_cone', 'golden_prefix', 'repeat_triplet'};
experiment.budgets = {'per_orientation', 'fixed_total'};
experiment.reference_position_m = [0; 0; 0.6];
experiment.azimuth_offset_deg = 0;
experiment.target_peb_m = 0.02;

style = ieee_plot_style();
style.font_size = 8;
style.width_inches = 7.16;

result = run_rx_experiment('K_information', p, experiment);
figures = plot_K_information(result, style);
rx_export_figures(figures, result.output_directory, style);
