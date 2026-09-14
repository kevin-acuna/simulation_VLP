function estimator = gob_estimator(model,bounds,noise,options)
if nargin<3, noise = gob_noise(); end
if nargin<4, options = struct(); end
settings = struct('height',0,'gain_unknown',false,'grid_counts',[], ...
    'starts',6,'max_iterations',180,'seed_separation',.12);
settings = gob_update(settings,options); d = size(bounds,1);
assert(ismember(d,[2,3]) && all(bounds(:,2)>bounds(:,1)) && settings.starts>=1, ...
    'gob:Estimator','Invalid bounds or starts.');
if isempty(settings.grid_counts)
    settings.grid_counts = [35,35];
    if d==3, settings.grid_counts = [31,31,9]; end
end
estimator = struct('model',model,'bounds',bounds,'noise',noise,'dimensions',d,'options',settings);
estimator.grid = gob_grid(bounds,settings.grid_counts,settings.height);
estimator.library = gob_power(model,estimator.grid).';
estimator.library_square = estimator.library.^2;
estimator.compressed_library = asinh(estimator.library/gob_sigma(0,noise));
estimator.compressed_norm = sum(estimator.compressed_library.^2,2);
estimator.optimizer = optimoptions('lsqnonlin','Display','off','SpecifyObjectiveGradient',true, ...
    'Algorithm','trust-region-reflective','FunctionTolerance',1e-12,'StepTolerance',1e-12, ...
    'OptimalityTolerance',1e-9,'MaxIterations',settings.max_iterations,'MaxFunctionEvaluations',600);
end
