function R = df_run_analysis(cfg)
% DF_RUN_ANALYSIS  Validate GLS/WLS direction finding + broadcast distance
%                  on an experimental sub3_spatial master.csv.
%
%   R = df_run_analysis(cfg)
%
% cfg fields (all optional except dataFile):
%   .dataFile     path to master.csv
%   .scanKind     'vertical' (PD -> zenith) or 'tilt' (PD tilted). Default 'vertical'
%   .K_id         orientation IDs (1..K) used for estimation, e.g. [1 3 4 5 6 9]
%                 Default: all IDs present for that scanKind.
%   .m            Lambertian order. Default 3.13 (Phi_1/2 = 36.7 deg)
%   .C_opt        radiometric constant (volt units). [] => empirical (df_estimate_C)
%   .v_dark       dark voltage subtracted from v_mean [V]. Default 0
%   .T            transmitter (LED) position. Default [0 0 2]
%   .autoRefMax   put the highest-signal orientation first (numerical ref). Default true
%   .saveFigures  save PNG (300 dpi) + PDF. Default true
%   .outDir       output folder. Default <dataFile dir>/figures_<scanKind>
%   .fontName/.fontSize   plot styling
%
% Returns R with per-instance ground truth, estimates and error arrays.

% ------------------------------------------------------------------ paths
libDir  = fileparts(mfilename('fullpath'));
exp3Dir = fileparts(libDir);
simRoot = fileparts(fileparts(fileparts(exp3Dir)));   % ...\simulation_VLP
addpath(fullfile(simRoot, 'F_broadcast_Konly', 'core'));   % broadcast_distance
addpath(fullfile(simRoot, 'fundamentals', 'core'));        % vlp_gls / vlp_wls (priority)
addpath(libDir);

% --------------------------------------------------------------- defaults
if ~isfield(cfg,'scanKind')    || isempty(cfg.scanKind),   cfg.scanKind   = 'vertical'; end
if ~isfield(cfg,'m')           || isempty(cfg.m),          cfg.m          = 3.13;       end
if ~isfield(cfg,'C_opt'),                                  cfg.C_opt      = [];         end
if ~isfield(cfg,'C_mode')      || isempty(cfg.C_mode),     cfg.C_mode     = 'empirical';end
if ~isfield(cfg,'nadirXYtol')  || isempty(cfg.nadirXYtol), cfg.nadirXYtol = 0.03;       end
if ~isfield(cfg,'nadirInclTol')|| isempty(cfg.nadirInclTol),cfg.nadirInclTol = 1.0;     end
if ~isfield(cfg,'nadirScanKind'),                          cfg.nadirScanKind = '';      end
if ~isfield(cfg,'v_dark')      || isempty(cfg.v_dark),     cfg.v_dark     = 0;          end
if ~isfield(cfg,'T')           || isempty(cfg.T),          cfg.T          = [0 0 2];    end
if ~isfield(cfg,'autoRefMax')  || isempty(cfg.autoRefMax), cfg.autoRefMax = true;       end
if ~isfield(cfg,'saveFigures') || isempty(cfg.saveFigures),cfg.saveFigures= true;       end
if ~isfield(cfg,'fontName')    || isempty(cfg.fontName),   cfg.fontName   = 'Times New Roman'; end
if ~isfield(cfg,'fontSize')    || isempty(cfg.fontSize),   cfg.fontSize   = 13;         end
assert(isfield(cfg,'dataFile') && isfile(cfg.dataFile), 'cfg.dataFile must point to master.csv');
if ~isfield(cfg,'outDir') || isempty(cfg.outDir)
    cfg.outDir = fullfile(fileparts(cfg.dataFile), ['figures_' cfg.scanKind]);
end

T_led   = cfg.T(:);
m       = cfg.m;
muFloor = 1e-6;

cTrue = [0.15 0.15 0.15];
cGLS  = [0.00 0.45 0.74];
cWLS  = [0.85 0.33 0.10];

% ----------------------------------------------------------------- load
Tbl = df_load_master(cfg.dataFile);
Tbl = Tbl(strcmpi(strtrim(Tbl.scan_kind), cfg.scanKind), :);
assert(~isempty(Tbl), 'No rows with scan_kind = "%s".', cfg.scanKind);

% Orientation IDs available in this subset
allIds = unique(Tbl.orientation_id(~isnan(Tbl.orientation_id))).';
if ~isfield(cfg,'K_id') || isempty(cfg.K_id)
    cfg.K_id = allIds;
end
K_id = cfg.K_id(:).';
missingDef = setdiff(K_id, allIds);
assert(isempty(missingDef), 'K_id contains IDs not present in data: %s', mat2str(missingDef));

% ----------------------------------------------------- group measurements
% One estimation instance per (point_id, repeat_id, tilt scan). The tilt
% command uniquely identifies each random-tilt scan within a point.
key = string(Tbl.point_id) + "|" + string(Tbl.repeat_id) + "|" + ...
      string(Tbl.tilt_cmd_deg) + "|" + string(Tbl.tilt_cmd_az);
[g, ~] = findgroups(key);
nG = max(g);

inst = struct('point_id',{},'pidx',{},'tnum',{},'pos',{},'nd_true',{},'d_true',{}, ...
              'nr',{},'nt',{},'mu',{},'vstd',{},'label',{});
tiltCount = containers.Map('KeyType','double','ValueType','double');
nSkipped = 0;

for gi = 1:nG
    sub = Tbl(g==gi, :);

    % locate each requested orientation ID (in K_id order)
    locs = arrayfun(@(id) find(sub.orientation_id==id, 1), K_id, 'UniformOutput', false);
    if any(cellfun(@isempty, locs)), nSkipped = nSkipped + 1; continue; end
    sel = cell2mat(locs);

    mu = sub.v_mean(sel).' - cfg.v_dark;
    if any(~isfinite(mu)), nSkipped = nSkipped + 1; continue; end
    mu   = max(mu, muFloor);
    vstd = sub.v_std(sel).';
    nt   = df_angles_to_nt(sub.nt_incl(sel), sub.nt_az(sel));   % 3xK
    nr   = df_angles_to_nr(sub.nr_incl(1),   sub.nr_az(1));     % 3x1

    % optional: use the brightest orientation as the ratio reference (col 1)
    if cfg.autoRefMax
        [~, imax] = max(mu);
        order = [imax, setdiff(1:numel(mu), imax, 'stable')];
        mu = mu(order); vstd = vstd(order); nt = nt(:, order);
    end

    pos     = [sub.x(1); sub.y(1); sub.z(1)];
    dvec    = pos - T_led;
    d_true  = norm(dvec);
    nd_true = dvec / d_true;

    tok  = regexp(sub.point_id{1}, '_(\d+)$', 'tokens', 'once');
    pidx = str2double(tok{1});
    if strcmpi(cfg.scanKind, 'tilt')
        if ~isKey(tiltCount, pidx), tiltCount(pidx) = 0; end
        tiltCount(pidx) = tiltCount(pidx) + 1;
        tnum  = tiltCount(pidx);
        label = sprintf('P%d.t%d', pidx, tnum);
    else
        tnum  = 0;
        label = sprintf('P%d', pidx);
    end

    inst(end+1) = struct('point_id',sub.point_id{1},'pidx',pidx,'tnum',tnum, ...
        'pos',pos,'nd_true',nd_true,'d_true',d_true,'nr',nr,'nt',nt, ...
        'mu',mu,'vstd',vstd,'label',label); %#ok<AGROW>
end

nI = numel(inst);
assert(nI > 0, 'No complete estimation instances for K_id = %s (scanKind = %s).', ...
       mat2str(K_id), cfg.scanKind);

% sort by point index, then tilt number (stable, chronological)
[~, sidx] = sortrows([[inst.pidx].', [inst.tnum].']);
inst = inst(sidx);

% ------------------------------------------------- radiometric constant C
if ~isempty(cfg.C_opt)
    C_opt = cfg.C_opt; C_all = [];
    Cmode = 'user-provided';
elseif strcmpi(cfg.C_mode, 'nadir')
    nopts = struct('xyTol', cfg.nadirXYtol, 'inclTol', cfg.nadirInclTol, ...
                   'v_dark', cfg.v_dark, 'scanKind', cfg.nadirScanKind);
    [C_opt, cinfo] = df_estimate_C_nadir(cfg.dataFile, m, T_led, nopts);
    C_all = cinfo.C_all;
    assert(~isnan(C_opt), ['No under-LED nadir rows found (xyTol=%.3g m, ' ...
        'inclTol=%.3g deg). Loosen cfg.nadir* or use cfg.C_mode=''empirical''.'], ...
        cfg.nadirXYtol, cfg.nadirInclTol);
    Cmode = sprintf('nadir under-LED (n=%d rows, xyTol=%.3g m)', cinfo.n_used, cfg.nadirXYtol);
else
    [C_opt, C_all] = df_estimate_C(inst, m);
    Cmode = 'empirical (median from GT)';
end

% ----------------------------------------------------------- estimation
angGLS=nan(nI,1); angWLS=nan(nI,1);
posGLS=nan(nI,1); posWLS=nan(nI,1);
dGLS  =nan(nI,1); dWLS  =nan(nI,1); dTrue=nan(nI,1);
estGLS=nan(nI,3); estWLS=nan(nI,3); posT=nan(nI,3);
labels = strings(nI,1);

for j = 1:nI
    s  = inst(j);
    nt = s.nt; mu = s.mu; nr = s.nr;
    sigma2 = max(mean(s.vstd.^2), eps);     % scale cancels in GLS direction

    % --- GLS ---
    nd_g = vlp_gls(nt, mu, m, sigma2); nd_g = nd_g(:);
    d_g  = broadcast_distance(nd_g, nt, mu, m, C_opt, nr);
    % --- WLS ---
    nd_w = vlp_wls(nt, mu, m);         nd_w = nd_w(:);
    d_w  = broadcast_distance(nd_w, nt, mu, m, C_opt, nr);

    angGLS(j) = real(acosd(min(1,max(-1, dot(nd_g, s.nd_true)))));
    angWLS(j) = real(acosd(min(1,max(-1, dot(nd_w, s.nd_true)))));

    if isfinite(d_g)
        pg = T_led + nd_g*d_g; estGLS(j,:) = pg.'; posGLS(j) = norm(pg - s.pos);
    end
    if isfinite(d_w)
        pw = T_led + nd_w*d_w; estWLS(j,:) = pw.'; posWLS(j) = norm(pw - s.pos);
    end
    dGLS(j)=d_g; dWLS(j)=d_w; dTrue(j)=s.d_true;
    posT(j,:)=s.pos.'; labels(j)=s.label;
end

% ------------------------------------------------------------- summary
rms  = @(v) sqrt(mean(v(isfinite(v)).^2));
med  = @(v) median(v(isfinite(v)));
R = struct();
R.cfg=cfg; R.C_opt=C_opt; R.Cmode=Cmode; R.C_all=C_all; R.K_id=K_id;
R.labels=labels; R.pos_true=posT; R.est_GLS=estGLS; R.est_WLS=estWLS;
R.ang_GLS=angGLS; R.ang_WLS=angWLS; R.pos_GLS=posGLS; R.pos_WLS=posWLS;
R.d_GLS=dGLS; R.d_WLS=dWLS; R.d_true=dTrue; R.nInstances=nI; R.nSkipped=nSkipped;

fprintf('\n=================== DF validation (%s PD) ===================\n', upper(cfg.scanKind));
fprintf(' data      : %s\n', cfg.dataFile);
fprintf(' K_id      : %s   (n=%d orientations)\n', mat2str(K_id), numel(K_id));
fprintf(' m         : %.3f    C_opt : %.4g  [%s]\n', m, C_opt, Cmode);
fprintf(' instances : %d used, %d skipped (incomplete)\n', nI, nSkipped);
fprintf(' -----------------------------------------------------------------\n');
fprintf(' %-8s | %8s %8s | %8s %8s | %7s %7s\n', 'label','angGLS','angWLS','posGLS','posWLS','dGLS','dWLS');
fprintf(' %-8s | %8s %8s | %8s %8s | %7s %7s\n', '',   '[deg]','[deg]','[m]','[m]','[m]','[m]');
for j = 1:nI
    fprintf(' %-8s | %8.2f %8.2f | %8.3f %8.3f | %7.3f %7.3f\n', ...
        labels(j), angGLS(j), angWLS(j), posGLS(j), posWLS(j), dGLS(j), dWLS(j));
end
fprintf(' -----------------------------------------------------------------\n');
fprintf(' angular  RMSE  [deg] : GLS %.2f   WLS %.2f\n', rms(angGLS), rms(angWLS));
fprintf(' angular  median[deg] : GLS %.2f   WLS %.2f\n', med(angGLS), med(angWLS));
fprintf(' position RMSE  [m]   : GLS %.3f   WLS %.3f\n', rms(posGLS), rms(posWLS));
fprintf(' position median[m]   : GLS %.3f   WLS %.3f\n', med(posGLS), med(posWLS));
fprintf('==================================================================\n\n');

% save per-instance results
if cfg.saveFigures && ~exist(cfg.outDir,'dir'), mkdir(cfg.outDir); end
if exist(cfg.outDir,'dir')
    Tres = table(labels, posT(:,1),posT(:,2),posT(:,3), dTrue, ...
        angGLS, angWLS, posGLS, posWLS, dGLS, dWLS, ...
        'VariableNames', {'label','x','y','z','d_true', ...
        'ang_GLS_deg','ang_WLS_deg','pos_GLS_m','pos_WLS_m','d_GLS_m','d_WLS_m'});
    writetable(Tres, fullfile(cfg.outDir, sprintf('results_%s.csv', cfg.scanKind)));
end

% ------------------------------------------------------------- figures
tag = sprintf('%s PD | K_{id}=%s | m=%.2f', cfg.scanKind, mat2str(K_id), m);

% ---- Fig 1: top-view (X-Y) localization map ----
f1 = figure('Color','w','Position',[80 80 760 680]); ax=axes(f1); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
plot(ax, 0,0,'p','MarkerSize',15,'MarkerFaceColor',[1 0.85 0],'MarkerEdgeColor','k','DisplayName','LED (Tx)');
for j=1:nI
    if all(isfinite(estGLS(j,:))), plot(ax,[posT(j,1) estGLS(j,1)],[posT(j,2) estGLS(j,2)],'-','Color',[cGLS 0.5],'HandleVisibility','off'); end
    if all(isfinite(estWLS(j,:))), plot(ax,[posT(j,1) estWLS(j,1)],[posT(j,2) estWLS(j,2)],'-','Color',[cWLS 0.5],'HandleVisibility','off'); end
end
hT=plot(ax,posT(:,1),posT(:,2),'o','MarkerSize',8,'MarkerFaceColor',cTrue,'MarkerEdgeColor','k','DisplayName','Ground truth');
hG=plot(ax,estGLS(:,1),estGLS(:,2),'^','MarkerSize',7,'MarkerFaceColor',cGLS,'MarkerEdgeColor','k','DisplayName','GLS');
hW=plot(ax,estWLS(:,1),estWLS(:,2),'s','MarkerSize',7,'MarkerFaceColor',cWLS,'MarkerEdgeColor','k','DisplayName','WLS');
for j=1:nI, text(ax,posT(j,1),posT(j,2),['  ' char(labels(j))],'FontSize',cfg.fontSize-4,'Color',cTrue); end
axis(ax,'equal'); xlabel(ax,'x [m]'); ylabel(ax,'y [m]');
title(ax,{'Top-view localization (X-Y)', tag});
legend(ax,[hT hG hW],'Location','bestoutside');
styleAxis(ax,cfg.fontName,cfg.fontSize);

% ---- Fig 2: 3D localization ----
f2 = figure('Color','w','Position',[120 120 820 700]); ax=axes(f2); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
plot3(ax,0,0,cfg.T(3),'p','MarkerSize',15,'MarkerFaceColor',[1 0.85 0],'MarkerEdgeColor','k','DisplayName','LED (Tx)');
for j=1:nI
    if all(isfinite(estGLS(j,:))), plot3(ax,[posT(j,1) estGLS(j,1)],[posT(j,2) estGLS(j,2)],[posT(j,3) estGLS(j,3)],'-','Color',[cGLS 0.4],'HandleVisibility','off'); end
    if all(isfinite(estWLS(j,:))), plot3(ax,[posT(j,1) estWLS(j,1)],[posT(j,2) estWLS(j,2)],[posT(j,3) estWLS(j,3)],'-','Color',[cWLS 0.4],'HandleVisibility','off'); end
end
plot3(ax,posT(:,1),posT(:,2),posT(:,3),'o','MarkerSize',7,'MarkerFaceColor',cTrue,'MarkerEdgeColor','k','DisplayName','Ground truth');
plot3(ax,estGLS(:,1),estGLS(:,2),estGLS(:,3),'^','MarkerSize',6,'MarkerFaceColor',cGLS,'MarkerEdgeColor','k','DisplayName','GLS');
plot3(ax,estWLS(:,1),estWLS(:,2),estWLS(:,3),'s','MarkerSize',6,'MarkerFaceColor',cWLS,'MarkerEdgeColor','k','DisplayName','WLS');
xlabel(ax,'x [m]'); ylabel(ax,'y [m]'); zlabel(ax,'z [m]'); view(ax,-35,20);
title(ax,{'3D localization', tag}); legend(ax,'Location','bestoutside');
styleAxis(ax,cfg.fontName,cfg.fontSize);

% ---- Fig 3: error bars (angular + position) ----
f3 = figure('Color','w','Position',[140 140 1180 500]);
tl = tiledlayout(f3,1,2,'TileSpacing','compact','Padding','compact');
axA = nexttile(tl); bar(axA,[angGLS angWLS]); grid(axA,'on');
yline(axA, med(angGLS),'--','Color',cGLS,'HandleVisibility','off');
yline(axA, med(angWLS),'--','Color',cWLS,'HandleVisibility','off');
set(axA,'XTick',1:nI,'XTickLabel',labels,'XTickLabelRotation',60);
ylabel(axA,'Angular error [deg]'); legend(axA,{'GLS','WLS'},'Location','best');
title(axA,'Direction error per instance'); colorOrderBars(axA,cGLS,cWLS); styleAxis(axA,cfg.fontName,cfg.fontSize);
axB = nexttile(tl); bar(axB,[posGLS posWLS]); grid(axB,'on');
yline(axB, med(posGLS),'--','Color',cGLS,'HandleVisibility','off');
yline(axB, med(posWLS),'--','Color',cWLS,'HandleVisibility','off');
set(axB,'XTick',1:nI,'XTickLabel',labels,'XTickLabelRotation',60);
ylabel(axB,'Position error [m]'); legend(axB,{'GLS','WLS'},'Location','best');
title(axB,'Position error per instance'); colorOrderBars(axB,cGLS,cWLS); styleAxis(axB,cfg.fontName,cfg.fontSize);
title(tl, tag, 'FontName',cfg.fontName,'FontSize',cfg.fontSize+1);

% ---- Fig 4: distance est vs true + error ECDF ----
f4 = figure('Color','w','Position',[160 160 1180 500]);
tl2 = tiledlayout(f4,1,2,'TileSpacing','compact','Padding','compact');
axC = nexttile(tl2); hold(axC,'on'); grid(axC,'on'); box(axC,'on');
lo = min([dTrue;dGLS;dWLS],[],'omitnan'); hi = max([dTrue;dGLS;dWLS],[],'omitnan');
plot(axC,[lo hi],[lo hi],'k--','DisplayName','ideal');
plot(axC,dTrue,dGLS,'^','MarkerFaceColor',cGLS,'MarkerEdgeColor','k','DisplayName','GLS');
plot(axC,dTrue,dWLS,'s','MarkerFaceColor',cWLS,'MarkerEdgeColor','k','DisplayName','WLS');
axis(axC,'equal'); xlabel(axC,'true distance [m]'); ylabel(axC,'estimated distance [m]');
title(axC,'Distance recovery'); legend(axC,'Location','best'); styleAxis(axC,cfg.fontName,cfg.fontSize);
axD = nexttile(tl2); hold(axD,'on'); grid(axD,'on'); box(axD,'on');
ecdfplot(axD, posGLS, cGLS, 'GLS'); ecdfplot(axD, posWLS, cWLS, 'WLS');
xlabel(axD,'position error [m]'); ylabel(axD,'empirical CDF');
title(axD,'Position-error CDF'); legend(axD,'Location','southeast'); styleAxis(axD,cfg.fontName,cfg.fontSize);
title(tl2, tag, 'FontName',cfg.fontName,'FontSize',cfg.fontSize+1);

% ------------------------------------------------------------- save
if cfg.saveFigures
    if ~exist(cfg.outDir,'dir'), mkdir(cfg.outDir); end
    sk = cfg.scanKind;
    saveFig(f1, fullfile(cfg.outDir, ['Fig1_map_topview_'  sk]));
    saveFig(f2, fullfile(cfg.outDir, ['Fig2_map_3D_'       sk]));
    saveFig(f3, fullfile(cfg.outDir, ['Fig3_errors_'       sk]));
    saveFig(f4, fullfile(cfg.outDir, ['Fig4_distance_cdf_' sk]));
    fprintf('Figures + results saved to: %s\n', cfg.outDir);
end
end

% =========================== local helpers ===============================
function styleAxis(ax, fontName, fontSize)
    set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',1.0,'Layer','top');
end

function colorOrderBars(ax, c1, c2)
    b = findobj(ax,'Type','Bar');
    if numel(b) >= 2
        set(b(end),  'FaceColor', c1);   % first series
        set(b(end-1),'FaceColor', c2);   % second series
    end
end

function ecdfplot(ax, v, col, name)
    v = sort(v(isfinite(v)));
    if isempty(v), plot(ax,NaN,NaN,'-','Color',col,'DisplayName',name); return; end
    y = (1:numel(v))/numel(v);
    stairs(ax,[0; v(:)],[0; y(:)],'-','LineWidth',1.8,'Color',col,'DisplayName',name);
    plot(ax, v, y, 'o','MarkerSize',4,'MarkerFaceColor',col,'MarkerEdgeColor',col,'HandleVisibility','off');
end

function saveFig(f, base)
    try
        exportgraphics(f, [base '.png'], 'Resolution', 300, 'BackgroundColor','white');
        exportgraphics(f, [base '.pdf'], 'ContentType','vector', 'BackgroundColor','white');
    catch
        saveas(f, [base '.png']);
    end
end
