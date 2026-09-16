function a = rx_estimator_context(normals, p, counts, options)
K = size(normals, 2);
validateattributes(normals, {'numeric'}, {'real', 'finite', '2d', 'nrows', 3, 'nonempty'});
assert(all(abs(sum(normals.^2, 1)-1)<1e-10), 'cambridge:UnitNormals', 'Normals must be unit vectors.');
if isempty(counts)
    counts = p.acquisition.samples_per_orientation;
end
if isscalar(counts)
    counts = repmat(counts, K, 1);
end
counts = counts(:);
validateattributes(counts, {'numeric'}, {'integer', 'positive', 'finite', 'numel', K});
validateattributes(p.noise.variance_W2, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(p.receiver.fov_deg, {'numeric'}, {'scalar', '>', 0, '<=', 90});
a.H = normals';
a.q = -p.transmitter.normal;
a.order = rx_receiver_order(p);
a.fov_cosine = cosd(p.receiver.fov_deg);
a.weights = sqrt(counts/mean(counts));
a.variance = p.noise.variance_W2./counts;
a.root_variance_scale = 1./counts;
s = svd(a.H, 'econ');
a.identifiable = numel(s)==3 && s(3)>p.numerics.rank_relative_tolerance*s(1);
a.max_iterations = 60;
a.step_tolerance = 1e-10;
a.gradient_tolerance = 1e-10;
fields = fieldnames(options);
for i = 1:numel(fields)
    assert(any(strcmp(fields{i}, {'max_iterations', 'step_tolerance', 'gradient_tolerance'})), ...
        'cambridge:EstimatorOption', 'Unknown estimator option: %s.', fields{i});
    a.(fields{i}) = options.(fields{i});
end
end
