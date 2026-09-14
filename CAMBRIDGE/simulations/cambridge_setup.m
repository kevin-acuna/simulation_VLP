function root = cambridge_setup()
root = fileparts(mfilename('fullpath'));
design = fullfile(root, 'Design of the Parameters (CRLB design)');
addpath(root, fullfile(root, 'System'), fullfile(root, 'System', 'Parameters'));
addpath(fullfile(root, 'Bounds (3D)', 'Position Error Bound'));
addpath(design, fullfile(design, 'studies'), fullfile(design, 'plotting'), fullfile(design, 'support'));
end
