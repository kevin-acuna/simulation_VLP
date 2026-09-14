function result = gob_localize(caseName,measurement,position)
if nargin<1, caseName = "tile_baseline_core_3d"; end
if nargin<2, measurement = []; end
if nargin<3, position = [.213;-.147;.436]; end
cases = gob_study_cases(); index = find([cases.name]==string(caseName),1);
assert(~isempty(index),'gob:Case','Unknown study case.'); c = cases(index);
m = gob_model(c.config); n = gob_noise(struct('bandwidth',100*numel(c.config.radii)));
truth = [];
if isempty(measurement)
    truth = position(:); if c.dimensions==2, truth(3) = 0; end
    mean_power = gob_power(m,truth); stream = RandStream('mt19937ar','Seed',20260913);
    measurement = mean_power+gob_sigma(mean_power,n).*randn(stream,size(mean_power));
elseif ischar(measurement) || isstring(measurement)
    measurement = readmatrix(measurement); measurement = measurement(:);
end
bounds = [-c.half_width,c.half_width;-c.half_width,c.half_width]; counts = [35,35];
if c.config.tiles==9, counts = [51,51]; end
if c.dimensions==3, bounds = [bounds;0,1]; counts = [counts,9]; end
est = gob_estimator(m,bounds,n,struct('gain_unknown',c.gain_unknown,'grid_counts',counts));
result = gob_fit(est,measurement); gainMode = 'known';
if c.gain_unknown, gainMode = 'common'; end
info = gob_information(m,result.position,n,c.dimensions,gainMode);
result.local_peb_m = info.peb; result.measurement_W = measurement;
if ~isempty(truth)
    result.truth_m = truth; result.error_m = norm(result.position-truth);
end
result.warning = 'Convergence and local PEB do not certify global uniqueness or physical calibration.';
end
