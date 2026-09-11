function [mean_W, jacobian_W_per_m, info] = rx_channel(positions_m, normals, p)
validateattributes(positions_m, {'numeric'}, {'real', 'finite', '2d', 'nrows', 3, 'nonempty'});
validateattributes(normals, {'numeric'}, {'real', 'finite', '2d', 'nrows', 3, 'nonempty'});
validateattributes(p.transmitter.position_m, {'numeric'}, {'real', 'finite', 'size', [3 1]});
validateattributes(p.transmitter.normal, {'numeric'}, {'real', 'finite', 'size', [3 1]});
assert(all(abs(sum(normals.^2, 1)-1)<1e-10) && abs(norm(p.transmitter.normal)-1)<1e-10, ...
    'cambridge:UnitNormals', 'Transmitter and receiver normals must be unit vectors.');
validateattributes(p.transmitter.half_angle_power_deg, {'numeric'}, {'scalar', '>', 0, '<', 90});
validateattributes(p.transmitter.power_W, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(p.receiver.area_m2, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(p.receiver.fov_deg, {'numeric'}, {'scalar', '>', 0, '<=', 90});
validateattributes(p.receiver.filter_transmission, {'numeric'}, {'scalar', 'real', 'finite', '>', 0, '<=', 1});
validateattributes(p.receiver.optical_gain, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(p.numerics.boundary_cosine_tolerance, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
q = -p.transmitter.normal;
v = p.transmitter.position_m-positions_m;
d = sqrt(sum(v.^2, 1));
assert(all(d>0), 'cambridge:CoincidentPosition', 'LED and receiver cannot occupy the same position.');
u = v./d;
c = q'*u;
s = normals'*u;
fov_cosine = cosd(p.receiver.fov_deg);
visible = c>0 & s>0 & s>=fov_cosine;
tol = p.numerics.boundary_cosine_tolerance;
boundary = abs(c)<=tol | (c>0 & any(abs(s-fov_cosine)<=tol, 1));
m = -log(2)/log(cosd(p.transmitter.half_angle_power_deg));
C = p.transmitter.power_W*(m+1)*p.receiver.area_m2 ...
    *p.receiver.filter_transmission*p.receiver.optical_gain/(2*pi);
beta = zeros(size(d));
emission_valid = c>0;
beta(emission_valid) = C*c(emission_valid).^m./d(emission_valid).^2;
mean_W = beta.*s;
mean_W(~visible) = 0;
if nargout < 2
    return;
end
safe_c = c;
safe_c(~emission_valid) = 1;
K = size(normals, 2);
P = size(positions_m, 2);
jacobian_W_per_m = zeros(K, 3, P);
for j = 1:3
    gradient = (beta./d).*(-normals(j, :)' + s.*((m+3)*u(j, :)-m*q(j)./safe_c));
    gradient(~visible) = 0;
    jacobian_W_per_m(:, j, :) = reshape(gradient, K, 1, P);
end
info = struct('visible', visible, 'visible_count', sum(visible, 1), 'boundary', boundary, ...
    'distance_m', d, 'direction_rx_to_tx', u, 'emission_cosine', c, 'incidence_cosine', s, ...
    'lambertian_order', m, 'radiometric_constant_W_m2', C);
end
