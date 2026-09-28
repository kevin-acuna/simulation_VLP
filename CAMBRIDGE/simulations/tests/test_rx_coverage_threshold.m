function tests = test_rx_coverage_threshold
tests = functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath')))); cambridge_setup();
end

function testFiniteDefaultAndCentimetres(t)
x = [0.02 0.1 0.1001 Inf NaN];
a = rx_design_metrics(x);
b = rx_design_metrics(x, 10);
verifyEqual(t, a.coverage, 3/5);
verifyEqual(t, b.coverage, 2/5);
verifyEqual(t, b.regular_coverage, 3/5);
verifyEqual(t, b.rms_full_m, Inf);
verifyEqual(t, b.rms_conditional_m, a.rms_conditional_m);
verifyEqual(t, b.nonregular_fraction, 1/5);
verifyEqual(t, rx_coverage_threshold(struct()), Inf);
end

function testThresholdDoesNotCensorRMSE(t)
a = rx_design_metrics([0.02 0.2], 10);
verifyEqual(t, a.coverage, 0.5);
verifyEqual(t, a.regular_coverage, 1);
verifyEqual(t, a.rms_full_m, sqrt((0.02^2+0.2^2)/2), 'RelTol', 1e-12);
end

function testStudyAndTablePreserveBothCoverages(t)
p = rx_test_parameters(); p.design.coverage_threshold_cm = 0.1;
p.environment.x_m = [-0.2 0.2]; p.environment.y_m = 0; p.environment.z_m = 0.6;
e = struct('K', 5, 'half_angles_deg', 45, 'fov_values_deg', 85, ...
    'tilt_values_deg', [1 10 30], 'azimuth_offset_deg', 0);
r = study_inclination(p, e);
expected = reshape(mean(isfinite(r.peb_m) & r.peb_m<=0.001, 1), [], 1);
verifyEqual(t, r.coverage, expected);
verifyEqual(t, r.table.Coverage_percent, 100*expected);
verifyEqual(t, r.table.RegularCoverage_percent, 100*ones(3, 1));
verifyEqual(t, r.table.CoverageThreshold_cm, 0.1*ones(3, 1));
p.design.coverage_threshold_cm = Inf;
b = study_inclination(p, e);
verifyEqual(t, r.peb_m, b.peb_m);
verifyEqual(t, r.rms_full_m, b.rms_full_m);
verifyEqual(t, b.coverage, r.regular_coverage);
end
