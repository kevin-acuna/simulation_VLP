function gob_plot_optics(outputDir,visible)
colors = lines(3);
f = figure('Visible',visible,'Color','w','Position',[50,50,1250,480]); tiledlayout(1,3,'TileSpacing','compact');
sets = {.015,[.012,.015],[-.010,-.011]}; edges = [.002,.002,.006];
titles = ["Convexa: R = 15 mm","Convexa: R = 12 / 15 mm","Cóncava: R = -10 / -11 mm"];
for k = 1:3
    ax = nexttile; hold(ax,'on');
    m = gob_model(gob_config(struct('radii',sets{k},'edge_thickness',edges(k)))); centers = gob_footprints(m);
    for j = 1:m.n_channels
        v = m.directions(:,j); s = dot(centers(:,j)-m.origins(:,j),v); q = m.q(j)+s;
        W = m.config.wavelength/pi*abs(q)^2/imag(q);
        C = W*(eye(2)+v(1:2)*v(1:2)'/v(3)^2);
        ellipse(ax,centers(1:2,j),C,colors(m.state_ids(j),:),'-');
        plot(ax,centers(1,j),centers(2,j),'.','Color',colors(m.state_ids(j),:),'MarkerSize',5);
    end
    rectangle(ax,'Position',[-5/6,-5/6,5/3,5/3],'LineStyle','--');
    axis(ax,'equal'); xlim(ax,[-1.25,1.25]); ylim(ax,[-1.25,1.25]);
    xlabel(ax,'x [m]'); ylabel(ax,'y [m]'); title(ax,titles(k));
end
sgtitle('Huellas en z = 0: contornos locales 1/e² del modelo Snell + ABCD');
gob_save_figure(f,outputDir,"01_huellas_opticas");
f = figure('Visible',visible,'Color','w','Position',[50,50,1150,480]); tiledlayout(1,2,'TileSpacing','compact');
ax = nexttile; hold(ax,'on');
c = gob_config(); m = gob_model(c); radius = c.radii(1);
[t,r] = meshgrid(linspace(0,2*pi,45),linspace(0,c.diameter/2,15));
x = r.*cos(t); y = r.*sin(t); z = c.array_lens_distance+m.center_thicknesses(1)-radius+sqrt(radius^2-r.^2);
surf(ax,1000*x,1000*y,1000*z,'FaceAlpha',.25,'EdgeColor','none','FaceColor',[.2,.6,.9]);
scatter3(ax,1000*m.local_xy(1,:),1000*m.local_xy(2,:),zeros(1,25),25,'k','filled');
for j = 1:25
    origin = [m.local_xy(:,j);0]; out = [m.local_xy(:,j);c.array_lens_distance+m.thicknesses(j,1)];
    tail = out+.010*m.local_directions(:,j,1);
    plot3(ax,1000*[origin(1),out(1),tail(1)],1000*[origin(2),out(2),tail(2)],1000*[origin(3),out(3),tail(3)],'Color',[.8,.3,.1]);
end
xlabel(ax,'x local [mm]'); ylabel(ax,'y local [mm]'); zlabel(ax,'z local [mm]');
title(ax,'Un tile y su lente común'); axis(ax,'equal'); grid(ax,'on'); view(ax,35,20);
ax = nexttile; hold(ax,'on'); full = gob_model(gob_config(struct('tiles',9))); centers = gob_footprints(full);
for j = 1:full.n_channels
    o = full.origins(:,j); p = centers(:,j);
    plot3(ax,[o(1),p(1)],[o(2),p(2)],[o(3),p(3)],'Color',[.65,.75,.85]);
end
scatter3(ax,centers(1,:),centers(2,:),zeros(1,225),7,full.tile_ids,'filled');
scatter3(ax,.2,-.1,.4,70,'r','filled');
plot3(ax,[-2.5,2.5,2.5,-2.5,-2.5],[-2.5,-2.5,2.5,2.5,-2.5],zeros(1,5),'k--');
xlabel(ax,'x [m]'); ylabel(ax,'y [m]'); zlabel(ax,'z [m]');
title(ax,'Nueve tiles: 225 haces y un PD'); axis(ax,'equal'); view(ax,35,25); grid(ax,'on');
gob_save_figure(f,outputDir,"02_geometria_sistema");
f = figure('Visible',visible,'Color','w','Position',[50,50,1000,400]); tiledlayout(1,2,'TileSpacing','compact');
ax = nexttile; hold(ax,'on'); s = linspace(0,3,301);
for k = 1:3
    mm = gob_model(gob_config(struct('radii',[.012,.015,.020]))); q = mm.local_q(13,k);
    w = sqrt(mm.config.wavelength/pi*abs(q+s).^2/imag(q));
    plot(ax,s,1000*w,'LineWidth',1.5,'DisplayName',"R = "+mm.config.radii(k)*1000+" mm");
end
xlabel(ax,'Distancia axial desde la salida [m]'); ylabel(ax,'Radio central w [mm]'); legend(ax,'Location','northwest'); grid(ax,'on');
ax = nexttile; hold(ax,'on');
for k = 1:3
    q = mm.local_q(1,k); w = sqrt(mm.config.wavelength/pi*abs(q+s).^2/imag(q));
    plot(ax,s,1000*w,'LineWidth',1.5,'DisplayName',"R = "+mm.config.radii(k)*1000+" mm");
end
xlabel(ax,'Distancia axial desde la salida [m]'); ylabel(ax,'Radio off-axis w [mm]'); legend(ax,'Location','northwest'); grid(ax,'on');
sgtitle('La curvatura modifica también el parámetro q y la evolución del haz');
gob_save_figure(f,outputDir,"03_evolucion_gaussian");
f = figure('Visible',visible,'Color','w','Position',[50,50,1050,410]); tiledlayout(1,2,'TileSpacing','compact');
ax = nexttile; model = gob_model(); p = [.213;-.147;.436]; expected = gob_power(model,p);
noise = gob_noise(); sigma = gob_sigma(expected,noise);
points = gob_grid([-.45,.45;-.45,.45],[101,101],p(3));
powers = gob_power(model,points); objective = sum(((powers-expected)./sigma).^2,1);
imagesc(ax,linspace(-.45,.45,101),linspace(-.45,.45,101),reshape(log10(max(objective,1e-8)),101,101));
axis(ax,'xy'); axis(ax,'equal'); axis(ax,'tight'); colorbar(ax); hold(ax,'on');
plot(ax,p(1),p(2),'rx','MarkerSize',10,'LineWidth',2); xlabel(ax,'x [m]'); ylabel(ax,'y [m]'); title(ax,'log10 del coste: corte a altura verdadera');
ax = nexttile; hold(ax,'on'); heights = linspace(0,1,151); p0 = [.21;-.14;.2];
points = [p0(1:2).*(3-heights)/(3-p0(3));heights];
for k = 1:2
    model = gob_model(gob_config(struct('radii',sets{k}))); n = gob_noise(struct('bandwidth',100*k));
    P0 = gob_power(model,p0); P = gob_power(model,points); sig = gob_sigma(P0,n);
    gain = sum(P0.*P./sig.^2,1)./sum(P.^2./sig.^2,1);
    calibrated = sum(((P-P0)./sig).^2,1); free = sum(((P.*gain-P0)./sig).^2,1);
    semilogy(ax,heights,max(calibrated,1e-8),'-','Color',colors(k,:),'DisplayName',"K="+k+", calibrado");
    semilogy(ax,heights,max(free,1e-8),'--','Color',colors(k,:),'DisplayName',"K="+k+", ganancia libre");
end
set(ax,'YScale','log'); xline(ax,.2,'k:','HandleVisibility','off'); yline(ax,1,'k:','HandleVisibility','off'); xlabel(ax,'Altura sobre una misma dirección [m]'); ylabel(ax,'Distancia cuadrática entre firmas');
legend(ax,'Location','best'); grid(ax,'on');
gob_save_figure(f,outputDir,"04_coste_y_ambiguedad");
end

function ellipse(ax,center,covariance,color,style)
[V,D] = eig(covariance); angle = linspace(0,2*pi,80);
p = center+V*sqrt(D)*[cos(angle);sin(angle)];
plot(ax,p(1,:),p(2,:),'Color',color,'LineStyle',style,'LineWidth',.7);
end
