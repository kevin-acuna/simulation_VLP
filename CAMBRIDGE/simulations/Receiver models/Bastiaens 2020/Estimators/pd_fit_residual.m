function [residual,J,gamma] = pd_fit_residual(u,gamma,y,a,method)
if a.q'*u<=0 || ~all(isfinite(u)) || abs(sum(u.^2)-1)>1e-10
    residual=Inf(size(y)); J=[]; return;
end
[h,dh]=rx_receiver_response(a.H*u,a.p);
E=rx_tangent_basis(u);
D=dh.*(a.H*E);
if startsWith(method,'ratio_')
    ref=a.reference;
    if ~a.ratio_valid || h(ref)<=sqrt(realmin)
        residual=Inf(numel(y)-1,1); J=[]; return;
    end
    idx=a.ratio_indices;
    residual=h(idx)/h(ref)-a.ratio_target;
    J=(D(idx,:)*h(ref)-h(idx)*D(ref,:))/h(ref)^2;
    if strcmp(method,'ratio_gls')
        residual=a.ratio_cholesky\residual; J=a.ratio_cholesky\J;
    else
        residual=residual./sqrt(diag(a.ratio_covariance));
        J=J./sqrt(diag(a.ratio_covariance));
    end
else
    w=a.weights.*h; z=a.weights.*y; dw=a.weights.*D;
    if strcmp(method,'profile_nls')
        denominator=w'*w;
        if denominator<=realmin
            residual=Inf(size(y)); J=[]; return;
        end
        gamma=(w'*z)/denominator;
        if gamma<=0
            residual=Inf(size(y)); J=[]; return;
        end
        dg=((z-2*gamma*w)'*dw)/denominator;
        residual=gamma*w-z;
        J=gamma*dw+w*dg;
    else
        residual=gamma*w-z;
        J=[gamma*dw gamma*w];
    end
end
end
