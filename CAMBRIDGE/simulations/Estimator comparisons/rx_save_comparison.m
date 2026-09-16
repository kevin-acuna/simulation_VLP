function result = rx_save_comparison(result, name)
parent = fileparts(mfilename('fullpath'));
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
output_dir = fullfile(parent, 'results', [name '_' stamp]);
assert(~isfolder(output_dir), 'cambridge:ExistingResults', 'Refusing to overwrite comparison data.');
mkdir(output_dir);
result.output_directory = output_dir;
result.generated_at = char(datetime('now'));
result.matlab_version = version;
save(fullfile(output_dir, 'comparison_results.mat'), 'result', '-v7.3');
writetable(result.table, fullfile(output_dir, 'metrics.csv'));
fprintf('Saved comparison: %s\n', output_dir);
end
