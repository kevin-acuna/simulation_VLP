function tests = test_rx_design_extensions
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
addpath(fileparts(fileparts(mfilename('fullpath'))));
cambridge_setup();
p = rx_test_parameters();
p.environment.x_m = [-0.2 0.2];
p.environment.y_m = [-0.2 0.2];
p.environment.z_m = [0.4 0.8];
p.environment.validation_x_m = [-0.2 0 0.2];
p.environment.validation_y_m = [-0.2 0 0.2];
p.environment.validation_z_m = [0.4 0.8];
testCase.TestData.p = p;
end

function testAllPatternsRespectTiltCap(testCase)
for name = {'uniform_cone', 'golden_prefix', 'center_ring', 'two_rings', 'repeat_triplet'}
    n = rx_capped_pattern(15, 3, name{1}, 7, 'maximum');
    verifyEqual(testCase, sum(n.^2, 1), ones(1, 15), 'AbsTol', 1e-14);
    verifyGreaterThanOrEqual(testCase, min(n(3, :)), cosd(3)-1e-14);
end
verifyError(testCase, @() rx_capped_pattern(9, 3, 'center_ring', 0, 'fixed'), 'cambridge:FixedTiltPattern');
a = rx_capped_pattern(9, 3, 'golden_prefix', 0, 'maximum');
b = rx_capped_pattern(15, 3, 'golden_prefix', 0, 'maximum');
verifyEqual(testCase, a, b(:, 1:9));
end

function testCoverageAndTargetCoverageAreDifferent(testCase)
q = rx_bound_quality([0.01 0.03 0.04], 0.02, 0.95);
verifyEqual(testCase, q.coverage, 1);
verifyEqual(testCase, q.target_coverage, 1/3);
verifyEqual(testCase, q.quantile_m, 0.04);
q = rx_bound_quality([0.01 Inf NaN], 0.02, 0.95);
verifyEqual(testCase, q.coverage, 1/3);
verifyEqual(testCase, q.rms_full_m, Inf);
verifyEqual(testCase, q.required_scale, Inf);
end

function testJointSearchKeepsActualSamplesAndAreaScaling(testCase)
p = testCase.TestData.p;
e = small_feasibility();
r = study_tilt_feasibility(p, e);
verifyEqual(testCase, height(r.table), 2*2*2*2*2*2);
base = r.table.BaseIndex(1);
rows = find(r.table.BaseIndex==base);
verifyEqual(testCase, r.table.RMS_full_cm(rows(1))/r.table.RMS_full_cm(rows(2)), 2, 'RelTol', 1e-12);
verifyTrue(testCase, all(r.table.TotalSamples(r.table.Budget=="fixed_total")==p.acquisition.total_samples));
verifyTrue(testCase, all(r.selected.normals(3, :)>=cosd(3)-1e-12));
verifyEqual(testCase, r.selected.metrics.coverage, 1);
verifyLessThanOrEqual(testCase, r.selected.refinement.final_score, r.selected.refinement.initial_score*(1+1e-12));
for row = [1 height(r.table)]
    pc = p;
    pc.transmitter.half_angle_power_deg = r.table.HalfAngle_deg(row);
    pc.receiver.fov_deg = r.table.FOV_deg(row);
    pc.receiver.area_m2 = r.table.Area_mm2(row)*1e-6;
    base = r.table.BaseIndex(row);
    expected = rx_peb(r.positions_m, r.base_normals{base}, pc, r.base_sample_counts{base});
    verifyEqual(testCase, r.rms_full_m(row), sqrt(mean(expected.^2)), 'RelTol', 1e-12);
end
verifyTrue(testCase, all(r.extra_tables.feasible_tradeoffs.ValidationFeasible));
end

function testNoFeasibleSearchDoesNotInventAnOptimum(testCase)
p = testCase.TestData.p;
e = small_feasibility();
e.tilt_deg = 0;
r = study_tilt_feasibility(p, e);
verifyTrue(testCase, all(isinf(r.rms_full_m)));
verifyTrue(testCase, isempty(r.selected));
verifyFalse(testCase, any(r.table.Feasible));
end

function testKInformationExplainsPlateauAndNesting(testCase)
p = testCase.TestData.p;
e = struct('tilt_deg', 3, 'half_angle_deg', 60, 'fov_values_deg', 85, ...
    'K_values', [3 6 9], 'patterns', {{'uniform_cone', 'golden_prefix', 'repeat_triplet'}}, ...
    'budgets', {{'per_orientation', 'fixed_total'}}, 'reference_position_m', [0; 0; 0.6], ...
    'azimuth_offset_deg', 0, 'target_peb_m', 0.02);
r = study_K_information(p, e);
verifyEqual(testCase, r.axis_peb_m(:, 1, 1, 2), repmat(r.axis_peb_m(1, 1, 1, 2), 3, 1), 'RelTol', 1e-12);
verifyEqual(testCase, r.axis_peb_m(:, 1, 1, 1)/r.axis_peb_m(1, 1, 1, 1), sqrt(3./e.K_values(:)), 'RelTol', 1e-12);
verifyGreaterThanOrEqual(testCase, min(diff(r.coverage(:, 2, 1, 1))), 0);
end

function testGeometricEnvelopeIsAnUpperBound(testCase)
p = testCase.TestData.p;
e = struct('tilt_values_deg', [0 3 15], 'fov_values_deg', [15 45 85], ...
    'K', 9, 'half_angle_deg', 60, 'azimuth_offset_deg', 0, 'target_peb_m', 0.02);
r = study_coverage_geometry(p, e);
verifyLessThanOrEqual(testCase, max(r.coverage(:)-r.potential_coverage(:)), 1e-12);
verifyEqual(testCase, r.potential_coverage(1, :), zeros(1, 3));
end

function testLinkBudgetScalingMatchesDirectFim(testCase)
p = testCase.TestData.p;
e.cases = rx_cone_cases(p, 60, 3, 9);
e.power_values_W = [p.transmitter.power_W, 2*p.transmitter.power_W];
e.sample_values = [1000 4000];
e.noise_std_scales = [1 2];
e.target_peb_m = 0.02;
e.min_target_coverage = 0.95;
r = study_link_budget(p, e);
pc = p;
pc.transmitter.half_angle_power_deg = 60;
pc.transmitter.power_W = e.power_values_W(2);
pc.noise.variance_W2 = 4*p.noise.variance_W2;
expected = rx_peb(r.positions_m, e.cases.normals, pc, 4000);
verifyEqual(testCase, r.peb_m(:, 2, 2, 2, 1), expected', 'RelTol', 1e-12);
end

function e = small_feasibility()
e = struct('tilt_deg', 3, 'tilt_constraint', 'maximum', 'half_angles_deg', [60 75], ...
    'fov_values_deg', [75 85], 'K_values', [3 9], 'area_values_mm2', [50 100], ...
    'patterns', {{'uniform_cone', 'golden_prefix'}}, 'budgets', {{'per_orientation', 'fixed_total'}}, ...
    'azimuth_offset_deg', 0, 'target_peb_m', 0.05, 'min_target_coverage', 0.95, ...
    'refine_selected', true, 'refinement_tilt_steps_deg', 0.25, 'refinement_azimuth_steps_deg', 2, ...
    'refinement_passes', 1, 'validation_heights_m', 0.6, 'map_step_m', 0.2);
end
