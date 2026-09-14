function summary = gob_run_case(c,options,outputDir)
m = gob_model(c.config); n = gob_noise(struct('bandwidth',100*numel(c.config.radii)));
gainMode = 'known';
if c.gain_unknown, gainMode = 'common'; end
points = gob_metric_grid(c,options.resolution);
metrics = gob_information(m,points,n,c.dimensions,gainMode);
case_definition = c; model_diagnostics = gob_diagnostics(m); noise = n;
save(fullfile(outputDir,'mapas',c.name+".mat"),'points','metrics','case_definition','model_diagnostics','noise');
bounds = [-c.half_width,c.half_width;-c.half_width,c.half_width];
counts = [35,35];
if c.config.tiles==9, counts = [51,51]; end
if c.dimensions==3, bounds = [bounds;0,1]; counts = [counts,9]; end
estimator = gob_estimator(m,bounds,n,struct('gain_unknown',c.gain_unknown,'grid_counts',counts,'starts',6));
stream = RandStream('mt19937ar','Seed',options.seed);
truth = gob_sample_positions(c,options.trials,stream); boundary = gob_boundary_positions(c);
truth = [truth,boundary]; true_gain = 1+.08*c.gain_unknown;
noiseless_mean = true_gain*gob_power(m,truth);
measurements = noiseless_mean+gob_sigma(noiseless_mean,n).*randn(stream,size(noiseless_mean));
N = size(truth,2); estimates = zeros(3,N); gains = zeros(1,N); cost = zeros(1,N);
optimizer_success = false(1,N); exitflags = zeros(1,N); alternate_gap = zeros(1,N); alternate_separation = zeros(1,N);
for j = 1:N
    fit = gob_fit(estimator,measurements(:,j)); estimates(:,j) = fit.position;
    gains(j) = fit.gain; cost(j) = fit.cost; optimizer_success(j) = fit.success;
    exitflags(j) = fit.exitflag; alternate_gap(j) = fit.alternate_cost_gap;
    alternate_separation(j) = fit.alternate_separation;
end
random_trial_count = options.trials;
save(fullfile(outputDir,'ensayos',c.name+".mat"),'truth','estimates','measurements','noiseless_mean', ...
    'gains','cost','optimizer_success','exitflags','alternate_gap','alternate_separation', ...
    'random_trial_count','case_definition','noise');
region = "prism";
if c.frustum, region = "frustum"; end
summary = struct('case_name',c.name,'tiles',c.config.tiles,'K',numel(c.config.radii), ...
    'dimensions',c.dimensions,'half_width_floor_m',c.half_width,'region',region,'gain',string(gainMode), ...
    'pilot_integration_seconds',.125*c.config.tiles,'grid_count',size(points,2), ...
    'grid_peb_median_m',gob_quantile(metrics.peb,.5,false),'grid_peb_p95_m',gob_quantile(metrics.peb,.95,false), ...
    'grid_peb_max_m',max(metrics.peb),'grid_fraction_peb_10cm',mean(metrics.peb<.1), ...
    'grid_fraction_full_rank',mean(metrics.rank==c.dimensions),'grid_minimum_visible_5sigma',min(metrics.visible_5sigma));
summary = gob_merge(summary,gob_error_summary(truth(:,1:options.trials),estimates(:,1:options.trials)));
boundary_errors = vecnorm(estimates(:,options.trials+1:end)-boundary);
summary.boundary_p95_m = gob_quantile(boundary_errors,.95); summary.boundary_max_m = max(boundary_errors);
summary.optimizer_success_fraction = mean(optimizer_success);
summary.alternative_gap_below9_fraction = mean(alternate_gap<9);
auditStream = RandStream('mt19937ar','Seed',options.seed+9000);
audit_truth = gob_sample_positions(c,min(24,options.trials),auditStream);
audit_estimates = zeros(size(audit_truth)); far_distances = zeros(1,size(audit_truth,2));
for j = 1:size(audit_truth,2)
    y = gob_power(m,audit_truth(:,j)); fit = gob_fit(estimator,y);
    audit_estimates(:,j) = fit.position; costs = gob_candidate_costs(estimator,y);
    far = vecnorm(estimator.grid-audit_truth(:,j))>=.1;
    far_distances(j) = sqrt(min(costs(far)));
end
summary.noiseless_audit_max_error_m = max(vecnorm(audit_truth-audit_estimates));
summary.sampled_far_fingerprint_min_sigma = min(far_distances);
save(fullfile(outputDir,'ensayos',c.name+"_auditoria.mat"),'audit_truth','audit_estimates','far_distances');
fprintf('%s: mediana=%.5g m, P95=%.5g m, <10cm=%.1f%%, frontera=%.5g m\n', ...
    c.name,summary.median_m,summary.p95_m,100*summary.fraction_error_10cm,summary.boundary_max_m);
end
