function [u, status] = led_direction(rss, normals, p, method)
% LED_DIRECTION  Direction of one LED (unit vector from the PD to the LED) from its K RSS.
%   [u, status] = led_direction(rss, normals, p, method)
%   rss      K x 1  RSS of the LED at the K PD orientations (any unit: only the shape is used)
%   normals  3 x K  PD normals (Z up)
%   p        parameters of CAMBRIDGE/simulations with the PD response (e.g. SQ of the PDA100A2)
%   method   'joint_nls' (free amplitude) | 'ratio_gls' | 'ratio_wls' (RSS ratios), as in pd_fit_estimate
% Only the variation of the RSS over the orientations is used, so the direction does NOT depend on the LED
% position, its power, the receiver gain, the calibration constant A or the Lambertian order m.
% pd_fit_estimate also returns a range with the LED of p; it is ignored here. u = NaN if the fit fails.
[~, info] = pd_fit_estimate(method, rss(:), normals, p, 1);
u = info.direction;
status = info.status;
end
