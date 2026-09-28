function [figures,output_directory]=replot_paper_PD(mat_file,style)
cambridge_setup();
if nargin<2, style=ieee_plot_style(); end
saved=load(mat_file,'result'); r=saved.result;
source=dir(mat_file);
output_directory=fullfile(source.folder,['figures_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
assert(~isfolder(output_directory),'cambridge:ExistingResults','Refusing to overwrite figures.'); mkdir(output_directory);
switch r.kind
    case 'responses', figures=plot_pd_responses(r,style);
    case 'K5', figures=plot_pd_K5(r,style);
    case 'estimators', figures=plot_pd_estimators(r,style);
    otherwise, error('cambridge:PaperPlotKind','Unknown paper dataset.');
end
rx_export_figures(figures,output_directory,style);
fprintf('Plot-only paper PD output: %s\n',output_directory);
end
