close all;
clear variables;
clc;
tic;

% Hyperparameters
N_pos = 1000; % Number of random Rx positions simulated
d_pd   = 0.20; % separación [m]

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
N_or = 3; % Number of orientations considered by the non-linear least square estimator
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
sigma2 = 30e6*10^(-21.8); % AWGN variance [A²]
C = -P_t*(m_t+1)*A_det/(2*pi); % Normalization factor

%---------------------------%
% RECEIVER PLANE PARAMETERS %
%---------------------------%

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

v_tr = zeros(N_pos,3); % Real unit vector from Tx to Rx
v_tr_est = zeros(N_pos,3); % Estimated unit vector from Tx to Rx
d_tr = zeros(N_pos,1); % Real absolute distance between Tx and Rx


%% ----- Parámetros del par de fotodiodos --------------------------

phi_s  = 30*pi/180; % orientación arbitraria del receptor (test)
s_vec  = d_pd * [ cos(phi_s); sin(phi_s); 0 ]; % vector de separación 3-D

P_r1 = cell(N_pos,N_or); % Received power at PD-1
P_r2 = cell(N_pos,N_or); % Received power at PD-2
P_r1_noisy = cell(N_pos,N_or); % Noise power observed [W]
P_r2_noisy = cell(N_pos,N_or); % Noise power observed [W]

%-----------------------------------------------------%
% Step 1: Computation of the observed received powers %
%-----------------------------------------------------%
for i_pos = 1:N_pos
    % coordenadas de los DOS PD
    R_c     = [X_r(i_pos) Y_r(i_pos) Z_r(i_pos)]; % centro
    R1      = R_c - 0.5*s_vec.';
    R2      = R_c + 0.5*s_vec.';
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~,P_r1{i_pos,i_dir}, ~, ~] = OWC_LOS_channel(R1(1),R1(2),R1(3),param_t,param_r); % PD-1
        [~,P_r2{i_pos,i_dir}, ~, ~] = OWC_LOS_channel(R2(1),R2(2),R2(3),param_t,param_r); % PD-2

        % Adding noise
        P_r1_noisy{i_pos,i_dir} = (R_pd.*P_r1{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000))./R_pd;
        P_r2_noisy{i_pos,i_dir} = (R_pd.*P_r2{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000))./R_pd;

    end
end


%----------------------------------------%
% Step 2: Estimation of the Rx positions %
%----------------------------------------%
d1_hat = zeros(N_pos,3);  d2_hat = zeros(N_pos,3);

for i_pos = 1:N_pos
    
    % --- PD-1 -----------------------------------------------------------
    beta = zeros(N_or-1,1);     A = zeros(N_or-1,3);
    beta_i = zeros(N_or-1,1);
    for i = 2:N_or
%         beta(i-1) = (P_r1{i_pos,i}/P_r1{i_pos,1}).^(1/m_t);
        beta(i-1) = (mean(P_r1_noisy{i_pos,i})/mean(P_r1_noisy{i_pos,1})).^(1/m_t);
        A(i-1,:)  = n_t(i,:) - beta(i-1)*n_t(1,:);
    end
    [~,~,V] = svd(A,0);                 % SVD minimal
    d1_hat(i_pos,:) = V(:,end).';
    if d1_hat(i_pos,:)*n_t(1,:).' < 0,  d1_hat(i_pos,:) = -d1_hat(i_pos,:); end

    % --- PD-2 -----------------------------------------------------------
    beta = zeros(N_or-1,1);     A = zeros(N_or-1,3);
    for i = 2:N_or
%         beta(i-1) = (P_r2{i_pos,i}/P_r2{i_pos,1}).^(1/m_t);
        beta(i-1) = (mean(P_r2_noisy{i_pos,i})/mean(P_r2_noisy{i_pos,1})).^(1/m_t);
        A(i-1,:)  = n_t(i,:) - beta(i-1)*n_t(1,:);
    end
    [~,~,V] = svd(A,0);
    d2_hat(i_pos,:) = V(:,end).';
    if d2_hat(i_pos,:)*n_t(1,:).' < 0,  d2_hat(i_pos,:) = -d2_hat(i_pos,:); end
    





    % Estudiar la forma OPTIMA de obtener este resultado
    d1 = d1_hat(i_pos,:).';   % [3×1]
    d2 = d2_hat(i_pos,:).';

    % 1) relación λ2 = λ1*(d1z/d2z)
    k  = d1(3)/d2(3);
    % 2) vector horizontal resultante h = k*[d2x;d2y] - [d1x;d1y]
    h  = k*[d2(1); d2(2)] - [d1(1); d1(2)];
    % 3) λ1 en forma cerrada (ec. 3)
    lambda1 = d_pd / norm(h);
    lambda2 = k * lambda1;
    % 4) centro del par (ec. 5)
    R1_est = T + (lambda1 * d1).';
    R2_est = T + (lambda2 * d2).';
    R_hat(i_pos,:) = 0.5*(R1_est + R2_est);






end

%% ----- Cálculo del error ----------------------------------------------
realPos = [X_r.' Y_r.' Z_r.'];    % vector de centros reales
err     = vecnorm(realPos - R_hat,2,2);

% Calcular percentil 90 para los tres métodos
[f_RMS, x_RMS] = ecdf(err(:));
idx90 = find(f_RMS<0.9, 1, 'last');
cdf90_RMS_cm = x_RMS(idx90)*100 % cm

figure(1)
cdfplot(err.*100); hold on;
xlabel('RMS error [cm]'); ylabel('Empirical cumulative distribution function'); 
legend('2PD');


toc;


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

