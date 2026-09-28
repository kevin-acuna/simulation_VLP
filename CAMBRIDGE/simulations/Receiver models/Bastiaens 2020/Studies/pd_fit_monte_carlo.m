function r=pd_fit_monte_carlo(truth,normals,e)
[r.positions_m,r.grid]=rx_testbed(truth);
P=size(r.positions_m,2); K=size(normals,2); M=numel(e.methods); T=e.trials;
counts=rx_sample_counts(K,truth,e.budget);
[nominal,channel]=rx_peb(r.positions_m,normals,truth,counts);
assert(all(channel.visible,'all') && all(isfinite(nominal)),'cambridge:FitBenchmarkVisibility', ...
    'The shared matched/mismatched benchmark uses explicit full-visibility points. Narrow the ROI or change tilt.');
r.peb_m=nominal;
if e.pose_std_deg>0
    r.peb_m=rx_pose_error_peb(r.positions_m,normals,truth,counts,e.pose_std_deg^2,'independent');
end
r.truth=truth; r.normals=normals; r.experiment=e; r.sample_counts=counts;
r.estimates_m=nan(3,P,T,M); r.errors_m=inf(P,T,M);
r.direction_errors_deg=inf(P,T,M); r.range_errors_m=nan(P,T,M);
r.success=false(P,T,M); r.status=strings(P,T,M); r.rss_W=nan(K,T,P);
r.reported_normals=nan(3,K,T,P);
assumed=bastiaens2020_parameters(truth,e.device,'cosine',e.outer_fov_deg);
r.mismatched_model=assumed;
state=rng; cleanup=onCleanup(@() rng(state)); rng(e.seed,'twister');
noise=sqrt(truth.noise.variance_W2./counts).*randn(K,T,P);
for ip=1:P
    y=channel.mean_W(:,ip)+noise(:,:,ip); r.rss_W(:,:,ip)=y;
    reported=rx_perturb_normals(normals,e.pose_std_deg^2,'independent',T);
    r.reported_normals(:,:,:,ip)=reported;
    for im=1:M
        estimates=nan(3,T); directions=estimates; distances=nan(1,T); good=false(1,T); status=strings(1,T);
        if e.pose_std_deg==0
            if strcmp(e.methods{im},'cosine_NLS_mismatch')
                [estimates,detail]=rx_estimate('NLS',y,normals,assumed,counts);
            else
                [estimates,detail]=pd_fit_estimate(e.methods{im},y,normals,truth,counts,e.solver);
            end
            directions=detail.direction; distances=detail.distance_m; good=detail.success; status=detail.status;
        else
            for j=1:T
                if strcmp(e.methods{im},'cosine_NLS_mismatch')
                    [estimates(:,j),detail]=rx_estimate('NLS',y(:,j),reported(:,:,j),assumed,counts);
                else
                    [estimates(:,j),detail]=pd_fit_estimate(e.methods{im},y(:,j),reported(:,:,j),truth,counts,e.solver);
                end
                directions(:,j)=detail.direction; distances(j)=detail.distance_m;
                good(j)=detail.success; status(j)=detail.status;
            end
        end
        r.estimates_m(:,ip,:,im)=reshape(estimates,3,1,T);
        r.errors_m(ip,good,im)=sqrt(sum((estimates(:,good)-r.positions_m(:,ip)).^2,1));
        cosine=channel.direction_rx_to_tx(:,ip)'*directions(:,good);
        r.direction_errors_deg(ip,good,im)=acosd(max(-1,min(1,cosine)));
        r.range_errors_m(ip,good,im)=distances(good)-channel.distance_m(ip);
        r.success(ip,:,im)=good; r.status(ip,:,im)=status;
    end
end
r=rx_mc_metrics(r);
end
