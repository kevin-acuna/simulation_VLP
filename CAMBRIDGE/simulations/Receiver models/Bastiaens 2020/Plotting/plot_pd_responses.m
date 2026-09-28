function figures=plot_pd_responses(r,style)
e=r.spec;
figures=gobjects(1,2);
names={'PD_normalized_responses','PD_response_derivatives'};
for panel=1:2
    figures(panel)=rx_ieee_figure(names{panel},style,3.7);
    layout=tiledlayout(figures(panel),1,numel(e.devices),'TileSpacing','compact','Padding','loose');
    for id=1:numel(e.devices)
        ax=nexttile(layout); hold(ax,'on');
        handles=gobjects(1,numel(e.families)); labels=cell(size(handles));
        for im=1:numel(e.families)
            curve=r.curves{id,im}; d=rx_receiver_description(curve.parameters);
            angles=e.angles_deg(:)';
            if panel==1
                value=curve.response(:)';
            else
                value=abs(curve.slope_per_rad(:)');
                crossing=find(angles(1:end-1)<curve.cutoff_deg & angles(2:end)>curve.cutoff_deg,1);
                if ~isempty(crossing)
                    angles=[angles(1:crossing) curve.cutoff_deg angles(crossing+1:end)];
                    value=[value(1:crossing) NaN value(crossing+1:end)];
                end
            end
            handles(im)=rx_design_line(ax,angles,value,im,style);
            labels{im}=char(d.Label);
        end
        xlabel(ax,'Incidence angle \psi (deg)');
        if panel==1
            yline(ax,1/sqrt(2),'k:','HandleVisibility','off');
            yline(ax,.5,'k--','HandleVisibility','off');
            ylabel(ax,'Normalized response R(\psi), R(0)=1'); ylim(ax,[0 1.05]);
            location='southwest';
        else
            ylabel(ax,'|dR/d\psi| (rad^{-1}), away from cutoffs'); location='best';
        end
        title(ax,e.devices{id});
        legend(ax,handles,labels,'Location',location,'Box','off');
        rx_ieee_axes(ax,style); xlim(ax,[0 90]); xticks(ax,0:15:90);
    end
end
end
