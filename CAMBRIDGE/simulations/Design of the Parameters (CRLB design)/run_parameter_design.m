function results = run_parameter_design(p, output_dir)
assert(isfolder(output_dir), 'cambridge:OutputDirectory', 'Output directory must already exist.');
assert(p.design.reference_K>=3, 'cambridge:ReferenceK', 'Reference K must be at least three.');
started = tic;
results.parameters = p;
results.matlab_version = version;
results.generated_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
results.output_directory = output_dir;
[positions, results.position_grid] = rx_testbed(p);
[validation_positions, results.validation_grid] = rx_testbed(p, 'validation');
results.positions_m = positions;
e = struct('K', p.design.reference_K, 'half_angles_deg', p.design.half_angles_deg, ...
    'fov_values_deg', p.design.fov_values_deg, 'tilt_values_deg', p.design.tilt_values_deg, ...
    'azimuth_offset_deg', p.design.azimuth_offset_deg);
rx_print_experiment('inclination', p, e);
results.tilt = study_inclination(p, e);
nh = numel(e.half_angles_deg);
best_configurations = cell(1, nh);
cases = rx_cone_cases(p, e.half_angles_deg, zeros(1, nh), e.K);
for ih = 1:nh
    scores = results.tilt.rms_full_m(:, :, ih);
    [score, index] = min(scores(:));
    assert(isfinite(score), 'cambridge:NoFullCoverage', 'No fully covered cone at half-power angle %g deg.', e.half_angles_deg(ih));
    [it, jf] = ind2sub(size(scores), index);
    cases(ih).tilt_deg = e.tilt_values_deg(it);
    cases(ih).fov_deg = e.fov_values_deg(jf);
    cases(ih).normals = rx_cone_normals(e.K, cases(ih).tilt_deg, e.azimuth_offset_deg);
    best_configurations{ih} = struct('half_angle_deg', e.half_angles_deg(ih), 'fov_deg', cases(ih).fov_deg, ...
        'cone_tilt_deg', cases(ih).tilt_deg, 'reference_rms_m', score);
end
ke = struct('cases', cases, 'K_values', p.design.K_values, 'budgets', {{'per_orientation', 'fixed_total'}});
rx_print_experiment('K', p, ke);
results.K = study_K(p, ke);
results.K.budgets = ke.budgets;
for ih = 1:nh
    b = best_configurations{ih};
    curve = results.K.rms_full_m(:, ih, 1);
    [b.K_minimum_rms_m, index] = min(curve);
    assert(isfinite(b.K_minimum_rms_m), 'cambridge:NoFeasibleK', 'No fully covered K in the sweep.');
    b.K_minimum_peb = ke.K_values(index);
    eligible = curve<=(1+p.design.K_relative_tolerance)*b.K_minimum_rms_m;
    b.K_recommended = min(ke.K_values(eligible));
    [b.fixed_budget_minimum_rms_m, index] = min(results.K.rms_full_m(:, ih, 2));
    b.K_fixed_budget_minimum = ke.K_values(index);
    ph = rx_case_parameters(p, cases(ih));
    b.refinement = rx_refine_orientations(positions, ph, b.K_recommended, b.cone_tilt_deg);
    b.normals = b.refinement.normals;
    [b.peb_m, info] = rx_peb(positions, b.normals, ph);
    b.metrics = rx_design_metrics(b.peb_m);
    b.axis_bound_m = info.axis_bound_m;
    b.visible_count = info.visible_count;
    b.condition_fim = info.condition_fim;
    b.validation_peb_m = rx_peb(validation_positions, b.normals, ph);
    b.validation_metrics = rx_design_metrics(b.validation_peb_m);
    fprintf('Refined Phi=%g deg, K=%d: RMS %.4f cm; validation coverage %.3f%%.\n', ...
        b.half_angle_deg, b.K_recommended, b.metrics.rms_full_m*100, b.validation_metrics.coverage*100);
    best_configurations{ih} = b;
end
results.best = [best_configurations{:}];
ae = struct('cases', rx_cases_from_design(results), 'area_values_mm2', p.design.area_values_mm2);
rx_print_experiment('area', p, ae);
results.area = study_area(p, ae);
for ih = 1:nh
    [results.best(ih).area_minimum_rms_m, index] = min(results.area.rms_full_m(:, ih));
    results.best(ih).area_minimum_peb_mm2 = ae.area_values_mm2(index);
    eligible = results.area.rms_full_m(:, ih)<=p.design.target_rms_peb_m;
    results.best(ih).area_target_mm2 = NaN;
    if any(eligible)
        results.best(ih).area_target_mm2 = min(ae.area_values_mm2(eligible));
    end
end
[~, results.best_half_index] = min(arrayfun(@(b) b.metrics.rms_full_m, results.best));
results.heatmap = rx_design_heatmaps(results);
results.elapsed_seconds = toc(started);
results.summary = rx_design_summary(results);
rx_write_design_tables(results, output_dir);
save(fullfile(output_dir, 'design_results.mat'), 'results', '-v7.3');
if p.output.export_figures
    plot_parameter_design(results, output_dir);
end
disp(results.summary);
fprintf('All results saved in %s\n', output_dir);
end
