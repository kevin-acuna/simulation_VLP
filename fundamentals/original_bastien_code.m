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
orientationMode = 'deterministic'; % 'randomEqual'
N_or = 5; % Number of orientations considered by the non-linear least square estimator
theta = 30; % Main angle of orientation (only for deterministic mode) [°]
L = 2.4; W = 2.4; H = 2; % Full length, width and height of the room [m]
% L = 2; W = 2; H = 2.5; % Full Length, width and height of the room [m]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                          AP Parameters                            %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------%
% LIGHT SOURCES GEOMETRY %
%------------------------%
T = [0 0 0]; x_n = T(1); y_n = T(2); z_n = T(3); % Positions of the light source (origin of the main frame)
m_t = -log(2)./log(cosd(theta_half)); % Lambertian order of emission
if( strcmp(orientationMode, 'randomEqual') ) % Case of random Tx orientation (from 3 to 9 orientations supported)
    U1 = [-0.5+rand(1,2), -H]; U2 = [-0.5+rand(1,2), -H]; U3 = [-0.5+rand(1,2), -H];
    U4 = [-0.5+rand(1,2), -H]; U5 = [-0.5+rand(1,2), -H]; U6 = [-0.5+rand(1,2), -H];
    U7 = [-0.5+rand(1,2), -H]; U8 = [-0.5+rand(1,2), -H]; U9 = [-0.5+rand(1,2), -H];
    n_t = [U1; U2; U3; U4; U5; U6; U7; U8; U9];
    for i = 1:size(n_t,1)
        n_t(i,:) = n_t(i,:)./norm(n_t(i,:));
    end
else % Case of fixed Tx orientation (from 3 to 9 orientations supported)
    n_t = [       0,              0,             -1;
                  0,    sind(theta),   -cosd(theta);
        sind(theta),              0,   -cosd(theta);
       -sind(theta),              0,   -cosd(theta);
                  0,   -sind(theta),   -cosd(theta);
              sqrt(2)/2*sind(theta),   sqrt(2)/2*sind(theta),  -cosd(theta);
              sqrt(2)/2*sind(theta),  -sqrt(2)/2*sind(theta),  -cosd(theta);
             -sqrt(2)/2*sind(theta),   sqrt(2)/2*sind(theta),  -cosd(theta);
             -sqrt(2)/2*sind(theta),  -sqrt(2)/2*sind(theta),  -cosd(theta)];
end
% Cartesian coordinates of the orientations vectors
a_i = n_t(1,1); b_i = n_t(1,2); c_i = n_t(1,3);
a_j = n_t(2,1); b_j = n_t(2,2); c_j = n_t(2,3);
a_k = n_t(3,1); b_k = n_t(3,2); c_k = n_t(3,3);
a_l = n_t(4,1); b_l = n_t(4,2); c_l = n_t(4,3);
a_m = n_t(5,1); b_m = n_t(5,2); c_m = n_t(5,3);
a_n = n_t(6,1); b_n = n_t(6,2); c_n = n_t(6,3);
a_o = n_t(7,1); b_o = n_t(7,2); c_o = n_t(7,3);
a_p = n_t(8,1); b_p = n_t(8,2); c_p = n_t(8,3);
a_q = n_t(9,1); b_q = n_t(9,2); c_q = n_t(9,3);

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
sigma2 = 30e6*10^(-21.0); % AWGN variance [A²]
C = -P_t*(m_t+1)*A_det/(2*pi); % Normalization factor
%---------------------------%
% RECEIVER PLANE PARAMETERS %
%---------------------------%
N_pos = 1000; % Number of random Rx positions simulated
X_r = -L/2 + L.*rand(1,N_pos); % x-axis Rx coordinate
Y_r = -W/2 + W.*rand(1,N_pos); % y-axis Rx coordinate
% Z_r = (0.96-H).*ones(1,N_pos); % z-axis Rx coordinate (single reception plane)
Z_r = -(0.8+rand(1,N_pos)); % x-axis Rx coordinate (random altitudes)
% X_r = -L+2.*L.*rand(1,N_pos); % x-axis Rx coordinate
% Y_r = -W+2.*W.*rand(1,N_pos); % x-axis Rx coordinate
% Z_r = -H+rand(1,N_pos); % x-axis Rx coordinate
param_r = {A_det, n_r, FOV}; % Vector of the Rx parameters used for channel simulation

%% 2. Simulations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                         Simulation Core                           %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
P_r = cell(N_pos,5); % Real received power [W]
P_r_noisy = cell(N_pos,5); % Noise power observed [W]
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
        P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000))./(-C); % Noise power observed after normalization (needed for the non-linear MATLAB solver to coverge) [W]
    end
end

%----------------------------------------%
% Step 2: Estimation of the Rx positions %
%----------------------------------------%
for i_pos = 1:N_pos
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
    Q_n = a_n.*x + b_n.*y + c_n.*z;
    Q_o = a_o.*x + b_o.*y + c_o.*z;
    Q_p = a_p.*x + b_p.*y + c_p.*z;
    Q_q = a_q.*x + b_q.*y + c_q.*z;
    L = alpha.*x + beta.*y + gamma.*z;

    % 3. Definition of the objective functions F_i(x,y,z)
    F_i = sum( ( C.*L.*Q_i.^m_t - P_r_noisy{i_pos,1} ).^2 );
    F_j = sum( ( C.*L.*Q_j.^m_t - P_r_noisy{i_pos,2} ).^2 );
    F_k = sum( ( C.*L.*Q_k.^m_t - P_r_noisy{i_pos,3} ).^2 );
    F_l = sum( ( C.*L.*Q_l.^m_t - P_r_noisy{i_pos,4} ).^2 );
    F_m = sum( ( C.*L.*Q_m.^m_t - P_r_noisy{i_pos,5} ).^2 );
    F_n = sum( ( C.*L.*Q_n.^m_t - P_r_noisy{i_pos,6} ).^2 );
    F_o = sum( ( C.*L.*Q_o.^m_t - P_r_noisy{i_pos,7} ).^2 );
    F_p = sum( ( C.*L.*Q_p.^m_t - P_r_noisy{i_pos,8} ).^2 );
    F_q = sum( ( C.*L.*Q_q.^m_t - P_r_noisy{i_pos,9} ).^2 );

    % 4. Definition of the final objective function F(x,y,z) - CAN BE OPTIMIZED
    if( N_or == 3 )
        F = F_i + F_j + F_k;
    elseif( N_or == 4 )
        F = F_i + F_j + F_k + F_l;
    elseif( N_or == 5 )
        F = F_i + F_j + F_k + F_l + F_m;
    elseif( N_or == 6 )
        F = F_i + F_j + F_k + F_l + F_m + F_n;
    elseif( N_or == 7 )
        F = F_i + F_j + F_k + F_l + F_m + F_n + F_o;
    elseif( N_or == 8 )
        F = F_i + F_j + F_k + F_l + F_m + F_n + F_o + F_p;
    elseif( N_or == 9 )
        F = F_i + F_j + F_k + F_l + F_m + F_n + F_o + F_p + F_q;
    end

    % 5. Definition of the optimization problem to solve
    prob = optimproblem('Objective',F);

    % 6. Definition of the constraints
    Q1Constraint = Q_i >= 0;
    Q2Constraint = Q_j >= 0;
    Q3Constraint = Q_k >= 0;
    Q4Constraint = Q_l >= 0;
    Q5Constraint = Q_m >= 0;
    Q6Constraint = Q_n >= 0;
    Q7Constraint = Q_o >= 0;
    Q8Constraint = Q_p >= 0;
    Q9Constraint = Q_q >= 0;
    LConstraint = L <= 0;
    % sphereConstraint = x.^2 + y.^2 + z.^2 == 1; % Commented because otherwise prevents the optimization algorithm to converge

    % 7. Addition of the constraints to the optimization problem
    if( N_or == 3 )
        prob.Constraints.Q1 = Q1Constraint;
        prob.Constraints.Q2 = Q2Constraint;
        prob.Constraints.Q3 = Q3Constraint;
    elseif( N_or == 4 )
        prob.Constraints.Q1 = Q1Constraint;
        prob.Constraints.Q2 = Q2Constraint;
        prob.Constraints.Q3 = Q3Constraint;
        prob.Constraints.Q4 = Q4Constraint;
    elseif( N_or == 5 )
        prob.Constraints.Q1 = Q1Constraint;
        prob.Constraints.Q2 = Q2Constraint;
        prob.Constraints.Q3 = Q3Constraint;
        prob.Constraints.Q4 = Q4Constraint;
        prob.Constraints.Q5 = Q5Constraint;
    elseif( N_or == 6 )
        prob.Constraints.Q1 = Q1Constraint;
        prob.Constraints.Q2 = Q2Constraint;
        prob.Constraints.Q3 = Q3Constraint;
        prob.Constraints.Q4 = Q4Constraint;
        prob.Constraints.Q5 = Q5Constraint;
        prob.Constraints.Q6 = Q6Constraint;
    elseif( N_or == 7 )
        prob.Constraints.Q1 = Q1Constraint;
        prob.Constraints.Q2 = Q2Constraint;
        prob.Constraints.Q3 = Q3Constraint;
        prob.Constraints.Q4 = Q4Constraint;
        prob.Constraints.Q5 = Q5Constraint;
        prob.Constraints.Q6 = Q6Constraint;
        prob.Constraints.Q7 = Q7Constraint;
    elseif( N_or == 8 )
        prob.Constraints.Q1 = Q1Constraint;
        prob.Constraints.Q2 = Q2Constraint;
        prob.Constraints.Q3 = Q3Constraint;
        prob.Constraints.Q4 = Q4Constraint;
        prob.Constraints.Q5 = Q5Constraint;
        prob.Constraints.Q6 = Q6Constraint;
        prob.Constraints.Q7 = Q7Constraint;
        prob.Constraints.Q8 = Q8Constraint;
    elseif( N_or == 9 )
        prob.Constraints.Q1 = Q1Constraint;
        prob.Constraints.Q2 = Q2Constraint;
        prob.Constraints.Q3 = Q3Constraint;
        prob.Constraints.Q4 = Q4Constraint;
        prob.Constraints.Q5 = Q5Constraint;
        prob.Constraints.Q6 = Q6Constraint;
        prob.Constraints.Q7 = Q7Constraint;
        prob.Constraints.Q8 = Q8Constraint;
        prob.Constraints.Q9 = Q9Constraint;
    end
    prob.Constraints.L = LConstraint;
    % prob.Constraints.sphereConstraint = sphereConstraint; % Commented because otherwise prevents the optimization algorithm to converge

    % 8. Estimation of the unit vector from Tx to Rx
    x0.x = 0; x0.y = 0; x0.z = -1; % Initial guess 
    [sol,fval] = solve(prob,x0); % Non-linear optimization problem resolution
    v_hat = [sol.x, sol.y, sol.z]; % Solution reached
    v_tr_est(i_pos,:) = v_hat./norm(v_hat); % Normalized solution, i.e. estimate of the unit vector from Tx to Rx

    % 9. Estimation of the Rx coordinates from the estimated v_tr
    param_t_axis = {T, v_tr_est(i_pos,:), P_t, m_t};
    param_r_axis = {A_det, -v_tr_est(i_pos,:), FOV}; % Vector of the Rx parameters used for channel simulation
    [~, P_r_axis(i_pos), ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis); % Computation of the real received power if Tx and Rx oriented toward v_tr_est and -v_tr_est respectively
    P_r_axis_noisy(i_pos,:) = (R_pd.*P_r_axis(i_pos) + sqrt(sigma2).*randn(1,1000))./R_pd; % Corresponding noise power observed [W]
%     d_tr_est(i_pos) = sqrt(P_t*(m_t+1)*A_det/(2*pi*P_r_axis(i_pos))); % Estimated absolute distance (case without noise) [m]
    d_tr_est(i_pos) = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy(i_pos,:)))); % Estimated absolute distance (case with noise) [m]
    estPos(i_pos,:) = v_tr_est(i_pos,:).*d_tr_est(i_pos); % Estimated coordinates of the Rx
    
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
        P_r_axis_noisy_SVD(i_pos,:) = (R_pd.*P_r_axis_SVD(i_pos) + sqrt(sigma2).*randn(1,1000))./R_pd; % Corresponding noise power observed [W]
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
errorNLS = realPos' - estPos;
errorSVD = realPos' - estPosSVD;
for i = 1:length(errorNLS)
    errorNorm(i) = norm(errorNLS(i,:));
    errorNormSVD(i) = norm(errorSVD(i,:));
end
cdfplot(errorNorm.*1e3); hold on;
cdfplot(errorNormSVD.*1e3); hold off;
xlabel('RMS error [mm]'); ylabel('Empirical cumulative distribution function'); xlim([0,50]);
legend('Non-linear estimator of X','Linear estimator of P_{r,i} + SVD');


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
