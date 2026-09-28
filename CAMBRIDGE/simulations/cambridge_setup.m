function root = cambridge_setup()
root = fileparts(mfilename('fullpath'));
design = fullfile(root, 'Design of the Parameters (CRLB design)');
models = fullfile(root, 'Receiver models');
paper = fullfile(models, 'Bastiaens 2020');
addpath(models, paper, fullfile(paper,'Parameters'), fullfile(paper,'Estimators'), ...
    fullfile(paper,'Experiments'), fullfile(paper,'Studies'), fullfile(paper,'Plotting'));
addpath(root, fullfile(root, 'System'), fullfile(root, 'System', 'Parameters'));
addpath(fullfile(root, 'Coverage target design'));
addpath(fullfile(root, 'Bounds (3D)', 'Position Error Bound'));
addpath(fullfile(root, 'Estimators'), fullfile(root, 'Estimator comparisons'), fullfile(root, 'Reorientation sensitivity'));
addpath(design, fullfile(design, 'studies'), fullfile(design, 'plotting'), fullfile(design, 'support'));
end
