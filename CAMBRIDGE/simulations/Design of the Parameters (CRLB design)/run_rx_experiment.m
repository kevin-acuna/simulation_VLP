function result = run_rx_experiment(kind, p, experiment, output_parent)
root = cambridge_setup();
if nargin < 4
    output_parent = fullfile(root, 'Design of the Parameters (CRLB design)', 'results');
end
assert(isfolder(output_parent), 'cambridge:OutputDirectory', 'The output parent must already exist.');
calculators = struct('inclination', @study_inclination, 'K', @study_K, 'area', @study_area, 'heatmap', @study_heatmap, ...
    'tilt_feasibility', @study_tilt_feasibility, 'K_information', @study_K_information, ...
    'link_budget', @study_link_budget, 'coverage_geometry', @study_coverage_geometry);
assert(isfield(calculators, kind), 'cambridge:ExperimentKind', 'Unknown experiment: %s.', kind);
transcript = evalc('rx_print_experiment(kind, p, experiment);');
transcript = regexprep(transcript, '</?strong>', '');
fprintf('%s', transcript);
started = tic;
calculate = calculators.(kind);
result = calculate(p, experiment);
result.elapsed_seconds = toc(started);
result.generated_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
result.matlab_version = version;
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
result.output_directory = fullfile(output_parent, [kind '_' stamp]);
assert(~isfolder(result.output_directory), 'cambridge:ExistingResults', 'Refusing to overwrite an experiment.');
mkdir(result.output_directory);
save(fullfile(result.output_directory, 'experiment_results.mat'), 'result', '-v7.3');
writetable(result.table, fullfile(result.output_directory, 'metrics.csv'));
if isfield(experiment, 'cases')
    writetable(rx_case_table(experiment.cases, kind, p), fullfile(result.output_directory, 'cases.csv'));
end
if isfield(result, 'extra_tables')
    names = fieldnames(result.extra_tables);
    for i = 1:numel(names)
        writetable(result.extra_tables.(names{i}), fullfile(result.output_directory, [names{i} '.csv']));
    end
end
if isfield(result, 'selected') && ~isempty(result.selected)
    fprintf('%s\n', result.selected.policy);
    disp(result.extra_tables.selected_configuration);
    disp(result.extra_tables.selected_validation);
end
fid = fopen(fullfile(result.output_directory, 'parameters.txt'), 'wt');
assert(fid>=0, 'cambridge:Manifest', 'Cannot write the parameter manifest.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', transcript);
finite = result.rms_full_m(isfinite(result.rms_full_m));
fprintf('Completed %d configurations; regular coverage range %.2f--%.2f%%.\n', ...
    height(result.table), 100*min(result.coverage(:)), 100*max(result.coverage(:)));
if isempty(finite)
    fprintf('No configuration has a finite full-domain RMS. Inspect coverage, not only conditional PEB.\n');
else
    fprintf('Smallest full-domain RMS in this experiment: %.6g cm.\n', 100*min(finite));
end
if height(result.table)<=16
    disp(result.table);
end
fprintf('Saved data: %s\n', fullfile(result.output_directory, 'experiment_results.mat'));
end
