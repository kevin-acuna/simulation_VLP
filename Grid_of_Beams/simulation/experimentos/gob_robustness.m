function results = gob_robustness(outputDir,options)
cases = gob_study_cases(); names = ["tile_baseline_core_3d","tile_convex_core_3d", ...
    "tile_diverging_ninth_3d","grid_diverging_full_3d"];
cases = cases(ismember([cases.name],names)); rows = cell(1,0);
for c = cases
    stream = RandStream('mt19937ar','Seed',options.seed+3000);
    m = gob_model(c.config); K = numel(c.config.radii); n = gob_noise(struct('bandwidth',100*K));
    counts = [31,31,9];
    if c.config.tiles==9, counts = [45,45,9]; end
    est = gob_estimator(m,[-c.half_width,c.half_width;-c.half_width,c.half_width;0,1],n,struct('grid_counts',counts,'starts',5));
    truth = gob_sample_positions(c,options.robustness_trials,stream); mean_power = gob_power(m,truth);
    perturbation = ["matched","global_gain_plus2pct","vcsel_calibration_1pct", ...
        "residual_background_0p1nW","pd_tilt_3deg","curvature_error_0.1pct", ...
        "curvature_error_1pct","edge_thickness_plus0p1mm"];
    actual = cell(1,8); actual{1} = mean_power; actual{2} = 1.02*mean_power;
    emitter_gain = 1+.01*repmat(randn(stream,25*c.config.tiles,1),K,1);
    actual{3} = emitter_gain.*mean_power; actual{4} = mean_power+1e-10;
    actual{5} = gob_power(m,truth,[sind(3);0;cosd(3)]);
    actual{6} = gob_power(gob_model(gob_update(c.config,struct('radii',c.config.radii*1.001))),truth);
    actual{7} = gob_power(gob_model(gob_update(c.config,struct('radii',c.config.radii*1.01))),truth);
    actual{8} = gob_power(gob_model(gob_update(c.config,struct('edge_thickness',c.config.edge_thickness+.0001))),truth);
    errors = randn(stream,size(mean_power)); estimates = cell(1,8); measurements = cell(1,8);
    for j = 1:8
        observations = actual{j}+gob_sigma(actual{j},n).*errors;
        estimated = zeros(size(truth));
        for t = 1:size(truth,2)
            fit = gob_fit(est,observations(:,t)); estimated(:,t) = fit.position;
        end
        estimates{j} = estimated; measurements{j} = observations;
        rows{end+1} = gob_merge(struct('case_name',c.name,'perturbation',perturbation(j)),gob_error_summary(truth,estimated));
    end
    case_definition = c;
    save(fullfile(outputDir,'datos',c.name+"_robustez.mat"),'truth','actual','measurements','estimates','perturbation','case_definition','emitter_gain');
    fprintf('Sensibilidad: %s\n',c.name);
end
results = struct2table([rows{:}]); writetable(results,fullfile(outputDir,'tablas','robustness.csv'));
end
