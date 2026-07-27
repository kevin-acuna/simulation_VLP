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
cfg.dataFile = fullfile(thisDir,'data','20260727_152417','master.csv');
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

cfg.v_dark  = 0.05;      % dark voltage [V] to subtract (0 = none; no V_dark in this run)
cfg.T       = [0 0 2];% LED position (transmitter_z = 2 m in metadata)

% --- NLS estimator (third method compared against GLS & WLS) ------------
% vlp_nls_lm solves the same normalized-power problem nonlinearly (LM). It can
% use either the Lambertian cos^m model or the MEASURED LED beam R(theta) from
% the sub0 axis sweep (exp1_Calibration/sub0_axis_sweep).
cfg.addNLS        = true;    % include NLS in the comparison
cfg.nlsUseProfile = true;    % true -> NLS uses measured R(theta); false -> cos^m
cfg.mFromProfile  = false;   % true -> also set m from the profile fit (all methods)
cfg.profileDir    = '';      % '' -> default exp1 sub0_axis_sweep session
cfg.profileVdark  = [];      % [] -> read v_dark from the profile metadata.txt

cfg.autoRefMax  = true;   % use the brightest orientation as ratio reference
cfg.saveFigures = false;
cfg.fontName    = 'Times New Roman';
cfg.fontSize    = 13;

%% ============================ RUN =======================================
R = df_run_analysis(cfg);
