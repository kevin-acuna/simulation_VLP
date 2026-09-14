function [cost,gains,sigma] = gob_candidate_costs(estimator,measurement)
y = measurement(:); sigma = gob_sigma(y,estimator.noise); w = 1./sigma.^2;
aa = estimator.library_square*w; ab = estimator.library*(w.*y);
gains = ones(size(aa));
if estimator.options.gain_unknown
    gains = max(.2,min(5,ab./max(aa,1e-300)));
end
cost = max(0,gains.^2.*aa-2*gains.*ab+sum(y.^2.*w));
end
