function [A, m, xy, info] = pp_calibrate(x_mm, y_mm, rss, xy, h, p, method)
% LED calibration from a horizontal PD scan (psi = phi, cos phi = h / d):
%   log(RSS d^2 / R(phi)) = log A + m log cos(phi)
% 'staged': A from the point closest to the LED axis, m by least squares; 'joint': A and m by least squares;
% 'joint_xy': LED XY too (Nelder-Mead on the joint cost).
if strcmp(method, 'joint_xy')
    cost = @(c) calfit(x_mm, y_mm, rss, c, h, p, 'joint');
    xy = fminsearch(cost, xy, optimset('TolX', 1e-3, 'TolFun', 1e-12, 'Display', 'off'));
    method = 'joint';
end
[value, A, m, phi_max] = calfit(x_mm, y_mm, rss, xy, h, p, method);
info = struct('rms_log', sqrt(value), 'phi_max_deg', phi_max);
end

function [value, A, m, phi_max] = calfit(x_mm, y_mm, rss, xy, h, p, method)
r = hypot(x_mm - xy(1), y_mm - xy(2))/1e3;
d = sqrt(r.^2 + h^2);
c = h./d;
R = rx_receiver_response(c, p);
ok = R > 0 & rss > 0;
Y = log(rss(ok).*d(ok).^2./R(ok));
X = log(c(ok));
switch method
    case 'staged'
        rr = r(ok);
        [~, k] = min(rr);
        logA = Y(k);
        m = sum((Y - logA).*X)/sum(X.^2);
    case 'joint'
        coef = [ones(size(X)) X] \ Y;
        logA = coef(1);
        m = coef(2);
    otherwise
        error('Unknown calibration method %s.', method);
end
A = exp(logA);
value = mean((Y - logA - m*X).^2);
phi_max = acosd(min(c(ok)));
end
