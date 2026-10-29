function [value, offset] = pp_shape(mode, truth, theta, rss, sel, offset_deg, tilt_deg, p)
% RSS-shape test at the true positions: rms (%) of RSS_k / R(psi_k) around its per-site mean. It does not
% depend on A, m or the LED pattern (common to the K orientations of a site).
% mode 'rms': value of the test; mode 'fit': MTRS offset minimising it (Nelder-Mead from offset_deg).
switch mode
    case 'rms'
        value = shape_rms(truth, theta, rss, sel, offset_deg, tilt_deg, p);
        offset = offset_deg;
    case 'fit'
        cost = @(o) shape_rms(truth, theta, rss, sel, o, tilt_deg, p);
        offset = fminsearch(cost, offset_deg, optimset('TolX', 1e-4, 'TolFun', 1e-10, 'Display', 'off'));
        value = cost(offset);
    otherwise
        error('mode must be ''rms'' or ''fit''.');
end
end

function value = shape_rms(truth, theta, rss, sel, offset_deg, tilt_deg, p)
deviation = [];
for i = find(sel)
    N = pp_normals(theta(:, i), offset_deg, tilt_deg);
    v = p.transmitter.position_m - truth(:, i);
    R = rx_receiver_response(N'*(v/norm(v)), p);
    if any(R <= 0)
        value = Inf;
        return;
    end
    ratio = rss(:, i)./R;
    deviation = [deviation; ratio/mean(ratio) - 1]; %#ok<AGROW>
end
value = 100*sqrt(mean(deviation.^2));
end
