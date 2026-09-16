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
experiment.m_R_values = [0.5 1 2 3];
experiment.noise_std_scales = [1 10];
style = ieee_plot_style();

result = study_estimator_orders(p, experiment);
result = rx_save_comparison(result, 'receiver_order');
figures = plot_estimator_orders(result, style);
rx_export_figures(figures, result.output_directory, style);
disp(result.table);
