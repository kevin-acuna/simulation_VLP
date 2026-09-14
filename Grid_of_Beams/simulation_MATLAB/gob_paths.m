function root = gob_paths()
root = fileparts(mfilename('fullpath'));
folders = {'configuracion','modelo','estimacion','experimentos','graficas', ...
    'validacion','pruebas','utilidades'};
for k = 1:numel(folders)
    addpath(fullfile(root,folders{k}));
end
end
