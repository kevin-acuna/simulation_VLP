function [v, status, iterations] = rx_optical_nls(y, a)
[v, status] = rx_optical_ls(y, a);
iterations = 0;
if a.order==1
    direct = (a.H.*a.weights)\(y.*a.weights);
    if rx_optical_domain(direct, a)
        v = direct;
        status = "success";
        return;
    end
end
if status~="success"
    u = a.q/norm(a.q);
    beta = rx_profile_amplitude(y, u, a);
    v = beta^(1/a.order)*u;
    if ~rx_optical_domain(v, a)
        status = "no_full_visibility_initialization";
        return;
    end
end
lambda = 1e-3;
status = "iteration_limit";
for iterations = 1:a.max_iterations
    s = a.H*v;
    residual = a.weights.*(s.^a.order-y);
    J = (a.weights.*(a.order*s.^(a.order-1))).*a.H;
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
        candidate = v+step;
        if rx_optical_domain(candidate, a)
            trial_residual = a.weights.*((a.H*candidate).^a.order-y);
            if all(isfinite(trial_residual)) && trial_residual'*trial_residual<=cost
                v = candidate;
                lambda = max(lambda/3, 1e-12);
                accepted = true;
                break;
            end
        end
        lambda = min(lambda*10, 1e16);
    end
    if accepted && norm(step)<=a.step_tolerance*(1+norm(v))
        status = "success";
        return;
    end
    if ~accepted
        status = "step_rejected";
        return;
    end
end
end
