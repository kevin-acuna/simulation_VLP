function cases = gob_study_cases()
b = gob_config(); convex = gob_config(struct('radii',[.012,.015]));
concave = gob_config(struct('radii',[-.010,-.011],'edge_thickness',.006));
base = struct('name',"",'config',b,'half_width',.45,'dimensions',3,'frustum',true,'gain_unknown',false);
groups = {"tile_baseline_core",b,.45;"tile_baseline_ninth",b,5/6; ...
    "tile_convex_core",convex,.6;"tile_diverging_ninth",concave,5/6; ...
    "grid_baseline_full",gob_update(b,struct('tiles',9)),2.5; ...
    "grid_convex_core",gob_update(convex,struct('tiles',9)),1.8; ...
    "grid_diverging_full",gob_update(concave,struct('tiles',9)),2.5; ...
    "grid_convex_retilted_full",gob_update(b,struct('tiles',9,'tilt_deg',27,'radii',[.010,.012,.015])),2.5};
cases = repmat(base,1,0);
for k = 1:size(groups,1)
    for d = [2,3]
        c = base; c.name = groups{k,1}+"_"+d+"d";
        c.config = groups{k,2}; c.half_width = groups{k,3}; c.dimensions = d;
        cases(end+1) = c;
    end
end
extra = {"tile_convex_ninth_3d",convex,5/6,true; ...
    "tile_scan8_ninth_3d",gob_update(b,struct('radii',[.010,.011,.012,.013,.015,.017,.020,.025])),5/6,true; ...
    "tile_diverging_single_3d",gob_update(concave,struct('radii',-.010)),5/6,true; ...
    "grid_convex_full_3d",gob_update(convex,struct('tiles',9)),2.5,true; ...
    "tile_diverging_prism_3d",concave,5/6,false; ...
    "grid_diverging_prism_3d",gob_update(concave,struct('tiles',9)),2.5,false};
for k = 1:size(extra,1)
    c = base; c.name = extra{k,1}; c.config = extra{k,2};
    c.half_width = extra{k,3}; c.frustum = extra{k,4}; cases(end+1) = c;
end
names = ["tile_baseline_core_3d","tile_diverging_ninth_3d","grid_diverging_full_3d"];
for k = 1:numel(names)
    c = cases(find([cases.name]==names(k),1));
    c.name = c.name+"_unknown_gain"; c.gain_unknown = true; cases(end+1) = c;
end
end
