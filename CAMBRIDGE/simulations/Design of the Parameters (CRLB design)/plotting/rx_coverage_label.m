function label = rx_coverage_label(r, default_label)
label = default_label;
if isfield(r, 'coverage_threshold_cm') && isfinite(r.coverage_threshold_cm)
    label = sprintf('Coverage: PEB \\leq %g cm', r.coverage_threshold_cm);
end
end
