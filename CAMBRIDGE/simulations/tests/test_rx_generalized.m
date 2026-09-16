function tests = test_rx_generalized
tests = functiontests(localfunctions);
end

function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
t.TestData.p = rx_test_parameters();
end

function testMR1MatchesOriginalFormula(t)
p = t.TestData.p;
r = [0.2 0.8 -0.4; -0.1 0.3 0.7; 0.2 0.8 1.1];
n = rx_cone_normals(9, 40);
[mu, J] = rx_channel(r, n, p);
m = -log(2)/log(cosd(p.transmitter.half_angle_power_deg));
C = p.transmitter.power_W*(m+1)*p.receiver.area_m2/(2*pi);
v = p.transmitter.position_m-r;
d = sqrt(sum(v.^2, 1));
u = v./d;
q = -p.transmitter.normal;
c = q'*u;
s = n'*u;
visible = c>0 & s>0 & s>=cosd(p.receiver.fov_deg);
expected = C*c.^m./d.^2.*s;
expected(~visible) = 0;
verifyEqual(t, mu, expected, 'AbsTol', 1e-20);
for j = 1:3
    old = C*c.^m./d.^3.*(-n(j, :)'+s.*((m+3)*u(j, :)-m*q(j)./c));
    old(~visible) = 0;
    verifyEqual(t, reshape(J(:, j, :), size(s)), old, 'AbsTol', 1e-20);
end
legacy = p;
legacy.receiver = rmfield(legacy.receiver, 'm_R');
verifyEqual(t, rx_peb(r, n, legacy), rx_peb(r, n, p), 'RelTol', 1e-13);
end

function testGeneralizedGradient(t)
p = t.TestData.p;
r = [0.21 -0.3; 0.17 0.15; 0.4 0.9];
n = rx_cone_normals(7, 35);
for order = [0.5 1 2 3]
    p.receiver.m_R = order;
    for asymmetry = [0 0.3]
        p.transmitter.pattern_asymmetry = asymmetry;
        [~, J] = rx_channel(r, n, p);
        numerical = zeros(size(J));
        for j = 1:3
            step = zeros(3, 1);
            step(j) = 1e-5;
            difference = (rx_channel(r+step, n, p)-rx_channel(r-step, n, p))/(2e-5);
            numerical(:, j, :) = reshape(difference, size(n, 2), 1, []);
        end
        verifyLessThan(t, norm(J(:)-numerical(:))/norm(J(:)), 3e-8);
    end
end
end

function testGeneralizedAxialPEBAndRank(t)
p = t.TestData.p;
theta = 35;
K = 9;
r = [0; 0; 0.4];
n = rx_cone_normals(K, theta);
m = -log(2)/log(cosd(p.transmitter.half_angle_power_deg));
C = p.transmitter.power_W*(m+1)*p.receiver.area_m2/(2*pi);
d = norm(p.transmitter.position_m-r);
for order = [0.5 1 2 3]
    p.receiver.m_R = order;
    expected = sqrt(p.noise.variance_W2*d^6/(p.acquisition.samples_per_orientation*K*C^2) ...
        *(4/(order^2*sind(theta)^2*cosd(theta)^(2*order-2))+1/(4*cosd(theta)^(2*order))));
    [peb, info] = rx_peb(r, n, p);
    verifyEqual(t, peb, expected, 'RelTol', 1e-12);
    verifyEqual(t, info.rank, 3);
    verifyEqual(t, rx_peb(r, rx_cone_normals(2, theta), p), Inf);
end
end

function testOrderChangesSignalButNotFov(t)
p = t.TestData.p;
r = [0.1; 0.2; 0.6];
n = rx_cone_normals(9, 50);
p.receiver.fov_deg = 45;
[a, ~, ia] = rx_channel(r, n, p);
p.receiver.m_R = 2;
[b, J, ib] = rx_channel(r, n, p);
verifyEqual(t, ia.visible, ib.visible);
verifyEqual(t, b, a.*ia.incidence_cosine, 'AbsTol', 1e-20);
verifyTrue(t, all(isfinite(J(:))));
p.receiver.m_R = 0;
verifyError(t, @() rx_channel(r, n, p), 'MATLAB:expectedPositive');
end
