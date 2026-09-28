function [h, derivative_s, info] = rx_receiver_response(s, p)
validateattributes(s, {'numeric'}, {'real', 'finite'});
validateattributes(p.receiver.fov_deg, {'numeric'}, {'scalar', 'real', 'finite', '>', 0, '<=', 90});
model = rx_receiver_model(p);
assert(strcmp(model,'cosine_power') || ~isfield(p.receiver,'m_R'), 'cambridge:ConflictingReceiverParameters', ...
    'A paper response must use its published parameters, not an additional m_R. Recreate it with bastiaens2020_parameters.');
cutoff = p.receiver.fov_deg*pi/180;
order = NaN;
a = NaN; b = NaN;
switch model
    case 'cosine_power'
        order = rx_receiver_order(p);
    case {'bastiaens_sq','bastiaens_sqapprox'}
        psi3 = p.receiver.response_parameters.psi_3db_rad;
        validateattributes(psi3, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
        a = (1-1/sqrt(2))/psi3^2;
        b = 2*a;
        if strcmp(model,'bastiaens_sq')
            cutoff = min(cutoff, 1/sqrt(a));
        elseif b>1
            cutoff = min(cutoff, acos(1-1/b));
        end
    case 'bastiaens_exp'
        half = p.receiver.response_parameters.psi_half_rad;
        slope = p.receiver.response_parameters.slope;
        validateattributes(half, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
        validateattributes(slope, {'numeric'}, {'scalar', 'real', 'finite', '>=', 2});
        a = log(2)/half^slope;
end
if strcmp(model,'cosine_power')
    cutoff_cosine = cosd(p.receiver.fov_deg);
else
    cutoff_cosine = cos(cutoff);
end
active = s>0 & s>=cutoff_cosine;
h = zeros(size(s)); derivative_s = h;
x = min(1,s(active));
if strcmp(model,'cosine_power')
    h(active) = s(active).^order;
    derivative_s(active) = order*s(active).^(order-1);
else
    psi = acos(x);
    switch model
        case 'bastiaens_sq'
            value = max(0,1-a*psi.^2);
            ratio = ones(size(psi));
            away = psi>1e-7;
            ratio(away) = psi(away)./sin(psi(away));
            ratio(~away) = 1+psi(~away).^2/6;
            derivative = 2*a*ratio;
        case 'bastiaens_sqapprox'
            value = max(0,1-b+b*x);
            derivative = b*ones(size(x));
        case 'bastiaens_exp'
            value = exp(-a*psi.^slope);
            ratio = ones(size(psi));
            away = psi>1e-7;
            ratio(away) = psi(away)./sin(psi(away));
            ratio(~away) = 1+psi(~away).^2/6;
            derivative = a*slope*psi.^(slope-2).*ratio.*value;
    end
    h(active) = value;
    derivative(value<=0) = 0;
    derivative_s(active) = derivative;
    active = active & h>0;
end
info = struct('model',model,'active',active,'boundary',abs(s-cutoff_cosine)<=p.numerics.boundary_cosine_tolerance, ...
    'effective_cutoff_deg',rad2deg(cutoff),'outer_fov_deg',p.receiver.fov_deg,'receiver_order',order, ...
    'square_coefficient',a,'affine_coefficient',b);
end
