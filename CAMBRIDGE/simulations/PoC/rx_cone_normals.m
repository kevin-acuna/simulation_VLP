function N = rx_cone_normals(axis, theta_c_deg, K, phi0_deg, add_axis)
%RX_CONE_NORMALS  K PD normals on a cone of half-angle theta_c around a given axis.
%   N = rx_cone_normals(axis, theta_c_deg, K, phi0_deg, add_axis)
%   axis       : 3x1 unit vector (cone axis, e.g. [0;0;1] body-vertical or the
%                estimated LED direction u_hat for the LED-centred design)
%   theta_c_deg: cone half-angle [deg]
%   K          : number of orientations on the cone (uniform in azimuth)
%   phi0_deg   : azimuth offset of the first orientation [deg] (default 0)
%   add_axis   : if true, appends the axis itself as an extra orientation
%   N          : (K or K+1) x 3 matrix of unit normals (rows)
if nargin < 4 || isempty(phi0_deg), phi0_deg = 0; end
if nargin < 5, add_axis = false; end
axis = axis(:) / norm(axis);
% Orthonormal basis of the plane perpendicular to the axis
e1 = cross(axis, [0; 0; 1]);
if norm(e1) < 1e-9, e1 = cross(axis, [1; 0; 0]); end
e1 = e1 / norm(e1);
e2 = cross(axis, e1);
az = phi0_deg + (0:K-1) * 360 / K;
N = zeros(K, 3);
for k = 1:K
    N(k, :) = (cosd(theta_c_deg) * axis + sind(theta_c_deg) * (cosd(az(k)) * e1 + sind(az(k)) * e2))';
end
if add_axis, N = [N; axis']; end
end
