function results = run_parameter_design(p, output_dir)
assert(isfolder(output_dir), 'cambridge:OutputDirectory', 'Output directory must already exist.');
assert(all(p.design.tilt_values_deg<=p.receiver.max_tilt_deg), 'cambridge:TiltLimit', 'Tilt sweep exceeds the receiver limit.');
assert(all(p.design.K_values>=1 & p.design.K_values==round(p.design.K_values)), 'cambridge:KValues', 'K must be positive integer.');
assert(p.design.reference_K>=3, 'cambridge:ReferenceK', 'Reference K must be at least three.');
[positions, grid] = rx_testbed(p);
[validation_positions, validation_grid] = rx_testbed(p, 'validation');
half_angles = p.design.half_angles_deg;
fovs = p.design.fov_values_deg;
tilts = p.design.tilt_values_deg;
Ks = p.design.K_values;
areas = p.design.area_values_mm2;
nh = numel(half_angles);
nf = numel(fovs);
nt = numel(tilts);
nk = numel(Ks);
np = size(positions, 2);
results.parameters = p;
results.matlab_version = version;
results.generated_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
results.output_directory = output_dir;
results.position_grid = grid;
results.positions_m = positions;
results.validation_grid = validation_grid;
results.tilt.peb_m = nan(np, nt, nf, nh);
results.tilt.rms_full_m = inf(nt, nf, nh);
results.tilt.rms_conditional_m = nan(nt, nf, nh);
results.tilt.coverage = zeros(nt, nf, nh);
results.tilt.nonregular_fraction = zeros(nt, nf, nh);
results.K.peb_m = nan(np, nk, nh, 2);
results.K.rms_full_m = inf(nk, nh, 2);
results.K.rms_conditional_m = nan(nk, nh, 2);
results.K.coverage = zeros(nk, nh, 2);
results.K.sample_counts = cell(nk, 2);
results.K.budgets = {'per_orientation', 'fixed_total'};
results.K.normals = cell(nk, nh);
results.area.rms_full_m = inf(numel(areas), nh);
results.area.coverage = zeros(numel(areas), nh);
best_configurations = cell(1, nh);
started = tic;
fprintf('Design grid: %d positions. Validation grid: %d positions.\n', np, size(validation_positions, 2));
for ih = 1:nh
    ph = p;
    ph.transmitter.half_angle_power_deg = half_angles(ih);
    fprintf('Half-power angle %g deg: inclination and FOV sweep.\n', half_angles(ih));
    for jf = 1:nf
        ph.receiver.fov_deg = fovs(jf);
        for it = 1:nt
            normals = rx_cone_normals(p.design.reference_K, tilts(it), p.design.azimuth_offset_deg);
            peb = rx_peb(positions, normals, ph);
            metrics = rx_design_metrics(peb);
            results.tilt.peb_m(:, it, jf, ih) = peb(:);
            results.tilt.rms_full_m(it, jf, ih) = metrics.rms_full_m;
            results.tilt.rms_conditional_m(it, jf, ih) = metrics.rms_conditional_m;
            results.tilt.coverage(it, jf, ih) = metrics.coverage;
            results.tilt.nonregular_fraction(it, jf, ih) = metrics.nonregular_fraction;
        end
    end
    scores = results.tilt.rms_full_m(:, :, ih);
    [best_score, linear_index] = min(scores(:));
    assert(isfinite(best_score), 'cambridge:NoFullCoverage', ...
        'No fully covered cone at half-power angle %g deg. Revise FOV, K or the design domain.', half_angles(ih));
    [it, jf] = ind2sub([nt nf], linear_index);
    best = struct('half_angle_deg', half_angles(ih), 'fov_deg', fovs(jf), ...
        'cone_tilt_deg', tilts(it), 'reference_rms_m', best_score);
    ph.receiver.fov_deg = best.fov_deg;
    for ik = 1:nk
        normals = rx_cone_normals(Ks(ik), best.cone_tilt_deg, p.design.azimuth_offset_deg);
        results.K.normals{ik, ih} = normals;
        for budget = 1:2
            counts = rx_sample_counts(Ks(ik), p, results.K.budgets{budget});
            results.K.sample_counts{ik, budget} = counts;
            peb = rx_peb(positions, normals, ph, counts);
            metrics = rx_design_metrics(peb);
            results.K.peb_m(:, ik, ih, budget) = peb(:);
            results.K.rms_full_m(ik, ih, budget) = metrics.rms_full_m;
            results.K.rms_conditional_m(ik, ih, budget) = metrics.rms_conditional_m;
            results.K.coverage(ik, ih, budget) = metrics.coverage;
        end
    end
    curve = results.K.rms_full_m(:, ih, 1);
    [best.K_minimum_rms_m, index] = min(curve);
    assert(isfinite(best.K_minimum_rms_m), 'cambridge:NoFeasibleK', 'No fully covered K in the sweep.');
    best.K_minimum_peb = Ks(index);
    eligible = find(curve<=(1+p.design.K_relative_tolerance)*best.K_minimum_rms_m);
    best.K_recommended = min(Ks(eligible));
    [best.fixed_budget_minimum_rms_m, index] = min(results.K.rms_full_m(:, ih, 2));
    best.K_fixed_budget_minimum = Ks(index);
    fprintf('  Cone: tilt %.3f deg, FOV %g deg, RMS %.3f cm at K=%d. Recommended K=%d.\n', ...
        best.cone_tilt_deg, best.fov_deg, best.reference_rms_m*100, p.design.reference_K, best.K_recommended);
    best.refinement = rx_refine_orientations(positions, ph, best.K_recommended, best.cone_tilt_deg);
    best.normals = best.refinement.normals;
    [best.peb_m, diagnostics] = rx_peb(positions, best.normals, ph);
    best.metrics = rx_design_metrics(best.peb_m);
    best.axis_bound_m = diagnostics.axis_bound_m;
    best.visible_count = diagnostics.visible_count;
    best.condition_fim = diagnostics.condition_fim;
    best.validation_peb_m = rx_peb(validation_positions, best.normals, ph);
    best.validation_metrics = rx_design_metrics(best.validation_peb_m);
    for ia = 1:numel(areas)
        pa = ph;
        pa.receiver.area_m2 = areas(ia)*1e-6;
        metrics = rx_design_metrics(rx_peb(positions, best.normals, pa));
        results.area.rms_full_m(ia, ih) = metrics.rms_full_m;
        results.area.coverage(ia, ih) = metrics.coverage;
    end
    [best.area_minimum_rms_m, index] = min(results.area.rms_full_m(:, ih));
    best.area_minimum_peb_mm2 = areas(index);
    eligible = find(results.area.rms_full_m(:, ih)<=p.design.target_rms_peb_m);
    best.area_target_mm2 = NaN;
    if ~isempty(eligible)
        best.area_target_mm2 = min(areas(eligible));
    end
    best_configurations{ih} = best;
    fprintf('  2DoF refined: %.3f cm; dense-grid coverage %.2f%%, RMS %.3f cm.\n', ...
        best.metrics.rms_full_m*100, best.validation_metrics.coverage*100, best.validation_metrics.rms_full_m*100);
end
results.best = [best_configurations{:}];
[~, results.best_half_index] = min(arrayfun(@(b) b.metrics.rms_full_m, results.best));
results.elapsed_seconds = toc(started);
results.summary = make_summary(results);
write_tables(results, output_dir);
results.heatmap = make_heatmaps(results);
save(fullfile(output_dir, 'design_results.mat'), 'results', '-v7.3');
if p.output.export_figures
    plot_parameter_design(results, output_dir);
end
disp(results.summary);
fprintf('All results saved in %s\n', output_dir);
end

function summary = make_summary(r)
b = r.best;
summary = table([b.half_angle_deg]', [b.fov_deg]', [b.cone_tilt_deg]', [b.K_minimum_peb]', ...
    [b.K_recommended]', [b.K_fixed_budget_minimum]', ...
    100*arrayfun(@(x) x.refinement.cone_rms_m, b)', 100*arrayfun(@(x) x.metrics.rms_full_m, b)', ...
    100*arrayfun(@(x) x.validation_metrics.coverage, b)', 100*arrayfun(@(x) x.validation_metrics.rms_full_m, b)', ...
    [b.area_minimum_peb_mm2]', [b.area_target_mm2]', 100*[b.area_minimum_rms_m]', ...
    'VariableNames', {'HalfAngle_deg', 'FOV_deg', 'ConeTilt_deg', 'K_minPEB', 'K_recommended', 'K_fixedBudget', ...
    'ConeRMS_cm', 'RefinedRMS_cm', 'ValidationCoverage_percent', 'ValidationRMS_cm', ...
    'Area_minPEB_mm2', 'Area_target_mm2', 'Area_minRMS_cm'});
end

function write_tables(r, output_dir)
p = r.parameters;
writetable(r.summary, fullfile(output_dir, 'best_configurations.csv'));
[T, F, H] = ndgrid(p.design.tilt_values_deg, p.design.fov_values_deg, p.design.half_angles_deg);
t = table(H(:), F(:), T(:), 100*r.tilt.rms_full_m(:), 100*r.tilt.rms_conditional_m(:), ...
    100*r.tilt.coverage(:), 100*r.tilt.nonregular_fraction(:), ...
    'VariableNames', {'HalfAngle_deg', 'FOV_deg', 'Tilt_deg', 'RMS_full_cm', 'RMS_conditional_cm', 'Coverage_percent', 'Nonregular_percent'});
writetable(t, fullfile(output_dir, 'inclination_sweep.csv'));
[K, H, B] = ndgrid(p.design.K_values, p.design.half_angles_deg, 1:2);
t = table(H(:), K(:), B(:), 100*r.K.rms_full_m(:), 100*r.K.rms_conditional_m(:), 100*r.K.coverage(:), ...
    'VariableNames', {'HalfAngle_deg', 'K', 'Budget_1_perOrientation_2_fixedTotal', 'RMS_full_cm', 'RMS_conditional_cm', 'Coverage_percent'});
writetable(t, fullfile(output_dir, 'K_sweep.csv'));
[A, H] = ndgrid(p.design.area_values_mm2, p.design.half_angles_deg);
t = table(H(:), A(:), 100*r.area.rms_full_m(:), 100*r.area.coverage(:), ...
    'VariableNames', {'HalfAngle_deg', 'Area_mm2', 'RMS_full_cm', 'Coverage_percent'});
writetable(t, fullfile(output_dir, 'area_sweep.csv'));
for ih = 1:numel(r.best)
    b = r.best(ih);
    n = b.normals;
    t = table((1:size(n, 2))', acosd(max(-1, min(1, n(3, :))))', mod(atan2d(n(2, :), n(1, :)), 360)', n(1, :)', n(2, :)', n(3, :)', ...
        'VariableNames', {'Orientation', 'Tilt_deg', 'Azimuth_deg', 'nx', 'ny', 'nz'});
    writetable(t, fullfile(output_dir, sprintf('orientations_Phi%g.csv', b.half_angle_deg)));
end
end

function heatmap = make_heatmaps(r)
p = r.parameters;
x = linspace(min(p.environment.x_m), max(p.environment.x_m), ...
    round(range(p.environment.x_m)/p.output.heatmap_step_m)+1);
y = linspace(min(p.environment.y_m), max(p.environment.y_m), ...
    round(range(p.environment.y_m)/p.output.heatmap_step_m)+1);
[X, Y] = meshgrid(x, y);
heatmap.x_m = x;
heatmap.y_m = y;
heatmap.comparison_height_m = p.output.heatmap_comparison_height_m;
heatmap.comparison_peb_m = nan(numel(y), numel(x), numel(r.best));
for ih = 1:numel(r.best)
    b = r.best(ih);
    ph = p;
    ph.transmitter.half_angle_power_deg = b.half_angle_deg;
    ph.receiver.fov_deg = b.fov_deg;
    positions = [X(:)'; Y(:)'; repmat(heatmap.comparison_height_m, 1, numel(X))];
    heatmap.comparison_peb_m(:, :, ih) = reshape(rx_peb(positions, b.normals, ph), size(X));
end
b = r.best(r.best_half_index);
p.transmitter.half_angle_power_deg = b.half_angle_deg;
p.receiver.fov_deg = b.fov_deg;
heatmap.heights_m = p.output.heatmap_heights_m;
heatmap.areas_mm2 = [p.receiver.area_m2*1e6, b.area_minimum_peb_mm2];
heatmap.best_peb_m = nan(numel(y), numel(x), numel(heatmap.heights_m), 2);
for ia = 1:2
    p.receiver.area_m2 = heatmap.areas_mm2(ia)*1e-6;
    for iz = 1:numel(heatmap.heights_m)
        positions = [X(:)'; Y(:)'; repmat(heatmap.heights_m(iz), 1, numel(X))];
        heatmap.best_peb_m(:, :, iz, ia) = reshape(rx_peb(positions, b.normals, p), size(X));
    end
end
end
