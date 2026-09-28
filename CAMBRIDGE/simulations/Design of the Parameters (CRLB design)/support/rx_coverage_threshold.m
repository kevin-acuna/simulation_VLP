function threshold_cm = rx_coverage_threshold(p)
threshold_cm = Inf;
if isfield(p, 'design') && isfield(p.design, 'coverage_threshold_cm')
    threshold_cm = p.design.coverage_threshold_cm;
end
validateattributes(threshold_cm, {'numeric'}, {'scalar', 'real', 'nonnan', 'nonnegative'});
end
