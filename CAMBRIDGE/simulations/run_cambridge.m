function results = run_cambridge(mode, p)
if nargin < 1
    mode = 'full';
end
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'System'), fullfile(root, 'System', 'Parameters'));
addpath(fullfile(root, 'Bounds (3D)', 'Position Error Bound'));
addpath(fullfile(root, 'Design of the Parameters (CRLB design)'));
if nargin < 2
    p = system_parameters();
end
switch mode
    case 'test'
        results = runtests(fullfile(root, 'tests'));
        assertSuccess(results);
        return;
    case 'quick'
        p.environment.x_m = linspace(min(p.environment.x_m), max(p.environment.x_m), 9);
        p.environment.y_m = linspace(min(p.environment.y_m), max(p.environment.y_m), 9);
        p.environment.z_m = linspace(min(p.environment.z_m), max(p.environment.z_m), 4);
        p.design.tilt_values_deg = unique([0:5:p.receiver.max_tilt_deg, atan(2)*180/pi]);
        p.design.refinement_steps_deg = [4 1];
        p.design.refinement_passes = 1;
    case 'full'
    otherwise
        error('cambridge:RunMode', 'Choose full, quick or test.');
end
p.execution_mode = mode;
output_parent = fullfile(root, 'Design of the Parameters (CRLB design)', 'results');
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
output_dir = fullfile(output_parent, [mode '_' stamp]);
assert(~isfolder(output_dir), 'cambridge:ExistingResults', 'Refusing to overwrite a results directory.');
mkdir(output_dir);
results = run_parameter_design(p, output_dir);
end
