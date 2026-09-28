function r=study_pd_K5(base,e)
if ~isfield(e,'families'), e.families={'cosine_1','cosine','SQ'}; end
if ~isfield(e,'cosine_fov_deg')
    e.cosine_fov_deg=e.outer_fov_deg;
    if isfield(e,'legacy_fov_deg'), e.cosine_fov_deg=e.legacy_fov_deg; end
end
if ~isfield(e,'m_R'), e.m_R=[]; end
r.kind='K5'; r.parameters=base; r.spec=e;
r.cases=bastiaens2020_cases(base,e.device,e.outer_fov_deg,e.cosine_fov_deg,e.families,e.m_R);
r.runs=cell(1,numel(r.cases)); tables=cell(size(r.runs)); selections=tables; descriptions=tables;
for i=1:numel(r.cases)
    pc=r.cases(i).parameters;
    descriptions{i}=addvars(struct2table(rx_receiver_description(pc)),string(r.cases(i).id),'Before',1,'NewVariableNames','ModelID');
    fprintf('\nMODEL %s: %s\n',r.cases(i).id,r.cases(i).label); disp(descriptions{i});
    run=study_K5_tilt_coverage(pc,e);
    run.table.ModelID=repmat(string(r.cases(i).id),height(run.table),1);
    run.selection_table.ModelID=repmat(string(r.cases(i).id),height(run.selection_table),1);
    r.runs{i}=run; tables{i}=run.table; selections{i}=run.selection_table;
    disp(run.selection_table);
end
r.table=vertcat(tables{:}); r.selection_table=vertcat(selections{:}); r.model_table=vertcat(descriptions{:});
end
