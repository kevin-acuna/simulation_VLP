function [mean_W, variance_W2, mean_gradient, variance_gradient, info] = rx_actuation_moments(positions, normals, p, counts, variance_deg2)
validateattributes(variance_deg2, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(p.noise.variance_W2, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
K = size(normals, 2);
if isscalar(counts)
    counts = repmat(counts, K, 1);
end
counts = counts(:);
validateattributes(counts, {'numeric'}, {'integer', 'positive', 'numel', K});
[mean_W, mean_gradient, info] = rx_channel(positions, normals, p);
P = size(positions, 2);
variance_W2 = repmat(p.noise.variance_W2./counts, 1, P);
variance_gradient = zeros(K, 3, P);
if variance_deg2==0
    return;
end
v = variance_deg2*(pi/180)^2;
nu = info.receiver_order;
s = info.incidence_cosine;
active = info.visible;
h = zeros(K, P); hp = h; g = h; gp = h;
x = min(1, s(active));
a = nu*(nu-1)/2;
h(active) = x.^nu+v*(-nu*x.^nu+a*x.^(nu-2).*(1-x.^2));
hp(active) = nu*x.^(nu-1)+v*(-nu^2*x.^(nu-1) ...
    +a*((nu-2)*x.^(nu-3).*(1-x.^2)-2*x.^(nu-1)));
g(active) = nu^2*x.^(2*nu-2).*(1-x.^2);
gp(active) = nu^2*((2*nu-2)*x.^(2*nu-3).*(1-x.^2)-2*x.^(2*nu-1));
beta = info.beta_W;
mean_W = beta.*h;
variance_W2 = variance_W2+v*beta.^2.*g;
for j = 1:3
    ds = -(normals(j, :)'-s.*info.direction_rx_to_tx(j, :))./info.distance_m;
    dmean = h.*info.beta_gradient_W_per_m(j, :)+beta.*hp.*ds;
    dvariance = v*(2*beta.*g.*info.beta_gradient_W_per_m(j, :)+beta.^2.*gp.*ds);
    mean_gradient(:, j, :) = reshape(dmean, K, 1, P);
    variance_gradient(:, j, :) = reshape(dvariance, K, 1, P);
end
end
