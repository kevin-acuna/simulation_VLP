% =========================================================================
%  plot_sampling_status.m
% -------------------------------------------------------------------------
%  Sampling-progress map of sub-dataset 3. Every acquisition session (one
%  folder under data/) is tied to ONE robot base position (robot_base_x/y
%  in its metadata.txt). Robot base positions live on a regular grid
%  (cfg.gridX / cfg.gridY, 0.5 m step) and are identified by an ID (see
%  cfg.predefined). Every grid node is classified as:
%     - registered  : at least one session listed in cfg.dataDirs
%     - to register : ID listed in cfg.toRegister, no valid session yet
%     - not planned : not in cfg.toRegister and no valid session
%  Sessions under data/ that are NOT in cfg.dataDirs do not count as
%  registered (they are only reported as "discarded").
%  The top view also shows the receiver points already measured.
%  Keep cfg.dataDirs in sync with analyze_df_vertical.m / analyze_df_tilted.m.
% =========================================================================
clear; clc; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
addpath(fullfile(thisDir,'lib'));
dataRoot = fullfile(thisDir,'data');

%% ============================ CONFIG ====================================
cfg = struct();

% Sessions considered valid (same list as the analysis scripts). Any other
% session folder found under data/ is reported as "discarded".
cfg.dataDirs = { ...
    '20260727_152417', ...
    '20260728_110846', ...
    '20260730_111944', ...
    '20260827_104436', ...
    '20260828_110759', ...
    '20260828_165643', ...
    '20260828_171822', ...
    '20260831_141942', ...
    '20260831_143348', ...
    '20260831_153237', ...
    '20260901_114654', ...
    '20260902_143037', ...
    '20260903_113408', ...
    '20260904_133623', ...
    '20260907_113612', ...
    '20260908_104339', ...
    '20260910_110707', ...
    '20260911_133428', ...
    '20260921_151640', ...
    '20260922_162454', ...
    '20260924_143134', ...
    '20260929_145944'};

% Planned grid of robot base positions [m] (PREDEFINED_POSITIONS of
% sub3_spatial.cpp + the custom x = -1 column).
cfg.gridX = -1.5:0.5:1.5;
cfg.gridY = -0.5:0.5:1.5;

% PREDEFINED_POSITIONS of sub3_spatial.cpp, in menu order: row i -> ID i
% (= robot_position_index in metadata.txt). Positions outside this list get
% negative IDs -1, -2, ... (x descending, then y ascending).
cfg.predefined = [ ...
    -0.5 -0.5; -0.5  0.0; -0.5  0.5; -0.5  1.0; -0.5  1.5; ...
     0.0 -0.5;  0.0  0.0;  0.0  0.5;  0.0  1.0;  0.0  1.5; ...
     0.5 -0.5;  0.5  0.0;  0.5  0.5;  0.5  1.0;  0.5  1.5; ...
     1.0 -0.5;  1.0  0.0;  1.0  0.5;  1.0  1.0;  1.0  1.5; ...
     1.5 -0.5;  1.5  0.0;  1.5  0.5;  1.5  1.0;  1.5  1.5];

% IDs of the robot positions that MUST be registered (orange until a valid
% session exists there, then green). IDs not listed stay uncolored.
cfg.toRegister = [-1,-2,-3,-4];

cfg.showReceivers = true;                 % overlay XY of the measured receiver points
cfg.rxArea        = [-1.4 1.4 -1.4 1.4];  % receiver sampling area [xmin xmax ymin ymax] (positions3D.txt)

cfg.saveFigures = false;
cfg.outDir      = fullfile(dataRoot,'figures_sampling');
cfg.fontName    = 'Times New Roman';
cfg.fontSize    = 13;

%% ======================= SESSIONS & ROBOT BASES =========================
d    = dir(dataRoot);
sess = {d([d.isdir]).name};
sess = sess(cellfun(@(s) isfile(fullfile(dataRoot,s,'metadata.txt')) && ...
                         isfile(fullfile(dataRoot,s,'master.csv')), sess)).';

missing = setdiff(cfg.dataDirs, sess);
if ~isempty(missing)
    warning('plot_sampling_status:missing', 'Sessions in cfg.dataDirs not found under data/: %s', ...
        strjoin(missing, ', '));
end

nS      = numel(sess);
isValid = ismember(sess, cfg.dataDirs);
base    = nan(nS,2);
nPts    = zeros(nS,1);
rxXY    = cell(nS,1);
for i = 1:nS
    base(i,:) = local_read_base(fullfile(dataRoot, sess{i}, 'metadata.txt'));
    Ti = df_load_master(fullfile(dataRoot, sess{i}, 'master.csv'));
    [~, ia] = unique(Ti.point_id, 'stable');
    nPts(i) = numel(ia);
    rxXY{i} = [Ti.x(ia) Ti.y(ia)];
end
noBase = ~all(isfinite(base),2);
if any(noBase)
    warning('plot_sampling_status:noBase', 'No robot_base_x/y in metadata.txt of: %s', ...
        strjoin(sess(noBase), ', '));
end

% grid nodes + predefined positions + any off-grid base actually used
[GX, GY]  = ndgrid(cfg.gridX, cfg.gridY);
gridNodes = round([GX(:) GY(:)]*1000)/1000;
preNodes  = round(cfg.predefined*1000)/1000;
nodes     = unique([gridNodes; preNodes; round(base(~noBase,:)*1000)/1000], 'rows');
[isPre, id] = ismember(nodes, preNodes, 'rows');
onGrid    = isPre | ismember(nodes, gridNodes, 'rows');
ex        = find(~isPre);
[~, o]    = sortrows(nodes(ex,:), [-1 2]);
id(ex(o)) = -(1:numel(ex));

inPlan  = ismember(id, cfg.toRegister);
unknown = setdiff(cfg.toRegister, id);
if ~isempty(unknown)
    warning('plot_sampling_status:unknownId', 'IDs in cfg.toRegister not on the grid: %s', ...
        mat2str(unknown));
end

nN     = size(nodes,1);
status = zeros(nN,1);          % 2 = registered, 1 = to register, 0 = not planned
nValid = zeros(nN,1);  nOther = zeros(nN,1);
sValid = strings(nN,1); sOther = strings(nN,1);
for j = 1:nN
    on = all(abs(base - nodes(j,:)) < 1e-6, 2);
    nValid(j) = sum(nPts(on &  isValid));
    nOther(j) = sum(nPts(on & ~isValid));
    sValid(j) = strjoin(string(sess(on &  isValid)), ', ');
    sOther(j) = strjoin(string(sess(on & ~isValid)), ', ');
    if any(on & isValid), status(j) = 2;
    elseif inPlan(j),     status(j) = 1;
    end
end

%% ============================ SUMMARY ===================================
stName = ["not planned", "to register", "registered"];
yn     = ["no", "yes"];
[~, ord] = sortrows([id<0, abs(id)]);
fprintf('\n================ SAMPLING STATUS (robot base grid) ================\n');
fprintf(' %4s %6s %6s | %-11s | %-7s | %6s | %6s | %s\n', 'ID', 'x', 'y', 'status', 'listed', ...
    'valid', 'disc.', 'sessions');
for j = ord.'
    s = sValid(j);
    if sOther(j) ~= "", s = strtrim(s + " [discarded: " + sOther(j) + "]"); end
    if ~onGrid(j), s = "(off-grid) " + s; end
    fprintf(' %4d %6.2f %6.2f | %-11s | %-7s | %6d | %6d | %s\n', id(j), nodes(j,1), nodes(j,2), ...
        stName(status(j)+1), yn(inPlan(j)+1), nValid(j), nOther(j), s);
end
fprintf(' -----------------------------------------------------------------\n');
fprintf(' listed in cfg.toRegister: %d -> registered: %d | to register: %d\n', ...
    nnz(inPlan), nnz(inPlan & status==2), nnz(status==1));
extra = id(~inPlan & status==2);
if ~isempty(extra)
    fprintf(' registered but NOT listed in cfg.toRegister: %s\n', mat2str(sort(extra(:)).'));
end
fprintf(' receiver points: %d valid, %d in discarded sessions\n', sum(nPts(isValid)), sum(nPts(~isValid)));
fprintf('==================================================================\n\n');

%% ============================= FIGURE ===================================
cDone = [0.20 0.63 0.17];
cTodo = [0.89 0.47 0.10];
cNone = [1.00 1.00 1.00];
cDisc = [0.60 0.60 0.60];
cLED  = [1.00 0.85 0.00];

f  = figure('Color','w','Position',[100 100 960 780]);
ax = axes(f); hold(ax,'on'); box(ax,'on'); grid(ax,'on');

a  = cfg.rxArea;
hA = plot(ax, a([3 3 4 4 3]), a([1 2 2 1 1]), '--', 'Color',[0.5 0.5 0.5], 'LineWidth',1.0, ...
    'DisplayName','receiver area');
hR = gobjects(0);
if cfg.showReceivers
    rxV = unique(round(vertcat(zeros(0,2), rxXY{isValid})*1000)/1000, 'rows');
    rxO = setdiff(unique(round(vertcat(zeros(0,2), rxXY{~isValid})*1000)/1000, 'rows'), rxV, 'rows');
    if ~isempty(rxV)
        hR(end+1) = plot(ax, rxV(:,2), rxV(:,1), 'o', 'MarkerSize',3, 'MarkerFaceColor',0.45*cDone+0.55, ...
            'MarkerEdgeColor','none', 'DisplayName',sprintf('receiver XY, valid (%d)', size(rxV,1)));
    end
    if ~isempty(rxO)
        hR(end+1) = plot(ax, rxO(:,2), rxO(:,1), 'o', 'MarkerSize',3, 'MarkerFaceColor',cDisc, ...
            'MarkerEdgeColor','none', 'DisplayName',sprintf('receiver XY, discarded sessions (%d)', size(rxO,1)));
    end
end
defs = {2, cDone, 'robot base: registered'; 1, cTodo, 'robot base: to register'; 0, cNone, 'robot base: not planned'};
hB = gobjects(size(defs,1),1);
for k = 1:size(defs,1)
    sel = status == defs{k,1};
    hB(k) = plot(ax, nodes(sel,2), nodes(sel,1), 's', 'MarkerSize',15, 'LineWidth',1.2, ...
        'MarkerFaceColor',defs{k,2}, 'MarkerEdgeColor','k', ...
        'DisplayName',sprintf('%s (%d)', defs{k,3}, nnz(sel)));
end
hL = plot(ax, 0, 0, 'p', 'MarkerSize',16, 'MarkerFaceColor',cLED, 'MarkerEdgeColor','k', ...
    'DisplayName','LED (Tx)');
for j = 1:nN
    text(ax, nodes(j,2)+0.07, nodes(j,1)-0.09, sprintf('%d', id(j)), 'FontName',cfg.fontName, ...
        'FontSize',cfg.fontSize-2, 'FontWeight','bold', 'Color',[0.15 0.15 0.15]);
end

allX = [nodes(:,1); a(1:2).'];  allY = [nodes(:,2); a(3:4).'];
axis(ax,'equal');
xl = [min(allX)-0.3, max(allX)+0.3];  yl = [min(allY)-0.3, max(allY)+0.3];
xlim(ax, yl); ylim(ax, xl);
set(ax, 'YDir','reverse', 'XTick', ceil(yl(1)/0.5)*0.5:0.5:yl(2), 'YTick', ceil(xl(1)/0.5)*0.5:0.5:xl(2));
xlabel(ax,'y [m]'); ylabel(ax,'x [m]');
title(ax, {'Sub-dataset 3: sampling status of the robot base positions', ...
    sprintf('%d/%d listed positions registered | label = position ID (1-25: robot menu, <0: extra)', ...
    nnz(inPlan & status==2), nnz(inPlan))});
legend(ax, [hL; hB; hR(:); hA], 'Location','bestoutside');
set(ax,'FontName',cfg.fontName,'FontSize',cfg.fontSize,'LineWidth',1.0,'Layer','top');

if cfg.saveFigures
    if ~exist(cfg.outDir,'dir'), mkdir(cfg.outDir); end
    local_save(f, fullfile(cfg.outDir, 'Fig_sampling_status'));
    fprintf('Figure saved to: %s\n', cfg.outDir);
end

% =========================== local helpers ===============================
function b = local_read_base(f)
    txt = fileread(f);
    b   = nan(1,2);
    k   = {'robot_base_x','robot_base_y'};
    for i = 1:2
        t = regexp(txt, ['^' k{i} '=([^\r\n]*)'], 'tokens', 'once', 'lineanchors');
        if ~isempty(t), b(i) = str2double(t{1}); end
    end
end

function local_save(f, base)
    try
        exportgraphics(f, [base '.png'], 'Resolution', 300, 'BackgroundColor','white');
        exportgraphics(f, [base '.pdf'], 'ContentType','vector', 'BackgroundColor','white');
    catch
        saveas(f, [base '.png']);
    end
end
