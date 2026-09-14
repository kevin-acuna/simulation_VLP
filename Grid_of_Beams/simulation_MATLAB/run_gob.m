function result = run_gob(mode,overrides)
if nargin<1, mode = 'demo'; end
if nargin<2, overrides = struct(); end
root = gob_paths(); mode = string(mode);
if mode=="test"
    result = runtests(fullfile(root,'pruebas')); assertSuccess(result);
    save(fullfile(root,'pruebas','ultimo_resultado.mat'),'result');
    return
end
if mode=="demo"
    result = gob_localize("tile_baseline_core_3d",[],[.213;-.147;.436]);
    disp(result); return
end
options = gob_run_options(mode,overrides);
if ismember(mode,["plots","verify","report"])
    outputDir = string(options.output_directory);
    if strlength(outputDir)==0
        latest = load(fullfile(root,'resultados','ultimo_completo.mat')); outputDir = latest.output_directory;
    end
    switch mode
        case "plots", gob_plot_results(outputDir,options.visible);
        case "verify", gob_verify_results(outputDir);
        case "report", gob_report_tables(outputDir,root);
    end
    result = struct('output_directory',outputDir); return
end
assert(ismember(mode,["full","quick"]),'gob:Mode','Use demo, test, quick, full, plots, verify or report.');
outputDir = string(options.output_directory);
if strlength(outputDir)==0
    stamp = string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    outputDir = string(fullfile(root,'resultados',mode+"_"+stamp));
end
assert(~isfolder(outputDir),'gob:ExistingResults','Refusing to overwrite %s.',outputDir);
mkdir(outputDir);
for folder = ["tablas","mapas","ensayos","datos","figuras"]
    mkdir(fullfile(outputDir,folder));
end
cases = gob_study_cases();
if options.scope~="all", cases = cases(startsWith([cases.name],options.scope)); end
if ~isempty(options.case_filter), cases = cases(ismember([cases.name],options.case_filter)); end
assert(~isempty(cases),'gob:Cases','No cases selected.');
environment = struct('matlab_version',version,'toolboxes',ver,'rng','mt19937ar','solver','lsqnonlin trust-region-reflective');
status = "running";
save(fullfile(outputDir,'manifest.mat'),'options','cases','environment','status');
fprintf('Directorio de resultados: %s\n',outputDir);
rows = cell(1,numel(cases));
for k = 1:numel(cases)
    rows{k} = gob_run_case(cases(k),options,outputDir);
    summary = struct2table([rows{1:k}]); writetable(summary,fullfile(outputDir,'tablas','summary.csv'));
end
if options.sweeps, gob_design_sweep(outputDir,options); end
if options.controls, gob_controls(outputDir,options); end
if options.rays, gob_ray_validation(outputDir,options); end
if options.robustness, gob_robustness(outputDir,options); end
status = "complete";
save(fullfile(outputDir,'manifest.mat'),'options','cases','environment','status');
if options.export_figures, gob_plot_results(outputDir,options.visible); end
gob_verify_results(outputDir);
if mode=="full" && numel(cases)==25 && options.trials==300 && options.resolution==61
    output_directory = outputDir;
    save(fullfile(root,'resultados','ultimo_completo.mat'),'output_directory');
end
result = struct('output_directory',outputDir,'summary',summary,'options',options);
end
