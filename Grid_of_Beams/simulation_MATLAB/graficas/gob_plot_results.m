function gob_plot_results(outputDir,visible)
if nargin<2, visible = 'off'; end
gob_plot_optics(outputDir,visible);
keys = ["tile_baseline_ninth_3d","tile_convex_core_3d","tile_diverging_ninth_3d", ...
    "grid_baseline_full_3d","grid_convex_core_3d","grid_diverging_full_3d"];
names = ["Un tile, K=1, noveno nominal","Un tile, K=2, base 1.2 m","Cóncava K=2, noveno (ideal)", ...
    "Nueve tiles K=1, base 5 m","Nueve tiles K=2, base 3.6 m","Cóncava K=2, base 5 m (ideal)"];
f = figure('Visible',visible,'Color','w','Position',[20,20,1250,750]); layout = tiledlayout(2,3,'TileSpacing','compact');
for k = 1:numel(keys)
    ax = nexttile; path = fullfile(outputDir,'mapas',keys(k)+".mat");
    if ~isfile(path), axis(ax,'off'); continue; end
    data = load(path); mask = abs(data.points(3,:))<1e-10; count = round(sqrt(sum(mask)));
    x = unique(data.points(1,mask)); y = unique(data.points(2,mask));
    peb = reshape(data.metrics.peb(mask),count,count);
    imagesc(ax,x,y,min(peb,10)); axis(ax,'xy'); axis(ax,'equal'); axis(ax,'tight');
    set(ax,'ColorScale','log'); clim(ax,[1e-3,1]); hold(ax,'on');
    if min(peb,[],'all')<.1 && max(peb,[],'all')>.1
        contour(ax,x,y,peb,[.1,.1],'w','LineWidth',.8);
    end
    title(ax,names(k)); xlabel(ax,'x [m]'); ylabel(ax,'y [m]'); lastGoodAxis = ax;
end
if ~exist('lastGoodAxis','var'), lastGoodAxis = ax; end
cb = colorbar(lastGoodAxis); cb.Layout.Tile = 'east'; cb.Label.String = 'PEB 3D [m]; contorno blanco: 10 cm';
title(layout,'Información de posición en z = 0: escalas espaciales indicadas por panel');
gob_save_figure(f,outputDir,"05_mapas_informacion");
plot_cdf(outputDir,visible,"tile"); plot_cdf(outputDir,visible,"grid");
f = figure('Visible',visible,'Color','w','Position',[30,30,1050,450]); ax = axes(f); hold(ax,'on'); colors = lines(3);
keys = ["tile_baseline_core_3d","tile_diverging_ninth_3d","grid_diverging_full_3d"];
for k = 1:3
    for unknown = [false,true]
        name = keys(k); style = '-'; label = name+" calibrado";
        if unknown, name = name+"_unknown_gain"; style = '--'; label = keys(k)+" ganancia libre"; end
        path = fullfile(outputDir,'ensayos',name+".mat");
        if ~isfile(path), continue; end
        data = load(path); n = data.random_trial_count;
        errors = sort(vecnorm(data.estimates(:,1:n)-data.truth(:,1:n)));
        semilogx(ax,max(errors,1e-7),(1:n)/n,'LineStyle',style,'Color',colors(k,:),'DisplayName',label);
    end
end
set(ax,'XScale','log'); xlim(ax,[1e-4,3]); ylim(ax,[0,1.01]); grid(ax,'on');
xlabel(ax,'Error 3D [m]'); ylabel(ax,'CDF empírica'); legend(ax,'Interpreter','none','Location','southeast','FontSize',8);
gob_save_figure(f,outputDir,"08_ganancia_desconocida");
path = fullfile(outputDir,'tablas','robustness.csv');
if isfile(path)
    t = gob_read_table(path); cases = unique(t.case_name,'stable'); perturbations = unique(t.perturbation,'stable');
    values = zeros(numel(perturbations),numel(cases));
    for k = 1:numel(cases), values(:,k) = t.p95_m(t.case_name==cases(k)); end
    f = figure('Visible',visible,'Color','w','Position',[30,30,1250,500]); ax = axes(f);
    bar(ax,values); set(ax,'YScale','log','XTick',1:numel(perturbations),'XTickLabel',perturbations,'TickLabelInterpreter','none');
    xtickangle(ax,25); yline(ax,.1,'k--'); ylabel(ax,'P95 del error 3D [m]');
    legend(ax,cases,'Interpreter','none','Location','best','FontSize',8); grid(ax,'on');
    gob_save_figure(f,outputDir,"09_sensibilidad_calibracion");
end
path = fullfile(outputDir,'tablas','ray_validation.csv');
if isfile(path)
    t = readtable(path); labels = compose('R=%g, i=%d',t.radius_mm,t.channel_1based);
    f = figure('Visible',visible,'Color','w','Position',[30,30,1250,460]); tiledlayout(1,2,'TileSpacing','compact');
    ax = nexttile; bar(ax,[t.minor_width_ratio,t.major_width_ratio]); yline(ax,1,'k--');
    set(ax,'XTick',1:height(t),'XTickLabel',labels); xtickangle(ax,50); ylabel(ax,'Radio ray tracing / radio ABCD');
    legend(ax,{'Eje menor','Eje mayor'},'Location','northwest'); grid(ax,'on');
    ax = nexttile; bar(ax,t.centroid_offset_mm); set(ax,'XTick',1:height(t),'XTickLabel',labels);
    xtickangle(ax,50); ylabel(ax,'Desplazamiento del centroide [mm]'); grid(ax,'on');
    gob_save_figure(f,outputDir,"10_validacion_ray_tracing");
    data = load(fullfile(outputDir,'datos','ray_examples.mat'));
    f = figure('Visible',visible,'Color','w','Position',[30,30,1100,450]); tiledlayout(1,2,'TileSpacing','compact');
    selected = [6,9];
    for j = 1:2
        ax = nexttile; hold(ax,'on'); example = data.examples{selected(j)};
        scatter(ax,example.xy(1,:),example.xy(2,:),3,[.6,.7,.8],'.');
        angle = linspace(0,2*pi,101); [V,D] = eig(example.predicted_covariance);
        p = example.predicted_centroid+2*V*sqrt(D)*[cos(angle);sin(angle)];
        plot(ax,p(1,:),p(2,:),'r-','LineWidth',1.5);
        title(ax,labels(selected(j))); xlabel(ax,'x local a 3 m [m]'); ylabel(ax,'y local a 3 m [m]'); axis(ax,'equal'); grid(ax,'on');
    end
    sgtitle('Rayos de esquina: dispersión real y contorno 1/e² predicho por el modelo circular');
    gob_save_figure(f,outputDir,"11_aberraciones_esquina");
end
path = fullfile(outputDir,'tablas','noise_area_tradeoff.csv');
if isfile(path)
    t = gob_read_table(path); f = figure('Visible',visible,'Color','w','Position',[30,30,950,430]); ax = axes(f); hold(ax,'on');
    for area = [.1,1,10]
        mask = abs(t.pd_area_mm2-area)<1e-10 & t.radii_mm=="15";
        loglog(ax,t.bandwidth_hz_per_reference_pilot(mask),t.peb_p95_m(mask),'-o','DisplayName',"Área = "+area+" mm²");
    end
    set(ax,'XScale','log','YScale','log'); xlabel(ax,'Ancho de banda por piloto de referencia [Hz]'); ylabel(ax,'P95 espacial de PEB [m]');
    legend(ax,'Location','northwest'); grid(ax,'on'); title(ax,'Un tile, R=15 mm, núcleo local; electrónica y fondo fijos');
    gob_save_figure(f,outputDir,"12_tiempo_area_ruido");
end
gob_plot_design(outputDir,visible);
fprintf('Figuras exportadas en PNG, PDF y FIG: %s\n',fullfile(outputDir,'figuras'));
end

function plot_cdf(outputDir,visible,prefix)
if prefix=="tile"
    keys = ["tile_baseline_core","tile_baseline_ninth","tile_convex_core","tile_diverging_ninth"];
    labels = ["Convexa K=1, base 0.9 m","Convexa K=1, noveno nominal","Convexa K=2, base 1.2 m","Cóncava K=2, noveno (ideal)"];
    upper = 3; number = "06";
else
    keys = ["grid_baseline_full","grid_convex_core","grid_convex_full","grid_diverging_full","grid_convex_retilted_full"];
    labels = ["K=1, base 5 m","Convexa K=2, base 3.6 m","Convexa K=2, base 5 m","Cóncava K=2, base 5 m (ideal)","Convexa K=3, 27 grados (ideal)"];
    upper = 10; number = "07";
end
colors = lines(numel(keys));
f = figure('Visible',visible,'Color','w','Position',[30,30,1200,460]); tiledlayout(1,2,'TileSpacing','compact');
for d = [2,3]
    ax = nexttile; hold(ax,'on');
    for k = 1:numel(keys)
        path = fullfile(outputDir,'ensayos',keys(k)+"_"+d+"d.mat");
        if ~isfile(path), continue; end
        data = load(path); n = data.random_trial_count;
        errors = sort(vecnorm(data.estimates(:,1:n)-data.truth(:,1:n)));
        semilogx(ax,max(errors,1e-7),(1:n)/n,'Color',colors(k,:),'LineWidth',1.2,'DisplayName',labels(k));
    end
    set(ax,'XScale','log'); xlim(ax,[1e-5,upper]); ylim(ax,[0,1.01]); xline(ax,.01,'k:','HandleVisibility','off'); xline(ax,.1,'k--','HandleVisibility','off');
    xlabel(ax,'Error euclídeo [m]'); ylabel(ax,'CDF empírica'); title(ax,"Estimación "+d+"D"); grid(ax,'on');
    legend(ax,'Location','southeast','FontSize',8);
end
gob_save_figure(f,outputDir,number+"_cdf_"+prefix);
end
