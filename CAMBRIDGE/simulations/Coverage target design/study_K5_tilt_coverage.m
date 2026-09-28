function result = study_K5_tilt_coverage(p, e)
validateattributes(e.K, {'numeric'}, {'scalar', 'integer', '>=', 3});
validateattributes(e.tilt_values_deg, {'numeric'}, {'vector', 'nonempty', 'finite', 'increasing', '>=', 0, '<=', p.receiver.max_tilt_deg});
validateattributes(e.orientation_std_deg, {'numeric'}, {'scalar', 'finite', 'nonnegative'});
assert(any(strcmp(e.orientation_structure, {'independent', 'common_rotation'})), 'cambridge:PoseStructure', 'Unknown angular error structure.');
assert(isfinite(rx_coverage_threshold(p)), 'cambridge:TargetThreshold', 'This study requires a finite coverage threshold in cm.');
result.parameters = p;
result.spec = e;
result.sample_counts = rx_sample_counts(e.K, p, e.budget);
result.orientation_std_values_deg = unique([0 e.orientation_std_deg], 'stable');
result.grid_names = {'design', 'validation'};
result.grid_results = cell(1, 2);
rows = cell(2, numel(result.orientation_std_values_deg));
curve_tables = cell(1, 2);
for ig = 1:2
    [positions, grid] = rx_testbed(p, result.grid_names{ig});
    g = struct('parameters', p, 'positions_m', positions, 'grid', grid);
    nt = numel(e.tilt_values_deg);
    ns = numel(result.orientation_std_values_deg);
    g.peb_m = nan(size(positions, 2), nt, ns);
    g.all_visible_coverage = zeros(nt, 1);
    for it = 1:nt
        normals = rx_cone_normals(e.K, e.tilt_values_deg(it), e.azimuth_offset_deg);
        [nominal, info] = rx_peb(positions, normals, p, result.sample_counts);
        g.peb_m(:, it, 1) = nominal';
        g.all_visible_coverage(it) = mean(all(info.visible, 1));
        for is = 2:ns
            sigma = result.orientation_std_values_deg(is);
            g.peb_m(:, it, is) = rx_pose_error_peb(positions, normals, p, result.sample_counts, sigma^2, e.orientation_structure)';
        end
    end
    g = rx_summarize_study(g);
    [T, S] = ndgrid(e.tilt_values_deg, result.orientation_std_values_deg);
    g.table = table(T(:), S(:), 100*g.coverage(:), 100*g.regular_coverage(:), ...
        100*g.rms_conditional_m(:), 100*g.rms_full_m(:), 100*g.nonregular_fraction(:), ...
        'VariableNames', {'Tilt_deg', 'OrientationStd_deg', 'Coverage_percent', 'RegularCoverage_percent', ...
        'RMS_conditional_cm', 'RMS_full_cm', 'Nonregular_percent'});
    g.table.CoverageThreshold_cm = repmat(g.coverage_threshold_cm, height(g.table), 1);
    g.table.Grid = repmat(string(result.grid_names{ig}), height(g.table), 1);
    curve_tables{ig} = g.table;
    g.selections = cell(1, ns);
    for is = 1:ns
        s = rx_select_coverage_tilt(e.tilt_values_deg, g.coverage(:, is), e);
        g.selections{is} = s;
        rows{ig, is} = table(string(result.grid_names{ig}), size(positions, 2), result.orientation_std_values_deg(is), ...
            100*s.maximum_coverage, s.optimal_tilt_deg, s.minimum_acceptable_tilt_deg, s.minimum_near_peak_tilt_deg, ...
            'VariableNames', {'Grid', 'Positions', 'OrientationStd_deg', 'MaximumCoverage_percent', ...
            'OptimalTilt_deg', 'MinimumAcceptableTilt_deg', 'MinimumNearPeakTilt_deg'});
    end
    result.grid_results{ig} = g;
end
result.selection_table = vertcat(rows{:});
result.table = vertcat(curve_tables{:});
result.selection_table.RequiredCoverage_percent = repmat(e.minimum_coverage_percent, height(result.selection_table), 1);
result.selection_table.NearPeakLoss_pp = repmat(e.near_peak_loss_pp, height(result.selection_table), 1);
result.selection_table.CoverageThreshold_cm = repmat(rx_coverage_threshold(p), height(result.selection_table), 1);
result.grid_agreement_table = rx_K5_grid_agreement(result);
end
