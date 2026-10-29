function E = pp_estimate(model, method, rss, theta, offset_deg, tilt_deg, p)
% Position estimates of every site (columns of rss, K x S) with the estimators of the simulation library.
% SQ: pd_fit_estimate (joint NLS of direction + amplitude, nonlinear ratio GLS / WLS); cosine families:
% rx_estimate (NLS-TCOM, ratio GLS / WLS). Range in closed form from the same RSS (inside the estimators).
% offset_deg may be a scalar or one value per site. Also returns the RSS-shape residual of the fit (%).
S = size(rss, 2);
if isscalar(offset_deg)
    offset_deg = repmat(offset_deg, 1, S);
end
E = struct('r', nan(3, S), 'u', nan(3, S), 'd', nan(1, S), 'ok', false(1, S), 'status', strings(1, S), ...
    'shape_rms', nan(1, S), 'beta', nan(1, S));
for i = 1:S
    N = pp_normals(theta(:, i), offset_deg(i), tilt_deg);
    if strcmp(model, 'SQ')
        name = struct('GLS', 'ratio_gls', 'WLS', 'ratio_wls', 'NLS', 'joint_nls').(method);
        [r, info] = pd_fit_estimate(name, rss(:, i), N, p, 1);
    else
        name = struct('GLS', 'GLS', 'WLS', 'WLS', 'NLS', 'NLS_TCOM').(method);
        [r, info] = rx_estimate(name, rss(:, i), N, p, 1);
    end
    E.status(i) = info.status;
    if ~info.success
        continue;
    end
    E.r(:, i) = r;
    E.u(:, i) = info.direction;
    E.d(i) = info.distance_m;
    E.ok(i) = true;
    h = rx_receiver_response(N'*info.direction, p);
    beta = sum(rss(:, i).*h)/sum(h.^2);
    E.beta(i) = beta;
    E.shape_rms(i) = 100*sqrt(mean((rss(:, i)./(beta*h) - 1).^2));
end
end
