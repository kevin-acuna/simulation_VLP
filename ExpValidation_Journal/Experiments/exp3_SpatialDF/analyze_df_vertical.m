% =========================================================================
%  analyze_df_vertical.m
% -------------------------------------------------------------------------
%  Direction-finding validation for the VERTICAL-PD measurements of
%  sub-dataset 3 (master.csv). The PD points to the zenith (nr = [0 0 1]).
%
%  For each receiver position the LED sweeps the K-orientation codebook and
%  the mean voltage (~ optical power) is recorded. This script:
%     1) selects the codebook orientations listed in K_id,
%     2) estimates the Tx->Rx direction with GLS (vlp_gls) and WLS (vlp_wls),
%     3) recovers the distance with broadcast_distance,
%     4) compares against ground truth and plots the results.
%
%  Edit the CONFIG block (mainly K_id) and run.
%  Companion script for tilted PD: analyze_df_tilted.m
% =========================================================================
clear; clc; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
addpath(fullfile(thisDir,'lib'));

%% ============================ CONFIG ====================================
cfg = struct();

% --- Data selection -----------------------------------------------------
% Session folder(s) under data/ to analyse. Their master.csv files are MERGED
% and treated as ONE dataset (localization over every listed point). Use plain
% folder names (resolved against this script's data/ dir) or absolute paths.
% Comment entries out to exclude them; a single entry reproduces the classic
% single-session run.
    % '20260727_152417', ...
    % '20260728_110846', ...
    % '20260729_105752', ...
    % '20260730_111944'};
cfg.dataDirs = { ...
    '20260827_104436'};
% Still supported instead of dataDirs: a single file or an explicit list:
%   cfg.dataFile = fullfile(thisDir,'data','20260727_152417','master.csv');

cfg.scanKind = 'vertical';        % PD pointing to the zenith

% Codebook orientation IDs used for the estimation (1..12). Example subsets:
%   1:12                     -> use all orientations
%   [1 2 3 4 5 6 7 8 9]      -> only the optimized-codebook ring (K=9 of TCOM)
%   [10 11 12 4 7]            -> a custom subset
cfg.K_id = [1 2 3 4 5 6 7 8 9] ;

cfg.m       = 3.13;   % Lambertian order (Phi_1/2 = 36.7 deg, exp2_Cone fit)

% --- Radiometric constant C ---------------------------------------------
% cfg.C_opt takes precedence. Set it to [] to compute C automatically via
% cfg.C_mode:
%   'empirical' -> all points & orientations, using ground truth (df_estimate_C)
%   'nadir'     -> ONLY receivers under the LED (|x|,|y|<=nadirXYtol) with the
%                  LED pointing to the floor (nt_incl<=nadirInclTol). This is the
%                  experimental analogue of sub-dataset 2 (df_estimate_C_nadir).
% 8.4711: Empirical , 8.652: nadir
cfg.C_opt        = [];   % [] to use cfg.C_mode; or the sub2 value (was 8.4711)
cfg.C_mode       = 'empirical';  % 'empirical' | 'nadir'
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
cfg.profileVdark  = 0.05;      % [] -> read v_dark from the profile metadata.txt

cfg.autoRefMax  = true;   % use the brightest orientation as ratio reference
cfg.saveFigures = false;
cfg.fontName    = 'Times New Roman';
cfg.fontSize    = 13;

%% ============================ RUN =======================================
R = df_run_analysis(cfg);
