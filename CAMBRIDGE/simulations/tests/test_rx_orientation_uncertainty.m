function tests = test_rx_orientation_uncertainty
tests = functiontests(localfunctions);
end

function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
t.TestData.p = rx_test_parameters();
end

function testZeroUncertaintyAndMonotonicPoseBound(t)
p = t.TestData.p;
n = rx_cone_normals(7, 20);
r = [0.2 -0.3; 0.1 0.2; 0.4 0.8];
for order = [0.5 1 2]
    p.receiver.m_R = order;
    for structure = {'independent', 'common_rotation'}
        previous = rx_peb(r, n, p);
        verifyEqual(t, rx_pose_error_peb(r, n, p, 1000, 0, structure{1}), previous, 'RelTol', 1e-12);
        for variance = [0.001 0.01 0.1 1]
            value = rx_pose_error_peb(r, n, p, 1000, variance, structure{1});
            verifyTrue(t, all(value>=previous*(1-1e-12)));
            previous = value;
        end
    end
end
end

function testSchurComplementMatchesEffectiveCovariance(t)
p = t.TestData.p;
p.receiver.m_R = 2;
n = rx_cone_normals(5, 25);
r = [0.2; -0.1; 0.6];
variance = 0.04;
[~, detail] = rx_pose_error_peb(r, n, p, 1000, variance, 'independent');
[~, J] = rx_channel(r, n, p);
D = detail.pose_jacobian{1};
W = eye(5)*1000/p.noise.variance_W2;
A = J'*W*J;
B = J'*W*D;
C = D'*W*D+eye(10)/(variance*(pi/180)^2);
expected = A-B*(C\B');
verifyLessThan(t, norm(detail.fim_per_m2-expected, 'fro')/norm(expected, 'fro'), 1e-10);
end

function testMomentDerivativesAndZeroVariance(t)
p = t.TestData.p;
n = rx_cone_normals(7, 25);
r = [0.2; -0.15; 0.6];
for order = [0.5 1 2 3]
    p.receiver.m_R = order;
    [mu, v, J, V] = rx_actuation_moments(r, n, p, 1000, 0.04);
    numeric_J = zeros(7, 3);
    numeric_V = zeros(7, 3);
    for j = 1:3
        step = zeros(3, 1); step(j) = 1e-5;
        [a, b] = rx_actuation_moments(r+step, n, p, 1000, 0.04);
        [c, d] = rx_actuation_moments(r-step, n, p, 1000, 0.04);
        numeric_J(:, j) = (a-c)/(2e-5);
        numeric_V(:, j) = (b-d)/(2e-5);
    end
    verifyTrue(t, all(mu>0 & v>0));
    verifyLessThan(t, norm(J-numeric_J, 'fro')/norm(J, 'fro'), 1e-7);
    verifyLessThan(t, norm(V-numeric_V, 'fro')/norm(V, 'fro'), 1e-6);
    verifyEqual(t, rx_actuation_peb(r, n, p, 1000, 0), rx_peb(r, n, p), 'RelTol', 1e-12);
end
end

function testPerturbationPreservesUnitNormals(t)
n = rx_cone_normals(7, 15);
state = rng; cleanup = onCleanup(@() rng(state));
rng(11);
for structure = {'independent', 'common_rotation'}
    generated = rx_perturb_normals(n, 0.25, structure{1}, 20);
    verifyEqual(t, sum(generated.^2, 1), ones(1, 7, 20), 'AbsTol', 1e-13);
    zero = rx_perturb_normals(n, 0, structure{1}, 2);
    verifyEqual(t, zero, repmat(n, 1, 1, 2), 'AbsTol', 1e-15);
end
verifyEqual(t, generated(:, :, 1)'*generated(:, :, 1), n'*n, 'AbsTol', 1e-13);
end

function testZeroSensitivityMatchesNominalMonteCarlo(t)
p = t.TestData.p;
p.environment.x_m = [-0.2 0.2]; p.environment.y_m = 0; p.environment.z_m = 0.5;
n = rx_cone_normals(7, 20);
e = struct('methods', {{'LS', 'GLS', 'WLS', 'NLS'}}, 'trials', 10, 'seed', 42, ...
    'budget', 'per_orientation', 'solver', struct(), 'mode', 'pose_measurement', 'structure', 'independent');
a = rx_monte_carlo(p, p, n, e);
b = rx_sensitivity_run(p, n, e, 0);
verifyEqual(t, a.errors_m, b.errors_m, 'AbsTol', 1e-12);
verifyEqual(t, b.visibility_disagreement_fraction, 0);
end
