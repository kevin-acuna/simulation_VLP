function t = gob_read_table(path)
options = detectImportOptions(path,'TextType','string');
textColumns = intersect(options.VariableNames,{'case_name','variant','region','radii_mm','gain_mode','gain','perturbation','reason'});
if ~isempty(textColumns), options = setvartype(options,textColumns,'string'); end
t = readtable(path,options);
end
