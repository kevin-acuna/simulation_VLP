function [u, detail] = rx_ratio_direction(y, a, full_covariance)
u = nan(3, 1);
detail = struct('status', "nonpositive_power_for_root", 'reference', NaN, 'covariance', []);
if a.order~=1 && any(y<=0)
    return;
end
if a.order==1
    z = y;
    derivative = ones(size(y));
else
    z = y.^(1/a.order);
    derivative = y.^(1/a.order-1)/a.order;
end
[reference_power, ref] = max(z);
if reference_power<=0
    detail.status = "nonpositive_reference";
    return;
end
indices = [1:ref-1 ref+1:numel(y)];
ratios = z(indices)/z(ref);
variance = a.root_variance_scale.*derivative.^2;
C = diag(variance(indices))+variance(ref)*(ratios*ratios');
if ~all(isfinite(C), 'all') || max(diag(C))<=0
    detail.status = "invalid_ratio_covariance";
    return;
end
C = C/max(diag(C));
A = a.H(indices, :)-ratios*a.H(ref, :);
detail.reference = ref;
detail.covariance = C;
if full_covariance
    [L, flag] = chol(C, 'lower');
    if flag~=0
        detail.status = "invalid_ratio_covariance";
        return;
    end
    G = L\A;
else
    G = A./sqrt(diag(C));
end
M = G'*G;
[V, D] = eig((M+M')/2, 'vector');
[~, index] = min(D);
u = V(:, index);
if a.q'*u<0
    u = -u;
end
u = u/norm(u);
detail.status = "success";
if ~rx_optical_domain(u, a)
    detail.status = "outside_full_visibility_domain";
end
end
