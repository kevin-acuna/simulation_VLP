% Slide-quality figures of the 3D experimental campaign (exp3_SpatialDF)
% for the SNS JU ArchWG presentation. Uses results/exp3_results.mat
% produced by run_exp3_analysis.m. Also writes results/exp3_metrics.txt.
function make_exp3_figures()
here    = fileparts(mfilename('fullpath'));
presDir = fileparts(fileparts(here));
resDir  = fullfile(presDir, 'results');
figDir  = fullfile(presDir, 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end
L = load(fullfile(resDir, 'exp3_results.mat'));
S = L.S;

V = S.vertical_K9_nadir;     % PD to zenith
Tt = S.tilt_K9_nadir;        % PD randomly tilted (<= 15 deg)
iN = find(strcmp(V.estimators, 'NLS'));
iG = find(strcmp(V.estimators, 'GLS'));
T_led = [0 0 2];
phiHalf = 36.7;

C.blue   = [0.16 0.38 0.74];
C.purple = [0.55 0.27 0.80];
C.orange = [0.93 0.49 0.19];
C.green  = [0.30 0.62 0.25];
C.gray   = [0.45 0.45 0.45];
C.red    = [0.80 0.10 0.10];
C.gold   = [1.00 0.80 0.00];
FS = 16; FN = 'Arial';

fid = fopen(fullfile(resDir, 'exp3_metrics.txt'), 'w');
cl = onCleanup(@() fclose(fid));
out = @(varargin) fprintf(fid, varargin{:});

% ------------------------------------------------------------ derived
D = derive(V, T_led);  Dt = derive(Tt, T_led);
nP = size(V.pos_true, 1);
out('Vertical instances: %d (unique xyz %d, unique xy %d)\n', nP, ...
    size(unique(round(V.pos_true,3),'rows'),1), size(unique(round(V.pos_true(:,1:2),3),'rows'),1));
out('Tilt instances: %d\n', size(Tt.pos_true,1));
out('z levels: %s\n', mat2str(unique(V.pos_true(:,3)).'));
out('x range [%.2f %.2f], y range [%.2f %.2f]\n', min(V.pos_true(:,1)), max(V.pos_true(:,1)), min(V.pos_true(:,2)), max(V.pos_true(:,2)));
out('off-axis range [%.1f %.1f] deg, d range [%.2f %.2f] m\n', min(D.offax), max(D.offax), min(V.d_true), max(V.d_true));

sets = {'vertical', V, D; 'tilt', Tt, Dt};
for s = 1:2
    R = sets{s,2}; DD = sets{s,3};
    for k = 1:numel(R.methods)
        e = 100*R.pos(:,k); a = R.ang(:,k);
        out('[%s|%s] all: dir mean %.2f med %.2f p90 %.2f | pos mean %.2f med %.2f p90 %.2f rmse %.2f\n', sets{s,1}, R.estimators{k}, ...
            mean(a,'omitnan'), pct(a,50), pct(a,90), mean(e,'omitnan'), pct(e,50), pct(e,90), sqrt(mean(e.^2,'omitnan')));
        for th = [25 30 phiHalf 40 45]
            m = DD.offax <= th;
            out('    offaxis<=%.1f (n=%d): dir mean %.2f p90 %.2f | pos med %.2f p90 %.2f rmse %.2f | range|err| med %.2f p90 %.2f | lateral med %.2f\n', th, nnz(m), ...
                mean(a(m),'omitnan'), pct(a(m),90), pct(e(m),50), pct(e(m),90), sqrt(mean(e(m).^2,'omitnan')), ...
                pct(abs(100*DD.dErr(m,k)),50), pct(abs(100*DD.dErr(m,k)),90), pct(100*DD.lat(m,k),50));
        end
    end
end

% ---- receiver-orientation repeatability (same point: 1 vertical + 3 tilts)
[spreadDeg, spreadCm, nPts, dirDiff] = orientation_spread(V, Tt, iN, T_led);
out('Orientation repeatability (NLS): %d points with 4 PD orientations; pooled within-point angular RMS = %.3f deg (%.2f cm at range)\n', ...
    nPts, spreadDeg, spreadCm);
[spreadDegG, spreadCmG] = orientation_spread(V, Tt, iG, T_led);
out('Orientation repeatability (GLS): pooled within-point angular RMS = %.3f deg (%.2f cm)\n', spreadDegG, spreadCmG);
out('Mean |dir error tilt - dir error vertical| (NLS) = %.3f deg; median = %.3f\n', mean(abs(dirDiff),'omitnan'), median(abs(dirDiff),'omitnan'));

% tilt statistics actually applied (from the tilt dataset table)
% (not stored in R; recomputed from labels is not possible) -> skipped here

% ======================================================= FIGURE 1: 3D map
f = newfig(7.2, 5.6);
ax = axes(f); hold(ax,'on'); grid(ax,'on'); box(ax,'off');
e = 100*V.pos(:,iN);
ec = min(e, 10);
P = V.pos_true;
% LED half-power cone footprint at floor of workspace (z=0.4) and top (z=1.1)
for zc = [0.4 1.1]
    rr = (2-zc)*tand(phiHalf); tt = linspace(0,2*pi,200);
    plot3(ax, rr*cos(tt), rr*sin(tt), zc*ones(size(tt)), ':', 'Color', [C.gray 0.9], 'LineWidth', 1.2);
end
% codebook beams (K=9) as thin lines to z = 0
cb = [16 90;16 210;16 330;60 0;64 60;64 120;60 180;64 240;64 300];
for i = 1:size(cb,1)
    nt = [sind(cb(i,1))*cosd(cb(i,2)); sind(cb(i,1))*sind(cb(i,2)); -cosd(cb(i,1))];
    pE = T_led(:) + 0.9*nt;
    plot3(ax, [T_led(1) pE(1)], [T_led(2) pE(2)], [T_led(3) pE(3)], '-', 'Color', [C.purple 0.8], 'LineWidth', 2);
end
scatter3(ax, P(:,1), P(:,2), P(:,3), 22, ec, 'filled', 'MarkerEdgeColor', [0.25 0.25 0.25], 'LineWidth', 0.25);
plot3(ax, T_led(1), T_led(2), T_led(3), 'p', 'MarkerSize', 20, 'MarkerFaceColor', C.gold, 'MarkerEdgeColor', 'k');
text(ax, 0.08, 0.05, 2.12, 'Single steered LED (AP)', 'FontName', FN, 'FontSize', FS-2, 'FontWeight', 'bold');
colormap(ax, turbo(256)); caxis(ax, [0 10]);
cb_ = colorbar(ax); cb_.Label.String = '3D position error [cm]'; cb_.Ticks = 0:2:10; cb_.TickLabels{end} = '\geq10';
xlabel(ax,'x [m]'); ylabel(ax,'y [m]'); zlabel(ax,'z [m]');
xlim(ax,[-1.5 1.5]); ylim(ax,[-1.5 1.5]); zlim(ax,[0 2.2]);
view(ax, -38, 22); daspect(ax,[1 1 1]);
style(ax, FN, FS);
savefig_(f, fullfile(figDir, 'exp3_3D_error_map'));

% ======================================================= FIGURE 2: CDFs
f = newfig(11.5, 4.4);
tl = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
ax1 = nexttile(tl); hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
h = gobjects(0);
h(end+1) = ecdf_(ax1, V.ang(:,iN),  C.blue,   '-',  'NLS - vertical PD');
h(end+1) = ecdf_(ax1, Tt.ang(:,iN), C.blue,   '--', 'NLS - tilted PD');
h(end+1) = ecdf_(ax1, V.ang(:,iG),  C.orange, '-',  'GLS - vertical PD');
h(end+1) = ecdf_(ax1, Tt.ang(:,iG), C.orange, '--', 'GLS - tilted PD');
yline(ax1, 0.9, ':', 'Color', C.gray, 'LineWidth', 1.2, 'HandleVisibility','off');
xlim(ax1,[0 4]); ylim(ax1,[0 1]);
xlabel(ax1,'Direction-finding error [deg]'); ylabel(ax1,'Empirical CDF');
title(ax1,'(a) Direction finding (AoD-like)','FontWeight','normal');
legend(ax1, h, 'Location','southeast','FontSize',FS-3);
style(ax1, FN, FS);

ax2 = nexttile(tl); hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
h = gobjects(0);
h(end+1) = ecdf_(ax2, 100*V.pos(:,iN),  C.blue,   '-',  'NLS - vertical PD');
h(end+1) = ecdf_(ax2, 100*Tt.pos(:,iN), C.blue,   '--', 'NLS - tilted PD');
h(end+1) = ecdf_(ax2, 100*V.pos(:,iG),  C.orange, '-',  'GLS - vertical PD');
h(end+1) = ecdf_(ax2, 100*V.pos(D.offax<=phiHalf, iN), C.green, '-', sprintf('NLS - inside LED half-power cone (\\leq%.1f\\circ)', phiHalf));
xline(ax2, 5, '-', 'Color', C.red, 'LineWidth', 1.6, 'HandleVisibility','off');
text(ax2, 12, 0.62, {'OPTI-6G target','P90 \leq 5 cm'}, 'Color', C.red, 'FontName', FN, 'FontSize', FS-3);
annotation_arrow(ax2, [11.8 5.2], [0.62 0.62], C.red);
yline(ax2, 0.9, ':', 'Color', C.gray, 'LineWidth', 1.2, 'HandleVisibility','off');
xlim(ax2,[0 20]); ylim(ax2,[0 1]);
xlabel(ax2,'3D position error [cm]'); ylabel(ax2,'Empirical CDF');
title(ax2,'(b) 3D positioning (broadcast mode)','FontWeight','normal');
legend(ax2, h, 'Location','southeast','FontSize',FS-3);
style(ax2, FN, FS);
savefig_(f, fullfile(figDir, 'exp3_cdf_direction_position'));

% ================================== FIGURE 3: error vs off-axis angle
edges = [0 15 25 35 45 55 70];
ctr = (edges(1:end-1)+edges(2:end))/2;
nb = numel(ctr);
[aMed,aQ1,aQ3,pMed,pP90,latMed,rngMed,cnt] = deal(nan(1,nb));
for b = 1:nb
    m = D.offax >= edges(b) & D.offax < edges(b+1);
    cnt(b) = nnz(m);
    a = V.ang(m,iN); aMed(b) = pct(a,50); aQ1(b) = pct(a,25); aQ3(b) = pct(a,75);
    pE = 100*V.pos(m,iN); pMed(b) = pct(pE,50); pP90(b) = pct(pE,90);
    latMed(b) = pct(100*D.lat(m,iN),50); rngMed(b) = pct(abs(100*D.dErr(m,iN)),50);
end
f = newfig(11.5, 4.4);
tl = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
ax1 = nexttile(tl); hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
bar(ax1, 1:nb, aMed, 0.6, 'FaceColor', C.blue, 'EdgeColor', 'none');
errorbar(ax1, 1:nb, aMed, aMed-aQ1, aQ3-aMed, 'k', 'LineStyle','none','LineWidth',1.2,'CapSize',8);
set(ax1,'XTick',1:nb,'XTickLabel',arrayfun(@(i) sprintf('%d-%d',edges(i),edges(i+1)),1:nb,'UniformOutput',false));
ylim(ax1,[0 2.5]);
xlabel(ax1,'Angle from AP nadir [deg]'); ylabel(ax1,'Direction error [deg]');
title(ax1,'(a) Direction error: median (IQR)','FontWeight','normal');
for b = 1:nb, text(ax1, b, 2.3, sprintf('%d',cnt(b)), 'HorizontalAlignment','center','Color',C.gray,'FontName',FN,'FontSize',FS-4); end
text(ax1, 0.45, 2.3, 'n =', 'HorizontalAlignment','right','Color',C.gray,'FontName',FN,'FontSize',FS-4);
style(ax1, FN, FS);
ax2 = nexttile(tl); hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
hb = bar(ax2, 1:nb, [latMed; rngMed].', 0.8, 'grouped', 'EdgeColor','none');
hb(1).FaceColor = C.purple; hb(2).FaceColor = C.orange;
hp = plot(ax2, 1:nb, pP90, 'o-', 'Color', 'k', 'MarkerFaceColor', 'k', 'LineWidth', 1.8);
hm = plot(ax2, 1:nb, pMed, 's--', 'Color', C.blue, 'MarkerFaceColor', C.blue, 'LineWidth', 1.8);
yline(ax2, 5, '-', 'Color', C.red, 'LineWidth', 1.4, 'HandleVisibility','off');
set(ax2,'XTick',1:nb,'XTickLabel',arrayfun(@(i) sprintf('%d-%d',edges(i),edges(i+1)),1:nb,'UniformOutput',false));
xlabel(ax2,'Angle from AP nadir [deg]'); ylabel(ax2,'Error [cm]');
ylim(ax2,[0 25]);
title(ax2,'(b) 3D error and its components','FontWeight','normal');
legend(ax2,[hb(1) hb(2) hm hp],{'lateral (direction) - median','range |d-d_{true}| - median','3D error - median','3D error - P90'},'Location','northwest','FontSize',FS-4);
style(ax2, FN, FS);
savefig_(f, fullfile(figDir, 'exp3_error_vs_offaxis'));
out('\nOff-axis bins %s\n cnt %s\n dirMed %s\n posMed %s\n posP90 %s\n latMed %s\n rngMed %s\n', mat2str(edges), mat2str(cnt), ...
    mat2str(aMed,3), mat2str(pMed,3), mat2str(pP90,3), mat2str(latMed,3), mat2str(rngMed,3));

% ================================== FIGURE 4: receiver-orientation robustness
f = newfig(11.5, 4.4);
tl = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
ax1 = nexttile(tl); hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
[av, at] = paired_dir(V, Tt, iN);
scatter(ax1, av, at, 22, C.blue, 'filled', 'MarkerFaceAlpha', 0.55);
plot(ax1, [0 4], [0 4], 'k--', 'LineWidth', 1.4);
axis(ax1,'equal'); xlim(ax1,[0 4]); ylim(ax1,[0 4]);
xlabel(ax1,'Direction error, vertical PD [deg]'); ylabel(ax1,{'Direction error, tilted PD [deg]','(mean of 3 random tilts)'});
title(ax1,'(a) Same point, different PD orientation','FontWeight','normal');
style(ax1, FN, FS);
ax2 = nexttile(tl); hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
h = gobjects(0);
h(end+1) = ecdf_(ax2, 100*V.pos(:,iN),  C.blue,  '-',  sprintf('vertical PD (n=%d)', size(V.pos,1)));
h(end+1) = ecdf_(ax2, 100*Tt.pos(:,iN), C.purple,'--', sprintf('tilted PD \\leq15\\circ (n=%d)', size(Tt.pos,1)));
h(end+1) = ecdf_(ax2, 100*V.pos(D.offax<=phiHalf,iN),  C.green, '-',  'vertical, inside half-power cone');
h(end+1) = ecdf_(ax2, 100*Tt.pos(Dt.offax<=phiHalf,iN), C.green, '--', 'tilted, inside half-power cone');
xline(ax2, 5, '-', 'Color', C.red, 'LineWidth', 1.4, 'HandleVisibility','off');
yline(ax2, 0.9, ':', 'Color', C.gray, 'LineWidth', 1.2, 'HandleVisibility','off');
xlim(ax2,[0 20]); ylim(ax2,[0 1]);
xlabel(ax2,'3D position error [cm] (NLS)'); ylabel(ax2,'Empirical CDF');
title(ax2,'(b) 3D error, vertical vs tilted receiver','FontWeight','normal');
legend(ax2, h, 'Location','southeast','FontSize',FS-4);
style(ax2, FN, FS);
savefig_(f, fullfile(figDir, 'exp3_tilt_robustness'));

% ================================== FIGURE 5: top-view map (median over heights)
f = newfig(6.4, 5.6);
ax = axes(f); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
xy = round(P(:,1:2),3);
[uxy,~,g] = unique(xy,'rows');
medE = accumarray(g, e, [], @(v) median(v,'omitnan'));
step = 0.2;
for i = 1:size(uxy,1)
    rectangle(ax,'Position',[uxy(i,1)-step/2, uxy(i,2)-step/2, step, step], ...
        'FaceColor', val2rgb(min(medE(i),10), [0 10]), 'EdgeColor', [1 1 1], 'LineWidth', 0.6);
end
tt = linspace(0,2*pi,300);
for zc = [0.4 0.75 1.1]
    rr = (2-zc)*tand(phiHalf);
    plot(ax, rr*cos(tt), rr*sin(tt), '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.1);
end
plot(ax, 0, 0, 'p', 'MarkerSize', 20, 'MarkerFaceColor', C.gold, 'MarkerEdgeColor', 'k');
colormap(ax, turbo(256)); caxis(ax,[0 10]);
cb_ = colorbar(ax); cb_.Label.String = 'Median 3D error over heights [cm]'; cb_.Ticks = 0:2:10; cb_.TickLabels{end} = '\geq10';
axis(ax,'equal'); xlim(ax,[-1.6 1.6]); ylim(ax,[-1.6 1.6]);
xlabel(ax,'x [m]'); ylabel(ax,'y [m]');
style(ax, FN, FS);
savefig_(f, fullfile(figDir, 'exp3_topview_median_error'));

% ================================== FIGURE 6: codebook footprints (beam sweep)
f = newfig(6.4, 5.6);
ax = axes(f); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
zP = 0.75; mL = 3.13;
[gx, gy] = meshgrid(linspace(-2.6,2.6,521));
dx = gx - T_led(1); dy = gy - T_led(2); dz = zP - T_led(3);
dd = sqrt(dx.^2 + dy.^2 + dz.^2);
cpsi = -dz ./ dd;
cbc = [repmat(C.orange,3,1); repmat(C.purple,6,1)];
for i = 1:size(cb,1)
    nt = [sind(cb(i,1))*cosd(cb(i,2)); sind(cb(i,1))*sind(cb(i,2)); -cosd(cb(i,1))];
    cphi = max(0, (nt(1)*dx + nt(2)*dy + nt(3)*dz) ./ dd);
    I = cphi.^mL .* cpsi ./ dd.^2;
    I = I / max(I(:));
    contourf(ax, gx, gy, I, [0.5 0.5], 'FaceColor', cbc(i,:), 'FaceAlpha', 0.10, 'EdgeColor', cbc(i,:), 'LineWidth', 1.8);
    [~, im] = max(I(:));
    plot(ax, gx(im), gy(im), '+', 'Color', cbc(i,:), 'MarkerSize', 12, 'LineWidth', 2);
    text(ax, gx(im)+0.2*cosd(cb(i,2)), gy(im)+0.2*sind(cb(i,2)), sprintf('%d', i), 'Color', cbc(i,:)*0.8, ...
        'FontName', FN, 'FontSize', FS-3, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
end
plot(ax, uxy(:,1), uxy(:,2), '.', 'Color', [0.35 0.35 0.35], 'MarkerSize', 9);
plot(ax, 0, 0, 'p', 'MarkerSize', 20, 'MarkerFaceColor', C.gold, 'MarkerEdgeColor', 'k');
axis(ax,'equal'); xlim(ax,[-2.0 2.0]); ylim(ax,[-2.0 2.0]);
xlabel(ax,'x [m]'); ylabel(ax,'y [m]');
style(ax, FN, FS);
savefig_(f, fullfile(figDir, 'exp3_codebook_footprints'));

fprintf('Figures saved in %s\n', figDir);
type(fullfile(resDir, 'exp3_metrics.txt'));
end

% ======================================================================
function D = derive(R, T)
n = size(R.pos_true,1); nM = numel(R.methods);
D.offax = acosd((T(3) - R.pos_true(:,3)) ./ R.d_true);
D.dErr = R.d - R.d_true;
D.lat = R.d_true .* sind(R.ang);
D.dir = nan(n,3,nM);
for k = 1:nM
    v = R.est(:,:,k) - T;
    D.dir(:,:,k) = v ./ vecnorm(v,2,2);
end
end

function [av, at] = paired_dir(V, Tt, k)
labV = string(V.labels); labT = regexprep(string(Tt.labels), '\.t\d+$', '');
av = nan(numel(labV),1); at = nan(numel(labV),1);
for i = 1:numel(labV)
    m = labT == labV(i);
    if any(m), av(i) = V.ang(i,k); at(i) = mean(Tt.ang(m,k),'omitnan'); end
end
ok = isfinite(av) & isfinite(at); av = av(ok); at = at(ok);
end

function [rmsDeg, rmsCm, nPts, dDiff] = orientation_spread(V, Tt, k, T)
labV = string(V.labels); labT = regexprep(string(Tt.labels), '\.t\d+$', '');
dV = V.est(:,:,k) - T; dV = dV ./ vecnorm(dV,2,2);
dT = Tt.est(:,:,k) - T; dT = dT ./ vecnorm(dT,2,2);
ss = 0; dof = 0; ssCm = 0; nPts = 0; dDiff = nan(numel(labV),1);
for i = 1:numel(labV)
    m = find(labT == labV(i));
    if numel(m) < 1, continue; end
    U = [dV(i,:); dT(m,:)];
    U = U(all(isfinite(U),2),:);
    if size(U,1) < 2, continue; end
    mu = mean(U,1); mu = mu/norm(mu);
    dev = acosd(min(1, U*mu.'));
    ss = ss + sum(dev.^2); dof = dof + size(U,1) - 1; nPts = nPts + 1;
    ssCm = ssCm + sum((V.d_true(i)*100*sind(dev)).^2);
    dDiff(i) = mean(Tt.ang(m,k),'omitnan') - V.ang(i,k);
end
rmsDeg = sqrt(ss/dof); rmsCm = sqrt(ssCm/dof);
end

function q = pct(v, p)
v = sort(v(isfinite(v))); n = numel(v);
if n == 0, q = NaN; return; end
x = ((1:n) - 0.5)/n*100;
q = interp1([0 x 100], [v(1); v(:); v(end)], p, 'linear');
end

function h = ecdf_(ax, v, col, ls, name)
v = sort(v(isfinite(v))); y = (1:numel(v))/numel(v);
h = stairs(ax, [0; v(:)], [0; y(:)], ls, 'Color', col, 'LineWidth', 2.2, 'DisplayName', name);
end

function annotation_arrow(ax, xs, ys, col)
plot(ax, xs, ys, '-', 'Color', col, 'LineWidth', 1.4, 'HandleVisibility', 'off');
plot(ax, xs(2), ys(2), '<', 'MarkerSize', 7, 'MarkerFaceColor', col, 'MarkerEdgeColor', col, 'HandleVisibility', 'off');
end

function f = newfig(w, h)
f = figure('Color','w','Units','inches','Position',[1 1 w h], 'Visible','off');
end

function style(ax, fn, fs)
set(ax,'FontName',fn,'FontSize',fs,'LineWidth',1.0,'Layer','top','GridAlpha',0.18);
end

function c = val2rgb(v, lim)
cm = turbo(256);
i = round(1 + (v-lim(1))/(lim(2)-lim(1))*255); i = max(1,min(256,i));
c = cm(i,:);
end

function savefig_(f, base)
exportgraphics(f, [base '.png'], 'Resolution', 250, 'BackgroundColor', 'white');
close(f);
end
