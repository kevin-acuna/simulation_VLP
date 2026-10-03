function gob_save_figure(fig,outputDir,name)
folder = fullfile(outputDir,'figuras');
if ~isfolder(folder), mkdir(folder); end
set(findall(fig,'Type','axes'),'FontSize',10,'FontName','Arial','TickLabelInterpreter','none');
exportgraphics(fig,fullfile(folder,name+".png"),'Resolution',180,'BackgroundColor','white');
exportgraphics(fig,fullfile(folder,name+".pdf"),'ContentType','vector','BackgroundColor','white');
savefig(fig,fullfile(folder,name+".fig"));
close(fig);
end
