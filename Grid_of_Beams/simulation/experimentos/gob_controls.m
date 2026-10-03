function gob_controls(outputDir,options)
rows = {}; sets = {.015,[.015,.015],[.012,.015],repmat(.015,1,8),[.010,.011,.012,.013,.015,.017,.020,.025]};
for k = 1:numel(sets)
    R = sets{k}; m = gob_model(gob_config(struct('radii',R))); n = gob_noise(struct('bandwidth',100*numel(R)));
    for gain = ["known","common","per_state"]
        for width = [.45,.6,5/6]
            p = domain_points(width,options.design_resolution);
            label = struct('radii_mm',strjoin(compose('%g',R*1000),','),'K',numel(R),'half_width_m',width,'gain_mode',gain);
            rows{end+1} = gob_merge(label,gob_bound_summary(m,p,n,3,gain));
        end
    end
end
writetable(struct2table([rows{:}]),fullfile(outputDir,'tablas','diversity_controls.csv'));
rows = {}; sets = {.015,[.012,.015],[.010,.013],[.011,.015],[.010,.012,.015],[.010,.012,.015,.017]};
for tilt = [21,24,27,30,33]
    for k = 1:numel(sets)
        R = sets{k}; m = gob_model(gob_config(struct('radii',R,'tiles',9,'tilt_deg',tilt)));
        label = struct('tilt_deg',tilt,'radii_mm',strjoin(compose('%g',R*1000),','),'K',numel(R));
        rows{end+1} = gob_merge(label,gob_bound_summary(m,domain_points(2.5,min(25,options.design_resolution+8)),gob_noise(struct('bandwidth',100*numel(R)))));
    end
end
writetable(struct2table([rows{:}]),fullfile(outputDir,'tablas','grid_tilt_sweep.csv'));
rows = {}; sets = {.015,.45;[.012,.015],.6};
for bandwidth = [10,100,1000,10000]
    for area = [1e-7,1e-6,1e-5]
        for k = 1:2
            R = sets{k,1}; m = gob_model(gob_config(struct('radii',R,'pd_area',area)));
            label = struct('bandwidth_hz_per_reference_pilot',bandwidth,'pd_area_mm2',area*1e6, ...
                'radii_mm',strjoin(compose('%g',R*1000),','),'tile_integration_seconds',25/(2*bandwidth));
            rows{end+1} = gob_merge(label,gob_bound_summary(m,domain_points(sets{k,2},options.design_resolution),gob_noise(struct('bandwidth',bandwidth*numel(R)))));
        end
    end
end
writetable(struct2table([rows{:}]),fullfile(outputDir,'tablas','noise_area_tradeoff.csv'));
rows = {}; sets = {.015,.002;[.012,.015],.002;[-.010,-.011],.006};
for k = 1:3
    R = sets{k,1}; m = gob_model(gob_config(struct('radii',R,'edge_thickness',sets{k,2})));
    p1 = [.21;-.14;.2]; p2 = [p1(1:2)*(3-.8)/(3-p1(3));.8]; P = gob_power(m,[p1,p2]);
    sigma = gob_sigma(P(:,1),gob_noise(struct('bandwidth',100*numel(R))));
    gain = sum(P(:,1).*P(:,2)./sigma.^2)/sum(P(:,2).^2./sigma.^2);
    rows{end+1} = struct('radii_mm',strjoin(compose('%g',R*1000),','),'separation_m',norm(p1-p2), ...
        'gain_on_second_position',gain,'calibrated_distance_sigma',norm((P(:,1)-P(:,2))./sigma), ...
        'free_gain_distance_sigma',norm((P(:,1)-gain*P(:,2))./sigma));
end
writetable(struct2table([rows{:}]),fullfile(outputDir,'tablas','radial_ambiguity.csv'));
fprintf('Controles de diversidad, ganancia, inclinacion y ruido completados.\n');
end

function p = domain_points(width,resolution)
c = struct('half_width',width,'dimensions',3,'frustum',true);
p = gob_metric_grid(c,resolution);
end
