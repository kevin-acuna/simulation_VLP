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
[incidence_power, incidence_derivative, response] = rx_receiver_response(s, p);
visible = c>0 & response.active;
incidence_power(~visible) = 0;
incidence_derivative(~visible) = 0;
tol = p.numerics.boundary_cosine_tolerance;
boundary = abs(c)<=tol | (c>0 & any(response.boundary, 1));
order = response.receiver_order;
[emission_gain, emission_gradient, m] = rx_emission_pattern(p, u);
C = p.transmitter.power_W*(m+1)*p.receiver.area_m2 ...
    *p.receiver.filter_transmission*p.receiver.optical_gain/(2*pi);
beta = C*emission_gain./d.^2;
mean_W = beta.*incidence_power;
if nargout < 2
    return;
end
tangent_emission_gradient = emission_gradient-u.*sum(u.*emission_gradient, 1);
beta_gradient = (C./d.^3).*(2*u.*emission_gain-tangent_emission_gradient);
K = size(normals, 2);
P = size(positions_m, 2);
jacobian_W_per_m = zeros(K, 3, P);
for j = 1:3
    gradient = incidence_power.*beta_gradient(j, :) ...
        -(beta./d).*incidence_derivative.*(normals(j, :)'-s.*u(j, :));
    gradient(~visible) = 0;
    jacobian_W_per_m(:, j, :) = reshape(gradient, K, 1, P);
end
info = struct('visible', visible, 'visible_count', sum(visible, 1), 'boundary', boundary, ...
    'distance_m', d, 'direction_rx_to_tx', u, 'emission_cosine', c, 'incidence_cosine', s, ...
    'lambertian_order', m, 'receiver_order', order, 'radiometric_constant_W_m2', C, ...
    'emission_gain', emission_gain, 'beta_W', beta, 'beta_gradient_W_per_m', beta_gradient, ...
    'response_model', response.model, 'response_value', incidence_power, 'response_derivative_s', incidence_derivative, ...
    'effective_cutoff_deg', response.effective_cutoff_deg);
end
