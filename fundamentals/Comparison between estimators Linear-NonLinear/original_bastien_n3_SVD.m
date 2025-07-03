%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This script simulates a 3D beamsteering-based positioning system using a 
% single steerable optical source, which orientation can be changed 
% from 3 to 9 times while considering additive white Gaussian noise 
% independant from the received signal of interest at the single-photodiode 
% level. Two methods for estimating the receiver's position are
% implemented:
% 1. Direct estimation of the receivers coordinates from the observed
% received power using non-linear least square optimization
% 2. Indirect estimation of the receivers coordinates via direct estimation
% of the received optical power using the MVU (and here efficient) least
% square estimator, and then sigular value decomposition.
% More details in '20250521 - Notes positionnement 3D (V0.2).pdf'
%
% B. Béchadergue - LISV - May 2025
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
close all;
clear variables;
clc;
tic;
rng(42);
%% 1. Simulation Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                    Main Simulation Parameters                     %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------------------------%
% LIGHT SOURCES CORE SIMULATION PARAMETERS %
%------------------------------------------%
theta_half = 45; % 60; % Semi-angle at half-power [°]
P_t = 0.405; % 1; % Transmitted optical power [W]
N_or = 3; % Number of orientations considered by the non-linear least square estimator
L = 3; W = 3; H = 2; Hmax=1.2; % Full length, width and height of the room [m]
% L = 2; W = 2; H = 2.5; % Full Length, width and height of the room [m]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                          AP Parameters                            %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------%
% LIGHT SOURCES GEOMETRY %
%------------------------%
T = [0 0 0]; x_n = T(1); y_n = T(2); z_n = T(3); % Positions of the light source (origin of the main frame)
m_t = -log(2)./log(cosd(theta_half)); % Lambertian order of emission
% Use optimized orientations for K=3 to K=9 from the CRLB analysis
% [theta1, rho1, theta2, rho2, ...] donde theta es elevación y rho es azimuth
% Configurations
orientations_K3 = [36.93, 56.20, 35.42, 176.85, 33.39, 296.52];
orientations_K4 = [36.87, 17.59, 41.59, 198.61, 42.40, 108.42, 39.37, 293.57];

% orientations_K5 = [0.48, 294.81,30.57, 87.79, 30.71, 358.55, 30.17, 177.68, 30.72, 268.14];
% orientations_K5 = [0.48, 294.81,57.57, 87.79, 57.71, 358.55, 57.17, 177.68, 55.72, 268.14];
incl=45;
orientations_K5 = [0.48, 294.81,incl, 87.79, incl, 358.55,incl, 177.68, incl, 268.14];

orientations_K6 = [53.23, 179.80, 58.97, 355.37, 48.42, 97.78, 49.58, 268.13, 19.80, 252.81, 25.95, 39.19];
orientations_K7 = [27.60, 355.20, 49.75, 182.12, 51.74, 280.40, 39.06, 251.04, 58.92, 352.88, 16.73, 71.81, 42.72, 104.45];
orientations_K8 = [32.76, 218.19, 28.47, 61.48, 51.87, 178.18, 35.72, 25.47, 51.63, 338.81, 57.74, 273.57, 49.66, 106.23, 18.14, 243.22];
orientations_K9 = [26.09, 251.86, 64.05, 261.27, 60.74, 358.44, 57.22, 187.22, 63.10, 175.67, 11.75, 76.79, 44.54, 119.76, 58.20, 85.09, 25.17, 304.81];
all_orientations = {orientations_K3, orientations_K4, orientations_K5, orientations_K6, orientations_K7, orientations_K8, orientations_K9};
K_values = [3, 4, 5, 6, 7, 8, 9];

% Convert spherical orientation angles to cartesian vectors
n_t = zeros(N_or, 3);
% Using fixed optimized Tx orientation
for i = 1:N_or
    theta_i = all_orientations{N_or-2}(2*i-1);  % elevation angle
    rho_i = all_orientations{N_or-2}(2*i);      % azimuth angle
    % Convert from spherical to cartesian coordinates
    n_t(i,1) = sind(theta_i) * cosd(rho_i);  % x component
    n_t(i,2) = sind(theta_i) * sind(rho_i);  % y component
    n_t(i,3) = -cosd(theta_i);               % z component (negative because pointing down)
end

% Cartesian coordinates of the orientations vectors
a_i = n_t(1,1); b_i = n_t(1,2); c_i = n_t(1,3);
a_j = n_t(2,1); b_j = n_t(2,2); c_j = n_t(2,3);
a_k = n_t(3,1); b_k = n_t(3,2); c_k = n_t(3,3);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                          Rx Parameters                            %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%--------------------------%
% PHOTODETECTOR PARAMETERS %
%--------------------------%
p = 4.8e-3; q = 5.5e-3; % Dimensions of the rectangular photodiode [m]
N_det = 1; % Number of photodiodes
A_det = p*q*N_det; % Photoreceiver sensitive area [m²]
R_pd = 0.63; % Photosensitivity of the photodiode [A/W]
FOV = 85; % Fielf-of-view of the photoreceiver [°]
n_r = [0, 0, 1]; % Normal vector of the photoreceiver
% n_r = [-0.5+rand(1,2), H]; Normal vector of the photoreceiver (random)
% n_r = n_r/norm(n_r); % Normal vector of the photoreceiver (normalized)
alpha = n_r(1,1); beta = n_r(1,2); gamma = n_r(1,3); % Cartesian coordinates of the normal vector of the photoreceiver
% sigma2 = 30e6*10^(-21.0); % AWGN variance [A²]
sigma2 = 30e6*10^(-21.0);
C = -P_t*(m_t+1)*A_det/(2*pi); % Normalization factor
%---------------------------%
% RECEIVER PLANE PARAMETERS %
%---------------------------%
N_pos = 1000; % Number of random Rx positions simulated
X_r = -L/2 + L.*rand(1,N_pos); % x-axis Rx coordinate
Y_r = -W/2 + W.*rand(1,N_pos); % y-axis Rx coordinate
Z_r = -(0.8+Hmax*rand(1,N_pos)); % x-axis Rx coordinate (random altitudes)

param_r = {A_det, n_r, FOV}; % Vector of the Rx parameters used for channel simulation

%% 2. Simulations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                         Simulation Core                           %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
P_r = cell(N_pos,3); % Real received power [W]
P_r_noisy = cell(N_pos,3); % Noise power observed [W]
v_tr = zeros(N_pos,3); % Real unit vector from Tx to Rx
v_tr_est = zeros(N_pos,3); % Estimated unit vector from Tx to Rx
d_tr = zeros(N_pos,1); % Real absolute distance between Tx and Rx
%-----------------------------------------------------%
% Step 1: Computation of the observed received powers %
%-----------------------------------------------------%
for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:size(n_t,1)
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), d_tr(i_pos,1)] = OWC_LOS_channel(x, y, z, param_t, param_r);
        % P_r_noisy{i_pos,i_dir} = (R_pd.*P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000))./(-R_pd*C); % Noise power observed after normalization (needed for the non-linear MATLAB solver to coverge) [W]
        P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000)); % Noise power observed after normalization (needed for the non-linear MATLAB solver to coverge) [W]
        %P_r_noisy{i_pos,i_dir} = min(max(P_r_noisy{i_pos,i_dir}, 0.00000000001), 1000);
    end
end

%----------------------------------------%
% Step 2: Estimation of the Rx positions %
%----------------------------------------%
for i_pos = 1:N_pos
    x_real = X_r(i_pos); y_real = Y_r(i_pos); z_real = Z_r(i_pos); % Real position of the Rx
    
    %---------------------------------------------------------------------------------------%
    % Case 2: Indirect position estimation with with estimation of the received power + SVD %      
    %---------------------------------------------------------------------------------------%
    K_ij = (mean(P_r_noisy{i_pos,1})./mean(P_r_noisy{i_pos,2})).^(1/m_t);
    K_jk = (mean(P_r_noisy{i_pos,2})./mean(P_r_noisy{i_pos,3})).^(1/m_t);
    K_ik = (mean(P_r_noisy{i_pos,1})./mean(P_r_noisy{i_pos,3})).^(1/m_t);
    alpha_ij = a_i - K_ij*a_j;
    alpha_jk = a_j - K_jk*a_k;
    alpha_ik = a_i - K_ik*a_k;
    beta_ij = b_i - K_ij*b_j;
    beta_jk = b_j - K_jk*b_k;
    beta_ik = b_i - K_ik*b_k;
    gamma_ij = c_i - K_ij*c_j;
    gamma_jk = c_j - K_jk*c_k;
    gamma_ik = c_i - K_ik*c_k;
    eigenVectorsSVD{i_pos,1} = null( [alpha_ij, beta_ij, gamma_ij;
                                      alpha_jk, beta_jk, gamma_jk;
                                      alpha_ik, beta_ik, gamma_ik]);

    if( length(eigenVectorsSVD{i_pos,1}) == 3 && eigenVectorsSVD{i_pos,1}(3) >= 0 )
        v_tr_est_SVD(i_pos,:) = -eigenVectorsSVD{i_pos,1};
        param_t_axis = {T, v_tr_est_SVD(i_pos,:), P_t, m_t};
        param_r_axis = {A_det, -v_tr_est_SVD(i_pos,:), FOV}; % Vector of the Rx parameters used for channel simulation
        [~, P_r_axis_SVD(i_pos), ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
        P_r_axis_noisy_SVD(i_pos,:) = P_r_axis_SVD(i_pos) + sqrt(sigma2).*randn(1,1000); % Corresponding noise power observed [W]
%         d_tr_est_SVD(i_pos) = sqrt(P_t*(m_t+1)*A_det/(2*pi*P_r_axis_SVD(i_pos)) );
        d_tr_est_SVD(i_pos) = sqrt( P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_SVD(i_pos,:))) );
        estPosSVD(i_pos,:) = v_tr_est_SVD(i_pos,:).*d_tr_est_SVD(i_pos);
    elseif( length(eigenVectorsSVD{i_pos,1}) == 3 && eigenVectorsSVD{i_pos,1}(3) < 0 )
        v_tr_est_SVD(i_pos,:) = eigenVectorsSVD{i_pos,1};
        param_t_axis = {T, v_tr_est_SVD(i_pos,:), P_t, m_t};
        param_r_axis = {A_det, -v_tr_est_SVD(i_pos,:), FOV}; % Vector of the Rx parameters used for channel simulation
        [~, P_r_axis_SVD(i_pos), ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
        P_r_axis_noisy_SVD(i_pos,:) = (R_pd.*P_r_axis_SVD(i_pos) + sqrt(sigma2).*randn(1,1000))./R_pd; % Corresponding noise power observed [W]
%         d_tr_est_SVD(i_pos) = sqrt( P_t*(m_t+1)*A_det/(2*pi*P_r_axis_SVD(i_pos)) );
        d_tr_est_SVD(i_pos) = sqrt( P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy_SVD(i_pos,:))) );
        estPosSVD(i_pos,:) = v_tr_est_SVD(i_pos,:).*d_tr_est_SVD(i_pos);
    else
        v_tr_est_SVD(i_pos,:) = [NaN, NaN, NaN];
        estPosSVD(i_pos,:) = [NaN, NaN, NaN];
    end
end
%%
realPos = [X_r ; Y_r ; Z_r];

errorSVD = realPos' - estPosSVD;
for i = 1:length(errorSVD)
    
    errorNormSVD(i) = norm(errorSVD(i,:));
end
cdfplot(errorNormSVD.*1e2); hold off;
xlabel('RMS error [cm]'); ylabel('Empirical cumulative distribution function'); xlim([0 20])
legend('Non-linear estimator of X','Linear estimator of P_{r,i} + SVD','Location','best');


%% Appendix: Functions used by the main scipt
function [H0, P_r_LOS, v_tr, d_tr] = OWC_LOS_channel(x, y, z, param_t, param_r)
% 1. Parameters initialization
T = param_t{1}; % Transmitter coordinates
n_t = param_t{2}; % Transmitter normal
P_t = param_t{3}; % Transmitter optical power
m = param_t{4}; % Transmitter Lambertian order
R = [x,y,z]; % Receiver coordinates
A_det = param_r{1}; % Receiver sensitive area
n_r = param_r{2}; % Receiver normal
FOV = param_r{3}; % Reveiver field of view

% 2. LOS received optical power calculation
v_tr = (R-T)./norm(R-T);
d_tr = sqrt(dot(R-T,R-T));
cos_phi = dot(n_t,v_tr);
cos_psi = dot(n_r,-v_tr);
if( abs(acosd(cos_psi)) <= FOV && cos_phi > 0 )
    H0 = (m+1)*A_det/(2*pi*d_tr^2)*cos_phi^m*cos_psi; % Channel DC gain (no units)
else
    H0 = 0;
end
P_r_LOS = P_t*H0;
end
