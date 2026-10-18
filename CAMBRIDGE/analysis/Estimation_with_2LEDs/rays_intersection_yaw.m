function [r, yaw_deg, info] = rays_intersection_yaw(anchors, body_directions, grid_step_deg)
% RAYS_INTERSECTION_YAW  Position AND yaw from N >= 2 rays whose directions are known only up to an unknown
% rotation about the vertical (Z) axis:  u_j = Rz(yaw) b_j  (Rz counter-clockwise seen from above).
%   [r, yaw_deg, info] = rays_intersection_yaw(anchors, body_directions, grid_step_deg)
%   anchors          3 x N  points of the lines (LED positions, world frame)
%   body_directions  3 x N  directions in the receiver frame (e.g. PD -> LED); their elevation is known
%                           (roll and pitch known), their azimuth is offset by the unknown yaw
%   grid_step_deg    coarse yaw grid (default 1 deg); the best grid point is refined locally
%   r, yaw_deg       position and yaw minimising the sum of squared perpendicular distances to the rays;
%                    for every yaw, r is the least-squares intersection (rays_intersection)
%   info             cost_m2, miss_m, range_m, min_angle_deg (as rays_intersection), second_ratio = cost of
%                    the best competing minimum (> 10 deg away) / best cost, second_yaw_deg, valid
% With 2 rays there are 4 equations (2 per ray) for 4 unknowns (r, yaw); more rays are overdetermined.
% Only physical solutions are kept: positive ranges (anchors ahead of r) and r below all the anchors.
if nargin < 3 || isempty(grid_step_deg)
    grid_step_deg = 1;
end
B = body_directions./vecnorm(body_directions);
grid = 0:grid_step_deg:360 - grid_step_deg;
cost = yaw_cost(anchors, B, grid);
info = struct('cost_m2', nan, 'miss_m', nan, 'range_m', nan, 'min_angle_deg', nan, 'rcond', nan, ...
    'second_ratio', nan, 'second_yaw_deg', nan, 'valid', false);
r = nan(3, 1);
yaw_deg = nan;
if ~any(isfinite(cost))
    return;
end
% local minima on the circular grid, best first
is_min = cost <= cost([end 1:end-1]) & cost <= cost([2:end 1]) & isfinite(cost);
minima = find(is_min);
[~, order] = sort(cost(minima));
minima = minima(order);
refined = nan(size(minima));
refined_cost = nan(size(minima));
for k = 1:numel(minima)
    g = grid(minima(k));
    [refined(k), refined_cost(k)] = fminbnd(@(y) yaw_cost(anchors, B, y), g - grid_step_deg, g + grid_step_deg, ...
        optimset('TolX', 1e-4, 'Display', 'off'));
end
[best_cost, k] = min(refined_cost);
yaw_deg = mod(refined(k), 360);
far = abs(mod(refined - yaw_deg + 180, 360) - 180) > 10;
if any(far)
    [second, k2] = min(refined_cost(far));
    yaws = refined(far);
    info.second_ratio = second/max(best_cost, eps);
    info.second_yaw_deg = mod(yaws(k2), 360);
end
[r, ray_info] = rays_intersection(anchors, rotate_z(B, yaw_deg));
info.cost_m2 = best_cost;
info.miss_m = ray_info.miss_m;
info.range_m = ray_info.range_m;
info.min_angle_deg = ray_info.min_angle_deg;
info.rcond = ray_info.rcond;
info.valid = true;
end

function cost = yaw_cost(L, B, yaws)
% Sum of squared perpendicular distances of the LS intersection, for every yaw (vectorised)
G = numel(yaws);
N = size(L, 2);
c = reshape(cosd(yaws), 1, 1, G);
s = reshape(sind(yaws), 1, 1, G);
M = zeros(3, 3, G);
b = zeros(3, 1, G);
U = zeros(3, N, G);
for j = 1:N
    u = [c*B(1, j) - s*B(2, j); s*B(1, j) + c*B(2, j); repmat(B(3, j), 1, 1, G)];   % 3 x 1 x G
    U(:, j, :) = u;
    M = M + eye(3) - pagemtimes(u, 'none', u, 'transpose');
    b = b + L(:, j) - u.*sum(u.*L(:, j), 1);
end
r = pagemldivide(M, b);                                    % 3 x 1 x G
D = L - r;                                                 % 3 x N x G
t = sum(U.*D, 1);                                          % ranges, 1 x N x G
miss = D - U.*t;
cost = reshape(sum(miss.^2, [1 2]), 1, G);
valid = reshape(all(t > 0, 2) & r(3, 1, :) < min(L(3, :)), 1, G);
cost(~valid) = Inf;
end

function U = rotate_z(B, yaw_deg)
U = [cosd(yaw_deg) -sind(yaw_deg) 0; sind(yaw_deg) cosd(yaw_deg) 0; 0 0 1]*B;
end
