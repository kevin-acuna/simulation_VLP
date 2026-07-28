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
%   .addNLS        include the NLS-LM estimator (vlp_nls_lm). Default true
%   .nlsUseProfile NLS direction finding uses the measured LED profile R(theta)
%                  instead of cos^m(theta). Default true (needs the sub0 axis
%                  sweep). Every other stage (GLS, WLS, distance recovery and C)
%                  always uses the single Lambertian order m = cfg.m.
%   .profileDir    folder with data_x.csv/data_y.csv (default: exp1 axis sweep)
%   .profileVdark  dark voltage for the profile ([] => read from its metadata)
%
% Returns R with per-instance ground truth, estimates and error arrays for
% every method (GLS, WLS and, if enabled, NLS).

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
if ~isfield(cfg,'addNLS')       || isempty(cfg.addNLS),       cfg.addNLS        = true;  end
if ~isfield(cfg,'nlsUseProfile')|| isempty(cfg.nlsUseProfile),cfg.nlsUseProfile = true;  end
if ~isfield(cfg,'profileDir'),                                cfg.profileDir    = '';    end
if ~isfield(cfg,'profileVdark'),                              cfg.profileVdark  = [];    end
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
cNLS  = [0.47 0.67 0.19];

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

% ---------------------------------------------- LED radiation profile (NLS)
% The sub0 axis sweep measures R(theta) = v_mean(theta) for the LED beam. When
% nlsUseProfile is true, ONLY the NLS direction finder uses this measured
% profile; every other stage keeps the single Lambertian order m = cfg.m.
prof = [];
if cfg.addNLS && cfg.nlsUseProfile
    if isempty(cfg.profileDir)
        cfg.profileDir = fullfile(simRoot, 'ExpValidation_Journal', 'Experiments', ...
            'exp1_Calibration', 'sub0_axis_sweep', '20260722_165901');
    end
    try
        prof = df_load_profile(cfg.profileDir, cfg.profileVdark);
    catch ME
        warning('df_run_analysis:profile', ...
            'Could not load LED profile (%s). NLS falls back to Lambertian cos^m.', ME.message);
        prof = [];
    end
end
nlsProfile = cfg.addNLS && cfg.nlsUseProfile && ~isempty(prof);
if cfg.addNLS && ~exist('lsqnonlin', 'file')
    warning('df_run_analysis:nls', ...
        'lsqnonlin not found (Optimization Toolbox). Disabling NLS.');
    cfg.addNLS = false; nlsProfile = false;
end

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
% Method table: {name, color, marker}. GLS & WLS always; NLS optional.
methodDefs = {'GLS', cGLS, '^'; 'WLS', cWLS, 's'};
if cfg.addNLS
    if nlsProfile, nlsName = 'NLS (profile)'; else, nlsName = 'NLS (Lamb.)'; end
    methodDefs = [methodDefs; {nlsName, cNLS, 'd'}];
end
mName  = methodDefs(:,1);
mCol   = methodDefs(:,2);
mMark  = methodDefs(:,3);
nM     = size(methodDefs,1);
mShort = cellfun(@(s) regexprep(s,'\s.*$',''), mName, 'UniformOutput', false);

colvec = @(x) x(:);
ang  = nan(nI, nM);   posE = nan(nI, nM);   dEst = nan(nI, nM);
est  = nan(nI, 3, nM);
dTrue = nan(nI,1);    posT = nan(nI,3);      labels = strings(nI,1);

for j = 1:nI
    s  = inst(j);
    nt = s.nt; mu = s.mu; nr = s.nr;
    sigma2 = max(mean(s.vstd.^2), eps);     % scale cancels in GLS direction

    nd = cell(nM,1);
    nd{1} = colvec(vlp_gls(nt, mu, m, sigma2));
    nd{2} = colvec(vlp_wls(nt, mu, m));
    if cfg.addNLS
        if nlsProfile
            nd{3} = colvec(vlp_nls_lm_profile(nt, mu, prof.Rfun));
        else
            nd{3} = colvec(vlp_nls_lm(nt, mu, m));
        end
    end

    for k = 1:nM
        v  = nd{k};
        ang(j,k) = real(acosd(min(1, max(-1, dot(v, s.nd_true)))));
        dk = broadcast_distance(v, nt, mu, m, C_opt, nr);
        dEst(j,k) = dk;
        if isfinite(dk)
            p = T_led + v*dk; est(j,:,k) = p.'; posE(j,k) = norm(p - s.pos);
        end
    end
    dTrue(j) = s.d_true; posT(j,:) = s.pos.'; labels(j) = s.label;
end

% ------------------------------------------------------------- summary
rms  = @(v) sqrt(mean(v(isfinite(v)).^2));
med  = @(v) median(v(isfinite(v)));
avg  = @(v) mean(v(isfinite(v)));
p90  = @(v) local_pct(v, 90);          % 90th percentile (base MATLAB, no toolbox)
R = struct();
R.cfg=cfg; R.C_opt=C_opt; R.Cmode=Cmode; R.C_all=C_all; R.K_id=K_id;
R.methods=mName; R.labels=labels; R.pos_true=posT; R.est=est;
R.ang=ang; R.pos=posE; R.d=dEst; R.d_true=dTrue;
R.profile=prof; R.m=m; R.nInstances=nI; R.nSkipped=nSkipped;

% per-method metrics (RMSE, mean, median, 90th-percentile) for both errors
dirM = struct('method',{},'rmse',{},'mean',{},'median',{},'cdf90',{});
posM = struct('method',{},'rmse',{},'mean',{},'median',{},'cdf90',{});
for k=1:nM
    dirM(k) = struct('method',mName{k},'rmse',rms(ang(:,k)), 'mean',avg(ang(:,k)), 'median',med(ang(:,k)), 'cdf90',p90(ang(:,k)));
    posM(k) = struct('method',mName{k},'rmse',rms(posE(:,k)),'mean',avg(posE(:,k)),'median',med(posE(:,k)),'cdf90',p90(posE(:,k)));
end
R.metrics = struct('direction',dirM,'position',posM);

if nlsProfile, pstat='used by NLS (direction only)'; elseif ~isempty(prof), pstat='loaded (unused)'; else, pstat=''; end

fprintf('\n=================== DF validation (%s PD) ===================\n', upper(cfg.scanKind));
fprintf(' data      : %s\n', cfg.dataFile);
fprintf(' K_id      : %s   (n=%d orientations)\n', mat2str(K_id), numel(K_id));
fprintf(' m         : %.3f    C_opt : %.4g  [%s]\n', m, C_opt, Cmode);
if ~isempty(prof)
    fprintf(' profile   : m_fit=%.3f, half-angle=%.1f deg, v_dark=%.4g V  [%s]\n', ...
        prof.m_fit, prof.theta_half_deg, prof.vdark, pstat);
end
fprintf(' methods   : %s\n', strjoin(mName.', ', '));
fprintf(' instances : %d used, %d skipped (incomplete)\n', nI, nSkipped);
fprintf(' -----------------------------------------------------------------\n');
hdr = sprintf(' %-7s', 'label');
for k=1:nM, hdr = [hdr sprintf(' | a%-5s', mShort{k})]; end %#ok<AGROW>
for k=1:nM, hdr = [hdr sprintf(' | p%-5s', mShort{k})]; end %#ok<AGROW>
fprintf('%s\n', hdr);
for j = 1:nI
    row = sprintf(' %-7s', labels(j));
    for k=1:nM, row = [row sprintf(' | %6.2f', ang(j,k))];  end %#ok<AGROW>
    for k=1:nM, row = [row sprintf(' | %6.3f', posE(j,k))]; end %#ok<AGROW>
    fprintf('%s\n', row);
end
fprintf(' (a* = angular error [deg], p* = position error [m])\n');
fprintf(' -----------------------------------------------------------------\n');
fprintf(' DIRECTION error [deg]\n');
fprintf('   %-14s %8s %8s %8s %8s\n', 'method', 'RMSE', 'Mean', 'Median', 'CDF90');
for k=1:nM
    fprintf('   %-14s %8.2f %8.2f %8.2f %8.2f\n', mName{k}, rms(ang(:,k)), avg(ang(:,k)), med(ang(:,k)), p90(ang(:,k)));
end
fprintf('\n POSITION error [m]\n');
fprintf('   %-14s %8s %8s %8s %8s\n', 'method', 'RMSE', 'Mean', 'Median', 'CDF90');
for k=1:nM
    fprintf('   %-14s %8.3f %8.3f %8.3f %8.3f\n', mName{k}, rms(posE(:,k)), avg(posE(:,k)), med(posE(:,k)), p90(posE(:,k)));
end
fprintf(' (CDF90 = 90th percentile of the error)\n');
fprintf('==================================================================\n\n');

% save per-instance results
if cfg.saveFigures && ~exist(cfg.outDir,'dir'), mkdir(cfg.outDir); end
if exist(cfg.outDir,'dir')
    vn = {'label','x','y','z','d_true'};
    dataCols = {labels, posT(:,1), posT(:,2), posT(:,3), dTrue};
    for k=1:nM
        dataCols{end+1} = ang(:,k);  vn{end+1} = ['ang_' mShort{k} '_deg']; %#ok<AGROW>
        dataCols{end+1} = posE(:,k); vn{end+1} = ['pos_' mShort{k} '_m'];   %#ok<AGROW>
        dataCols{end+1} = dEst(:,k); vn{end+1} = ['d_'   mShort{k} '_m'];   %#ok<AGROW>
    end
    Tres = table(dataCols{:}, 'VariableNames', vn);
    writetable(Tres, fullfile(cfg.outDir, sprintf('results_%s.csv', cfg.scanKind)));
end

% ------------------------------------------------------------- figures
if nlsProfile,     nlsTag = ' | NLS:profile';
elseif cfg.addNLS, nlsTag = ' | NLS:Lamb';
else,              nlsTag = ''; end
tag  = sprintf('%s PD | K_{id}=%s | m=%.2f%s', cfg.scanKind, mat2str(K_id), m, nlsTag);
cLED = [1 0.85 0];

% ---- Fig 1: top-view (X-Y) localization map ----
f1 = figure('Color','w','Position',[80 80 820 700]); ax=axes(f1); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
hLED = plot(ax,0,0,'p','MarkerSize',15,'MarkerFaceColor',cLED,'MarkerEdgeColor','k','DisplayName','LED (Tx)');
for k=1:nM
    for j=1:nI
        if all(isfinite(est(j,:,k)))
            plot(ax,[posT(j,1) est(j,1,k)],[posT(j,2) est(j,2,k)],'-','Color',[mCol{k} 0.4],'HandleVisibility','off');
        end
    end
end
hT = plot(ax,posT(:,1),posT(:,2),'o','MarkerSize',5,'MarkerFaceColor',cTrue,'MarkerEdgeColor','k','DisplayName','Ground truth');
hM = gobjects(nM,1);
for k=1:nM
    hM(k) = plot(ax,est(:,1,k),est(:,2,k),mMark{k},'MarkerSize',5,'MarkerFaceColor',mCol{k},'MarkerEdgeColor','k','DisplayName',mName{k});
end
%for j=1:nI, text(ax,posT(j,1),posT(j,2),['  ' char(labels(j))],'FontSize',cfg.fontSize-4,'Color',cTrue); end
axis(ax,'equal'); xlabel(ax,'x [m]'); ylabel(ax,'y [m]');
xlim(ax,[-1.4 1.4]); ylim(ax,[-1.4 1.4]);
title(ax,{'Top-view localization (X-Y)', tag});
legend(ax,[hLED hT hM.'],'Location','bestoutside');
styleAxis(ax,cfg.fontName,cfg.fontSize);

% ---- Fig 2: 3D localization ----
f2 = figure('Color','w','Position',[120 120 860 720]); ax=axes(f2); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
plot3(ax,0,0,cfg.T(3),'p','MarkerSize',15,'MarkerFaceColor',cLED,'MarkerEdgeColor','k','DisplayName','LED (Tx)');
for k=1:nM
    for j=1:nI
        if all(isfinite(est(j,:,k)))
            plot3(ax,[posT(j,1) est(j,1,k)],[posT(j,2) est(j,2,k)],[posT(j,3) est(j,3,k)],'-','Color',[mCol{k} 0.35],'HandleVisibility','off');
        end
    end
end
plot3(ax,posT(:,1),posT(:,2),posT(:,3),'o','MarkerSize',5,'MarkerFaceColor',cTrue,'MarkerEdgeColor','k','DisplayName','Ground truth');
for k=1:nM
    plot3(ax,est(:,1,k),est(:,2,k),est(:,3,k),mMark{k},'MarkerSize',5,'MarkerFaceColor',mCol{k},'MarkerEdgeColor','k','DisplayName',mName{k});
end
xlabel(ax,'x [m]'); ylabel(ax,'y [m]'); zlabel(ax,'z [m]'); view(ax,-35,20);
xlim(ax,[-1.4 1.4]); ylim(ax,[-1.4 1.4]);
title(ax,{'3D localization', tag}); legend(ax,'Location','bestoutside');
styleAxis(ax,cfg.fontName,cfg.fontSize);

% ---- Fig 3: error bars (angular + position) ----
f3 = figure('Color','w','Position',[140 140 1220 520]);
tl = tiledlayout(f3,1,2,'TileSpacing','compact','Padding','compact');
axA = nexttile(tl); hbA = bar(axA, ang); grid(axA,'on'); hold(axA,'on');
for k=1:nM, hbA(k).FaceColor = mCol{k}; yline(axA, med(ang(:,k)),'--','Color',mCol{k},'HandleVisibility','off'); end
set(axA,'XTick',1:nI,'XTickLabel',labels,'XTickLabelRotation',60);
ylabel(axA,'Angular error [deg]'); legend(axA,mName,'Location','best');
title(axA,'Direction error per instance'); styleAxis(axA,cfg.fontName,cfg.fontSize);
axB = nexttile(tl); hbB = bar(axB, posE); grid(axB,'on'); hold(axB,'on');
for k=1:nM, hbB(k).FaceColor = mCol{k}; yline(axB, med(posE(:,k)),'--','Color',mCol{k},'HandleVisibility','off'); end
set(axB,'XTick',1:nI,'XTickLabel',labels,'XTickLabelRotation',60);
ylabel(axB,'Position error [m]'); legend(axB,mName,'Location','best');
title(axB,'Position error per instance'); styleAxis(axB,cfg.fontName,cfg.fontSize);
title(tl, tag, 'FontName',cfg.fontName,'FontSize',cfg.fontSize+1);

% ---- Fig 4: distance est vs true + error ECDF ----
f4 = figure('Color','w','Position',[160 160 1220 520]);
tl2 = tiledlayout(f4,1,2,'TileSpacing','compact','Padding','compact');
axC = nexttile(tl2); hold(axC,'on'); grid(axC,'on'); box(axC,'on');
allD = [dTrue; dEst(:)];
lo = min(allD,[],'omitnan'); hi = max(allD,[],'omitnan');
plot(axC,[lo hi],[lo hi],'k--','DisplayName','ideal');
for k=1:nM, plot(axC,dTrue,dEst(:,k),mMark{k},'MarkerFaceColor',mCol{k},'MarkerEdgeColor','k','DisplayName',mName{k}); end
axis(axC,'equal'); xlabel(axC,'true distance [m]'); ylabel(axC,'estimated distance [m]');
title(axC,'Distance recovery'); legend(axC,'Location','best'); styleAxis(axC,cfg.fontName,cfg.fontSize);
axD = nexttile(tl2); hold(axD,'on'); grid(axD,'on'); box(axD,'on');
for k=1:nM, ecdfplot(axD, posE(:,k), mCol{k}, mName{k}); end
xlabel(axD,'position error [m]'); ylabel(axD,'empirical CDF');
title(axD,'Position-error CDF'); legend(axD,'Location','southeast'); styleAxis(axD,cfg.fontName,cfg.fontSize);
title(tl2, tag, 'FontName',cfg.fontName,'FontSize',cfg.fontSize+1);

% ---- Fig 5: LED radiation profile (only if a profile was loaded) ----
f5 = [];
if ~isempty(prof)
    f5 = figure('Color','w','Position',[180 180 780 560]); ax=axes(f5); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    plot(ax, prof.theta_deg, prof.R, 'o','MarkerSize',4,'MarkerFaceColor',cNLS,'MarkerEdgeColor',cNLS,'DisplayName','measured R(\theta)');
    thf = linspace(0,90,181);
    plot(ax, thf, cosd(thf).^prof.m_fit, '-','LineWidth',1.8,'Color',cGLS,'DisplayName',sprintf('cos^m fit, m=%.2f',prof.m_fit));
    plot(ax, thf, cosd(thf).^m, '--','LineWidth',1.5,'Color',cWLS,'DisplayName',sprintf('cos^m used, m=%.2f',m));
    yline(ax,0.5,':','Color',[.4 .4 .4],'HandleVisibility','off');
    xline(ax,prof.theta_half_deg,':','Color',[.4 .4 .4],'HandleVisibility','off');
    xlabel(ax,'off-axis angle \theta [deg]'); ylabel(ax,'normalized radiance R(\theta)');
    xlim(ax,[0 90]); ylim(ax,[0 1.05]);
    title(ax,{'LED radiation profile (sub0 axis sweep)', sprintf('half-angle = %.1f deg', prof.theta_half_deg)});
    legend(ax,'Location','northeast'); styleAxis(ax,cfg.fontName,cfg.fontSize);
end

% ------------------------------------------------------------- save
if cfg.saveFigures
    if ~exist(cfg.outDir,'dir'), mkdir(cfg.outDir); end
    sk = cfg.scanKind;
    saveFig(f1, fullfile(cfg.outDir, ['Fig1_map_topview_'  sk]));
    saveFig(f2, fullfile(cfg.outDir, ['Fig2_map_3D_'       sk]));
    saveFig(f3, fullfile(cfg.outDir, ['Fig3_errors_'       sk]));
    saveFig(f4, fullfile(cfg.outDir, ['Fig4_distance_cdf_' sk]));
    if ~isempty(f5), saveFig(f5, fullfile(cfg.outDir, ['Fig5_led_profile_' sk])); end
    fprintf('Figures + results saved to: %s\n', cfg.outDir);
end
end

% =========================== local helpers ===============================
function styleAxis(ax, fontName, fontSize)
    set(ax,'FontName',fontName,'FontSize',fontSize,'LineWidth',1.0,'Layer','top');
end

function q = local_pct(v, p)
% Percentile without the Statistics Toolbox (MATLAB prctile convention).
    v = sort(v(isfinite(v)));
    n = numel(v);
    if n == 0, q = NaN; return; end
    if n == 1, q = v(1); return; end
    x = ((1:n) - 0.5) / n * 100;       % plotting positions in percent
    if p <= x(1),   q = v(1);   return; end
    if p >= x(end), q = v(end); return; end
    q = interp1(x, v, p, 'linear');
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
