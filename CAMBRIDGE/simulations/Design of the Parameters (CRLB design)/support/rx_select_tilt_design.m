function r = rx_select_tilt_design(r)
e = r.spec;
r.selected = [];
r.minimum_error_row = [];
r.recommended_row = [];
r.extra_tables.feasible_tradeoffs = rx_feasible_tradeoffs(r.table);
valid = find(isfinite(r.rms_full_m));
if isempty(valid)
    return;
end
[~, index] = min(r.rms_full_m(valid));
r.minimum_error_row = valid(index);
feasible = find(r.table.Feasible);
if isempty(feasible)
    row = r.minimum_error_row;
    policy = 'No feasible candidate: showing the smallest finite RMS within the tested bounds';
else
    ranking = [r.table.TotalSamples(feasible), r.table.Area_mm2(feasible), r.table.K(feasible), r.table.RMS_full_cm(feasible)];
    [~, order] = sortrows(ranking, [1 2 3 4]);
    row = feasible(order(1));
    r.recommended_row = row;
    policy = 'Feasible candidates: minimize samples, then area, then K, then RMS';
end
candidate = r.table(row, :);
base = candidate.BaseIndex;
p = r.parameters;
p.receiver.max_tilt_deg = e.tilt_deg;
p.receiver.area_m2 = candidate.Area_mm2*1e-6;
p.receiver.fov_deg = candidate.FOV_deg;
p.transmitter.half_angle_power_deg = candidate.HalfAngle_deg;
counts = r.base_sample_counts{base};
refinement = rx_refine_capped_pattern(r.positions_m, r.base_normals{base}, p, counts, e);
normals = refinement.normals;
peb = rx_peb(r.positions_m, normals, p, counts);
q = rx_bound_quality(peb, e.target_peb_m, e.min_target_coverage);
[validation_positions, validation_grid] = rx_testbed(p, 'validation');
r.extra_tables.feasible_tradeoffs = rx_validate_tradeoffs(r, validation_positions);
validation_peb = rx_peb(validation_positions, normals, p, counts);
v = rx_bound_quality(validation_peb, e.target_peb_m, e.min_target_coverage);
r.selected = struct('row', row, 'policy', policy, 'candidate', candidate, 'parameters', p, ...
    'normals', normals, 'sample_counts', counts, 'peb_m', peb, 'metrics', q, 'refinement', refinement, ...
    'validation_grid', validation_grid, 'validation_peb_m', validation_peb, 'validation_metrics', v);
r.extra_tables.selected_configuration = candidate;
r.extra_tables.selected_validation = table(["Design after refinement"; "Dense validation"], ...
    100*[q.rms_full_m; v.rms_full_m], 100*[q.quantile_m; v.quantile_m], ...
    100*[q.coverage; v.coverage], 100*[q.target_coverage; v.target_coverage], [q.feasible; v.feasible], ...
    'VariableNames', {'Grid', 'RMS_full_cm', 'TargetQuantile_cm', 'RegularCoverage_percent', 'TargetCoverage_percent', 'Feasible'});
r.extra_tables.selected_orientations = table((1:size(normals, 2))', acosd(max(-1, min(1, normals(3, :))))', ...
    mod(atan2d(normals(2, :), normals(1, :)), 360)', counts, normals(1, :)', normals(2, :)', normals(3, :)', ...
    'VariableNames', {'Orientation', 'Tilt_deg', 'Azimuth_deg', 'Samples', 'nx', 'ny', 'nz'});
x = linspace(min(p.environment.x_m), max(p.environment.x_m), ceil(range(p.environment.x_m)/e.map_step_m)+1);
y = linspace(min(p.environment.y_m), max(p.environment.y_m), ceil(range(p.environment.y_m)/e.map_step_m)+1);
[X, Y] = meshgrid(x, y);
c = rx_cone_cases(p, candidate.HalfAngle_deg, e.tilt_deg, candidate.K);
c.family = 'explicit';
c.normals = normals;
c.tilt_deg = NaN;
map = struct('kind', 'heatmap', 'parameters', p, 'x_m', x, 'y_m', y, ...
    'spec', struct('cases', c, 'heights_m', e.validation_heights_m, 'grid_step_m', e.map_step_m), ...
    'peb_m', nan(numel(X), numel(e.validation_heights_m), 1), 'sample_counts', counts);
for j = 1:numel(e.validation_heights_m)
    positions = [X(:)'; Y(:)'; repmat(e.validation_heights_m(j), 1, numel(X))];
    map.peb_m(:, j, 1) = rx_peb(positions, normals, p, counts)';
end
r.selected.heatmap = rx_summarize_study(map);
end
