function q = rx_bound_quality(peb_m, target_m, target_fraction)
validateattributes(target_m, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(target_fraction, {'numeric'}, {'scalar', 'real', 'finite', '>=', 0, '<=', 1});
q = rx_design_metrics(peb_m);
q.target_coverage = nnz(isfinite(peb_m) & peb_m<=target_m)/numel(peb_m);
q.worst_m = Inf;
q.quantile_m = Inf;
q.required_scale = Inf;
if q.coverage==1
    ordered = sort(peb_m(:));
    q.worst_m = ordered(end);
    q.quantile_m = 0;
    if target_fraction>0
        q.quantile_m = ordered(ceil(target_fraction*numel(ordered)));
    end
    q.required_scale = max(q.rms_full_m, q.quantile_m)/target_m;
end
q.feasible = q.coverage==1 && q.rms_full_m<=target_m && q.target_coverage>=target_fraction;
end
