function audit = gob_audit_solver(outputDir,caseName)
if nargin<1 || strlength(string(outputDir))==0
    root = gob_paths(); latest = load(fullfile(root,'resultados','ultimo_completo.mat'));
    outputDir = latest.output_directory;
end
if nargin<2, caseName = "grid_convex_core_2d"; end
data = load(fullfile(outputDir,'ensayos',string(caseName)+".mat"));
c = data.case_definition; errors = vecnorm(data.estimates-data.truth);
[~,index] = max(errors); truth = data.truth(:,index); measurement = data.measurements(:,index);
m = gob_model(c.config); n = data.noise;
gainMode = 'known'; if c.gain_unknown, gainMode = 'common'; end
info = gob_information(m,truth,n,c.dimensions,gainMode);
truth_cost = sum(((data.noiseless_mean(:,index)-measurement)./gob_sigma(measurement,n)).^2);
fprintf('Caso %s, ensayo %d: error guardado %.6g m, PEB %.6g m, coste en verdad %.6g\n', ...
    caseName,index,errors(index),info.peb,truth_cost);
bounds = [-c.half_width,c.half_width;-c.half_width,c.half_width];
if c.dimensions==3, bounds = [bounds;0,1]; end
settings = [51,6;51,16;81,12]; rows = cell(1,3);
for k = 1:3
    counts = [settings(k,1),settings(k,1)];
    if c.dimensions==3, counts = [counts,9]; end
    estimator = gob_estimator(m,bounds,n,struct('grid_counts',counts,'starts',settings(k,2),'gain_unknown',c.gain_unknown));
    fit = gob_fit(estimator,measurement);
    rows{k} = struct('grid_per_axis',settings(k,1),'starts',settings(k,2), ...
        'error_m',norm(fit.position-truth),'cost',fit.cost,'exitflag',fit.exitflag);
end
audit = struct('case_name',string(caseName),'trial_index',index,'truth',truth, ...
    'saved_estimate',data.estimates(:,index),'saved_error_m',errors(index),'comparisons',struct2table([rows{:}]));
disp(audit.comparisons);
end
