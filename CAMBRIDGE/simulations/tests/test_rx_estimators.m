function tests = test_rx_estimators
tests = functiontests(localfunctions);
end

function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
t.TestData.p = rx_test_parameters();
end

function testAllMethodsRecoverNoiselessPosition(t)
p = t.TestData.p;
n = rx_cone_normals(9, 25);
r = [0.25; -0.15; 0.6];
for order = [0.5 1 2 3]
    p.receiver.m_R = order;
    y = rx_channel(r, n, p);
    for method = {'LS', 'GLS', 'WLS', 'NLS'}
        [estimate, info] = rx_estimate(method{1}, y, n, p);
        verifyTrue(t, info.success);
        verifyEqual(t, estimate, r, 'AbsTol', 2e-7);
    end
end
end

function testLSAndNLSAgreeForMR1(t)
p = t.TestData.p;
n = rx_cone_normals(9, 25);
r = [0.25; -0.1; 0.6];
y = rx_channel(r, n, p)+sqrt(p.noise.variance_W2/1000)*[0.4; -0.2; 1; 0.3; -0.7; 1.1; -0.4; 0.2; -0.6];
[a, ia] = rx_estimate_ls(y, n, p);
[b, ib] = rx_estimate_nls(y, n, p);
verifyTrue(t, ia.success && ib.success);
verifyEqual(t, a, b, 'AbsTol', 2e-8);
verifyEqual(t, ia.objective, ib.objective, 'RelTol', 1e-9);
end

function testNLSUsesUnequalSampleWeights(t)
p = t.TestData.p;
n = rx_cone_normals(7, 30);
N = (1:7)'*100;
r = [0.2; 0.1; 0.5];
y = rx_channel(r, n, p)+[1; -1; 0.5; 0.2; -0.2; 0.1; -0.4]*1e-8;
H = n';
v = (sqrt(N).*H)\(sqrt(N).*y);
u = v/norm(v);
m = -log(2)/log(cosd(p.transmitter.half_angle_power_deg));
C = p.transmitter.power_W*(m+1)*p.receiver.area_m2/(2*pi);
expected = p.transmitter.position_m-u*sqrt(C*(-p.transmitter.normal'*u)^m/norm(v));
[estimate, info] = rx_estimate_nls(y, n, p, N);
verifyTrue(t, info.success);
verifyEqual(t, estimate, expected, 'AbsTol', 2e-7);
end

function testRatioCovarianceKeepsReferenceCorrelation(t)
p = t.TestData.p;
p.receiver.m_R = 2;
n = rx_cone_normals(7, 25);
y = rx_channel([0.2; 0.1; 0.4], n, p);
a = rx_estimator_context(n, p, [], struct());
[~, g] = rx_ratio_direction(y/max(y), a, true);
verifyGreaterThan(t, norm(g.covariance-diag(diag(g.covariance)), 'fro'), 0);
verifyEqual(t, g.reference, find(y==max(y), 1));
end

function testNoPowerClippingOrOracleMask(t)
p = t.TestData.p;
p.receiver.m_R = 2;
n = rx_cone_normals(7, 25);
y = rx_channel([0.1; 0.1; 0.4], n, p);
y(1) = -1e-9;
for method = {'LS', 'GLS', 'WLS'}
    [estimate, info] = rx_estimate(method{1}, y, n, p);
    verifyFalse(t, info.success);
    verifyTrue(t, all(isnan(estimate)));
    verifyEqual(t, info.status, "nonpositive_power_for_root");
end
end

function testEmissionPatternOnlyChangesDistanceForSameData(t)
p = t.TestData.p;
n = rx_cone_normals(9, 25);
r = [0.35; 0.1; 0.6];
truth = p;
truth.transmitter.pattern_asymmetry = 0.3;
y = rx_channel(r, n, truth);
for method = {'LS', 'GLS', 'WLS', 'NLS'}
    [matched, a] = rx_estimate(method{1}, y, n, truth);
    [mismatched, b] = rx_estimate(method{1}, y, n, p);
    verifyTrue(t, a.success && b.success);
    verifyEqual(t, matched, r, 'AbsTol', 2e-7);
    verifyEqual(t, a.direction, b.direction, 'AbsTol', 2e-12);
    verifyGreaterThan(t, norm(mismatched-r), 1e-4);
end
end
