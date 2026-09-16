function [positions, info] = rx_estimate(method, mean_W, normals, p, counts, options)
if nargin < 5
    counts = [];
end
if nargin < 6
    options = struct();
end
method = upper(char(method));
assert(any(strcmp(method, {'LS', 'GLS', 'WLS', 'NLS'})), 'cambridge:EstimatorMethod', 'Choose LS, GLS, WLS or NLS.');
validateattributes(mean_W, {'numeric'}, {'real', 'finite', '2d', 'nrows', size(normals, 2)});
a = rx_estimator_context(normals, p, counts, options);
trials = size(mean_W, 2);
positions = nan(3, trials);
info = struct('success', false(1, trials), 'status', repmat("rank_deficient", 1, trials), ...
    'direction', nan(3, trials), 'distance_m', nan(1, trials), 'amplitude_W', nan(1, trials), ...
    'optical_vector_normalized', nan(3, trials), 'power_scale_W', nan(1, trials), ...
    'objective', nan(1, trials), 'iterations', zeros(1, trials), 'method', method);
if ~a.identifiable
    return;
end
for j = 1:trials
    scale = max(abs(mean_W(:, j)));
    if scale<=0
        info.status(j) = "zero_power_vector";
        continue;
    end
    y = mean_W(:, j)/scale;
    switch method
        case 'LS'
            [v, status] = rx_optical_ls(y, a);
        case {'GLS', 'WLS'}
            [u, detail] = rx_ratio_direction(y, a, strcmp(method, 'GLS'));
            status = detail.status;
            v = nan(3, 1);
            if status=="success"
                beta = rx_profile_amplitude(y, u, a);
                if isfinite(beta)
                    v = beta^(1/a.order)*u;
                else
                    status = "nonpositive_amplitude";
                end
            end
        case 'NLS'
            [v, status, info.iterations(j)] = rx_optical_nls(y, a);
    end
    info.status(j) = status;
    if status~="success" || ~rx_optical_domain(v, a)
        continue;
    end
    [position, u, beta, distance] = rx_optical_position(v, scale, p);
    if ~all(isfinite(position)) || distance<=0 || beta<=0
        info.status(j) = "invalid_distance";
        continue;
    end
    positions(:, j) = position;
    info.success(j) = true;
    info.direction(:, j) = u;
    info.distance_m(j) = distance;
    info.amplitude_W(j) = beta;
    info.optical_vector_normalized(:, j) = v;
    info.power_scale_W(j) = scale;
    residual = scale*(a.H*v).^a.order-mean_W(:, j);
    info.objective(j) = sum(residual.^2./a.variance);
end
end
