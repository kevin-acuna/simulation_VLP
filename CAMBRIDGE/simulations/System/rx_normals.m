function normals = rx_normals(tilt_deg, azimuth_deg)
validateattributes(tilt_deg, {'numeric'}, {'real', 'finite', 'vector', '>=', 0, '<=', 180});
validateattributes(azimuth_deg, {'numeric'}, {'real', 'finite', 'vector'});
tilt_deg = tilt_deg(:)';
azimuth_deg = azimuth_deg(:)';
assert(numel(tilt_deg) == numel(azimuth_deg) || isscalar(tilt_deg) || isscalar(azimuth_deg), ...
    'cambridge:AngleSizes', 'Tilt and azimuth must have compatible lengths.');
x = sind(tilt_deg).*cosd(azimuth_deg);
y = sind(tilt_deg).*sind(azimuth_deg);
z = cosd(tilt_deg)+zeros(size(x));
normals = [x; y; z];
end
