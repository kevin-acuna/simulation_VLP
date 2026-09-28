function r=study_pd_responses(base,e)
validateattributes(e.angles_deg,{'numeric'},{'real','finite','vector','nonempty','>=',0,'<=',90});
if ~isfield(e,'families'), e.families={'cosine_1','cosine','SQ'}; end
if ~isfield(e,'cosine_fov_deg'), e.cosine_fov_deg=e.outer_fov_deg; end
if ~isfield(e,'m_R'), e.m_R=[]; end
e.families=cellstr(string(e.families));
r.kind='responses'; r.parameters=base; r.spec=e;
r.curves=cell(numel(e.devices),numel(e.families)); rows=cell(size(r.curves));
r.labels=cell(size(r.curves));
for id=1:numel(e.devices)
    cases=bastiaens2020_cases(base,e.devices{id},e.outer_fov_deg,e.cosine_fov_deg,e.families,e.m_R);
    for im=1:numel(cases)
        p=cases(im).parameters;
        [h,ds,info]=rx_receiver_response(cosd(e.angles_deg),p);
        curve=struct('parameters',p,'response',h,'slope_per_rad',-ds.*sind(e.angles_deg), ...
            'cutoff_deg',info.effective_cutoff_deg,'label',cases(im).label,'family',cases(im).family);
        curve.slope_per_rad(info.boundary)=NaN;
        r.curves{id,im}=curve; r.labels{id,im}=cases(im).label;
        rows{id,im}=addvars(struct2table(rx_receiver_description(p)),string(cases(im).id), ...
            'Before',1,'NewVariableNames','ModelID');
    end
end
r.model_table=vertcat(rows{:}); r.table=r.model_table;
end
