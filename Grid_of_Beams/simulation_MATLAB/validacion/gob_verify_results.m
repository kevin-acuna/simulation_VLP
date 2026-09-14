function gob_verify_results(outputDir)
manifest = load(fullfile(outputDir,'manifest.mat'));
assert(manifest.status=="complete",'gob:Incomplete','Study is not complete.');
t = readtable(fullfile(outputDir,'tablas','summary.csv'),'TextType','string');
assert(height(t)==numel(manifest.cases),'gob:Results','Summary case count mismatch.');
trials = 0;
for k = 1:numel(manifest.cases)
    c = manifest.cases(k); row = t(t.case_name==c.name,:);
    data = load(fullfile(outputDir,'ensayos',c.name+".mat"));
    m = gob_model(c.config); N = data.random_trial_count;
    assert(N==manifest.options.trials && size(data.measurements,1)==m.n_channels,'gob:Results','Observation shape mismatch.');
    assert(all(isfinite(data.measurements),'all') && all(isfinite(data.estimates),'all'),'gob:Results','Nonfinite trials.');
    recomputed = gob_error_summary(data.truth(:,1:N),data.estimates(:,1:N));
    names = fieldnames(recomputed);
    for j = 1:numel(names)
        value = recomputed.(names{j}); stored = row.(names{j});
        assert(abs(value-stored)<=1e-12+1e-10*abs(value),'gob:Results','Summary mismatch: %s',names{j});
    end
    expected = (1+.08*c.gain_unknown)*gob_power(m,data.truth(:,1:3));
    assert(max(abs(expected-data.noiseless_mean(:,1:3)),[],'all')<1e-18,'gob:Results','Stored optical means differ from model.');
    map = load(fullfile(outputDir,'mapas',c.name+".mat"));
    expected_count = manifest.options.resolution^2*(1+4*(c.dimensions==3));
    assert(size(map.points,2)==expected_count,'gob:Results','Map shape mismatch.');
    expected_points = gob_metric_grid(c,manifest.options.resolution);
    assert(max(abs(map.points-expected_points),[],'all')<1e-13,'gob:Results','Map coordinates or height do not match the declared domain.');
    assert(~any(isnan(map.metrics.peb)) && all(map.metrics.peb>0),'gob:Results','Invalid information bound.');
    assert(all(map.metrics.rank<=c.dimensions),'gob:Results','Invalid rank.');
    trials = trials+N;
end
requirements = {manifest.options.sweeps,'design_sweep.csv';manifest.options.controls,'diversity_controls.csv'; ...
    manifest.options.controls,'grid_tilt_sweep.csv';manifest.options.controls,'noise_area_tradeoff.csv'; ...
    manifest.options.controls,'radial_ambiguity.csv';manifest.options.rays,'ray_validation.csv'; ...
    manifest.options.robustness,'robustness.csv'};
for k = 1:size(requirements,1)
    if requirements{k,1}
        assert(isfile(fullfile(outputDir,'tablas',requirements{k,2})),'gob:Results','Missing experiment table.');
    end
end
root = gob_paths(); original = load(fullfile(root,'referencias','python_snapshot_initial.mat'));
current = gob_python_snapshot(fullfile(fileparts(root),'simulations'));
assert(isequal(current,original.s),'gob:PythonChanged','The original Python folder differs from the initial snapshot.');
verification = struct('cases',height(t),'random_trials',trials,'python_unchanged',true,'passed',true);
save(fullfile(outputDir,'verification.mat'),'verification');
fprintf('Verificados %d casos y %d ensayos, mapas, medias y tablas. Python intacto.\n',height(t),trials);
end
