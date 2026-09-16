addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();
p.receiver.m_R = 1;
p.environment.x_m = [-0.3 0 0.3];
p.environment.y_m = [-0.3 0 0.3];
p.environment.z_m = [0.5 1.1];

experiment = struct('methods', {{'LS', 'GLS', 'WLS', 'NLS'}}, 'trials', 150, ...
    'seed', 20260916, 'budget', 'per_orientation', 'solver', struct());
experiment.mode = 'pose_measurement';
experiment.structure = 'independent';
experiment.orientation_variances_deg2 = [0 0.0025 0.01 0.04 0.16 0.49 1];
experiment.cases = rx_cone_cases(p, [45 45], [3 10], 9);
experiment.cases(1).label = 'Nominal tilt = 3 deg';
experiment.cases(2).label = 'Nominal tilt = 10 deg';
style = ieee_plot_style();

result = study_orientation_sensitivity(p, experiment);
figures = plot_orientation_sensitivity(result, style);
rx_export_figures(figures, result.output_directory, style);
