function r = study_tilt_feasibility(p, e)
validateattributes(e.tilt_deg, {'numeric'}, {'scalar', 'real', 'finite', '>=', 0, '<=', p.receiver.max_tilt_deg});
validateattributes(e.area_values_mm2, {'numeric'}, {'vector', 'real', 'finite', 'positive', 'nonempty'});
validateattributes(e.K_values, {'numeric'}, {'vector', 'integer', '>=', 3, 'nonempty'});
validateattributes(e.half_angles_deg, {'numeric'}, {'vector', 'real', 'finite', 'nonempty', '>', 0, '<', 90});
validateattributes(e.fov_values_deg, {'numeric'}, {'vector', 'real', 'finite', 'nonempty', '>', 0, '<=', 90});
validateattributes(e.map_step_m, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(e.validation_heights_m, {'numeric'}, {'vector', 'real', 'finite', 'nonempty'});
assert(~isempty(e.patterns) && ~isempty(e.budgets), 'cambridge:EmptyExperiment', 'Patterns and budgets are required.');
r.kind = 'tilt_feasibility';
r.parameters = p;
r.spec = e;
[r.positions_m, r.grid] = rx_testbed(p);
[H, F, K, P, B] = ndgrid(e.half_angles_deg, e.fov_values_deg, e.K_values, 1:numel(e.patterns), 1:numel(e.budgets));
nb = numel(H);
patterns = string(e.patterns);
budgets = string(e.budgets);
r.base_table = table((1:nb)', H(:), F(:), K(:), reshape(patterns(P(:)), [], 1), reshape(budgets(B(:)), [], 1), ...
    'VariableNames', {'BaseIndex', 'HalfAngle_deg', 'FOV_deg', 'K', 'Pattern', 'Budget'});
r.base_peb_m = nan(size(r.positions_m, 2), nb);
r.base_normals = cell(nb, 1);
r.base_sample_counts = cell(nb, 1);
quality = zeros(nb, 6);
total_samples = zeros(nb, 1);
for i = 1:nb
    pc = p;
    pc.receiver.max_tilt_deg = e.tilt_deg;
    pc.transmitter.half_angle_power_deg = H(i);
    pc.receiver.fov_deg = F(i);
    normals = rx_capped_pattern(K(i), e.tilt_deg, e.patterns{P(i)}, e.azimuth_offset_deg, e.tilt_constraint);
    counts = rx_sample_counts(K(i), p, e.budgets{B(i)});
    peb = rx_peb(r.positions_m, normals, pc, counts);
    q = rx_bound_quality(peb, e.target_peb_m, e.min_target_coverage);
    r.base_peb_m(:, i) = peb';
    r.base_normals{i} = normals;
    r.base_sample_counts{i} = counts;
    quality(i, :) = [q.rms_full_m q.rms_conditional_m q.coverage q.worst_m q.quantile_m q.required_scale];
    total_samples(i) = sum(counts);
end
r.base_table.RequiredArea_mm2 = p.receiver.area_m2*1e6*quality(:, 6);
r.base_table.TotalSamples = total_samples;
na = numel(e.area_values_mm2);
base = repelem((1:nb)', na);
area = repmat(e.area_values_mm2(:), nb, 1);
scale = p.receiver.area_m2*1e6./area;
r.rms_full_m = quality(base, 1).*scale;
r.rms_conditional_m = quality(base, 2).*scale;
r.coverage = quality(base, 3);
r.target_coverage = zeros(numel(base), 1);
for i = 1:numel(base)
    peb = r.base_peb_m(:, base(i))*scale(i);
    r.target_coverage(i) = mean(isfinite(peb) & peb<=e.target_peb_m);
end
r.table = r.base_table(base, :);
r.table.Area_mm2 = area;
r.table.RMS_full_cm = 100*r.rms_full_m;
r.table.RMS_conditional_cm = 100*r.rms_conditional_m;
r.table.Worst_cm = 100*quality(base, 4).*scale;
r.table.RegularCoverage_percent = 100*r.coverage;
r.table.TargetCoverage_percent = 100*r.target_coverage;
r.table.Feasible = r.coverage==1 & r.rms_full_m<=e.target_peb_m & r.target_coverage>=e.min_target_coverage;
r.extra_tables.base_profiles = r.base_table;
r = rx_select_tilt_design(r);
end
