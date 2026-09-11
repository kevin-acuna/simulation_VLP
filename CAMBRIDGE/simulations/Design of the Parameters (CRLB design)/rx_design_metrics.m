function metrics = rx_design_metrics(peb_m)
validateattributes(peb_m, {'numeric'}, {'real', 'nonempty', 'nonnegative'});
finite = isfinite(peb_m);
metrics.coverage = nnz(finite)/numel(peb_m);
metrics.rms_full_m = Inf;
metrics.rms_conditional_m = NaN;
metrics.worst_finite_m = NaN;
metrics.nonregular_fraction = nnz(isnan(peb_m))/numel(peb_m);
if any(finite(:))
    metrics.rms_conditional_m = sqrt(mean(peb_m(finite).^2));
    metrics.worst_finite_m = max(peb_m(finite));
end
if all(finite(:))
    metrics.rms_full_m = metrics.rms_conditional_m;
end
end
