function r = rx_sensitivity_run(p, normals, e, variance_deg2)
assert(any(strcmp(e.mode, {'pose_measurement', 'actuation'})), 'cambridge:SensitivityMode', 'Unknown sensitivity mode.');
if strcmp(e.mode, 'actuation')
    assert(strcmp(e.structure, 'independent'), 'cambridge:ActuationStructure', 'The actuation approximation currently supports independent errors.');
end
[r.positions_m, r.grid] = rx_testbed(p);
P = size(r.positions_m, 2);
K = size(normals, 2);
M = numel(e.methods);
counts = rx_sample_counts(K, p, e.budget);
[r.nominal_peb_m, info] = rx_peb(r.positions_m, normals, p, counts);
assert(all(info.visible, 'all') && all(isfinite(r.nominal_peb_m)), 'cambridge:BenchmarkVisibility', ...
    'Use a nominal codebook/ROI with complete visibility and rank three.');
if strcmp(e.mode, 'pose_measurement')
    r.peb_m = rx_pose_error_peb(r.positions_m, normals, p, counts, variance_deg2, e.structure);
    r.bound_label = 'Pose-nuisance PEB';
else
    r.peb_m = rx_actuation_peb(r.positions_m, normals, p, counts, variance_deg2);
    r.bound_label = 'Gaussian moment PEB (approx.)';
end
r.parameters = p;
r.normals = normals;
r.experiment = e;
r.orientation_variance_deg2 = variance_deg2;
r.sample_counts = counts;
r.estimates_m = nan(3, P, e.trials, M);
r.errors_m = inf(P, e.trials, M);
r.direction_errors_deg = inf(P, e.trials, M);
r.range_errors_m = nan(P, e.trials, M);
r.success = false(P, e.trials, M);
r.status = strings(P, e.trials, M);
r.perturbed_normals = nan(3, K, e.trials, P);
r.pose_coordinates_rad = cell(1, P);
r.rss_W = nan(K, e.trials, P);
r.visibility_disagreement = false(P, e.trials);
previous = rng;
cleanup = onCleanup(@() rng(previous));
rng(e.seed, 'twister');
noise = sqrt(p.noise.variance_W2./counts).*randn(K, e.trials, P);
for ip = 1:P
    [perturbed, coordinates] = rx_perturb_normals(normals, variance_deg2, e.structure, e.trials);
    r.perturbed_normals(:, :, :, ip) = perturbed;
    r.pose_coordinates_rad{ip} = coordinates;
    for trial = 1:e.trials
        if strcmp(e.mode, 'pose_measurement')
            mean_W = info.mean_W(:, ip);
            assumed_normals = perturbed(:, :, trial);
            actual_visible = info.visible(:, ip);
        else
            mean_W = rx_channel(r.positions_m(:, ip), perturbed(:, :, trial), p);
            assumed_normals = normals;
            actual_visible = mean_W>0;
        end
        y = mean_W+noise(:, trial, ip);
        r.rss_W(:, trial, ip) = y;
        s = assumed_normals'*info.direction_rx_to_tx(:, ip);
        r.visibility_disagreement(ip, trial) = any(actual_visible~=(s>0 & s>=cosd(p.receiver.fov_deg)));
        for im = 1:M
            [estimate, result] = rx_estimate(e.methods{im}, y, assumed_normals, p, counts, e.solver);
            r.estimates_m(:, ip, trial, im) = estimate;
            r.success(ip, trial, im) = result.success;
            r.status(ip, trial, im) = result.status;
            if result.success
                r.errors_m(ip, trial, im) = norm(estimate-r.positions_m(:, ip));
                cosine = info.direction_rx_to_tx(:, ip)'*result.direction;
                r.direction_errors_deg(ip, trial, im) = acosd(max(-1, min(1, cosine)));
                r.range_errors_m(ip, trial, im) = result.distance_m-info.distance_m(ip);
            end
        end
    end
end
r.visibility_disagreement_fraction = mean(r.visibility_disagreement, 'all');
r = rx_mc_metrics(r);
end
