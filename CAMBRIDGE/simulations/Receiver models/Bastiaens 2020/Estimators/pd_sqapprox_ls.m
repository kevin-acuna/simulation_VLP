function [u,gamma,status] = pd_sqapprox_ls(y,a)
assert(strcmp(rx_receiver_model(a.p),'bastiaens_sqapprox'),'cambridge:SQapproxRequired','This closed form is specific to SQapprox.');
u=nan(3,1); gamma=NaN; status="unsupported_cone";
c=a.H(1,3); st=sqrt(max(0,1-c^2));
if st<1e-10 || max(abs(a.H(:,3)-c))>1e-10, return; end
[~,~,response]=rx_receiver_response(1,a.p);
b=response.affine_coefficient; c0=1-b; k=b*c;
if k^2-c0^2<=1e-12, return; end
X=[a.H(:,1:2)/st ones(size(y))];
if rank(X)<3, status="rank_deficient"; return; end
coefficient=(a.weights.*X)\(a.weights.*y);
wxy=coefficient(1:2)/(b*st); A=coefficient(3);
delta=k^2-c0^2;
gamma=(-A*c0+k*sqrt(A^2+delta*sum(wxy.^2)))/delta;
if gamma<=0 || ~isfinite(gamma), status="nonpositive_amplitude"; return; end
wz=(A-c0*gamma)/k;
u=[wxy;wz]/gamma; u=u/norm(u);
[h,~,r]=rx_receiver_response(a.H*u,a.p);
status="success";
if any(h<=0) || any(r.boundary) || a.q'*u<=0, status="outside_full_visibility_domain"; end
end
