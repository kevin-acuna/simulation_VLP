function [peb_m, info] = rx_peb(positions_m, normals, p, sample_counts)
K = size(normals, 2);
if nargin < 4
    sample_counts = p.acquisition.samples_per_orientation;
end
if isscalar(sample_counts)
    sample_counts = repmat(sample_counts, K, 1);
end
sample_counts = sample_counts(:);
validateattributes(sample_counts, {'numeric'}, {'real', 'finite', 'integer', 'positive', 'numel', K});
validateattributes(p.noise.variance_W2, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(p.numerics.rank_relative_tolerance, {'numeric'}, {'scalar', '>', 0, '<', 1});
assert(strcmp(p.noise.model, 'independent_homoscedastic_optical_power'), ...
    'cambridge:NoiseModel', 'This FIM requires independent, position-independent optical noise.');
[mu, J, info] = rx_channel(positions_m, normals, p);
G = J.*sqrt(sample_counts/p.noise.variance_W2);
if nargout > 1
    [~, S, V] = pagesvd(G, 'econ', 'vector');
else
    S = pagesvd(G, 'econ', 'vector');
end
P = size(positions_m, 2);
singular_values = zeros(3, P);
singular_values(1:min(K, 3), :) = reshape(S, min(K, 3), P);
rank_J = sum(singular_values>p.numerics.rank_relative_tolerance*singular_values(1, :), 1);
regular = ~info.boundary;
valid = rank_J==3 & regular;
peb_m = inf(1, P);
peb_m(valid) = sqrt(sum(singular_values(:, valid).^(-2), 1));
peb_m(~regular) = NaN;
if nargout < 2
    return;
end
info.mean_W = mu;
info.jacobian_W_per_m = J;
info.fim_per_m2 = pagemtimes(G, 'transpose', G, 'none');
info.singular_values = singular_values;
info.rank = rank_J;
info.regular = regular;
info.identifiable = valid;
info.sample_counts = sample_counts;
info.covariance_m2 = nan(3, 3, P);
info.axis_bound_m = inf(3, P);
if any(valid)
    weighted_V = V(:, :, valid)./reshape(singular_values(:, valid), 1, 3, []);
    info.covariance_m2(:, :, valid) = pagemtimes(weighted_V, 'none', weighted_V, 'transpose');
    info.axis_bound_m(:, valid) = reshape(sqrt(sum(weighted_V.^2, 2)), 3, []);
end
info.axis_bound_m(:, ~regular) = NaN;
info.condition_fim = (singular_values(1, :)./singular_values(3, :)).^2;
info.condition_fim(singular_values(3, :)==0) = Inf;
end
