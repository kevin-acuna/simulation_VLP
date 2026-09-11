function tests = test_rx_bounds
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'System'), fullfile(root, 'System', 'Parameters'));
addpath(fullfile(root, 'Bounds (3D)', 'Position Error Bound'));
addpath(fullfile(root, 'Design of the Parameters (CRLB design)'));
testCase.TestData.p = system_parameters();
end

function testGradientCentralDifferences(testCase)
p = testCase.TestData.p;
n = rx_normals([12 24 35 48 57], [3 75 150 235 300]);
r = [0.13 -0.21 0.41; -0.17 0.12 0.05; 0.3 0.7 0.9];
for half = p.design.half_angles_deg
    p.transmitter.half_angle_power_deg = half;
    [~, J, info] = rx_channel(r, n, p);
    verifyFalse(testCase, any(info.boundary));
    numerical = zeros(size(J));
    h = 1e-5;
    for j = 1:3
        step = zeros(3, 1);
        step(j) = h;
        delta = (rx_channel(r + step, n, p) - rx_channel(r - step, n, p))/(2*h);
        numerical(:, j, :) = reshape(delta, size(n, 2), 1, []);
    end
    verifyLessThan(testCase, norm(J(:)-numerical(:))/norm(J(:)), 2e-8);
end
end

function testAxialClosedForm(testCase)
p = testCase.TestData.p;
theta = atan(2)*180/pi;
K = 9;
r = [0; 0; 0.4];
for half = p.design.half_angles_deg
    p.transmitter.half_angle_power_deg = half;
    [peb, info] = rx_peb(r, rx_cone_normals(K, theta), p);
    m = -log(2)/log(cosd(half));
    C = p.transmitter.power_W*(m+1)*p.receiver.area_m2/(2*pi);
    d = norm(p.transmitter.position_m-r);
    expected = sqrt(p.noise.variance_W2*d^6/(p.acquisition.samples_per_orientation*C^2*K) ...
        *(4/sind(theta)^2+1/(4*cosd(theta)^2)));
    verifyEqual(testCase, peb, expected, 'RelTol', 1e-12);
    verifyEqual(testCase, trace(info.covariance_m2), peb^2, 'RelTol', 1e-12);
    verifyLessThan(testCase, peb, rx_peb(r, rx_cone_normals(K, theta-0.1), p));
    verifyLessThan(testCase, peb, rx_peb(r, rx_cone_normals(K, theta+0.1), p));
end
end

function testRankAndMinimumK(testCase)
p = testCase.TestData.p;
r = [0; 0; 0.5];
for K = 1:2
    verifyEqual(testCase, rx_peb(r, rx_cone_normals(K, 40), p), Inf);
end
verifyEqual(testCase, rx_peb(r, rx_cone_normals(9, 0), p), Inf);
verifyTrue(testCase, isfinite(rx_peb(r, rx_cone_normals(3, 40), p)));
n = rx_normals([10 25 40 60], [0 0 0 0]);
[peb, info] = rx_peb(r, n, p);
verifyEqual(testCase, peb, Inf);
verifyEqual(testCase, info.rank, 2);
end

function testVisibilityAndBoundary(testCase)
p = testCase.TestData.p;
p.receiver.fov_deg = 45;
r = [0; 0; 0.6];
[peb, info] = rx_peb(r, rx_cone_normals(5, 45), p);
verifyTrue(testCase, isnan(peb));
verifyTrue(testCase, info.boundary);
[peb, info] = rx_peb(r, rx_cone_normals(5, 46), p);
verifyEqual(testCase, peb, Inf);
verifyEqual(testCase, info.visible_count, 0);
verifyEqual(testCase, info.mean_W, zeros(5, 1));
verifyEqual(testCase, info.jacobian_W_per_m, zeros(5, 3));
verifyTrue(testCase, isfinite(rx_peb(r, rx_cone_normals(5, 44), p)));
verifyEqual(testCase, rx_peb(r, rx_cone_normals(5, 90), p), Inf);
p.receiver.fov_deg = 85;
[peb, info] = rx_peb([0; 0; 2.5], rx_cone_normals(5, 40), p);
verifyEqual(testCase, peb, Inf);
verifyTrue(testCase, all(isfinite(info.jacobian_W_per_m(:))));
verifyError(testCase, @() rx_peb(p.transmitter.position_m, rx_cone_normals(5, 40), p), 'cambridge:CoincidentPosition');
end

function testScalingsAndBudgets(testCase)
p = testCase.TestData.p;
n = rx_cone_normals(9, 40);
r = [0.1; 0.2; 0.4];
baseline = rx_peb(r, n, p);
p2 = p;
p2.receiver.area_m2 = 2*p.receiver.area_m2;
verifyEqual(testCase, rx_peb(r, n, p2), baseline/2, 'RelTol', 1e-12);
p2 = p;
p2.transmitter.power_W = 2*p.transmitter.power_W;
verifyEqual(testCase, rx_peb(r, n, p2), baseline/2, 'RelTol', 1e-12);
p2 = p;
p2.noise.variance_W2 = 4*p.noise.variance_W2;
verifyEqual(testCase, rx_peb(r, n, p2), baseline*2, 'RelTol', 1e-12);
verifyEqual(testCase, rx_peb(r, n, p, 4000), baseline/2, 'RelTol', 1e-12);
verifyEqual(testCase, rx_peb(r, rx_cone_normals(3, 40), p, 3000), baseline, 'RelTol', 1e-12);
N = rx_sample_counts(7, p, 'fixed_total');
verifyEqual(testCase, sum(N), p.acquisition.total_samples);
verifyLessThanOrEqual(testCase, max(N)-min(N), 1);
end

function testFovAndNestedInformation(testCase)
p = testCase.TestData.p;
n = rx_cone_normals(9, 35);
r = [0.4; 0.1; 0.6];
p.receiver.fov_deg = 65;
[a, ia] = rx_peb(r, n, p);
p.receiver.fov_deg = 85;
[b, ib] = rx_peb(r, n, p);
verifyLessThanOrEqual(testCase, b, a*(1+1e-12));
verifyGreaterThanOrEqual(testCase, min(eig(ib.fim_per_m2-ia.fim_per_m2)), -1e-8);
extra = [n, rx_normals(20, 10)];
verifyLessThanOrEqual(testCase, rx_peb(r, extra, p), b*(1+1e-12));
p.receiver.fov_deg = 80;
verifyEqual(testCase, rx_peb([0; 0; 0.6], n, p), ...
    rx_peb([0; 0; 0.6], n, testCase.TestData.p), 'RelTol', 1e-12);
end

function testUnknownGainAndOffset(testCase)
p = testCase.TestData.p;
r = [0.2; -0.1; 0.5];
n = rx_cone_normals(9, 35);
[~, info] = rx_peb(r, n, p);
mu = info.mean_W;
J = info.jacobian_W_per_m;
u = (p.transmitter.position_m-r)/norm(p.transmitter.position_m-r);
projected = J-mu*((mu'*J)/(mu'*mu));
verifyLessThan(testCase, norm(projected*u)/norm(J), 1e-12);
verifyEqual(testCase, rank(projected, 1e-10*norm(projected)), 2);
verifyEqual(testCase, rank([n', ones(9, 1)]), 3);
varied = [n, [0; 0; 1]];
verifyEqual(testCase, rank([varied', ones(10, 1)]), 4);
end

function testLinearFactorizationAndRankWithClipping(testCase)
p = testCase.TestData.p;
p.receiver.fov_deg = 60;
n = rx_cone_normals(9, 45);
r = [1.1; 0.2; 0.8];
[peb, info] = rx_peb(r, n, p);
u = info.direction_rx_to_tx;
d = info.distance_m;
c = info.emission_cosine;
m = info.lambertian_order;
beta = info.radiometric_constant_W_m2*c^m/d^2;
B = -beta/d*(eye(3)+u*(m*(-p.transmitter.normal)'/c-(m+3)*u'));
active = info.visible;
verifyEqual(testCase, info.jacobian_W_per_m(active, :), n(:, active)'*B, 'AbsTol', 1e-20);
verifyEqual(testCase, info.rank, rank(n(:, active)));
verifyEqual(testCase, det(B), 2*(beta/d)^3, 'RelTol', 1e-12);
verifyTrue(testCase, isfinite(peb));
verifyGreaterThan(testCase, nnz(~active), 0);
end

function testRigidFrameInvariance(testCase)
p = testCase.TestData.p;
n = rx_cone_normals(7, 40);
r = [0.2; 0.1; 0.7];
Q = [cosd(23) 0 sind(23); 0 1 0; -sind(23) 0 cosd(23)];
shift = [0.3; -0.2; 0.5];
[a, ia] = rx_peb(r, n, p);
p.transmitter.position_m = Q*p.transmitter.position_m+shift;
p.transmitter.normal = Q*p.transmitter.normal;
[b, ib] = rx_peb(Q*r+shift, Q*n, p);
verifyEqual(testCase, a, b, 'RelTol', 1e-12);
verifyEqual(testCase, ib.fim_per_m2, Q*ia.fim_per_m2*Q', 'RelTol', 1e-10, 'AbsTol', 1e-8);
end

function testNoiselessAndHighSnrReconstruction(testCase)
p = testCase.TestData.p;
p.noise.variance_W2 = p.noise.variance_W2/100;
n = rx_cone_normals(9, 40);
r = [0.2; -0.1; 0.6];
[peb, info] = rx_peb(r, n, p);
[estimated, valid] = rx_position_gls(info.mean_W, n, p);
verifyTrue(testCase, valid);
verifyEqual(testCase, estimated, r, 'AbsTol', 2e-14);
previous = rng;
restore = onCleanup(@() rng(previous));
rng(271828, 'twister');
trials = 30000;
y = info.mean_W+sqrt(p.noise.variance_W2/p.acquisition.samples_per_orientation)*randn(9, trials);
[estimated, valid] = rx_position_gls(y, n, p);
verifyTrue(testCase, all(valid));
errors = estimated-r;
rmse = sqrt(mean(sum(errors.^2, 1)));
verifyLessThan(testCase, abs(rmse/peb-1), 0.025);
verifyLessThan(testCase, norm(mean(errors, 2))/peb, 0.025);
verifyLessThan(testCase, norm(cov(errors')-info.covariance_m2, 'fro')/norm(info.covariance_m2, 'fro'), 0.04);
end

function testAggregationDoesNotHideOutages(testCase)
a = rx_design_metrics([0.01 0.02 Inf NaN]);
verifyEqual(testCase, a.coverage, 0.5);
verifyEqual(testCase, a.rms_full_m, Inf);
verifyEqual(testCase, a.rms_conditional_m, sqrt(0.00025), 'AbsTol', 1e-15);
a = rx_design_metrics([Inf NaN]);
verifyEqual(testCase, a.coverage, 0);
verifyTrue(testCase, isnan(a.rms_conditional_m));
end

function testDesignPipelineAndInfeasibleGrid(testCase)
p = testCase.TestData.p;
p.environment.x_m = [-0.2 0.2];
p.environment.y_m = [-0.2 0.2];
p.environment.z_m = 0.5;
p.environment.validation_x_m = [-0.2 0 0.2];
p.environment.validation_y_m = [-0.2 0 0.2];
p.environment.validation_z_m = 0.5;
p.design.half_angles_deg = [60 75];
p.design.fov_values_deg = 85;
p.design.tilt_values_deg = [20 40];
p.design.K_values = [3 4 5];
p.design.area_values_mm2 = [26.4 100];
p.design.refinement_steps_deg = 1;
p.design.refinement_passes = 1;
p.output.export_figures = false;
p.output.heatmap_step_m = 0.2;
output_dir = tempname;
mkdir(output_dir);
cleanup = onCleanup(@() rmdir(output_dir, 's'));
r = run_parameter_design(p, output_dir);
verifyEqual(testCase, numel(r.best), 2);
verifyTrue(testCase, isfile(fullfile(output_dir, 'design_results.mat')));
verifyTrue(testCase, isfile(fullfile(output_dir, 'best_configurations.csv')));
for b = r.best
    verifyEqual(testCase, b.metrics.coverage, 1);
    verifyLessThanOrEqual(testCase, b.metrics.rms_full_m, b.refinement.cone_rms_m*(1+1e-12));
    verifyEqual(testCase, b.area_minimum_peb_mm2, 100);
end
p.design.tilt_values_deg = 0;
verifyError(testCase, @() run_parameter_design(p, output_dir), 'cambridge:NoFullCoverage');
end

function testBatchAndUnequalCounts(testCase)
p = testCase.TestData.p;
n = rx_cone_normals(5, 40);
r = [0.2 -0.3; 0.1 0.2; 0.4 0.9];
N = [100 200 300 400 500];
[batch, info] = rx_peb(r, n, p, N);
for i = 1:size(r, 2)
    verifyEqual(testCase, batch(i), rx_peb(r(:, i), n, p, N), 'RelTol', 1e-12);
    J = info.jacobian_W_per_m(:, :, i);
    expected = J'*(J.*(N(:)/p.noise.variance_W2));
    verifyEqual(testCase, info.fim_per_m2(:, :, i), expected, 'RelTol', 1e-12);
end
end
