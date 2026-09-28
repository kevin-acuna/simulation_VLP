function figures=plot_pd_K5(r,style)
sigmas=r.runs{1}.orientation_std_values_deg; e=r.spec;
sigma_label='\sigma_{orient}'; protocol='Independent receiver-orientation uncertainty';
if strcmp(e.orientation_structure,'common_rotation')
    sigma_label='\sigma_{attitude}'; protocol='Common attitude-reference uncertainty';
end
figures=gobjects(1,2+numel(r.cases));
figures(1)=rx_ieee_figure('K5_PD_model_coverage',style,4.0);
layout=tiledlayout(figures(1),1,numel(sigmas),'TileSpacing','compact','Padding','loose');
for is=1:numel(sigmas)
    ax=nexttile(layout); hold(ax,'on'); handles=gobjects(1,numel(r.cases));
    for im=1:numel(r.cases)
        g=r.runs{im}.grid_results{2};
        handles(im)=rx_design_line(ax,e.tilt_values_deg,100*g.coverage(:,is),im,style);
    end
    yline(ax,e.minimum_coverage_percent,'k:','HandleVisibility','off');
    xlabel(ax,'Common PD inclination \theta (deg)');
    ylabel(ax,sprintf('Grid positions with PEB <= %g cm (%%)',rx_coverage_threshold(r.parameters)));
    title(ax,sprintf('K=%d; %s=%g deg/component',e.K,sigma_label,sigmas(is)));
    ylim(ax,[0 103]); rx_ieee_axes(ax,style); xlim(ax,[0 90]); xticks(ax,0:15:90);
    if is==1
        lg=legend(ax,handles,{r.cases.label},'NumColumns',min(2,numel(r.cases)),'Box','off'); lg.Layout.Tile='north';
    end
end
figures(2)=rx_ieee_figure('K5_PD_model_conditional_PEB',style,4.0);
layout=tiledlayout(figures(2),1,numel(sigmas),'TileSpacing','compact','Padding','loose');
for is=1:numel(sigmas)
    ax=nexttile(layout); hold(ax,'on'); handles=gobjects(1,numel(r.cases));
    for im=1:numel(r.cases)
        g=r.runs{im}.grid_results{2};
        handles(im)=rx_design_line(ax,e.tilt_values_deg,100*g.rms_conditional_m(:,is),im,style);
    end
    yline(ax,10,':','10 cm','Color',[.5 .5 .5],'LineWidth',1, ...
        'LabelHorizontalAlignment','right','LabelVerticalAlignment','bottom', ...
        'FontName',style.font_name,'FontSize',style.font_size, ...
        'HandleVisibility','off','Tag','PEB_10cm_reference');
    xlabel(ax,'Common PD inclination \theta (deg)'); ylabel(ax,'RMS-PEB over finite points (cm)');
    title(ax,sprintf('%s=%g deg/component; finite subset only',sigma_label,sigmas(is)));
    set(ax,'YScale',style.peb_scale);
    if ~isempty(style.peb_limits_cm), ylim(ax,style.peb_limits_cm); end
    rx_ieee_axes(ax,style,true); xlim(ax,[0 90]); xticks(ax,0:15:90);
    if is==1
        lg=legend(ax,handles,{r.cases.label},'NumColumns',min(2,numel(r.cases)),'Box','off'); lg.Layout.Tile='north';
    end
end
for im=1:numel(r.cases)
    map=plot_K5_target_design(r.runs{im},style,'maps');
    name=['K5_' r.cases(im).id '_spatial_coverage'];
    map.Name=name; map.UserData.export_name=name;
    sgtitle(map,[r.cases(im).label ' | ' protocol],'FontName',style.font_name,'FontSize',style.font_size);
    figures(2+im)=map;
end
end
