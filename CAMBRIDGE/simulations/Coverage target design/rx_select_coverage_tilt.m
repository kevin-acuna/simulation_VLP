function s = rx_select_coverage_tilt(tilts_deg, coverage, e)
validateattributes(e.minimum_coverage_percent, {'numeric'}, {'scalar', '>=', 0, '<=', 100});
validateattributes(e.near_peak_loss_pp, {'numeric'}, {'scalar', '>=', 0, '<=', 100});
peak = max(coverage);
s = struct('maximum_coverage', peak, 'optimal_tilt_deg', NaN, ...
    'minimum_acceptable_tilt_deg', NaN, 'minimum_near_peak_tilt_deg', NaN);
if peak>0
    s.optimal_tilt_deg = min(tilts_deg(coverage>=peak-1e-12));
    near = coverage>=peak-e.near_peak_loss_pp/100-1e-12 & coverage>0;
    s.minimum_near_peak_tilt_deg = min(tilts_deg(near));
end
acceptable = coverage>=e.minimum_coverage_percent/100-1e-12 & coverage>0;
if any(acceptable)
    s.minimum_acceptable_tilt_deg = min(tilts_deg(acceptable));
end
end
