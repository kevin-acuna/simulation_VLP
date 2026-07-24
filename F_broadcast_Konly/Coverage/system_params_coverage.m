%% ========================================================================
%  system_params_coverage.m   --   *** COVERAGE FOLDER ONLY ***
%  ------------------------------------------------------------------------
%  ISOLATED parameter set used ONLY by the scripts inside F_broadcast_Konly/
%  Coverage/ (coverage_broadcast_Konly.m and visualize_received_power_3D.m).
%
%  >>> Editing THIS file affects ONLY the Coverage folder. <<<
%  It is a self-contained copy of system_params_F.m so you can freely tweak
%  power, noise, FOV, room, codebook, etc. for coverage experiments WITHOUT
%  touching ../simulations/system_params_F.m or any other part of the project.
%
%  Usage: system_params_coverage   (run as a script)
%% ========================================================================

% ========================================================================
% LED Transmitter: SFH4725S
% ========================================================================
theta_half = 36.7;                           % Semi-angle at half power [deg]
P_t        = 0.67;                           % Transmitted optical power [W]
m_t        = -log(2)/log(cosd(theta_half));  % Lambertian order

% ========================================================================
% Photodetector : BPX61
% ========================================================================
p = 2.65e-3; q = 2.65e-3;                   % PD dimensions [m] 
A_det = p*q;                                % Sensitive area [m^2]
R_pd  = 0.62*0.9;                           % Responsivity [A/W] 0.62 (850nm), 0.9 (940nm)
FOV   = 55;                                 % Field of view [deg]
n_r   = [0, 0, 1];                          % PD normal vector (known via IMU)

% ========================================================================
% Noise
% ========================================================================
sigma2 = 30e6*10^(-21.0);               % AWGN variance [W^2] (optical domain)
%   Per-SAMPLE variance for an electrical bandwidth B = 30 MHz.
%   The averaged-measurement SNR is N*mu^2/sigma2, so both SNR and the
%   Fisher information scale linearly with N (PEB ~ 1/sqrt(N)). Keep N and
%   sigma2 fixed to physically meaningful values: they are NOT design knobs.

% ========================================================================
% Derived Constants
% ========================================================================
C_opt = P_t*(m_t+1)*A_det/(2*pi);       % Radiometric constant (positive)
C_neg = -C_opt;                         % Signed constant (as in TCOM Eq. 31)

% ========================================================================
% Room and Testbed
% ========================================================================
T    = [0, 0, 2];                       % Transmitter position (ceiling center)
L = 3; W = 3; Hmax = 1.2;               % Room dimensions [m]
% Samples averaged per beam measurement. FIXED physical constant = B*T_int,
% NOT a tuning knob. N=1000 ~ 33 us of integration at B=30 MHz, and matches
% the experimental acquisition (n_samples=1000, fs=1000 in exp1_Calibration).
% Sweeping N rescales SNR (10*log10(N) dB) and PEB (1/sqrt(N)); that is why
% coverage looked so different at N=1 vs N=100. With N=1000, SNR_min=10 dB
% => threshold P_rx = sqrt(sigma2/N*10^(SNR_min/10)) = 0.0173 uW (-47.6 dBm).
N_samples = 1000;                       % Samples per beam measurement (fixed)
step  = 0.2;                            % Testbed X,Y step [m]
stepH = 0.2;                            % Testbed Z step [m]

% ========================================================================
% DEB-optimized Orientations (Phi_half = 45 deg) -- preset 'DEB_45'
% Format: [theta1, phi1, theta2, phi2, ...] in degrees
% ========================================================================
orientations_DEB_K3  = [17.48,203.70, 17.22,332.20, 18.71,88.79];
orientations_DEB_K4  = [29.88,315.03, 29.87,134.99, 29.87,45.03, 29.86,225.02];
orientations_DEB_K5  = [0.10,74.22, 65.68,269.84, 65.73,179.90, 65.91,359.82, 65.88,89.91];
orientations_DEB_K5  = [0,0,30,0,30,90,30,180,30,270];
orientations_DEB_K6  = [67.60,253.38, 66.63,321.05, 70.03,176.90, 0.12,274.29, 68.91,98.38, 66.82,24.94];
orientations_DEB_K7  = [65.60,353.25, 2.46,10.07, 66.17,273.62, 64.59,196.54, 62.48,130.76, 2.56,191.66, 63.78,68.11];
orientations_DEB_K8  = [67.61,67.08, 66.59,247.26, 2.79,39.70, 3.21,226.96, 64.71,2.81, 66.06,179.67, 66.89,298.24, 65.37,114.85];
orientations_DEB_K9  = [4.52,303.11, 66.06,165.39, 8.73,267.05, 66.75,273.80, 62.42,219.37, 64.16,21.63, 67.15,90.96, 13.90,105.06, 62.04,330.31];
orientations_DEB_K10 = [3.78,331.01, 67.31,81.94, 67.55,12.65, 12.87,13.36, 61.78,318.33, 67.79,193.90, 16.59,108.11, 67.13,263.27, 63.65,142.99, 25.08,230.08];
orientations_DEB_K11 = [9.24,127.82, 67.83,339.85, 71.61,209.53, 71.15,271.00, 37.04,280.24, 14.43,34.47, 66.12,87.01, 69.14,147.78, 1.57,280.98, 44.93,192.84, 69.30,20.68];
orientations_DEB_K12 = [14.24,336.52, 8.12,197.76, 66.66,132.66, 70.59,263.28, 7.64,55.75, 12.86,146.36, 69.08,339.30, 64.98,24.74, 66.36,84.64, 55.82,279.13, 60.28,206.89, 70.22,182.55];
orientations_DEB_K13 = [71.91,279.91, 61.21,127.86, 74.14,88.20, 0.11,341.06, 13.74,172.18, 44.00,71.92, 70.16,170.86, 62.55,252.98, 7.50,254.98, 71.16,198.34, 72.45,336.84, 34.80,353.62, 75.39,25.14];
orientations_DEB_K14 = [69.79,124.15, 71.28,358.09, 66.84,171.92, 4.16,340.43, 60.49,11.72, 67.41,245.74, 64.62,196.88, 9.12,172.11, 8.88,311.93, 63.31,67.05, 66.33,88.55, 6.23,128.89, 65.55,303.12, 63.44,271.33];
orientations_DEB_K15 = [56.58,61.23, 8.19,156.49, 15.81,340.94, 63.28,357.01, 68.95,240.51, 14.73,261.69, 62.69,289.64, 5.56,220.60, 57.75,110.72, 68.32,163.31, 73.36,90.46, 7.16,117.22, 64.26,189.02, 70.78,296.29, 66.46,11.91];

% ========================================================================
% DEB-optimized Orientations (Phi_half = 30 deg) -- preset 'DEB_30'
% ========================================================================
orientations_DEB_K3_Phi30  = [7.25,242.44,6.01,4.02,7.51,123.74];
orientations_DEB_K4_Phi30  = [16.59,315.00,16.60,135.00,16.57,45.03,16.58,225.01];
orientations_DEB_K5_Phi30  = [0.12,259.84,50.88,270.09,51.02,359.98,51.00,179.97,51.03,90.04];
orientations_DEB_K6_Phi30  = [19.99,0.43,61.44,180.32,43.57,270.08,20.12,179.67,61.29,359.77,43.99,90.06];
orientations_DEB_K7_Phi30  = [65.50,277.70,51.53,0.16,51.80,202.04,63.88,73.89,22.29,270.35,56.48,146.30,21.88,86.97];
orientations_DEB_K8_Phi30  = [54.79,359.81,65.76,297.29,28.42,164.03,59.31,224.79,60.26,84.53,26.76,282.01,21.76,59.75,65.01,166.79];
orientations_DEB_K9_Phi30  = [67.48,31.69,22.05,95.06,65.86,151.40,58.53,90.07,41.02,270.98,35.60,188.78,71.78,316.21,36.45,354.86,71.00,227.59];
orientations_DEB_K10_Phi30 = [61.20,17.63,60.79,177.29,70.77,226.63,70.07,322.95,69.29,72.47,68.43,127.12,31.52,89.28,25.69,199.74,51.60,273.27,27.64,340.12];

% ========================================================================
% Codebook collections (indexed by K via K_values / K_values_Phi30)
% ========================================================================
all_orientations_DEB = {orientations_DEB_K3,  orientations_DEB_K4,  orientations_DEB_K5, ...
                        orientations_DEB_K6,  orientations_DEB_K7,  orientations_DEB_K8, ...
                        orientations_DEB_K9,  orientations_DEB_K10, orientations_DEB_K11, ...
                        orientations_DEB_K12, orientations_DEB_K13, orientations_DEB_K14, ...
                        orientations_DEB_K15};
K_values = 3:15;

all_orientations_DEB_Phi30 = {orientations_DEB_K3_Phi30,  orientations_DEB_K4_Phi30,  orientations_DEB_K5_Phi30, ...
                              orientations_DEB_K6_Phi30,  orientations_DEB_K7_Phi30,  orientations_DEB_K8_Phi30, ...
                              orientations_DEB_K9_Phi30,  orientations_DEB_K10_Phi30};
K_values_Phi30 = 3:10;

% ========================================================================
% Helper: convert an orientation vector to 3xK unit vectors (nadir-referenced)
% ========================================================================
orient_to_vectors = @(orient_deg) cell2mat(arrayfun(@(i) ...
    [sind(orient_deg(2*i-1))*cosd(orient_deg(2*i)); ...
     sind(orient_deg(2*i-1))*sind(orient_deg(2*i)); ...
     -cosd(orient_deg(2*i-1))], ...
    1:length(orient_deg)/2, 'UniformOutput', false));
