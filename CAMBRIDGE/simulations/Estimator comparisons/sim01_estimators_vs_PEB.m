addpath(fileparts(mfilename('fullpath')));
addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();
p.receiver.m_R = 1;
p.environment.x_m = -0.4:0.2:0.4;
p.environment.y_m = -0.4:0.2:0.4;
p.environment.z_m = [0.2 0.8 1.4];

experiment = struct('methods', {{'LS', 'GLS', 'WLS', 'NLS'}}, 'trials', 500, ...
    'seed', 20260916, 'budget', 'per_orientation', 'solver', struct());
K = 9;
tilt_deg = 10;
normals = rx_cone_normals(K, tilt_deg);
style = ieee_plot_style();

rx_print_comparison(p, normals, experiment);
result = rx_monte_carlo(p, p, normals, experiment);
result = rx_save_comparison(result, 'baseline');
figures = plot_estimator_comparison(result, style);
rx_export_figures(figures, result.output_directory, style);
disp(result.table);
