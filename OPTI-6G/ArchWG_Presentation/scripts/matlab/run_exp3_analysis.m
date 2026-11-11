% Runs the exp3_SpatialDF analysis (all sessions) for the ArchWG presentation.
% Does NOT modify the experiment folders: outputs go to ArchWG_Presentation/results.
function run_exp3_analysis()
here    = fileparts(mfilename('fullpath'));
presDir = fileparts(fileparts(here));
simRoot = fileparts(fileparts(presDir));
exp3Dir = fullfile(simRoot, 'ExpValidation_Journal', 'Experiments', 'exp3_SpatialDF');
addpath(fullfile(exp3Dir, 'lib'));
resDir  = fullfile(presDir, 'results');
if ~exist(resDir, 'dir'), mkdir(resDir); end

d = dir(fullfile(exp3Dir, 'data', '2026*'));
dataDirs = {d([d.isdir]).name};

base = struct();
base.dataDirs     = dataDirs;
base.estimators   = {'GLS','WLS','NLS'};
base.m            = 3.13;
base.C_opt        = [];
base.nadirXYtol   = 0.03;
base.nadirInclTol = 1.0;
base.nadirScanKind= '';
base.v_dark       = 0.05;
base.T            = [0 0 2];
base.nlsUseProfile= false;
base.autoRefMax   = true;
base.saveFigures  = false;

kinds  = {'vertical','tilt'};
Kset   = {1:9, 1:12};
Cmodes = {'nadir','empirical'};
S = struct();
for ik = 1:numel(kinds)
    for iK = 1:numel(Kset)
        for ic = 1:numel(Cmodes)
            cfg = base;
            cfg.scanKind = kinds{ik};
            cfg.K_id     = Kset{iK};
            cfg.C_mode   = Cmodes{ic};
            cfg.outDir   = fullfile(resDir, sprintf('exp3_%s_K%d_%s', kinds{ik}, numel(Kset{iK}), Cmodes{ic}));
            if ~exist(cfg.outDir, 'dir'), mkdir(cfg.outDir); end
            R = df_run_analysis(cfg);
            close all;
            R = rmfield(R, 'data');
            name = sprintf('%s_K%d_%s', kinds{ik}, numel(Kset{iK}), Cmodes{ic});
            S.(name) = R;
        end
    end
end
save(fullfile(resDir, 'exp3_results.mat'), 'S', 'dataDirs');
fprintf('\n\n######## SUMMARY ########\n');
fn = fieldnames(S);
for i = 1:numel(fn)
    R = S.(fn{i});
    fprintf('%-26s  n=%4d  C=%.4f\n', fn{i}, R.nInstances, R.C_opt);
    for k = 1:numel(R.methods)
        dm = R.metrics.direction(k); pm = R.metrics.position(k);
        fprintf('    %-12s dir[deg] mean=%5.2f med=%5.2f p90=%5.2f | pos[cm] rmse=%6.2f mean=%6.2f med=%6.2f p90=%6.2f\n', ...
            R.methods{k}, dm.mean, dm.median, dm.cdf90, 100*pm.rmse, 100*pm.mean, 100*pm.median, 100*pm.cdf90);
    end
end
end
