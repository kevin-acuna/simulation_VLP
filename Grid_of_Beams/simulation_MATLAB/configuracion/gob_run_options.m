function options = gob_run_options(mode,overrides)
if nargin<1, mode = 'full'; end
if nargin<2, overrides = struct(); end
options = struct('trials',300,'resolution',61,'design_resolution',17,'ray_count',200000, ...
    'robustness_trials',100,'seed',20260912,'scope',"all",'case_filter',strings(1,0), ...
    'output_directory',"",'sweeps',true,'controls',true,'rays',true,'robustness',true, ...
    'export_figures',true,'visible','off','run_mode',string(mode));
if strcmp(mode,'quick')
    options.trials = 12; options.resolution = 13; options.design_resolution = 9;
    options.ray_count = 10000; options.robustness_trials = 8;
    options.sweeps = false;
    options.case_filter = ["tile_baseline_core_2d","tile_baseline_core_3d", ...
        "tile_convex_core_3d","grid_convex_core_3d","tile_diverging_ninth_3d"];
end
options = gob_update(options,overrides);
end
