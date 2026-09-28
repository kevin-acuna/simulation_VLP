function result = run_K5_target_experiment(p, e)
transcript = evalc('print_settings(p, e);');
fprintf('%s', transcript);
result = study_K5_tilt_coverage(p, e);
disp(result.selection_table);
disp(result.grid_agreement_table);
if e.run_monte_carlo
    result.monte_carlo = rx_K5_monte_carlo(result);
end
parent = fileparts(mfilename('fullpath'));
result.output_directory = fullfile(parent, 'results', ['K5_target_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))]);
assert(~isfolder(result.output_directory), 'cambridge:ExistingResults', 'Refusing to overwrite the study.');
mkdir(result.output_directory);
result.generated_at = char(datetime('now'));
result.matlab_version = version;
save(fullfile(result.output_directory, 'target_design_results.mat'), 'result', '-v7.3');
writetable(result.table, fullfile(result.output_directory, 'coverage_curves.csv'));
writetable(result.selection_table, fullfile(result.output_directory, 'selected_tilts.csv'));
writetable(result.grid_agreement_table, fullfile(result.output_directory, 'grid_agreement.csv'));
if isfield(result, 'monte_carlo')
    writetable(result.monte_carlo.table, fullfile(result.output_directory, 'monte_carlo_points.csv'));
end
fid = fopen(fullfile(result.output_directory, 'parameters.txt'), 'wt');
assert(fid>=0, 'cambridge:Manifest', 'Cannot write the manifest.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', transcript);
fprintf('Saved target-coverage study: %s\n', result.output_directory);
end

function print_settings(p, e)
fprintf('\nK=%d TARGET-COVERAGE TILT STUDY\n', e.K);
fprintf('m_R=%g; LED half-power=%g deg; FOV half-angle=%g deg (hard cutoff).\n', rx_receiver_order(p), p.transmitter.half_angle_power_deg, p.receiver.fov_deg);
fprintf('P_t=%g W; area=%g mm^2; LED=%s m; axis=%s; T_s=%g; gain=%g; R_p=%g A/W\n', ...
    p.transmitter.power_W, p.receiver.area_m2*1e6, mat2str(p.transmitter.position_m'), mat2str(p.transmitter.normal'), ...
    p.receiver.filter_transmission, p.receiver.optical_gain, p.receiver.responsivity_A_per_W);
fprintf('Noise=%g W^2/sample; budget=%s; actual counts=%s; total=%d\n', p.noise.variance_W2, e.budget, ...
    mat2str(rx_sample_counts(e.K, p, e.budget)'), sum(rx_sample_counts(e.K, p, e.budget)));
fprintf('Cones use uniform azimuths with fixed offset=%g deg; no position-dependent aiming.\n', e.azimuth_offset_deg);
fprintf('Tilt sweep=%s deg\n', mat2str(e.tilt_values_deg));
fprintf('Selected coverage: finite regular PEB <= %g cm; all grid points remain in denominator.\n', rx_coverage_threshold(p));
fprintf('Acceptable coverage=%g%%; near-peak loss=%g percentage points.\n', e.minimum_coverage_percent, e.near_peak_loss_pp);
fprintf('Pose-measurement uncertainty: sigma=%g deg PER COMPONENT, variance=%g deg^2, structure=%s.\n', ...
    e.orientation_std_deg, e.orientation_std_deg^2, e.orientation_structure);
fprintf('Bounds eliminate pose nuisance parameters; not an oracle perturbed-known-normal bound.\n');
fprintf('Design x=%s; y=%s; z=%s m\n', mat2str(p.environment.x_m), mat2str(p.environment.y_m), mat2str(p.environment.z_m));
fprintf('Validation x=%s; y=%s; z=%s m\n', mat2str(p.environment.validation_x_m), mat2str(p.environment.validation_y_m), mat2str(p.environment.validation_z_m));
fprintf('Every tilt is evaluated on both grids; no continuous-volume/global-codebook optimum is asserted.\n');
fprintf('MC=%d; trials=%d per fixed point; seed=%d; methods=%s\n', e.run_monte_carlo, e.mc_trials, e.seed, strjoin(e.methods, ', '));
fprintf('MC positions [m] are explicit, require full visibility, and do NOT estimate whole-room achieved coverage:\n');
disp(e.mc_positions_m);
end
