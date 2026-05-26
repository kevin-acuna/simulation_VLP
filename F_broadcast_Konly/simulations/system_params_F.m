%% System Parameters — Proposal F (Broadcast K-only OWP)
% Shared across all simulation scripts in F_broadcast_Konly/.
% Usage: system_params_F   (run as script)
%
% Inherits the TCOM system parameters and adds broadcast-specific config.

% ============================================================================================
% LED Transmitter
% ============================================================================================
theta_half = 45;                        % Semi-angle at half power [deg]
P_t = 0.405;                           % Transmitted optical power [W]
m_t = -log(2)/log(cosd(theta_half));   % Lambertian order

% ============================================================================================
% Photodetector
% ============================================================================================
p = 4.8e-3; q = 5.5e-3;               % PD dimensions [m]
A_det = p*q;                           % Sensitive area [m^2]
R_pd = 0.63;                           % Responsivity [A/W]
FOV = 85;                              % Field of view [deg]
n_r = [0, 0, 1];                       % PD normal vector (known via IMU)

% ============================================================================================
% Noise
% ============================================================================================
sigma2 = 30e6*10^(-21.0);             % AWGN variance [W^2] (optical domain)

% ============================================================================================
% Derived Constants
% ============================================================================================
C_opt = P_t*(m_t+1)*A_det/(2*pi);     % Radiometric constant (positive)
C_neg = -C_opt;                        % Signed constant (as in TCOM Eq. 31)

% ============================================================================================
% Room and Testbed
% ============================================================================================
T = [0, 0, 2];                         % Transmitter position (ceiling center)
L = 3; W = 3; Hmax = 1.2;             % Room dimensions
N_samples = 1000;                      % Samples per orientation
step = 0.2;                            % Testbed X,Y step [m]
stepH = 0.2;                           % Testbed Z step [m]

% ============================================================================================
% DEB-optimized Orientations (from TCOM RV2 Table III)
% Format: [theta1, phi1, theta2, phi2, ...] in degrees
% ============================================================================================
orientations_DEB_K3 = [17.48,203.70, 17.22,332.20, 18.71,88.79];
orientations_DEB_K4 = [29.88,315.03, 29.87,134.99, 29.87,45.03, 29.86,225.02];
orientations_DEB_K5 = [0.10,74.22, 65.68,269.84, 65.73,179.90, 65.91,359.82, 65.88,89.91];
orientations_DEB_K6 = [67.60,253.38, 66.63,321.05, 70.03,176.90, 0.12,274.29, 68.91,98.38, 66.82,24.94];
orientations_DEB_K7 = [65.60,353.25, 2.46,10.07, 66.17,273.62, 64.59,196.54, 62.48,130.76, 2.56,191.66, 63.78,68.11];
orientations_DEB_K8 = [67.61,67.08, 66.59,247.26, 2.79,39.70, 3.21,226.96, 64.71,2.81, 66.06,179.67, 66.89,298.24, 65.37,114.85];
orientations_DEB_K9 = [4.52,303.11, 66.06,165.39, 8.73,267.05, 66.75,273.80, 62.42,219.37, 64.16,21.63, 67.15,90.96, 13.90,105.06, 62.04,330.31];

all_orientations_DEB = {orientations_DEB_K3, orientations_DEB_K4, orientations_DEB_K5, ...
                        orientations_DEB_K6, orientations_DEB_K7, orientations_DEB_K8, ...
                        orientations_DEB_K9};
K_values = 3:9;

% ============================================================================================
% Helper: Convert orientation vector to 3xK unit vectors
% ============================================================================================
% Usage: nt = orient_to_vectors(orientations_DEB_K5)
%   Returns 3xK matrix of unit orientation vectors (nadir-referenced)
orient_to_vectors = @(orient_deg) cell2mat(arrayfun(@(i) ...
    [sind(orient_deg(2*i-1))*cosd(orient_deg(2*i)); ...
     sind(orient_deg(2*i-1))*sind(orient_deg(2*i)); ...
     -cosd(orient_deg(2*i-1))], ...
    1:length(orient_deg)/2, 'UniformOutput', false));
