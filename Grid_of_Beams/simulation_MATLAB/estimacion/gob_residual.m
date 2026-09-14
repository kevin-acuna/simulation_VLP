function [residual,J] = gob_residual(state,estimator,measurement,sigma)
d = estimator.dimensions;
position = state(1:d);
if d==2, position(3) = estimator.options.height; end
gain = 1;
if estimator.options.gain_unknown, gain = exp(state(end)); end
[power,J] = gob_power(estimator.model,position);
residual = (gain*power-measurement)./sigma;
J = gain*J(:,1:d);
if estimator.options.gain_unknown, J = [J,gain*power]; end
J = J./sigma;
end
