function gob_plot_design(outputDir,visible)
path = fullfile(outputDir,'tablas','design_sweep.csv');
if isfile(path)
    t = gob_read_table(path); mask = startsWith(t.variant,"pitch") & t.region=="tile_ninth";
    t = t(mask,:); pitches = unique(t.pitch_mm); values = nan(numel(pitches),3);
    for j = 1:numel(pitches)
        masks = {t.K==1,t.K==2,t.K>=7};
        for k = 1:3
            rows = abs(t.pitch_mm-pitches(j))<1e-10 & masks{k};
            if any(rows), values(j,k) = 100*max(t.fraction_peb_10cm(rows)); end
        end
    end
    f = figure('Visible',visible,'Color','w','Position',[30,30,1000,440]); ax = axes(f);
    plot(ax,pitches,values,'-o','LineWidth',1.4);
    xlabel(ax,'Pitch [mm]'); ylabel(ax,'Puntos con PEB < 10 cm [%]'); ylim(ax,[0,100]);
    legend(ax,{'Mejor focal muestreada','Mejor par muestreado','Barrido completo (7/8 estados)'},'Location','best');
    grid(ax,'on'); title(ax,'Noveno nominal: mejor cobertura de la malla por grupo, no óptimo global');
    gob_save_figure(f,outputDir,"13_barrido_pitch");
end
path = fullfile(outputDir,'tablas','diversity_controls.csv');
if isfile(path)
    t = gob_read_table(path); t = t(abs(t.half_width_m-.6)<1e-10 & t.gain_mode=="known",:);
    states = ["15","15,15","12,15","15,15,15,15,15,15,15,15","10,11,12,13,15,17,20,25"];
    values = zeros(5,2);
    for k = 1:5
        row = t(t.radii_mm==states(k),:);
        values(k,:) = [row.peb_p95_m,100*row.fraction_peb_10cm];
    end
    labels = {'Una focal','Repetir K=2','Variar K=2','Repetir K=8','Variar K=8'};
    f = figure('Visible',visible,'Color','w','Position',[30,30,1150,440]); tiledlayout(1,2,'TileSpacing','compact');
    ax = nexttile; bar(ax,values(:,1)); set(ax,'YScale','log','XTick',1:5,'XTickLabel',labels);
    xtickangle(ax,25); ylabel(ax,'P95 espacial de PEB [m]'); grid(ax,'on');
    ax = nexttile; bar(ax,values(:,2)); set(ax,'XTick',1:5,'XTickLabel',labels);
    xtickangle(ax,25); ylabel(ax,'Puntos con PEB < 10 cm [%]'); ylim(ax,[0,100]); grid(ax,'on');
    sgtitle('Mismo presupuesto de integración, mismo dominio de base 1.2 m');
    gob_save_figure(f,outputDir,"14_repeticion_vs_diversidad");
end
path = fullfile(outputDir,'tablas','grid_tilt_sweep.csv');
if isfile(path)
    t = gob_read_table(path); sets = ["15","12,15","10,12,15","10,12,15,17"];
    f = figure('Visible',visible,'Color','w','Position',[30,30,1000,440]); ax = axes(f); hold(ax,'on');
    for k = 1:numel(sets)
        rows = t.radii_mm==sets(k);
        plot(ax,t.tilt_deg(rows),100*t.fraction_peb_10cm(rows),'-o','LineWidth',1.3,'DisplayName',"R = "+sets(k)+" mm");
    end
    xlabel(ax,'Inclinación periférica [grados]'); ylabel(ax,'Puntos con PEB < 10 cm [%]'); ylim(ax,[0,100]);
    legend(ax,'Location','best'); grid(ax,'on'); title(ax,'AP de base 5 m: modelo circular, cuatro conjuntos representativos');
    gob_save_figure(f,outputDir,"15_barrido_inclinacion");
end
end
