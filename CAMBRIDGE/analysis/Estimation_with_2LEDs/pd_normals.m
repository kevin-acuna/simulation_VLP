function N = pd_normals(theta_deg, offset_deg, tilt_deg, direction)
% PD_NORMALS  PD normals (3 x K, Z up) at the MTRS angles theta_deg (testbed convention, see
% Experiment_01_3D_estimation): n = [sin(t) sin(a), sin(t) cos(a), cos(t)],  a = direction (theta - offset),
% t = adapter tilt from the vertical. At theta = offset the PD is tilted towards +Y; with direction = +1
% increasing theta turns the tilt from +Y towards +X.
if nargin < 4
    direction = 1;
end
a = direction*(theta_deg(:)' - offset_deg);
N = [sind(tilt_deg)*sind(a); sind(tilt_deg)*cosd(a); cosd(tilt_deg)*ones(size(a))];
end
