function r = rx_monte_carlo(truth, assumed, normals, e)
validateattributes(e.trials, {'numeric'}, {'scalar', 'integer', '>', 1});
[r.positions_m, r.grid] = rx_testbed(truth);
P = size(r.positions_m, 2);
K = size(normals, 2);
M = numel(e.methods);
counts = rx_sample_counts(K, truth, e.budget);
[r.peb_m, channel] = rx_peb(r.positions_m, normals, truth, counts);
assert(all(channel.visible, 'all') && all(isfinite(r.peb_m)), 'cambridge:BenchmarkVisibility', ...
    'The common LS/GLS/WLS/NLS benchmark requires complete visibility and rank three. Narrow the ROI or change the codebook/FOV.');
r.truth = truth;
r.assumed = assumed;
r.normals = normals;
r.experiment = e;
r.sample_counts = counts;
r.mean_W = channel.mean_W;
r.rss_W = nan(K, e.trials, P);
r.estimates_m = nan(3, P, e.trials, M);
r.errors_m = inf(P, e.trials, M);
r.direction_errors_deg = inf(P, e.trials, M);
r.range_errors_m = nan(P, e.trials, M);
r.success = false(P, e.trials, M);
r.status = strings(P, e.trials, M);
r.objective = nan(P, e.trials, M);
r.iterations = zeros(P, e.trials, M);
r.compute_seconds = zeros(1, M);
previous = rng;
cleanup = onCleanup(@() rng(previous));
rng(e.seed, 'twister');
for ip = 1:P
    y = channel.mean_W(:, ip)+sqrt(truth.noise.variance_W2./counts).*randn(K, e.trials);
    r.rss_W(:, :, ip) = y;
    for im = 1:M
        started = tic;
        [estimates, info] = rx_estimate(e.methods{im}, y, normals, assumed, counts, e.solver);
        r.compute_seconds(im) = r.compute_seconds(im)+toc(started);
        r.estimates_m(:, ip, :, im) = reshape(estimates, 3, 1, e.trials);
        good = info.success;
        r.errors_m(ip, good, im) = sqrt(sum((estimates(:, good)-r.positions_m(:, ip)).^2, 1));
        cosine = channel.direction_rx_to_tx(:, ip)'*info.direction(:, good);
        r.direction_errors_deg(ip, good, im) = acosd(max(-1, min(1, cosine)));
        r.range_errors_m(ip, good, im) = info.distance_m(good)-channel.distance_m(ip);
        r.success(ip, :, im) = good;
        r.status(ip, :, im) = info.status;
        r.objective(ip, :, im) = info.objective;
        r.iterations(ip, :, im) = info.iterations;
    end
end
r = rx_mc_metrics(r);
end
