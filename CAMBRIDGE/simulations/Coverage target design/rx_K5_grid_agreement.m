function t = rx_K5_grid_agreement(r)
e = r.spec;
a = r.grid_results{1}; b = r.grid_results{2};
rows = cell(1, numel(r.orientation_std_values_deg));
for is = 1:numel(rows)
    conservative = min(a.coverage(:, is), b.coverage(:, is));
    s = rx_select_coverage_tilt(e.tilt_values_deg, conservative, e);
    near = a.coverage(:, is)>=max(a.coverage(:, is))-e.near_peak_loss_pp/100-1e-12 ...
        & b.coverage(:, is)>=max(b.coverage(:, is))-e.near_peak_loss_pp/100-1e-12 ...
        & conservative>0;
    angle = NaN;
    if any(near)
        angle = min(e.tilt_values_deg(near));
    end
    rows{is} = table(r.orientation_std_values_deg(is), s.minimum_acceptable_tilt_deg, angle, ...
        s.optimal_tilt_deg, 100*s.maximum_coverage, ...
        'VariableNames', {'OrientationStd_deg', 'MinimumAcceptableBothGrids_deg', 'MinimumNearPeakBothGrids_deg', ...
        'MaximinTilt_deg', 'MaximinCoverage_percent'});
end
t = vertcat(rows{:});
end
