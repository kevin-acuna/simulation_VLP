function P = poc_params()
%% System Parameters — PoC: Receiver-Steered Single-Anchor OWP (3D)
% Returns a struct P with all physical/system parameters of the PoC.
% Usage:  P = poc_params();
%
% Inherits the TCOM/Broadcast baseline parameters (fixed LED at the ceiling,
% bare PD) and adds the receiver-side gimbal constraints.
%
% Author: Kevin Acuna-Condori
% Date:   04 Sep 2026
% Project: Cambridge — RX-steered single-anchor OWP

% ============================================================================================
% LED Transmitter (FIXED anchor, known position and orientation)
% ============================================================================================
P.Phi_half = 45;                                % Semi-angle at half power [deg]
P.P_t      = 0.405;                             % Transmitted optical power [W]
P.m        = -log(2)/log(cosd(P.Phi_half));     % Lambertian order (45 deg -> m = 2)
P.t        = [0, 0, 2];                         % LED position [m] (ceiling centre)
P.n_t      = [0, 0, -1];                        % LED optical axis (unit, pointing down)

% ============================================================================================
% Photodetector (single, mounted on a 2-DOF gimbal: tilt + azimuth)
% ============================================================================================
P.A_det    = 4.8e-3 * 5.5e-3;                   % Sensitive area [m^2]
P.R_pd     = 0.63;                              % Responsivity [A/W] (not used in optical-domain model)
P.FOV      = 85;                                % Half-angle field of view [deg]
P.theta_max = 75;                               % Mechanical tilt limit of the gimbal [deg]

% ============================================================================================
% Noise and acquisition
% ============================================================================================
P.sigma2    = 30e6 * 10^(-21.0);                % Per-sample AWGN variance [W^2] (optical domain)
P.N_samples = 1000;                             % Samples averaged per orientation
P.sigma2_mean = P.sigma2 / P.N_samples;         % Variance of the sample mean

% ============================================================================================
% Testbed (receiver positions, world frame; LED at the origin of x-y)
% ============================================================================================
P.L = 3; P.W = 3;                               % Floor dimensions [m]  -> x,y in [-L/2, L/2]
P.Hmax = 1.2;                                   % Max receiver height [m]
P.step  = 0.30;                                 % x,y step [m]
P.stepH = 0.60;                                 % z step [m]  -> heights 0, 0.6, 1.2

% ============================================================================================
% Derived constants
% ============================================================================================
P.C = P.P_t * (P.m + 1) * P.A_det / (2*pi);     % Radiometric constant [W m^2]
end
