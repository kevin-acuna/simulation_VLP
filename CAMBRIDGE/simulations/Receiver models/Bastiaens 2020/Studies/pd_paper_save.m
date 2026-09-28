function result = pd_paper_save(result, name, transcript)
parent = fileparts(fileparts(mfilename('fullpath')));
result.output_directory = fullfile(parent,'results',[name '_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
assert(~isfolder(result.output_directory),'cambridge:ExistingResults','Refusing to overwrite results.');
mkdir(result.output_directory);
result.generated_at = char(datetime('now'));
result.matlab_version = version;
save(fullfile(result.output_directory,'paper_results.mat'),'result','-v7.3');
if isfield(result,'table'), writetable(result.table,fullfile(result.output_directory,'metrics.csv')); end
if isfield(result,'model_table'), writetable(result.model_table,fullfile(result.output_directory,'models.csv')); end
if isfield(result,'selection_table'), writetable(result.selection_table,fullfile(result.output_directory,'selected_tilts.csv')); end
fid=fopen(fullfile(result.output_directory,'parameters.txt'),'wt');
assert(fid>=0,'cambridge:Manifest','Cannot write manifest.');
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s',regexprep(transcript,'</?strong>',''));
fprintf('Paper-model results saved: %s\n',result.output_directory);
end
