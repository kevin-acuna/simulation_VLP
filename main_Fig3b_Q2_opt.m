%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
close all;
clear variables;
clc;
tic;

%% 1. Simulation Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                    Main Simulation Parameters                     %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------------------------%
% LIGHT SOURCES CORE SIMULATION PARAMETERS %
%------------------------------------------%
P_t = 0.405;
theta_half = 45;
d = 0.125:0.125:2;
theta = atand(d./1.65); % Angle of orientation in the deterministic mode
N0 = 0; %10^(-22.5);
step = 0.1; % Distance between each receiving point (m)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                         Room Parameters                           %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
L = 4; W = 4; H = 2.5; % Length, width and height of the room (m)
N_wx = 40; % Number of wall reflectors considered along the x axis
N_wy = 40; % Number of wall reflectors considered along the y axis
N_wz = 25; % Number of wall reflectors considered along the z axis
bounceOrderDecomposition = 0;
bounceOrder = 1; % Number of bounces taken into account for the finite response

N = 2*N_wx*N_wy + 2*N_wx*N_wz + 2*N_wy*N_wz; % Total number of wall reflectors in the rooom
[reflectors, n_w, dA, numRefPerWall, X_w, Y_w, Z_w] = roomGenerator(L, W, H, N_wx, N_wy, N_wz, 0);
reflectivity = 0.6;
rho = [reflectivity.*ones(1,N-N_wy*N_wx), reflectivity.*ones(1,N_wy*N_wx)]; % Reflectivity factor of the wall reflectors
G_rho = diag(rho); % Reflectivity matrix
param_w = {reflectors, n_w, dA, L, W, H, G_rho};
i_t = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                          AP Parameters                            %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------%
% LIGHT SOURCES GEOMETRY %
%------------------------%
m_t = -log(2)./log(cosd(theta_half)); % Lambertian order of emission
coord_t = [0 0 0]; % Positions of the light sources
N_n_t = 3; % Number of different orientations of the Tx

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                          Rx Parameters                            %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%--------------------------%
% PHOTODETECTOR PARAMETERS %
%--------------------------%
p = 4.8e-3; q = 5.5e-3; % Dimensions of the rectangular photodiode (m)
N_det = 1; % Number of photodiodes
A_det = p*q*N_det; % Photoreceiver sensitive area (m²)
FOV = 85; % Fielf-of-view of the photoreceiver
% index = 1.5; % Refractive index of the Rx concentrator/lens (ignore if not used)
% G_Con = (index^2)/(sind(FOV).^2); % Gain of an ideal optical concentrator (ignore if not used)
G_Con = 1; % In case no concentrator is used
T_s = 1; % Gain of the optical filter (ignore if not used)
R_pd = 0.63; % Photodiode responsivity (A/W)
n_r = [0, 0, 1]; % Normal vector of the photoreceiver
n_r = n_r/norm(n_r); % Normal vector of the photoreceiver (normalized)
%------------------%
% NOISE PARAMETERS %
%------------------%
signalBandwidth = 30e6; % Bandwidth of the receiver (Hz)
sigma2_tot = signalBandwidth*N0; % Receiver's noise variance (A²)
%---------------------------%
% RECEIVER PLANE PARAMETERS %
%---------------------------%
X_r = 1:step:1.9; % Range of Rx points along x axis
Y_r = 1:step:1.9; % Range of Rx points along y axis
N_rx = length(X_r); N_ry = length(Y_r); % Number of reception points simulated along the x and y axis
[x_real, y_real] = meshgrid(X_r, Y_r);
z_ref = 0.85; % Height of the receiver plane from the ground (m)
z = z_ref-H; % z = -1.65; % Height of the Rx points ("-" because coordinates system origin at the center of the ceiling)
if( abs(z) > H )
    fprintf('ERROR: The receiver plane is out of the room.\n');
    return
end
param_r = {A_det, n_r, FOV}; % Vector of the Rx parameters used for channel simulation

%% 2. Simulations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                         Simulation Core                           %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
H_LOS = zeros(N_rx,N_ry,N_n_t);
H_NLOS = zeros(N_rx,N_ry,N_n_t);
P_r = zeros(N_rx,N_ry,N_n_t);
P_r_real = zeros(N_rx,N_ry,N_n_t);
cdf90_RMS = zeros(1,length(theta));
rmsError = cell(1,length(theta));
SNR = cell(1,length(theta));

delete(gcp("nocreate"));
profile = "Processes";
localPoolNumWorkers = 24;

for i_angle = 1:length(theta)
    n_t = [           1,            1, z;
           1+d(i_angle),            1, z;
                      1, 1+d(i_angle), z];
    n_t(1,:) = n_t(1,:)./norm(n_t(1,:));
    n_t(2,:) = n_t(2,:)./norm(n_t(2,:));
    n_t(3,:) = n_t(3,:)./norm(n_t(3,:));
    a = n_t(:,1); b = n_t(:,2); c = n_t(:,3); % Intermediate variables added for consistency with the work document
    for i_n = 1:size(n_t,1)
        param_t = {coord_t, n_t(i_n,:), m_t};
        parfor r_x = 1:N_rx
            for r_y = 1:N_ry
                x = X_r(r_x); y = Y_r(r_y);
                [H_LOS(r_x,r_y,i_n), H_NLOS(r_x,r_y,i_n), ~] = opticalWirelessChannel(param_t, i_t, param_w, param_r, x, y, z, bounceOrderDecomposition, bounceOrder);
                P_r_real(r_x,r_y,i_n) = ( H_LOS(r_x,r_y,i_n)+H_NLOS(r_x,r_y,i_n) )*P_t;
                s_r = (R_pd*P_r_real(r_x,r_y,i_n)).*ones(1,10000) + sqrt(sigma2_tot)*randn(1,10000);
                Pr_elec = sum(s_r.^2)./length(s_r); % Electrical power of the received signal (W or A²)
                P_r(r_x,r_y,i_n) = sqrt(Pr_elec)/R_pd; % Estimation of the optical power collected by the PD (W)
                % SNR{i_angle}(r_x,r_y,i_n) = 10*log10( (R_pd*P_r_real(r_x,r_y,i_n))^2/sigma2_tot );
                fprintf('Distance = %.3f m |  orientation n°%.0f, x = %.1f m, y = %.1f m (%.2f/100)\n', d(i_angle), i_n, x, y, round( ( (i_angle-1)*size(n_t,1)*N_rx*N_ry + (i_n-1)*N_rx*N_ry + (r_x-1)*N_ry + r_y )/(length(theta)*size(n_t,1)*N_rx*N_ry)*100 , 2) );
            end
        end
    end
    i = 1; j = 2; k = 1; l = 3;
    K_ij = (P_r(:,:,i)./P_r(:,:,j)).^(1/m_t);
    K_kl = (P_r(:,:,k)./P_r(:,:,l)).^(1/m_t);

    x_est = z.*( (K_kl.*b(l)-b(k)).*(c(i)-K_ij.*c(j)) - (K_ij.*b(j)-b(i)).*(c(k)-c(l).*K_kl) ) ./ ...
        ( (K_kl.*b(l)-b(k)).*(K_ij.*a(j)-a(i)) - (K_ij.*b(j)-b(i)).*(K_kl.*a(l)-a(k)) );

    y_est = z.*( (K_kl.*a(l)-a(k)).*(c(i)-K_ij.*c(j)) - (K_ij.*a(j)-a(i)).*(c(k)-c(l).*K_kl) ) ./ ...
        ( (K_kl.*a(l)-a(k)).*(K_ij.*b(j)-b(i)) - (K_ij.*a(j)-a(i)).*(K_kl.*b(l)-b(k)) );

    rmsError{i_angle} = sqrt((x_real'-x_est).^2+(y_real'-y_est).^2);
    [f_RMS,x_RMS] = ecdf(rmsError{i_angle}(:));
    cdf90_RMS(i_angle) = x_RMS(max(find(f_RMS<0.9)));
end

toc;

save workspace;