function r=study_pd_estimators(base,e)
r.kind='estimators'; r.parameters=base; r.spec=e; r.runs=cell(1,numel(e.sample_values)); rows=r.runs;
truth=bastiaens2020_parameters(base,e.device,e.truth_family,e.outer_fov_deg);
r.model_table=struct2table(rx_receiver_description(truth));
normals=rx_cone_normals(e.K,e.tilt_deg,e.azimuth_offset_deg);
for i=1:numel(e.sample_values)
    p=truth; p.acquisition.samples_per_orientation=e.sample_values(i);
    fprintf('Truth=%s/%s; K=%d, tilt=%g deg, N_i=%d; pose std=%g deg; no truth visibility masks.\n', ...
        e.device,e.truth_family,e.K,e.tilt_deg,e.sample_values(i),e.pose_std_deg);
    r.runs{i}=pd_fit_monte_carlo(p,normals,e);
    rows{i}=addvars(r.runs{i}.table,repmat(e.sample_values(i),numel(e.methods),1), ...
        'Before',1,'NewVariableNames','SamplesPerOrientation');
    disp(rows{i});
end
r.table=vertcat(rows{:});
end
