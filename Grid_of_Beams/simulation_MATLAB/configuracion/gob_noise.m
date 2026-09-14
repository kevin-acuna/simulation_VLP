function n = gob_noise(overrides)
n = struct('bandwidth',100,'responsivity',.7,'temperature',300, ...
    'feedback_resistance',10000,'amplifier_current_density',2e-12, ...
    'background_current',10e-6,'rin',10^(-155/10),'repeatability',.005);
if nargin>0
    n = gob_update(n,overrides);
end
end
