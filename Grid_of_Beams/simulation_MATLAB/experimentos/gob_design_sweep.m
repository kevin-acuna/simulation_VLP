function tableResults = gob_design_sweep(outputDir,options)
configs = {}; labels = strings(1,0); rejected = struct('variant',{},'radii_mm',{},'reason',{});
candidates = [.010,.011,.012,.013,.015,.017,.020,.025];
for pitch = [.0015,.002,.00225,.0025]
    valid = [];
    for R = candidates
        c = gob_config(struct('pitch',pitch,'radii',R));
        try
            gob_model(c); valid(end+1) = R;
        catch problem
            if ~strcmp(problem.identifier,'gob:Geometry'), rethrow(problem); end
            rejected(end+1) = struct('variant',"pitch"+pitch*1000,'radii_mm',R*1000,'reason',string(problem.message));
        end
    end
    pairs = nchoosek(valid,2); states = [num2cell(valid),mat2cell(pairs,ones(size(pairs,1),1),2).',{valid}];
    for k = 1:numel(states)
        configs{end+1} = gob_config(struct('pitch',pitch,'radii',states{k})); labels(end+1) = "pitch"+pitch*1000;
    end
end
variants = {"short_gap",struct('array_lens_distance',.001);"waist3um",struct('waist',3e-6); ...
    "waist2um",struct('waist',2e-6);"large_array",struct('pitch',.004,'diameter',.028,'tile_spacing',.030)};
for j = 1:size(variants,1)
    radii = [.013,.015,.020,.025];
    if j==4, radii = [.020,.022,.025,.030]; end
    pairs = nchoosek(radii,2); states = [num2cell(radii),mat2cell(pairs,ones(size(pairs,1),1),2).'];
    for k = 1:numel(states)
        configs{end+1} = gob_update(gob_config(variants{j,2}),struct('radii',states{k})); labels(end+1) = variants{j,1};
    end
end
regions = {"tile_core",.6,true;"tile_ninth",5/6,true;"tile_prism",5/6,false};
rows = cell(1,0);
for k = 1:numel(configs)
    c = configs{k};
    try
        m = gob_model(c);
    catch problem
        if ~strcmp(problem.identifier,'gob:Geometry'), rethrow(problem); end
        continue
    end
    n = gob_noise(struct('bandwidth',100*numel(c.radii)));
    for j = 1:size(regions,1)
        domain = struct('half_width',regions{j,2},'frustum',regions{j,3},'dimensions',3);
        summary = gob_bound_summary(m,gob_metric_grid(domain,options.design_resolution),n);
        label = struct('variant',labels(k),'region',regions{j,1},'pitch_mm',c.pitch*1000, ...
            'radii_mm',strjoin(compose('%g',c.radii*1000),','),'K',numel(c.radii));
        rows{end+1} = gob_merge(label,summary);
    end
end
tableResults = struct2table([rows{:}]);
writetable(tableResults,fullfile(outputDir,'tablas','design_sweep.csv'));
if ~isempty(rejected), writetable(struct2table(rejected),fullfile(outputDir,'tablas','design_rejected.csv')); end
save(fullfile(outputDir,'datos','design_configurations.mat'),'configs','labels','regions');
fprintf('Barrido de diseno: %d filas, %d configuraciones candidatas.\n',height(tableResults),numel(configs));
end
