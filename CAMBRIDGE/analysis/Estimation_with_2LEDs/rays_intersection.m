function [r, info] = rays_intersection(anchors, directions, weights)
% RAYS_INTERSECTION  Point closest to N >= 2 lines (weighted least squares of the perpendicular distances).
%   [r, info] = rays_intersection(anchors, directions, weights)
%   anchors    3 x N  a point of every line (e.g. the LED positions)
%   directions 3 x N  direction of every line (normalised here), e.g. the unit vector from the PD to each LED
%   weights    1 x N  optional (default ones)
%   r          3 x 1  minimiser of sum_j w_j |P_j (r - anchors_j)|^2,  P_j = I - u_j u_j'
%   info.range_m       distance from r to every anchor along its line, u_j'(anchors_j - r) (> 0: anchor ahead)
%   info.miss_m        perpendicular distance from r to every line
%   info.min_angle_deg smallest angle between two of the lines (geometry: small angle = poor depth)
%   info.rcond         reciprocal condition number of sum_j w_j P_j (0 = parallel lines)
% Generic: it does not depend on how the directions were obtained (VLP, cameras, AoA...).
N = size(anchors, 2);
assert(size(directions, 2) == N && N >= 2, 'rays_intersection: at least two lines are needed.');
if nargin < 3 || isempty(weights)
    weights = ones(1, N);
end
U = directions./vecnorm(directions);
M = zeros(3);
b = zeros(3, 1);
for j = 1:N
    P = eye(3) - U(:, j)*U(:, j)';
    M = M + weights(j)*P;
    b = b + weights(j)*P*anchors(:, j);
end
info.rcond = rcond(M);
r = M\b;
info.range_m = sum(U.*(anchors - r), 1);
info.miss_m = vecnorm((anchors - r) - U.*info.range_m);
cosines = abs(U'*U);
cosines(logical(eye(N))) = 0;
info.min_angle_deg = acosd(min(1, max(cosines(:))));
end
