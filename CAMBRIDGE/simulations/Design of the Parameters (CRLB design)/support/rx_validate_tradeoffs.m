function frontier = rx_validate_tradeoffs(r, positions)
frontier = r.extra_tables.feasible_tradeoffs;
count = height(frontier);
frontier.ValidationRMS_cm = nan(count, 1);
frontier.ValidationTargetCoverage_percent = zeros(count, 1);
frontier.ValidationRegularCoverage_percent = zeros(count, 1);
frontier.ValidationFeasible = false(count, 1);
for i = 1:count
    p = r.parameters;
    p.transmitter.half_angle_power_deg = frontier.HalfAngle_deg(i);
    p.receiver.fov_deg = frontier.FOV_deg(i);
    p.receiver.area_m2 = frontier.Area_mm2(i)*1e-6;
    base = frontier.BaseIndex(i);
    peb = rx_peb(positions, r.base_normals{base}, p, r.base_sample_counts{base});
    q = rx_bound_quality(peb, r.spec.target_peb_m, r.spec.min_target_coverage);
    frontier.ValidationRMS_cm(i) = 100*q.rms_full_m;
    frontier.ValidationTargetCoverage_percent(i) = 100*q.target_coverage;
    frontier.ValidationRegularCoverage_percent(i) = 100*q.coverage;
    frontier.ValidationFeasible(i) = q.feasible;
end
end
