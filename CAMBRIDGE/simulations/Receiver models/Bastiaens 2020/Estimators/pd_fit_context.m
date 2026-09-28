function a = pd_fit_context(normals,p,counts,options)
K=size(normals,2);
validateattributes(normals,{'numeric'},{'real','finite','nrows',3,'2d'});
assert(all(abs(sum(normals.^2,1)-1)<1e-10),'cambridge:UnitNormals','Unit normals required.');
if isempty(counts), counts=p.acquisition.samples_per_orientation; end
if isscalar(counts), counts=repmat(counts,K,1); end
counts=counts(:);
validateattributes(counts,{'numeric'},{'integer','positive','finite','numel',K});
validateattributes(p.noise.variance_W2,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(p.transmitter.normal,{'numeric'},{'real','finite','size',[3 1]});
assert(abs(norm(p.transmitter.normal)-1)<1e-10,'cambridge:UnitNormals','Unit LED normal required.');
a.H=normals'; a.p=p; a.q=-p.transmitter.normal;
a.weights=sqrt(counts/mean(counts)); a.variance=p.noise.variance_W2./counts;
a.starts=3; a.max_iterations=80; a.gradient_tolerance=1e-10; a.step_tolerance=1e-9;
a.ambiguity_cost_tolerance=1e-12; a.ambiguity_angle_rad=1e-3;
names=fieldnames(options);
for i=1:numel(names)
    assert(any(strcmp(names{i},{'starts','max_iterations','gradient_tolerance','step_tolerance','ambiguity_cost_tolerance','ambiguity_angle_rad'})), ...
        'cambridge:FitOption','Unknown fit option: %s.',names{i});
    a.(names{i})=options.(names{i});
end
validateattributes(a.starts,{'numeric'},{'scalar','integer','positive'});
E=rx_tangent_basis(a.q);
[theta,azimuth]=ndgrid([20 40 60 80]*pi/180,(0:45:315)*pi/180);
directions=a.q*cos(theta(:)')+E(:,1)*(sin(theta(:)').*cos(azimuth(:)')) ...
    +E(:,2)*(sin(theta(:)').*sin(azimuth(:)'));
a.seeds=[a.q directions normals(:,a.q'*normals>0)];
a.seeds=a.seeds./sqrt(sum(a.seeds.^2,1));
[~,indices]=unique(round(a.seeds'*1e12),'rows','stable');
a.seeds=a.seeds(:,indices);
end
