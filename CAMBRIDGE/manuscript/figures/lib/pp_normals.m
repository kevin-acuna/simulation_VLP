function N = pp_normals(theta_deg, offset_deg, tilt_deg)
% PD normals (3 x K, Z up) at MTRS angles theta_deg: n = [sin t sin a, sin t cos a, cos t], a = theta - offset.
% At theta = offset the PD is tilted towards +Y; increasing theta turns it towards +X.
a = theta_deg(:)' - offset_deg;
N = [sind(tilt_deg)*sind(a); sind(tilt_deg)*cosd(a); cosd(tilt_deg)*ones(size(a))];
end
