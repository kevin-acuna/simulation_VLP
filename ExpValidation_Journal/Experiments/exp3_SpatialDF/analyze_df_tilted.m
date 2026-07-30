% =========================================================================
%  analyze_df_tilted.m
% -------------------------------------------------------------------------
%  Direction-finding validation for the TILTED-PD measurements of
%  sub-dataset 3 (master.csv). The PD is deliberately tilted; its normal
%  nr is rebuilt from the recorded (nr_incl, nr_az) = commanded tilt.
%
%  There are several random-tilt scans per point (N_TILT_SCANS_PER_POINT),
%  each treated as an independent estimation instance (labelled Pk.tN).
%  For each instance the script:
%     1) selects the codebook orientations listed in K_id,
%     2) estimates the Tx->Rx direction with GLS (vlp_gls) and WLS (vlp_wls),
%     3) recovers the distance with broadcast_distance (using the tilted nr),
%     4) compares against ground truth and plots the results.
%
%  Edit the CONFIG block (mainly K_id) and run.
%  Companion script for vertical PD: analyze_df_vertical.m
% =========================================================================
clear; clc; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
addpath(fullfile(thisDir,'lib'));

%% ============================ CONFIG ====================================
cfg = struct();

% --- Data selection -----------------------------------------------------
% Session folder(s) under data/ to analyse. Their master.csv files are MERGED
% and treated as ONE dataset (every random-tilt scan of every listed point is
% an instance). Use plain folder names (resolved against this script's data/
% dir) or absolute paths. Comment entries out to exclude them; a single entry
% reproduces the classic single-session run.
cfg.dataDirs = { ...
    '20260727_152417', ...
    '20260728_110846', ...
    '20260729_105752', ...
    '20260730_111944'};
% Still supported instead of dataDirs: a single file or an explicit list:
%   cfg.dataFile = fullfile(thisDir,'data','20260727_152417','master.csv');

cfg.scanKind = 'tilt';            % PD deliberately tilted (<= TILT_MAX_DEG)

% Codebook orientation IDs used for the estimation (1..12). Example subsets:
%   1:12                     -> use all orientations
%   [1 2 3 4 5 6 7 8 9]      -> only the optimized-codebook ring (K=9 of TCOM)
%   [1 3 4 5 6 9]            -> a custom subset
cfg.K_id = [1 2 3 4 5 6 7 8 9];

cfg.m       = 3.13;   % Lambertian order (Phi_1/2 = 36.7 deg, exp2_Cone fit)

% --- Radiometric constant C ---------------------------------------------
% cfg.C_opt takes precedence. Set it to [] to compute C automatically via
% cfg.C_mode:
%   'empirical' -> all points & orientations, using ground truth (df_estimate_C)
%   'nadir'     -> ONLY receivers under the LED (|x|,|y|<=nadirXYtol) with the
%                  LED pointing to the floor (nt_incl<=nadirInclTol). This is the
%                  experimental analogue of sub-dataset 2 (df_estimate_C_nadir).
cfg.C_opt        = [];       % [] to use cfg.C_mode; or the sub2 value
cfg.C_mode       = 'nadir';  % 'empirical' | 'nadir'
cfg.nadirXYtol   = 0.03;     % under-LED tolerance on |x|,|y| [m]
cfg.nadirInclTol = 1.0;      % nadir tolerance on LED inclination [deg]
cfg.nadirScanKind= '';       % '' = any scan; 'vertical' = only PD-at-zenith (sub2 style)

cfg.v_dark  = 0.05;      % estimated dark/ambient floor [V] subtracted from v_mean (session has no recorded V_dark; 0 = none)
cfg.T       = [0 0 2];% LED position (transmitter_z = 2 m in metadata)

% --- NLS estimator (third method compared against GLS & WLS) ------------
% vlp_nls_lm solves the same normalized-power problem nonlinearly (LM). It can
% use either the Lambertian cos^m model or the MEASURED LED beam R(theta) from
% the sub0 axis sweep (exp1_Calibration/sub0_axis_sweep).
cfg.addNLS        = true;    % include NLS in the comparison
cfg.nlsUseProfile = false;    % true -> NLS direction finding uses measured R(theta); false -> cos^m. m = cfg.m always.
cfg.profileDir    = '';      % '' -> default exp1 sub0_axis_sweep session
cfg.profileVdark  = 0.05;    % [] -> read v_dark from the profile metadata.txt

cfg.autoRefMax  = true;   % use the brightest orientation as ratio reference
cfg.saveFigures = false;
cfg.fontName    = 'Times New Roman';
cfg.fontSize    = 13;

%% ============================ RUN =======================================
R = df_run_analysis(cfg);

%% ==================== Tilt-angle distributions ==========================
% Visualize the PD tilt applied across all tilt scans: one histogram for the
% inclination angle and another for the azimuth. Values are the recorded pose
% (nr_incl, nr_az), taken once per tilt-scan instance (12 orientations share
% the same tilt, so duplicates are collapsed).
Tbl   = R.data;   % merged table returned by df_run_analysis (all sessions)
Ttilt = Tbl(strcmpi(strtrim(Tbl.scan_kind), 'tilt'), :);
key   = string(Ttilt.point_id) + "|" + string(Ttilt.repeat_id) + "|" + ...
        string(Ttilt.tilt_cmd_deg) + "|" + string(Ttilt.tilt_cmd_az);
[~, ia] = unique(key, 'stable');
tiltIncl = Ttilt.nr_incl(ia);
tiltAz   = Ttilt.nr_az(ia);
tiltIncl = tiltIncl(isfinite(tiltIncl));
tiltAz   = mod(tiltAz(isfinite(tiltAz)), 360);

fTilt = figure('Color','w','Position',[200 200 1120 460]);
tlT   = tiledlayout(fTilt,1,2,'TileSpacing','compact','Padding','compact');

axI = nexttile(tlT);
histogram(axI, tiltIncl, 'BinWidth', 1, 'FaceColor', [0.00 0.45 0.74], 'EdgeColor', 'k');
xlabel(axI,'inclination angle [deg]'); ylabel(axI,'count');
title(axI, sprintf('PD inclination (n=%d, max=%.1f deg)', numel(tiltIncl), max([tiltIncl; 0])));
grid(axI,'on'); box(axI,'on');
set(axI,'FontName',cfg.fontName,'FontSize',cfg.fontSize,'LineWidth',1.0,'Layer','top');

axA = nexttile(tlT);
histogram(axA, tiltAz, 'BinWidth', 30, 'FaceColor', [0.85 0.33 0.10], 'EdgeColor', 'k');
xlim(axA,[0 360]); xticks(axA,0:60:360);
xlabel(axA,'azimuth angle [deg]'); ylabel(axA,'count');
title(axA, sprintf('PD azimuth (n=%d)', numel(tiltAz)));
grid(axA,'on'); box(axA,'on');
set(axA,'FontName',cfg.fontName,'FontSize',cfg.fontSize,'LineWidth',1.0,'Layer','top');

title(tlT, 'Tilt-angle distributions (tilt scans)', ...
      'FontName',cfg.fontName,'FontSize',cfg.fontSize+1);

if cfg.saveFigures && isfield(R,'cfg') && isfield(R.cfg,'outDir')
    if ~exist(R.cfg.outDir,'dir'), mkdir(R.cfg.outDir); end
    exportgraphics(fTilt, fullfile(R.cfg.outDir,'Fig6_tilt_angle_distributions.png'), ...
        'Resolution', 300, 'BackgroundColor', 'white');
end
