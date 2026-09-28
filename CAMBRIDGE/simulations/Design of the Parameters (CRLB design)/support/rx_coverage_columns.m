function r = rx_coverage_columns(r)
r.table.Coverage_percent = 100*r.coverage(:);
r.table.RegularCoverage_percent = 100*r.regular_coverage(:);
r.table.CoverageThreshold_cm = repmat(r.coverage_threshold_cm, height(r.table), 1);
end
