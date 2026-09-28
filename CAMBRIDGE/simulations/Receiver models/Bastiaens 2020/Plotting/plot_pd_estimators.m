function figures=plot_pd_estimators(r,style)
e=r.spec; M=numel(e.methods);
figures=rx_ieee_figure('PD_estimators_vs_samples',style,3.9);
layout=tiledlayout(figures(1),1,2,'TileSpacing','compact','Padding','loose');
ax=nexttile(layout); hold(ax,'on'); handles=gobjects(1,M+1);
for im=1:M
    value=cellfun(@(x) x.table.RMSE_success_cm(im),r.runs);
    handles(im)=rx_design_line(ax,e.sample_values,value,im,style);
end
peb=cellfun(@(x) 100*sqrt(mean(x.peb_m.^2)),r.runs);
handles(end)=plot(ax,e.sample_values,peb,'k--','LineWidth',1.3);
set(ax,'XScale','log','YScale',style.peb_scale);
if ~isempty(style.peb_limits_cm), ylim(ax,style.peb_limits_cm); end
xlabel(ax,'Samples per orientation'); ylabel(ax,'Successful-estimate RMSE / PEB (cm)');
rx_ieee_axes(ax,style,true);
lg=legend(ax,handles,[strrep(e.methods,'_',' ') {'Matched PEB'}],'NumColumns',2,'Box','off'); lg.Layout.Tile='north';
ax=nexttile(layout); hold(ax,'on');
for im=1:M
    value=cellfun(@(x) x.table.Failure_percent(im),r.runs);
    rx_design_line(ax,e.sample_values,value,im,style);
end
set(ax,'XScale','log'); xlabel(ax,'Samples per orientation'); ylabel(ax,'Failed estimates (%)');
ylim(ax,[0 max(1,1.1*max(r.table.Failure_percent))]); rx_ieee_axes(ax,style);
figures(2)=rx_ieee_figure('PD_estimator_error_CDF',style,3.5);
ax=axes(figures(2)); hold(ax,'on');
[~,index]=min(abs(e.sample_values-1000)); data=r.runs{index};
for im=1:M
    [x,f]=rx_empirical_cdf(100*data.errors_m(:,:,im));
    stairs(ax,x,f,'Color',style.colors(im,:),'LineWidth',style.line_width);
end
xlabel(ax,'3D position error (cm)'); ylabel(ax,'Empirical probability (all trials)'); ylim(ax,[0 1]);
legend(ax,strrep(e.methods,'_',' '),'Location','southeast','Box','off');
title(ax,sprintf('Truth: %s %s; K=%d; N_i=%d',e.device,e.truth_family,e.K,e.sample_values(index)));
rx_ieee_axes(ax,style);
end
