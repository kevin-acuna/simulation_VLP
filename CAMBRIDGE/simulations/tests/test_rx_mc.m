function tests = test_rx_mc
tests = functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
end

function testSmallComparisonIsReproducible(t)
p = rx_test_parameters();
p.environment.x_m = [-0.2 0.2];
p.environment.y_m = 0;
p.environment.z_m = 0.6;
n = rx_cone_normals(7, 25);
e = struct('trials', 20, 'seed', 42, 'methods', {{'LS', 'GLS', 'WLS', 'NLS'}}, ...
    'budget', 'per_orientation', 'solver', struct());
state = rng;
a = rx_monte_carlo(p, p, n, e);
b = rx_monte_carlo(p, p, n, e);
verifyEqual(t, rng, state);
verifyEqual(t, a.rss_W, b.rss_W);
verifyEqual(t, a.errors_m, b.errors_m);
verifyTrue(t, all(a.success, 'all'));
verifyEqual(t, a.errors_m(:, :, 1), a.errors_m(:, :, 4), 'AbsTol', 2e-8);
verifyEqual(t, height(a.table), 4);
end

function testFailureStatisticsAreNotSilentlyRenormalized(t)
r.errors_m = reshape([0.1 Inf 0.3], 1, 3, 1);
r.direction_errors_deg = r.errors_m;
r.range_errors_m = r.errors_m;
r.estimates_m = nan(3, 1, 3, 1);
r.positions_m = [0; 0; 0];
r.peb_m = 0.01;
r.experiment.methods = {'LS'};
r = rx_mc_metrics(r);
verifyEqual(t, r.table.RMSE_full_cm, Inf);
verifyEqual(t, r.table.RMSE_success_cm, 100*sqrt(0.05), 'RelTol', 1e-12);
verifyEqual(t, r.table.Failure_percent, 100/3, 'AbsTol', 1e-12);
[x, probability] = rx_empirical_cdf([0.1 Inf 0.3]);
verifyEqual(t, x, [0; 0.1; 0.3]);
verifyEqual(t, probability, [0; 1/3; 2/3]);
end

function testPartialVisibilityIsRejectedBeforeBenchmark(t)
p = rx_test_parameters();
p.environment.x_m = 0;
p.environment.y_m = 0;
p.environment.z_m = 0.5;
p.receiver.fov_deg = 30;
e = struct('trials', 10, 'seed', 42, 'methods', {{'LS'}}, 'budget', 'per_orientation', 'solver', struct());
verifyError(t, @() rx_monte_carlo(p, p, rx_cone_normals(7, 40), e), 'cambridge:BenchmarkVisibility');
end

function testGeneralizedNLSDoesNotIncreaseRSSObjective(t)
p = rx_test_parameters();
p.receiver.m_R = 2;
n = rx_cone_normals(9, 30);
y = rx_channel([0.3; -0.1; 0.5], n, p)+1e-8*[1; -1; 0.3; 0.2; -0.6; 1.2; -0.3; 0.7; -0.4];
[~, a] = rx_estimate_ls(y, n, p);
[~, b] = rx_estimate_nls(y, n, p);
verifyTrue(t, a.success && b.success);
verifyLessThanOrEqual(t, b.objective, a.objective+1e-8);
end
