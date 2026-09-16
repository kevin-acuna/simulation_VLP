function [peb, detail] = rx_pose_error_peb(positions, normals, p, counts, variance_deg2, structure)
validateattributes(variance_deg2, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(p.noise.variance_W2, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
K = size(normals, 2);
if isscalar(counts)
    counts = repmat(counts, K, 1);
end
counts = counts(:);
validateattributes(counts, {'numeric'}, {'integer', 'positive', 'numel', K});
[~, J, info] = rx_channel(positions, normals, p);
P = size(positions, 2);
peb = inf(1, P);
detail.pose_jacobian = cell(1, P);
detail.effective_covariance_W2 = nan(K, K, P);
detail.fim_per_m2 = nan(3, 3, P);
variance = variance_deg2*(pi/180)^2;
for ip = 1:P
    if strcmp(structure, 'independent')
        D = zeros(K, 2*K);
    elseif strcmp(structure, 'common_rotation')
        D = zeros(K, 3);
    else
        error('cambridge:PoseStructure', 'Choose independent or common_rotation.');
    end
    for i = 1:K
        if ~info.visible(i, ip)
            continue;
        end
        s = info.incidence_cosine(i, ip);
        factor = info.beta_W(ip)*info.receiver_order*s^(info.receiver_order-1);
        if strcmp(structure, 'independent')
            E = rx_tangent_basis(normals(:, i));
            D(i, 2*i-1:2*i) = factor*info.direction_rx_to_tx(:, ip)'*E;
        else
            D(i, :) = factor*cross(normals(:, i), info.direction_rx_to_tx(:, ip))';
        end
    end
    covariance = diag(p.noise.variance_W2./counts)+variance*(D*D');
    G = chol(covariance, 'lower')\J(:, :, ip);
    singular = svd(G, 'econ');
    if numel(singular)==3 && singular(3)>p.numerics.rank_relative_tolerance*singular(1)
        peb(ip) = norm(1./singular);
    end
    if info.boundary(ip)
        peb(ip) = NaN;
    end
    detail.pose_jacobian{ip} = D;
    detail.effective_covariance_W2(:, :, ip) = covariance;
    detail.fim_per_m2(:, :, ip) = G'*G;
end
end
