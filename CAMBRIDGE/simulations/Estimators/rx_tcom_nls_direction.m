function [u, gamma, status, iterations] = rx_tcom_nls_direction(y, a)
[b, seed_status] = rx_optical_ls(y, a);
if seed_status=="success"
    u = b/norm(b);
else
    [~, ref] = max(y);
    u = a.H(ref, :)';
    if ~rx_optical_domain(u, a)
        u = a.q/norm(a.q);
    end
end
gamma = rx_profile_amplitude(y, u, a);
iterations = 0;
status = "no_full_visibility_initialization";
if ~isfinite(gamma) || ~rx_optical_domain(u, a)
    return;
end
lambda = 1e-3;
status = "iteration_limit";
for iterations = 1:a.max_iterations
    [~, index] = min(abs(u));
    axis = zeros(3, 1); axis(index) = 1;
    t = axis-u*(u'*axis); t = t/norm(t);
    E = [t cross(u, t)];
    s = a.H*u;
    prediction = gamma*s.^a.order;
    residual = a.weights.*(prediction-y);
    J = a.weights.*[(gamma*a.order*s.^(a.order-1)).*(a.H*E), prediction];
    cost = residual'*residual;
    gradient = J'*residual;
    if norm(gradient, Inf)<=a.gradient_tolerance*(1+cost)
        status = "success";
        return;
    end
    H = J'*J;
    diagonal = max(diag(H), max(diag(H))*1e-12);
    accepted = false;
    for attempt = 1:15
        step = -(H+lambda*diag(diagonal))\gradient;
        angle = norm(step(1:2));
        factor = 1;
        if angle>0
            factor = sin(angle)/angle;
        end
        candidate = cos(angle)*u+factor*E*step(1:2);
        candidate = candidate/norm(candidate);
        candidate_gamma = gamma*exp(step(3));
        if isfinite(candidate_gamma) && candidate_gamma>0 && rx_optical_domain(candidate, a)
            trial = a.weights.*(candidate_gamma*(a.H*candidate).^a.order-y);
            if all(isfinite(trial)) && trial'*trial<=cost
                u = candidate;
                gamma = candidate_gamma;
                lambda = max(lambda/3, 1e-12);
                accepted = true;
                break;
            end
        end
        lambda = min(lambda*10, 1e16);
    end
    if accepted && norm(step)<=a.step_tolerance
        status = "success";
        return;
    end
    if ~accepted
        correction = J\residual;
        reduction = norm(J*correction)^2;
        roundoff = eps*(norm(a.weights.*prediction)+norm(a.weights.*y))*norm(residual);
        if norm(correction)<=a.step_tolerance || (norm(correction)<=sqrt(eps) && reduction<=roundoff)
            status = "success";
        else
            status = "step_rejected";
        end
        return;
    end
end
end
