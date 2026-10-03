function gob_export_python_reference(root)
if nargin<1, root = gob_paths(); end
pythonRoot = fullfile(fileparts(root),'simulations');
pyenv('Version','3.12','ExecutionMode','OutOfProcess');
sysmodule = py.importlib.import_module('sys'); osmodule = py.importlib.import_module('os');
py.setattr(sysmodule,'dont_write_bytecode',true);
osmodule.environ.update(py.dict(pyargs('OPENBLAS_NUM_THREADS','1','OMP_NUM_THREADS','1')));
sysmodule.path.insert(int32(0),pythonRoot);
optics = py.importlib.import_module('optics'); inference = py.importlib.import_module('inference');
np = py.importlib.import_module('numpy');
configs = {gob_config(),gob_config(struct('radii',[.012,.015])), ...
    gob_config(struct('radii',[-.010,-.011],'edge_thickness',.006)), ...
    gob_config(struct('tiles',9,'radii',[.013,.015,.020])), ...
    gob_config(struct('tiles',9,'radii',[-.010,-.011],'edge_thickness',.006))};
points = [0,.213,.4,.6,.8,2,.2,-.31;0,-.147,.4,.6,.8,2,.1,.27;0,.436,0,0,0,1,.5,.73];
reference = cell(size(configs));
for k = 1:numel(configs)
    c = configs{k};
    pc = optics.OpticalConfig(pyargs('radii',py.tuple(num2cell(c.radii)), ...
        'tiles',int32(c.tiles),'edge_thickness',c.edge_thickness));
    pm = optics.OpticalModel(pc); result = pm.power_and_jacobian(np.array(points.'));
    powers = result{1}; gradients = result{2}; q = pm.q;
    r = struct('config',c,'points',points,'origins',double(pm.origins.transpose()), ...
        'directions',double(pm.directions.transpose()), ...
        'q',reshape(double(np.ascontiguousarray(np.real(q)))+1i*double(np.ascontiguousarray(np.imag(q))),[],1), ...
        'powers',double(powers.transpose()),'jacobian',double(np.ascontiguousarray(gradients.transpose(py.tuple({int32(1),int32(2),int32(0)})))));
    modes = {'known','common','per_state'};
    for j = 1:numel(modes)
        metrics = inference.information_metrics(pm,np.array(points.'),pyargs('gain_mode',modes{j}));
        axis_std = metrics{'axis_std'}; singular = metrics{'singular'};
        r.information.(modes{j}) = struct('peb',reshape(double(metrics{'peb'}),1,[]), ...
            'axis_std',double(axis_std.transpose()),'singular',double(singular.transpose()));
    end
    reference{k} = r;
end
old = np.load(fullfile(pythonRoot,'results','grid_convex_core_2d_trials.npz'));
truth = double(old.get('truth')); measurements = double(old.get('measurements'));
regression = struct('position',truth(230,:).','measurement',measurements(230,:).');
old.close();
metadata = struct('purpose','Read-only migration reference; not MATLAB experiment results', ...
    'python_version',char(sysmodule.version),'numpy_version',char(py.getattr(np,'__version__')));
save(fullfile(root,'referencias','python_reference.mat'),'reference','regression','metadata');
snapshot = gob_python_snapshot(pythonRoot); initial = load(fullfile(root,'referencias','python_snapshot_initial.mat'));
assert(isequal(snapshot,initial.s),'gob:PythonChanged','Python directory changed during reference extraction.');
fprintf('Exported %d deterministic reference configurations. Python folder unchanged.\n',numel(reference));
end
