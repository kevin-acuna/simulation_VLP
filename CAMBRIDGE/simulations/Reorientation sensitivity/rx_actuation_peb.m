function [peb, detail] = rx_actuation_peb(positions, normals, p, counts, variance_deg2)
[mu, variance, J, V, info] = rx_actuation_moments(positions, normals, p, counts, variance_deg2);
P = size(positions, 2);
peb = inf(1, P);
detail.fim_per_m2 = nan(3, 3, P);
detail.mean_W = mu;
detail.variance_W2 = variance;
for ip = 1:P
    G = [J(:, :, ip)./sqrt(variance(:, ip)); V(:, :, ip)./(sqrt(2)*variance(:, ip))];
    singular = svd(G, 'econ');
    if numel(singular)==3 && singular(3)>p.numerics.rank_relative_tolerance*singular(1)
        peb(ip) = norm(1./singular);
    end
    if info.boundary(ip) || any(mu(:, ip)<0) || any(variance(:, ip)<=0)
        peb(ip) = NaN;
    end
    detail.fim_per_m2(:, :, ip) = G'*G;
end
detail.interpretation = 'Gaussian small-angle moment approximation, not the exact marginalized CRLB';
end
