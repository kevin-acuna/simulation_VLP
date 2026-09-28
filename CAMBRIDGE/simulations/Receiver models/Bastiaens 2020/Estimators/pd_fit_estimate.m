function [positions,info] = pd_fit_estimate(method,mean_W,normals,p,counts,options)
if nargin<5, counts=[]; end
if nargin<6, options=struct(); end
method=lower(char(method));
assert(any(strcmp(method,{'joint_nls','profile_nls','ratio_gls','ratio_wls','sqapprox_ls'})), ...
    'cambridge:FitMethod','Unknown calibrated-response estimator.');
if strcmp(method,'sqapprox_ls')
    assert(strcmp(rx_receiver_model(p),'bastiaens_sqapprox'),'cambridge:SQapproxRequired','Use the SQapprox profile for this closed form.');
end
validateattributes(mean_W,{'numeric'},{'real','finite','2d','nrows',size(normals,2)});
a=pd_fit_context(normals,p,counts,options);
T=size(mean_W,2); positions=nan(3,T);
info=struct('success',false(1,T),'status',repmat("no_physical_solution",1,T), ...
    'direction',nan(3,T),'distance_m',nan(1,T),'amplitude_W',nan(1,T),'objective',nan(1,T), ...
    'iterations',zeros(1,T),'ambiguous',false(1,T),'method',method,'response_model',rx_receiver_model(p));
for trial=1:T
    scale=max(abs(mean_W(:,trial)));
    if scale<=0, continue; end
    y=mean_W(:,trial)/scale; context=pd_fit_observation(a,y);
    if strcmp(method,'sqapprox_ls')
        [u,~,status]=pd_sqapprox_ls(y,context);
        iterations=0;
    else
        [shapes,~]=rx_receiver_response(a.H*a.seeds,p);
        weighted=a.weights.*shapes; z=a.weights.*y;
        amplitudes=(weighted'*z)'./sum(weighted.^2,1);
        scores=inf(1,size(a.seeds,2));
        for is=1:numel(scores)
            if isfinite(amplitudes(is)) && amplitudes(is)>0
                residual=pd_fit_residual(a.seeds(:,is),amplitudes(is),y,context,method);
                scores(is)=sum(residual.^2);
            end
        end
        [scores,indices]=sort(scores); selected=indices(isfinite(scores));
        selected=selected(1:min(a.starts,numel(selected)));
        best=Inf; status="no_physical_solution"; u=nan(3,1); iterations=0;
        solutions=nan(4,numel(selected)); costs=inf(1,numel(selected));
        for is=1:numel(selected)
            seed=selected(is);
            [candidate,eta,cost,state,it]=pd_fit_lm(a.seeds(:,seed),amplitudes(seed),y,context,method);
            if state=="success"
                solutions(:,is)=[candidate;eta]; costs(is)=cost;
                if cost<best
                    best=cost; u=candidate; status=state; iterations=it;
                end
            end
        end
        if status=="success"
            tied=find(costs<=best+a.ambiguity_cost_tolerance*(1+best));
            for is=tied
                if norm(solutions(1:3,is)-u)>a.ambiguity_angle_rad
                    info.ambiguous(trial)=true;
                end
            end
            if info.ambiguous(trial), status="multiple_competing_minima"; end
        end
    end
    info.status(trial)=status; info.iterations(trial)=iterations;
    if status~="success", continue; end
    [h,dh,response]=rx_receiver_response(a.H*u,p);
    if any(response.boundary), info.status(trial)="boundary_solution"; continue; end
    gamma=((a.weights.*h)'*(a.weights.*y))/sum((a.weights.*h).^2);
    if gamma<=0 || ~isfinite(gamma), info.status(trial)="nonpositive_amplitude"; continue; end
    E=rx_tangent_basis(u); G=a.weights.*[h dh.*(a.H*E)]; singular=svd(G,'econ');
    if numel(singular)<3 || singular(3)<=p.numerics.rank_relative_tolerance*singular(1)
        info.status(trial)="rank_deficient_solution"; continue;
    end
    beta=scale*gamma;
    [emission,~,m]=rx_emission_pattern(p,u);
    C=p.transmitter.power_W*(m+1)*p.receiver.area_m2*p.receiver.filter_transmission*p.receiver.optical_gain/(2*pi);
    distance=sqrt(C*emission/beta);
    position=p.transmitter.position_m-distance*u;
    if ~isfinite(distance) || distance<=0, info.status(trial)="invalid_distance"; continue; end
    positions(:,trial)=position; info.success(trial)=true;
    info.direction(:,trial)=u; info.distance_m(trial)=distance; info.amplitude_W(trial)=beta;
    info.objective(trial)=sum((beta*h-mean_W(:,trial)).^2./a.variance);
end
end
