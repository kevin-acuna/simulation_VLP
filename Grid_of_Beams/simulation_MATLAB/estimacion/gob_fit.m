function fit = gob_fit(estimator,measurement)
y = measurement(:); m = estimator.model; d = estimator.dimensions;
assert(numel(y)==m.n_channels && all(isfinite(y)),'gob:Measurement','Supply one finite labelled power per channel.');
[costs,gains,sigma] = gob_candidate_costs(estimator,y);
compressed = asinh(max(y,0)/gob_sigma(0,estimator.noise));
compressed_cost = estimator.compressed_norm-2*estimator.compressed_library*compressed;
[~,order1] = sort(compressed_cost); [~,order2] = sort(costs);
order = reshape([order1,order2].',[],1); seeds = zeros(1,estimator.options.starts); nseeds = 0;
for index = order.'
    if nseeds==0 || all(vecnorm(estimator.grid(:,index)-estimator.grid(:,seeds(1:nseeds)))>=estimator.options.seed_separation)
        nseeds = nseeds+1; seeds(nseeds) = index;
    end
    if nseeds==numel(seeds), break; end
end
seeds = seeds(1:nseeds); lower = estimator.bounds(:,1); upper = estimator.bounds(:,2);
if estimator.options.gain_unknown
    lower = [lower;log(.2)]; upper = [upper;log(5)];
end
states = zeros(numel(lower),nseeds); values = zeros(1,nseeds);
flags = zeros(1,nseeds); evaluations = zeros(1,nseeds);
objective = @(state)gob_residual(state,estimator,y,sigma);
for k = 1:nseeds
    index = seeds(k); initial = estimator.grid(1:d,index);
    if estimator.options.gain_unknown, initial = [initial;log(gains(index))]; end
    initial = max(lower+1e-9,min(upper-1e-9,initial));
    [states(:,k),values(k),~,flags(k),output] = lsqnonlin(objective,initial,lower,upper,estimator.optimizer);
    evaluations(k) = output.funcCount;
end
[values,order] = sort(values); states = states(:,order); flags = flags(order);
position = states(1:d,1);
if d==2, position(3) = estimator.options.height; end
gain = 1;
if estimator.options.gain_unknown, gain = exp(states(end,1)); end
separations = vecnorm(states(1:d,:)-states(1:d,1)); alternative = find(separations>.1,1);
gap = Inf; separation = 0;
if ~isempty(alternative)
    gap = values(alternative)-values(1); separation = separations(alternative);
end
fit = struct('position',position,'gain',gain,'cost',values(1),'success',flags(1)>0, ...
    'exitflag',flags(1),'alternate_separation',separation,'alternate_cost_gap',gap, ...
    'evaluations',sum(evaluations),'seed_positions',estimator.grid(:,seeds), ...
    'candidate_states',states,'candidate_costs',values);
end
