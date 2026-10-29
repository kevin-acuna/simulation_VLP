function s = pp_stats(e)
% Summary statistics of an error vector (same unit as e); failures (NaN) counted separately.
ok = isfinite(e);
v = e(ok);
s = struct('n', numel(e), 'n_ok', nnz(ok), 'mean', mean(v), 'median', median(v), ...
    'rmse', sqrt(mean(v.^2)), 'p90', prctile(v, 90), 'max', max(v));
end
