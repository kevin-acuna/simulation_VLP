function tests = test_rx_target_design
tests = functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath')))); cambridge_setup();
end

function testMinimumTiltPoliciesAreDifferent(t)
e.minimum_coverage_percent = 95; e.near_peak_loss_pp = 1;
s = rx_select_coverage_tilt([0 1 2 3 4], [0 .90 .95 .96 .96], e);
verifyEqual(t, s.optimal_tilt_deg, 3);
verifyEqual(t, s.minimum_acceptable_tilt_deg, 2);
verifyEqual(t, s.minimum_near_peak_tilt_deg, 2);
s = rx_select_coverage_tilt([0 1 2 3], [0 .8 .89 .895], e);
verifyTrue(t, isnan(s.minimum_acceptable_tilt_deg));
verifyEqual(t, s.minimum_near_peak_tilt_deg, 2);
end

function testVectorizedPoseBoundMatchesSchurImplementation(t)
p = rx_test_parameters(); p.receiver.m_R = 1.9; p.receiver.fov_deg = 46;
n = rx_cone_normals(5, 12);
r = [0 0.4 1; 0 -0.2 1; 0.6 1 1.4];
for sigma = [0 .1 1]
    a = rx_pose_error_peb(r, n, p, 1000, sigma^2, 'independent');
    [b, detail] = rx_pose_error_peb(r, n, p, 1000, sigma^2, 'independent');
    verifyEqual(t, isinf(a), isinf(b));
    valid = isfinite(b);
    verifyEqual(t, a(valid), b(valid), 'RelTol', 1e-11);
    verifySize(t, detail.fim_per_m2, [3 3 3]);
end
end

function testIndependentStudyHasExplicitGridAndNoise(t)
p = rx_test_parameters(); p.receiver.m_R = 1.9; p.design.coverage_threshold_cm = 10;
p.environment.x_m = [-0.2 0.2]; p.environment.y_m = 0; p.environment.z_m = 0.5;
p.environment.validation_x_m = [-0.2 0 0.2]; p.environment.validation_y_m = 0; p.environment.validation_z_m = 0.5;
e = struct('K',5,'tilt_values_deg',[0 1 3 10],'azimuth_offset_deg',0,'budget','per_orientation', ...
    'orientation_std_deg',1,'orientation_structure','independent','minimum_coverage_percent',95,'near_peak_loss_pp',1);
r = study_K5_tilt_coverage(p, e);
verifyEqual(t, r.orientation_std_values_deg, [0 1]);
verifyEqual(t, r.grid_results{1}.coverage(1, :), [0 0]);
verifyEqual(t, height(r.selection_table), 4);
verifyEqual(t, r.sample_counts, 1000*ones(5,1));
verifyTrue(t, all(r.grid_results{1}.coverage(:,2)<=r.grid_results{1}.coverage(:,1)));
end
