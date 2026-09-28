function [u,gamma,cost,status,iterations] = pd_fit_lm(u,gamma,y,a,method)
lambda=1e-3; status="iteration_limit"; cost=Inf;
for iterations=1:a.max_iterations
    [residual,J,gamma]=pd_fit_residual(u,gamma,y,a,method);
    cost=sum(residual.^2);
    if ~isfinite(cost) || isempty(J), status="invalid_model_region"; return; end
    gradient=J'*residual;
    if norm(gradient,Inf)<=a.gradient_tolerance*(1+cost)
        status="success"; return;
    end
    H=J'*J; diagonal=max(diag(H),max(diag(H))*1e-12);
    E=rx_tangent_basis(u); accepted=false;
    for attempt=1:16
        step=-(H+lambda*diag(diagonal))\gradient;
        angle=norm(step(1:2)); factor=1;
        if angle>0, factor=sin(angle)/angle; end
        candidate=cos(angle)*u+factor*E*step(1:2); candidate=candidate/norm(candidate);
        candidate_gamma=gamma;
        if strcmp(method,'joint_nls'), candidate_gamma=gamma*exp(step(3)); end
        if isfinite(candidate_gamma) && candidate_gamma>0
            trial=pd_fit_residual(candidate,candidate_gamma,y,a,method);
            new_cost=sum(trial.^2);
            if isfinite(new_cost) && new_cost<=cost
                u=candidate; gamma=candidate_gamma; cost=new_cost;
                lambda=max(lambda/3,1e-12); accepted=true; break;
            end
        end
        lambda=min(lambda*10,1e16);
    end
    if accepted && norm(step)<=a.step_tolerance
        status="success"; return;
    end
    if ~accepted
        correction=J\residual;
        roundoff=eps*(norm(a.weights.*y)+norm(residual)+1)*norm(residual);
        if norm(correction)<=a.step_tolerance || (norm(correction)<=sqrt(eps) && norm(J*correction)^2<=roundoff)
            status="success";
        else
            status="step_rejected";
        end
        return;
    end
end
end
