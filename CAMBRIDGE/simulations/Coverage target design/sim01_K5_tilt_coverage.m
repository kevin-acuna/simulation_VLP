addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();
p.receiver.m_R = 1.9;
p.design.coverage_threshold_cm = 10;

experiment = struct();
experiment.K = 5;
experiment.tilt_values_deg = 0:0.25:p.receiver.max_tilt_deg;
experiment.azimuth_offset_deg = 0;
experiment.budget = 'per_orientation';
experiment.orientation_std_deg = 1;
experiment.orientation_structure = 'independent';
experiment.minimum_coverage_percent = 95;
experiment.near_peak_loss_pp = 1;
experiment.plot_max_tilt_deg = 40;
experiment.map_heights_m = [0 0.7 1.4];
experiment.run_monte_carlo = true;
experiment.mc_trials = 300;
experiment.seed = 20260927;
experiment.mc_positions_m = [0 0.25 -0.25; 0 -0.15 0.15; 0.6 0.6 1.1];
experiment.methods = {'LS', 'GLS', 'WLS', 'NLS_joint', 'NLS_TCOM'};
style = ieee_plot_style();

result = run_K5_target_experiment(p, experiment);
figures = plot_K5_target_design(result, style);
rx_export_figures(figures, result.output_directory, style);
