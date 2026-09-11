function normals = rx_cone_normals(K, tilt_deg, azimuth_offset_deg)
if nargin < 3
    azimuth_offset_deg = 0;
end
validateattributes(K, {'numeric'}, {'scalar', 'integer', 'positive'});
validateattributes(tilt_deg, {'numeric'}, {'scalar', 'real', 'finite', '>=', 0, '<=', 90});
normals = rx_normals(tilt_deg, azimuth_offset_deg+(0:K-1)*360/K);
end
