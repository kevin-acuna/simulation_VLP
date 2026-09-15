function normals = rx_capped_pattern(K, tilt_deg, pattern, azimuth_deg, constraint)
validateattributes(K, {'numeric'}, {'scalar', 'integer', 'positive'});
validateattributes(tilt_deg, {'numeric'}, {'scalar', 'real', 'finite', '>=', 0, '<', 90});
assert(any(strcmp(constraint, {'maximum', 'fixed'})), 'cambridge:TiltConstraint', 'Choose maximum or fixed tilt.');
if strcmp(constraint, 'fixed')
    assert(~any(strcmp(pattern, {'center_ring', 'two_rings'})), 'cambridge:FixedTiltPattern', ...
        'Center and two-ring patterns need variable inclination; use the maximum-tilt constraint.');
end
switch pattern
    case 'uniform_cone'
        normals = rx_cone_normals(K, tilt_deg, azimuth_deg);
    case 'golden_prefix'
        normals = rx_normals(tilt_deg, mod(azimuth_deg+(0:K-1)*180*(3-sqrt(5)), 360));
    case 'repeat_triplet'
        triplet = rx_cone_normals(3, tilt_deg, azimuth_deg);
        normals = triplet(:, mod(0:K-1, 3)+1);
    case 'center_ring'
        normals = [0; 0; 1];
        if K>1
            normals = [normals, rx_cone_normals(K-1, tilt_deg, azimuth_deg)];
        end
    case 'two_rings'
        inner = floor(K/2);
        if inner==0
            normals = rx_cone_normals(K, tilt_deg, azimuth_deg);
        else
            normals = [rx_cone_normals(inner, tilt_deg/2, azimuth_deg), ...
                rx_cone_normals(K-inner, tilt_deg, azimuth_deg+180/(K-inner))];
        end
    otherwise
        error('cambridge:Pattern', 'Unknown pattern: %s.', pattern);
end
assert(all(normals(3, :)>=cosd(tilt_deg)-1e-12), 'cambridge:TiltLimit', 'Pattern exceeds the requested tilt.');
end
