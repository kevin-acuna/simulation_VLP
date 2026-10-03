function sigma_W = gob_sigma(power_W,n)
if nargin<2
    n = gob_noise();
end
power_W = max(power_W,0);
current = n.responsivity*power_W;
psd = 4*1.380649e-23*n.temperature/n.feedback_resistance ...
    + n.amplifier_current_density^2 ...
    + 2*1.602176634e-19*(current+n.background_current) + n.rin*current.^2;
sigma_W = sqrt(psd*n.bandwidth/n.responsivity^2+(n.repeatability*power_W).^2);
end
