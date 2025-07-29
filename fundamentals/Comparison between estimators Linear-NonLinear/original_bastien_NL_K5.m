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

rng(42);


N_or = 5; % Number of orientations considered by the non-linear least square estimator


%% 1. Simulation Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                    Main Simulation Parameters                     %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------------------------%
% LIGHT SOURCES CORE SIMULATION PARAMETERS %
%------------------------------------------%
theta_half = 45; %
P_t = 0.405; % 1; % Transmitted optical power [W]

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

% Use optimized orientations for K=3 to K=10 from the CRLB analysis
% [theta1, rho1, theta2, rho2, ...] donde theta es elevación y rho es azimuth
% orientations_K5 = [0.48, 294.81,30, 87.79, 30, 358.55,30, 177.68, 30, 268.14];
% orientations_K5 = [0.48, 294.81,57.57, 87.79, 57.71, 358.55, 57.17, 177.68, 55.72, 268.14];
orientations_K3=[35.40,140.13,33.31,36.38,29.58,262.70];
orientations_K4=[38.89,90.56,41.48,0.15,41.80,180.10,38.79,270.24];
orientations_K5=[0.10,211.14,50.55,89.96,50.66,179.99,50.37,359.93,50.59,269.96];
orientations_K6=[17.19,306.94,54.55,266.13,22.49,140.37,52.23,360.00,52.41,84.05,55.76,185.16];
orientations_K7=[58.91,355.65,53.77,170.74,27.75,43.75,5.36,305.88,54.35,96.46,35.10,220.04,54.78,278.61];
orientations_K8=[51.82,89.38,61.50,268.26,27.32,316.99,6.46,318.34,57.76,5.84,53.65,171.30,37.97,200.35,39.27,91.12];
orientations_K9=[0,28.15,56.92,178.69,36.54,266.83,33.86,182.29,42.20,78.36,53.07,97.46,57.91,359.73,37.07,355.08,58.23,272.07];
orientations_K10=[56.00,3.61,53.20,182.48,54.93,356.82,11.94,38.06,61.28,270.34,50.17,91.30,47.56,174.73,43.39,89.36,32.54,277.55,15.14,255.31];

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
a_l = n_t(4,1); b_l = n_t(4,2); c_l = n_t(4,3);
a_m = n_t(5,1); b_m = n_t(5,2); c_m = n_t(5,3);

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
alpha = n_r(1,1); beta = n_r(1,2); gamma = n_r(1,3); % Cartesian coordinates of the normal vector of the photoreceiver
sigma2 = 30e6*10^(-21.0);
C = -P_t*(m_t+1)*A_det/(2*pi); % Normalization factor
%---------------------------%
% RECEIVER PLANE PARAMETERS %
%---------------------------%
N_pos = 1000; % Number of random Rx positions simulated
X_r = -L/2 + L.*rand(1,N_pos); % x-axis Rx coordinate
Y_r = -W/2 + W.*rand(1,N_pos); % y-axis Rx coordinate
Z_r = -(0.8+Hmax*rand(1,N_pos)); % z_r [0.. 1.2] ; T=(0,0,2)
% Z_r = -(1.8+Hmax*rand(1,N_pos)); % z_r [0.. 1.2] ; T=(0,0,3)

param_r = {A_det, n_r, FOV}; % Vector of the Rx parameters used for channel simulation


%% Define Range of study

% range = 73:76;
range = 1:N_pos;



%% 2. Simulations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                         Simulation Core                           %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
P_r = cell(N_pos,N_or); % Real received power [W]
P_r_noisy = cell(N_pos,N_or); % Noise power observed [W]
v_tr = zeros(N_pos,3); % Real unit vector from Tx to Rx
v_tr_est = zeros(N_pos,3); % Estimated unit vector from Tx to Rx
d_tr = zeros(N_pos,1); % Real absolute distance between Tx and Rx
%-----------------------------------------------------%
% Step 1: Computation of the observed received powers %
%-----------------------------------------------------%
for i_pos = range
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:size(n_t,1)
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), d_tr(i_pos,1)] = OWC_LOS_channel(x, y, z, param_t, param_r);
        P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000))./(-C);

        %P_r_noisy{i_pos,i_dir} = min(max(P_r_noisy{i_pos,i_dir}, 0.00000000001), 1000);
    end
end

%----------------------------------------%
% Step 2: Estimation of the Rx positions %
%----------------------------------------%
time_NL = [];
for i_pos = range
    x_real = X_r(i_pos); y_real = Y_r(i_pos); z_real = Z_r(i_pos); % Real position of the Rx
    %--------------------------------------------------------------------------%
    % Case 1: Direct position estimation with non-linear least square approach %      
    %--------------------------------------------------------------------------%
    % 1. Definition of the parameters to estimate
    x = optimvar('x'); y = optimvar('y'); z = optimvar('z');

    % 2. Definition of the polynomials Q_i and L
    Q_i = a_i.*x + b_i.*y + c_i.*z;
    Q_j = a_j.*x + b_j.*y + c_j.*z;
    Q_k = a_k.*x + b_k.*y + c_k.*z;
    Q_l = a_l.*x + b_l.*y + c_l.*z;
    Q_m = a_m.*x + b_m.*y + c_m.*z;
    L = alpha.*x + beta.*y + gamma.*z;

    % 3. Definition of the objective functions F_i(x,y,z)
    F_i = sum( ( C.*L.*Q_i.^m_t - P_r_noisy{i_pos,1} ).^2 );
    F_j = sum( ( C.*L.*Q_j.^m_t - P_r_noisy{i_pos,2} ).^2 );
    F_k = sum( ( C.*L.*Q_k.^m_t - P_r_noisy{i_pos,3} ).^2 );
    F_l = sum( ( C.*L.*Q_l.^m_t - P_r_noisy{i_pos,4} ).^2 );
    F_m = sum( ( C.*L.*Q_m.^m_t - P_r_noisy{i_pos,5} ).^2 );

    % 4. Definition of the final objective function F(x,y,z) - CAN BE OPTIMIZED
    F = F_i + F_j + F_k + F_l + F_m;


    % 5. Definition of the optimization problem to solve
    prob = optimproblem('Objective',F);

    % 6. Definition of the constraints
    Q1Constraint = Q_i >= 0;
    Q2Constraint = Q_j >= 0;
    Q3Constraint = Q_k >= 0;
    Q4Constraint = Q_l >= 0;
    Q5Constraint = Q_m >= 0;
    LConstraint = L <= 0;
    % sphereConstraint = x.^2 + y.^2 + z.^2 == 1; % Commented because otherwise prevents the optimization algorithm to converge

    % 7. Addition of the constraints to the optimization problem
    prob.Constraints.Q1 = Q1Constraint;
    prob.Constraints.Q2 = Q2Constraint;
    prob.Constraints.Q3 = Q3Constraint;
    prob.Constraints.Q4 = Q4Constraint;
    prob.Constraints.Q5 = Q5Constraint;
    prob.Constraints.L = LConstraint;
    % prob.Constraints.sphereConstraint = sphereConstraint; % Commented because otherwise prevents the optimization algorithm to converge

    % 8. Estimation of the unit vector from Tx to Rx
    x0.x = 0; x0.y = 0; x0.z = -1; % Initial guess 
    tic;
    [sol,fval] = solve(prob,x0); % Non-linear optimization problem resolution
    v_hat = [sol.x, sol.y, sol.z]; % Solution reached
    v_tr_est(i_pos,:) = v_hat./norm(v_hat); % Normalized solution, i.e. estimate of the unit vector from Tx to Rx

    % 9. Estimation of the Rx coordinates from the estimated v_tr
    param_t_axis = {T, v_tr_est(i_pos,:), P_t, m_t};
    param_r_axis = {A_det, -v_tr_est(i_pos,:), FOV}; % Vector of the Rx parameters used for channel simulation
    [~, P_r_axis(i_pos), ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis); % Computation of the real received power if Tx and Rx oriented toward v_tr_est and -v_tr_est respectively
    P_r_axis_noisy(i_pos,:) = P_r_axis(i_pos) + sqrt(sigma2).*randn(1,1000); % Corresponding noise power observed [W]
    d_tr_est(i_pos) = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy(i_pos,:)))); % Estimated absolute distance (case with noise) [m]
    estPos(i_pos,:) = v_tr_est(i_pos,:).*d_tr_est(i_pos); % Estimated coordinates of the Rx
    tiempo_ejecucion = toc;
    time_NL = [time_NL; tiempo_ejecucion];
end


%%
realPos = [X_r ; Y_r ; Z_r];

errorNLS = realPos(:,range)' - estPos(range,:);

for i = 1:length(errorNLS)
    errorNorm(i) = norm(errorNLS(i,:));
end

% realPos(:,range)'
% estPos(range,:)
% errorNorm
% sample=73
% orientation=2
% [mean(P_r_noisy{sample,orientation}), min(P_r_noisy{sample,orientation}), max(P_r_noisy{sample,orientation})]

%%
cdfplot(errorNorm.*1e2); hold on;
xlabel('RMS error [cm]'); ylabel('Empirical cumulative distribution function'); xlim([0 10])
legend('Non-linear estimator of X','Location','best');

% save 'K5_NL.mat' errorNorm time_NL