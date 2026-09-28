function tests = test_rx_tcom_equivalence
tests = functiontests(localfunctions);
end

function setupOnce(t)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root); cambridge_setup();
t.TestData.p = rx_test_parameters();
end

function testRatioCovarianceEqualsTCOM(t)
p = t.TestData.p; p.receiver.m_R = 1.9;
n = rx_cone_normals(7, 25);
y = rx_channel([0.2; -0.1; 0.6], n, p);
N = (1:7)'*100;
a = rx_estimator_context(n, p, N, struct('reference_index', 1));
[~, detail] = rx_ratio_direction(y/max(y), a, true);
r = (y(2:end)/y(1)).^(1/p.receiver.m_R);
C = diag(r.^2./(N(2:end).*y(2:end).^2))+(r*r')/(N(1)*y(1)^2);
verifyEqual(t, detail.covariance, C/max(diag(C)), 'RelTol', 2e-13);
verifyEqual(t, detail.reference, 1);
end

function testObjectiveChangeOfVariables(t)
p = t.TestData.p;
n = rx_cone_normals(7, 20);
u = [0.1; -0.2; 1]; u = u/norm(u);
y = [0.8; 0.9; 0.7; 0.6; 0.9; 0.8; 1];
for order = [0.5 1 1.9 3]
    gamma = 1.3;
    b = gamma^(1/order)*u;
    spherical = sum((gamma*(n'*u).^order-y).^2);
    joint = sum(((n'*b).^order-y).^2);
    verifyEqual(t, spherical, joint, 'AbsTol', 2e-14);
end
end

function testNLSVariantsAndLegacyAlias(t)
p = t.TestData.p;
n = rx_cone_normals(9, 25);
r = [0.2; -0.1; 0.6];
for order = [1 1.9 3]
    p.receiver.m_R = order;
    y = rx_channel(r, n, p)+1e-8*[1; -1; 0.2; -0.3; 0.4; -0.1; 0.7; -0.5; 0.2];
    [a, ia] = rx_estimate('NLS', y, n, p);
    [b, ib] = rx_estimate('NLS_joint', y, n, p);
    [c, ic] = rx_estimate('NLS_TCOM', y, n, p);
    verifyTrue(t, ia.success && ib.success && ic.success);
    verifyEqual(t, a, b);
    verifyEqual(t, b, c, 'AbsTol', 2e-6);
    verifyEqual(t, ib.objective, ic.objective, 'AbsTol', 1e-6);
end
end

function testRoundoffLimitedTangentStep(t)
p = t.TestData.p; p.receiver.m_R = 1.9; p.transmitter.position_m = [0;0;2.5];
n = rx_cone_normals(5, 2);
state = rng; cleanup = onCleanup(@() rng(state));
rng(20260927);
y = rx_channel([0;0;0.6], n, p)+sqrt(p.noise.variance_W2/1000)*randn(5,300);
perturbed = rx_perturb_normals(n, 1, 'independent', 300);
[~, info] = rx_estimate_nls_tcom(y(:,171), perturbed(:,:,171), p);
verifyTrue(t, info.success);
end

function testNoiselessTCOMIncludingAxialPosition(t)
p = t.TestData.p; p.receiver.m_R = 1.9;
n = rx_cone_normals(5, 10);
r = [0 0.3; 0 -0.1; 0.6 0.8];
y = rx_channel(r, n, p);
[estimate, info] = rx_estimate_nls_tcom(y, n, p);
verifyTrue(t, all(info.success));
verifyEqual(t, estimate, r, 'AbsTol', 1e-7);
end
