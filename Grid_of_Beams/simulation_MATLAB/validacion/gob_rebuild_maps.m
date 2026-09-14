function gob_rebuild_maps(outputDir)
manifest = load(fullfile(outputDir,'manifest.mat'));
assert(manifest.status=="complete",'gob:Incomplete','Wait for the simulation to finish before rebuilding maps.');
summary = gob_read_table(fullfile(outputDir,'tablas','summary.csv'));
for c = manifest.cases
    m = gob_model(c.config); noise = gob_noise(struct('bandwidth',100*numel(c.config.radii)));
    gainMode = 'known'; if c.gain_unknown, gainMode = 'common'; end
    points = gob_metric_grid(c,manifest.options.resolution);
    metrics = gob_information(m,points,noise,c.dimensions,gainMode);
    case_definition = c; model_diagnostics = gob_diagnostics(m);
    save(fullfile(outputDir,'mapas',c.name+".mat"),'points','metrics','case_definition','model_diagnostics','noise');
    index = summary.case_name==c.name;
    summary.grid_peb_median_m(index) = gob_quantile(metrics.peb,.5,false);
    summary.grid_peb_p95_m(index) = gob_quantile(metrics.peb,.95,false);
    summary.grid_peb_max_m(index) = max(metrics.peb);
    summary.grid_fraction_peb_10cm(index) = mean(metrics.peb<.1);
    summary.grid_fraction_full_rank(index) = mean(metrics.rank==c.dimensions);
    summary.grid_minimum_visible_5sigma(index) = min(metrics.visible_5sigma);
end
writetable(summary,fullfile(outputDir,'tablas','summary.csv'));
gob_verify_results(outputDir);
if manifest.options.run_mode=="full" && numel(manifest.cases)==25 && manifest.options.trials==300 && manifest.options.resolution==61
    root = gob_paths(); output_directory = string(outputDir);
    save(fullfile(root,'resultados','ultimo_completo.mat'),'output_directory');
end
end
