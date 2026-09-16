function [gain, gradient_u, m] = rx_emission_pattern(p, u)
validateattributes(p.transmitter.half_angle_power_deg, {'numeric'}, {'scalar', '>', 0, '<', 90});
m = -log(2)/log(cosd(p.transmitter.half_angle_power_deg));
q = -p.transmitter.normal;
c = q'*u;
active = c>0;
gain = zeros(1, size(u, 2));
gradient_u = zeros(size(u));
asymmetry = 0;
if isfield(p.transmitter, 'pattern_asymmetry')
    asymmetry = p.transmitter.pattern_asymmetry;
end
validateattributes(asymmetry, {'numeric'}, {'scalar', 'real', 'finite', '>', -1, '<', 1});
Q = zeros(3);
if asymmetry~=0
    reference = [1; 0; 0];
    if isfield(p.transmitter, 'pattern_reference')
        reference = p.transmitter.pattern_reference;
    end
    validateattributes(reference, {'numeric'}, {'real', 'finite', 'size', [3 1]});
    a = reference-q*(q'*reference);
    assert(norm(a)>1e-12, 'cambridge:PatternReference', 'The pattern reference cannot be parallel to the LED axis.');
    a = a/norm(a);
    b = cross(q, a);
    Q = a*a'-b*b';
end
if ~any(active)
    return;
end
shape = 1+asymmetry*sum(u.*(Q*u), 1);
gain(active) = c(active).^m.*shape(active);
gradient_u(:, active) = q*(m*c(active).^(m-1).*shape(active)) ...
    +2*asymmetry*(Q*u(:, active)).*c(active).^m;
end
