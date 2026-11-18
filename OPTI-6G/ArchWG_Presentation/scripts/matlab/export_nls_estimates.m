% Writes the model-based NLS estimates (K = 9, nadir C) per fix, used as input of the ML correction.
function export_nls_estimates()
here = fileparts(mfilename('fullpath')); resDir = fullfile(fileparts(fileparts(here)), 'results');
L = load(fullfile(resDir, 'exp3_results.mat'));
fid = fopen(fullfile(resDir, 'nls_estimates.csv'), 'w');
fprintf(fid, 'kind,label,%s,nls_x,nls_y,nls_z\n', strjoin(compose('V_k%d', 1:9), ','));
for kind = ["vertical", "tilt"]
    R = L.S.(kind + "_K9_nadir"); k = find(strcmp(R.estimators, 'NLS'));
    for j = 1:R.nInstances
        fprintf(fid, '%s,%s,%s,%.6f,%.6f,%.6f\n', kind, R.labels(j), strjoin(compose('%.10g', R.V(j,:)), ','), R.est(j,1,k), R.est(j,2,k), R.est(j,3,k));
    end
end
fclose(fid);
end
