function cases = rx_cone_cases(p, half_angles_deg, tilts_deg, K)
validateattributes(half_angles_deg, {'numeric'}, {'real', 'finite', 'vector', 'nonempty', '>', 0, '<', 90});
count = numel(half_angles_deg);
if isscalar(tilts_deg)
    tilts_deg = repmat(tilts_deg, 1, count);
end
if isscalar(K)
    K = repmat(K, 1, count);
end
validateattributes(tilts_deg, {'numeric'}, {'real', 'finite', 'numel', count, '>=', 0, '<=', p.receiver.max_tilt_deg});
validateattributes(K, {'numeric'}, {'integer', 'positive', 'numel', count});
items = cell(1, count);
for i = 1:count
    items{i} = struct('label', sprintf('\\Phi_{1/2} = %g deg', half_angles_deg(i)), ...
        'half_angle_deg', half_angles_deg(i), 'fov_deg', p.receiver.fov_deg, ...
        'area_m2', p.receiver.area_m2, 'm_R', rx_receiver_order(p), 'K', K(i), 'tilt_deg', tilts_deg(i), ...
        'azimuth_offset_deg', p.design.azimuth_offset_deg, 'family', 'uniform_cone', ...
        'normals', rx_cone_normals(K(i), tilts_deg(i), p.design.azimuth_offset_deg));
end
cases = [items{:}];
end
