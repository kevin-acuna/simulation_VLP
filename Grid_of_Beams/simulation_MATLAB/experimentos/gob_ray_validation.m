function results = gob_ray_validation(outputDir,options)
radii = [.012,.015,-.010,-.011,.010]; rows = cell(1,15); examples = cell(1,15); k = 0;
for radius = radii
    edge = .002;
    if radius<0, edge = .006; end
    c = gob_config(struct('radii',radius,'edge_thickness',edge));
    for channel = [13,3,1]
        k = k+1; [rows{k},examples{k}] = gob_trace_beam(c,channel,options.ray_count);
    end
end
results = struct2table([rows{:}]);
writetable(results,fullfile(outputDir,'tablas','ray_validation.csv'));
save(fullfile(outputDir,'datos','ray_examples.mat'),'examples','results');
fprintf('Comprobacion optica independiente: %d rayos.\n',sum(results.rays));
end
