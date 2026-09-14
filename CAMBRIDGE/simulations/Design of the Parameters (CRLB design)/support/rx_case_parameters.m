function [p, normals] = rx_case_parameters(p, c)
p.transmitter.half_angle_power_deg = c.half_angle_deg;
p.receiver.fov_deg = c.fov_deg;
p.receiver.area_m2 = c.area_m2;
switch c.family
    case 'uniform_cone'
        normals = rx_cone_normals(c.K, c.tilt_deg, c.azimuth_offset_deg);
    case 'explicit'
        normals = c.normals;
    otherwise
        error('cambridge:OrientationFamily', 'Choose uniform_cone or explicit orientations.');
end
validateattributes(normals, {'numeric'}, {'real', 'finite', '2d', 'nrows', 3, 'ncols', c.K});
assert(all(normals(3, :)>=cosd(p.receiver.max_tilt_deg)-1e-12), ...
    'cambridge:TiltLimit', 'A case exceeds the receiver tilt limit.');
end
