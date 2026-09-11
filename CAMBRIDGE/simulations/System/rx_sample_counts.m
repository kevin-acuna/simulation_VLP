function counts = rx_sample_counts(K, p, budget)
validateattributes(K, {'numeric'}, {'scalar', 'integer', 'positive'});
switch budget
    case 'per_orientation'
        counts = repmat(p.acquisition.samples_per_orientation, K, 1);
    case 'fixed_total'
        total = p.acquisition.total_samples;
        validateattributes(total, {'numeric'}, {'scalar', 'integer', '>=', K});
        counts = repmat(floor(total/K), K, 1);
        counts(1:mod(total, K)) = counts(1:mod(total, K))+1;
    otherwise
        error('cambridge:Budget', 'Unknown acquisition budget: %s.', budget);
end
validateattributes(counts, {'numeric'}, {'integer', 'positive', 'finite'});
end
