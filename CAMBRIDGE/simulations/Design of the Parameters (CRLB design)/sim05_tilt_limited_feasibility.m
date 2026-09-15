addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = system_parameters();

experiment = struct();
experiment.tilt_deg = 3;
experiment.tilt_constraint = 'maximum';
experiment.half_angles_deg = unique([p.design.half_angles_deg, 75]);
experiment.fov_values_deg = [45 60 65 70 75 85];
experiment.K_values = [3 5 9 15 25 49 81 121];
experiment.area_values_mm2 = unique([25 50 p.receiver.area_m2*1e6 100 125 150]);
experiment.patterns = {'uniform_cone', 'golden_prefix', 'center_ring', 'two_rings'};
experiment.budgets = {'per_orientation', 'fixed_total'};
experiment.azimuth_offset_deg = 0;
experiment.target_peb_m = 0.02;
experiment.min_target_coverage = 0.95;
experiment.refine_selected = true;
experiment.refinement_tilt_steps_deg = [1 0.25];
experiment.refinement_azimuth_steps_deg = [10 2];
experiment.refinement_passes = 1;
experiment.validation_heights_m = [0 0.6 1.2];
experiment.map_step_m = 0.05;

style = ieee_plot_style();
style.font_size = 8;
style.width_inches = 7.16;

result = run_rx_experiment('tilt_feasibility', p, experiment);
figures = plot_tilt_feasibility(result, style);
rx_export_figures(figures, result.output_directory, style);
