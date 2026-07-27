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
cfg.dataFile = fullfile(thisDir,'data','20260727_152417','master.csv');
cfg.scanKind = 'vertical';        % PD pointing to the zenith

% Codebook orientation IDs used for the estimation (1..12). Example subsets:
%   1:12                     -> use all orientations
%   [1 2 3 4 5 6 7 8 9]      -> only the optimized-codebook ring (K=9 of TCOM)
%   [10 11 12 4 7]            -> a custom subset
cfg.K_id = [1 2 3 4 5 6 7 8 9] ;

cfg.m       = 3.13;   % Lambertian order (Phi_1/2 = 36.7 deg, exp2_Cone fit)
cfg.C_opt   = 8.4711;     % [] -> empirical C from ground truth; or set the sub2 value (8.4711)
cfg.v_dark  = 0.05;      % dark voltage [V] to subtract (0 = none; no V_dark in this run)
cfg.T       = [0 0 2];% LED position (transmitter_z = 2 m in metadata)

cfg.autoRefMax  = true;   % use the brightest orientation as ratio reference
cfg.saveFigures = false;
cfg.fontName    = 'Times New Roman';
cfg.fontSize    = 13;

%% ============================ RUN =======================================
R = df_run_analysis(cfg);
