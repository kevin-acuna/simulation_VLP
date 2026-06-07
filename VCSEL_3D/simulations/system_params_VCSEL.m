%% System Parameters — VCSEL Gaussian OWP
% Shared across all simulation scripts in VCSEL_3D/simulations/
% Usage: system_params_VCSEL   (run as script)

% ============================================================================================
% VCSEL Transmitter
% ============================================================================================
P_t = 5e-3;                         % Transmitted optical power [W] (eye-safe VCSEL)
theta_div_values = [5, 10, 15, 20, 30];  % Divergence angles to study [deg]

% ============================================================================================
% Lambertian LED Baseline (for comparison)
% ============================================================================================
Phi_half_LED = 45;                   % LED semi-angle at half power [deg]
m_LED = -log(2)/log(cosd(Phi_half_LED));  % Lambertian order
P_t_LED = 0.405;                     % LED transmitted power [W]

% ============================================================================================
% Photodetector
% ============================================================================================
p = 4.8e-3; q = 5.5e-3;             % PD dimensions [m]
A_det = p*q;                         % Sensitive area [m^2]
FOV = 85;                            % Field of view [deg]
n_r = [0, 0, 1];                     % PD normal vector (known)

% ============================================================================================
% Noise
% ============================================================================================
sigma2 = 30e6*10^(-21.0);           % AWGN variance [W^2] (optical domain)

% ============================================================================================
% Room and Testbed
% ============================================================================================
T = [0, 0, 2];                       % Transmitter position (ceiling center)
H = T(3);                            % Ceiling height [m]
L = 3; W = 3; Hmax = 1.2;           % Room dimensions [m]
N_samples = 1000;                    % Samples per orientation
step = 0.2;                          % Testbed X,Y step [m]
stepH = 0.2;                         % Testbed Z step [m]

% ============================================================================================
% Derived Constants
% ============================================================================================
C_VCSEL = P_t * A_det / (2*pi);     % Radiometric constant for VCSEL (without m+1 factor)
C_LED = P_t_LED * (m_LED+1) * A_det / (2*pi);  % Radiometric constant for LED
