%% System Parameters — Shared across estimator scripts
% Run this script (or call it from another) to load all common parameters.
% Usage: run('system_params.m')  or just: system_params

% LED
theta_half = 45;                        % Semi-angle at half power [deg]
P_t = 0.405;                           % Transmitted optical power [W]
m_t = -log(2)/log(cosd(theta_half));   % Lambertian order

% Photodetector
p = 4.8e-3; q = 5.5e-3;               % PD dimensions [m]
A_det = p*q;                           % Sensitive area [m^2]
R_pd = 0.63;                           % Responsivity [A/W]
FOV = 85;                              % Field of view [deg]
n_r = [0, 0, 1];                       % PD normal vector

% Noise
sigma2 = 30e6*10^(-21.0);             % AWGN variance σ² = σ_w²/R_p² [W^2] (optical domain)

% Derived
C = -P_t*(m_t+1)*A_det/(2*pi);        % Radiometric constant

% Room
L = 3; W = 3; Hmax = 1.2;

% Samples and grid
N_samples = 1000;
step = 0.2;                            % Testbed X,Y step [m]
stepH = 0.2;                           % Testbed Z step [m]



% ============================================================================================
% 3D-Positioning Optimization (Complete Problem : DF + DR)
% ============================================================================================

% PEB-optimized orientations [theta1, rho1, theta2, rho2, ...] in degrees
orientations_K3  = [35.40,140.13,33.31,36.38,29.58,262.70];
orientations_K4  = [38.89,90.56,41.48,0.15,41.80,180.10,38.79,270.24];
orientations_K5  = [0.10,211.14,50.55,89.96,50.66,179.99,50.37,359.93,50.59,269.96];
orientations_K6  = [17.19,306.94,54.55,266.13,22.49,140.37,52.23,360.00,52.41,84.05,55.76,185.16];
orientations_K7  = [58.91,355.65,53.77,170.74,27.75,43.75,5.36,305.88,54.35,96.46,35.10,220.04,54.78,278.61];
orientations_K8  = [51.82,89.38,61.50,268.26,27.32,316.99,6.46,318.34,57.76,5.84,53.65,171.30,37.97,200.35,39.27,91.12];
orientations_K9  = [0,28.15,56.92,178.69,36.54,266.83,33.86,182.29,42.20,78.36,53.07,97.46,57.91,359.73,37.07,355.08,58.23,272.07];
orientations_K10 = [56.00,3.61,53.20,182.48,54.93,356.82,11.94,38.06,61.28,270.34,50.17,91.30,47.56,174.73,43.39,89.36,32.54,277.55,15.14,255.31];

% NL-optimized orientations (GA with NL RMSE as objective)
orientations_NL_K5 = [21,42,21,341,23,174,25,247,21,112];
orientations_NL_K9 = [18.905,89.333,18.608,150.298,17.349,330.007,28.469,191.965,26.868,260.181,20.204,115.307,22.131,25.976,28.047,280.906,2.489,301.474];


% ============================================================================================
% Direction-Finding Optimization
% [theta1, rho1, theta2, rho2, ...] in degrees
% ============================================================================================

% DEB-optimized orientations (GA minimizing RMS-DEB over 3x3x2 m³ testbed)
orientations_DEB_K3 = [17.48,203.70,17.22,332.20,18.71,88.79];
orientations_DEB_K4 = [29.88,315.03,29.87,134.99,29.87,45.03,29.86,225.02];
orientations_DEB_K5 = [0.10,74.22,65.68,269.84,65.73,179.90,65.91,359.82,65.88,89.91];
orientations_DEB_K6 = [67.60,253.38,66.63,321.05,70.03,176.90,0.12,274.29,68.91,98.38,66.82,24.94];
orientations_DEB_K7 = [65.60,353.25,2.46,10.07,66.17,273.62,64.59,196.54,62.48,130.76,2.56,191.66,63.78,68.11];
orientations_DEB_K8 = [67.61,67.08,66.59,247.26,2.79,39.70,3.21,226.96,64.71,2.81,66.06,179.67,66.89,298.24,65.37,114.85];
orientations_DEB_K9 = [66.06,165.39,8.73,267.05,66.75,273.80,62.42,219.37,64.16,21.63,67.15,90.96,13.90,105.06,4.52,303.11,62.04,330.31];

% GLS-DF-optimized orientation 
% Conditions: MC=1 (normal situation)
orientations_GLS_DF_K5 = [1.58,153.32,41.37,129.51,31.95,217.36,34.21,306.97,30.33,42.52]; % usado para optimizacion con 0.3 (grid)
orientations_GLS_DF_K9 = [9.20,213.10,65.04,205.04,50.16,101.79,28.62,183.93,4.58,332.83,50.50,278.53,21.32,357.39,13.26,14.88,72.61,24.28];

% Conditions: MC=10 (Optimizado con M_trials=10)
orientations_GLS_DF_K5_MC10 = [4.94,224.16,33.89,47.73,35.32,139.14,35.99,320.48,36.73,228.08]; % Optimization with 0.2 (grid)
orientations_GLS_DF_K9_MC10 = [0.43,336.06,8.61,110.92,11.02,244.90,20.87,334.90,54.40,203.93,55.90,69.39,57.16,267.18,61.52,157.17,67.81,354.24];

% ============================================================================================

all_orientations = {orientations_K3, orientations_K4, orientations_DEB_K5, orientations_K6, orientations_K7, orientations_K8, orientations_DEB_K9, orientations_K10};
K_values = [3, 4, 5, 6, 7, 8, 9, 10];

all_orientations_NL = {[], [], orientations_NL_K5, [], [], [], orientations_NL_K9};
K_values_NL = [5, 9];
