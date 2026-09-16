function tests = test_rx_experiments
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
cambridge_setup();
p = rx_test_parameters();
p.environment.x_m = [-0.2 0.2];
p.environment.y_m = [-0.2 0.2];
p.environment.z_m = [0.4 0.8];
p.output.export_figures = false;
testCase.TestData.p = p;
end

function testIndependentInclinationAndInfeasibleCases(testCase)
p = testCase.TestData.p;
e = struct('K', 5, 'half_angles_deg', [45 75], 'fov_values_deg', [30 85], ...
    'tilt_values_deg', [0 20 40], 'azimuth_offset_deg', 7);
r = study_inclination(p, e);
verifyEqual(testCase, size(r.peb_m), [8 3 2 2]);
verifyEqual(testCase, r.coverage(1, :, :), zeros(1, 2, 2));
verifyTrue(testCase, all(isinf(r.rms_full_m(1, :, :)), 'all'));
p.transmitter.half_angle_power_deg = 75;
p.receiver.fov_deg = 85;
expected = rx_peb(r.positions_m, rx_cone_normals(5, 40, 7), p);
verifyEqual(testCase, r.peb_m(:, 3, 2, 2), expected', 'RelTol', 1e-12);
end

function testKDoesNotRunOrDependOnInclinationSearch(testCase)
p = testCase.TestData.p;
e.cases = rx_cone_cases(p, [60 75], 35, 9);
e.K_values = [3 5 7];
e.budgets = {'per_orientation', 'fixed_total'};
r = study_K(p, e);
p.design.tilt_values_deg = NaN;
p.design.half_angles_deg = NaN;
p.design.refine_2dof = true;
r2 = study_K(p, e);
verifyEqual(testCase, r.peb_m, r2.peb_m);
for i = 1:3
    verifyEqual(testCase, sum(r.sample_counts{i, 2}), p.acquisition.total_samples);
end
verifyEqual(testCase, r.spec.cases(1).tilt_deg, 35);
end

function testAreaScalingAndFrozenNormals(testCase)
p = testCase.TestData.p;
e.cases = rx_cone_cases(p, 75, 40, 5);
e.area_values_mm2 = [10 20 40];
r = study_area(p, e);
verifyEqual(testCase, r.peb_m(:, 1), 2*r.peb_m(:, 2), 'RelTol', 1e-12);
verifyEqual(testCase, r.peb_m(:, 1), 4*r.peb_m(:, 3), 'RelTol', 1e-12);
verifyEqual(testCase, r.spec.cases.normals, e.cases.normals);
end

function testHeatmapUsesFull3DFim(testCase)
p = testCase.TestData.p;
e.cases = rx_cone_cases(p, 60, 35, 5);
e.heights_m = [0.4 0.8];
e.grid_step_m = 0.2;
r = study_heatmap(p, e);
[X, Y] = meshgrid(r.x_m, r.y_m);
positions = [X(:)'; Y(:)'; repmat(0.8, 1, numel(X))];
p.transmitter.half_angle_power_deg = 60;
expected = rx_peb(positions, e.cases.normals, p);
verifyEqual(testCase, r.peb_m(:, 2, 1), expected', 'RelTol', 1e-12);
end

function testManifestPersistenceAndNoFigureSideEffects(testCase)
p = testCase.TestData.p;
e.cases = rx_cone_cases(p, 75, 35, 5);
e.area_values_mm2 = [10 20];
parent = tempname;
mkdir(parent);
cleanup = onCleanup(@() rmdir(parent, 's'));
existing_figures = findall(groot, 'Type', 'figure');
log = evalc('r = run_rx_experiment(''area'', p, e, parent);');
verifyTrue(testCase, contains(log, 'FIXED SYSTEM'));
verifyTrue(testCase, contains(log, 'SWEPT VARIABLES'));
verifyTrue(testCase, contains(log, sprintf('P_t = %.6g W', p.transmitter.power_W)));
verifyTrue(testCase, contains(log, '10 20'));
verifyTrue(testCase, isfile(fullfile(r.output_directory, 'experiment_results.mat')));
verifyTrue(testCase, isfile(fullfile(r.output_directory, 'parameters.txt')));
verifyEqual(testCase, findall(groot, 'Type', 'figure'), existing_figures);
saved = load(fullfile(r.output_directory, 'experiment_results.mat'), 'result');
verifyEqual(testCase, saved.result.parameters, p);
verifyEqual(testCase, saved.result.spec, e);
end

function testEditedConeTiltIsActuallyUsed(testCase)
p = testCase.TestData.p;
e.cases = rx_cone_cases(p, 75, 35, 5);
e.cases.tilt_deg = 50;
e.area_values_mm2 = p.receiver.area_m2*1e6;
r = study_area(p, e);
verifyEqual(testCase, r.spec.cases.normals, rx_cone_normals(5, 50));
p.transmitter.half_angle_power_deg = 75;
verifyEqual(testCase, r.peb_m, rx_peb(r.positions_m, rx_cone_normals(5, 50), p)', 'RelTol', 1e-12);
end

function testReplotUsesSavedDataAndPreservesOtherFigures(testCase)
p = testCase.TestData.p;
e.cases = rx_cone_cases(p, 75, 35, 5);
e.area_values_mm2 = [10 20];
parent = tempname;
mkdir(parent);
cleanup = onCleanup(@() rmdir(parent, 's'));
evalc('r = run_rx_experiment(''area'', p, e, parent);');
style = ieee_plot_style();
style.visible = 'off';
style.export = false;
style.keep_open = true;
other = figure('Visible', 'off');
other_cleanup = onCleanup(@() close(other));
mat_file = fullfile(r.output_directory, 'experiment_results.mat');
[figures, ~] = replot_experiment(mat_file, style);
figure_cleanup = onCleanup(@() close(figures));
verifyTrue(testCase, all(isgraphics(figures)));
verifyTrue(testCase, isgraphics(other));
verifyEqual(testCase, figures.UserData.plot_style.font_size, 8);
saved = load(mat_file, 'result');
verifyEqual(testCase, saved.result, r);
end

function testExplicitOrientationsCannotBeSilentlyResized(testCase)
p = testCase.TestData.p;
e.cases = rx_cone_cases(p, 75, 35, 5);
e.cases.family = 'explicit';
e.K_values = 3:5;
e.budgets = {'per_orientation'};
verifyError(testCase, @() study_K(p, e), 'cambridge:KRequiresCone');
end
