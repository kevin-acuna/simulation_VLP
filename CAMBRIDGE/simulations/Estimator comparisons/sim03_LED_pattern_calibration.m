addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();
p.receiver.m_R = 1;
p.environment.x_m = [-0.4 0 0.4];
p.environment.y_m = [-0.4 0 0.4];
p.environment.z_m = [0.2 0.8 1.4];

experiment = struct('methods', {{'LS', 'GLS', 'WLS', 'NLS'}}, 'trials', 200, ...
    'seed', 20260916, 'budget', 'per_orientation', 'solver', struct());
experiment.K = 9;
experiment.tilt_deg = 10;
experiment.true_asymmetries = [0 0.1 0.2 0.3];
experiment.assumed_half_angle_deg = p.transmitter.half_angle_power_deg;
style = ieee_plot_style();

result = study_LED_calibration(p, experiment);
result = rx_save_comparison(result, 'LED_calibration');
figures = plot_LED_calibration(result, style);
rx_export_figures(figures, result.output_directory, style);
disp(result.table);
