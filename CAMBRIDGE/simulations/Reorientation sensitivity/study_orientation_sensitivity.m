function result = study_orientation_sensitivity(p, e)
validateattributes(e.orientation_variances_deg2, {'numeric'}, {'real', 'finite', 'nonnegative', 'vector', 'nonempty'});
result.parameters = p;
result.experiment = e;
result.runs = cell(numel(e.orientation_variances_deg2), numel(e.cases));
rows = cell(size(result.runs));
for ic = 1:numel(e.cases)
    [pc, normals] = rx_case_parameters(p, e.cases(ic));
    rx_print_comparison(pc, normals, e);
    fprintf('Orientation error model: %s / %s\n', e.mode, e.structure);
    fprintf('Variance per angular component [deg^2]: %s; errors are constant over N optical samples.\n', mat2str(e.orientation_variances_deg2));
    for iv = 1:numel(e.orientation_variances_deg2)
        variance = e.orientation_variances_deg2(iv);
        run = rx_sensitivity_run(pc, normals, e, variance);
        result.runs{iv, ic} = run;
        rows{iv, ic} = addvars(run.table, repmat(ic, height(run.table), 1), ...
            repmat(variance, height(run.table), 1), repmat(100*run.visibility_disagreement_fraction, height(run.table), 1), ...
            'Before', 1, 'NewVariableNames', {'Case', 'OrientationVariance_deg2', 'VisibilityDisagreement_percent'});
        fprintf('Case %d, variance=%g deg^2, bound RMS=%.4g cm, mask disagreement=%.3f%%\n', ...
            ic, variance, 100*sqrt(mean(run.peb_m.^2)), 100*run.visibility_disagreement_fraction);
    end
end
result.table = vertcat(rows{:});
parent = fileparts(mfilename('fullpath'));
result.output_directory = fullfile(parent, 'results', [e.mode '_' e.structure '_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))]);
assert(~isfolder(result.output_directory), 'cambridge:ExistingResults', 'Refusing to overwrite sensitivity data.');
mkdir(result.output_directory);
result.generated_at = char(datetime('now'));
result.matlab_version = version;
save(fullfile(result.output_directory, 'sensitivity_results.mat'), 'result', '-v7.3');
writetable(result.table, fullfile(result.output_directory, 'metrics.csv'));
fprintf('Sensitivity results saved: %s\n', result.output_directory);
end
