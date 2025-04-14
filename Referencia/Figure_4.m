%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TBD
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
P_t = 1;
theta_half = 45;
% theta_half = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60];
% maxTransmitPower = [0.130, 0.540, 1.190, 2.060, 3.120, 4.310, 5.610, 6.970, 8.370, 9.780, 11.180, 12.560];
mode = 'deterministic'; % Two modes: '0/30' or 'random'
theta = 30; % Angle of orientation in the deterministic mode
N0 = 0; %1e-21; % Spectral density level of AWGN
signalBandwidth = 30e6; % Bandwidth of the receiver (Hz)
step = 0.1; % Distance between each receiving point (m)
% delta_z = -0.01:0.001:0.01;
% delta_K = -0.1:0.01:0.1;
delta_theta = -5:0.1:5;
orientationError = 'both'; %'overX';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                          AP Parameters                            %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------%
% LIGHT SOURCES GEOMETRY %
%------------------------%
L = 4; W = 4; H = 2.5; % Length, width and height of the room (m)
m_t = -log(2)./log(cosd(theta_half)); % Lambertian order of emission
coord_t = [0 0 0]; % Positions of the light sources

if( strcmp(mode,'random') )
    n_t = rand(3,3);
    n_t(:,end) = -abs(n_t(:,end));
    for i = 1:size(n_t,1)
        n_t(i,:) = n_t(i,:)./norm(n_t(i,:));
    end
elseif( strcmp(mode,'deterministic') )
    n_t = [          0,           0,           -1;
                     0, sind(theta), -cosd(theta);
           sind(theta),           0, -cosd(theta)];
end
a = n_t(:,1); b = n_t(:,2); c = n_t(:,3); % Intermediate variables added for consistency with the work document
N_n_t = size(n_t,1); % Number of different orientations of the Tx

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
sigma2_tot = signalBandwidth*N0; % Receiver's noise variance (A²)
%---------------------------%
% RECEIVER PLANE PARAMETERS %
%---------------------------%
X_r = -L/2:step:L/2; % Range of Rx points along x axis
Y_r = -W/2:step:W/2; % Range of Rx points along y axis
N_rx = length(X_r); N_ry = length(Y_r); % Number of reception points simulated along the x and y axis
[x_real, y_real] = meshgrid(X_r, Y_r);
x_real = x_real'; y_real = y_real';
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
H0_LOS = zeros(N_rx,N_ry,N_n_t);
P_r = zeros(N_rx,N_ry,N_n_t);
for i_n = 1:size(n_t,1)
    param_t = {coord_t, n_t(i_n,:), P_t, m_t};
    for r_x = 1:N_rx
        for r_y = 1:N_ry
            x = X_r(r_x); y = Y_r(r_y);
            [H0_LOS(r_x,r_y,i_n), P_r(r_x,r_y,i_n)] = OWC_LOS_channel(x, y, z, param_t, param_r);
        end
    end
end

i = 1; j = 2; k = 1; l = 3;
K_ij = (P_r(:,:,i)./P_r(:,:,j)).^(1/m_t);
K_kl = (P_r(:,:,k)./P_r(:,:,l)).^(1/m_t);


%% 3. Parameter Sensitivity
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                        Sensitivity in n_t                         %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if( strcmp(orientationError,'both') )
    x_est_err_theta = cell(length(delta_theta));
    y_est_err_theta = cell(length(delta_theta));
    error_RMS_theta = cell(length(delta_theta));
    cdf90_RMS = zeros(length(delta_theta));
    for i_theta = 1:length(delta_theta)
        for j_theta = 1:length(delta_theta)
            n_t_err_theta = [                               0,                                0,                                -1;
                                                            0, sind(theta+delta_theta(i_theta)), -cosd(theta+delta_theta(i_theta));
                             sind(theta+delta_theta(j_theta)),                                0, -cosd(theta+delta_theta(j_theta))];
            a_err = n_t_err_theta(:,1); b_err = n_t_err_theta(:,2); c_err = n_t_err_theta(:,3); % Intermediate variables added for consistency with the work document
            x_est_err_theta{i_theta, j_theta} = z.*( (K_kl.*b_err(l)-b_err(k)).*(c_err(i)-K_ij.*c_err(j)) - (K_ij.*b_err(j)-b_err(i)).*(c_err(k)-c_err(l).*K_kl) ) ./ ...
                ( (K_kl.*b_err(l)-b_err(k)).*(K_ij.*a_err(j)-a_err(i)) - (K_ij.*b_err(j)-b_err(i)).*(K_kl.*a_err(l)-a_err(k)) );
            y_est_err_theta{i_theta, j_theta} = z.*( (K_kl.*a_err(l)-a_err(k)).*(c_err(i)-K_ij.*c_err(j)) - (K_ij.*a_err(j)-a_err(i)).*(c_err(k)-c_err(l).*K_kl) ) ./ ...
                ( (K_kl.*a_err(l)-a_err(k)).*(K_ij.*b_err(j)-b_err(i)) - (K_ij.*a_err(j)-a_err(i)).*(K_kl.*b_err(l)-b_err(k)) );
            error_RMS_theta{i_theta, j_theta} = sqrt( (x_est_err_theta{i_theta, j_theta}-x_real).^2 + (y_est_err_theta{i_theta, j_theta}-y_real).^2);
            error_RMS_theta_Q1 = error_RMS_theta{i_theta, j_theta}(21:31,21:31);
            [f_RMS,x_RMS] = ecdf(error_RMS_theta_Q1(:));
            cdf90_RMS(i_theta,j_theta) = x_RMS(max(find(f_RMS<0.9)));
        end
    end
elseif( strcmp(orientationError,'overX') || strcmp(orientationError,'overY') )
    x_est_err_theta = cell(1,length(delta_theta));
    y_est_err_theta = cell(1,length(delta_theta));
    error_RMS_theta = cell(1,length(delta_theta));
    for i_theta = 1:length(delta_theta)
        if( strcmp(orientationError,'overY') )
            n_t_err_theta = [          0,                                0,                                -1;
                0, sind(theta+delta_theta(i_theta)), -cosd(theta+delta_theta(i_theta));
                sind(theta),                                0,                      -cosd(theta)];
        elseif( strcmp(orientationError,'overX') )
            n_t_err_theta = [                               0,           0,                                -1;
                0, sind(theta),                      -cosd(theta);
                sind(theta+delta_theta(i_theta)),           0, -cosd(theta+delta_theta(i_theta))];
        end
        a_err = n_t_err_theta(:,1); b_err = n_t_err_theta(:,2); c_err = n_t_err_theta(:,3); % Intermediate variables added for consistency with the work document
        x_est_err_theta{i_theta} = z.*( (K_kl.*b_err(l)-b_err(k)).*(c_err(i)-K_ij.*c_err(j)) - (K_ij.*b_err(j)-b_err(i)).*(c_err(k)-c_err(l).*K_kl) ) ./ ...
            ( (K_kl.*b_err(l)-b_err(k)).*(K_ij.*a_err(j)-a_err(i)) - (K_ij.*b_err(j)-b_err(i)).*(K_kl.*a_err(l)-a_err(k)) );

        y_est_err_theta{i_theta} = z.*( (K_kl.*a_err(l)-a_err(k)).*(c_err(i)-K_ij.*c_err(j)) - (K_ij.*a_err(j)-a_err(i)).*(c_err(k)-c_err(l).*K_kl) ) ./ ...
            ( (K_kl.*a_err(l)-a_err(k)).*(K_ij.*b_err(j)-b_err(i)) - (K_ij.*a_err(j)-a_err(i)).*(K_kl.*b_err(l)-b_err(k)) );
        error_RMS_theta{i_theta} = sqrt( (x_est_err_theta{i_theta}-x_real).^2 + (y_est_err_theta{i_theta}-y_real).^2);
    end
end


toc;

%% Plots
figure;
surf(delta_theta, delta_theta, cdf90_RMS.*100);
view([0,90]); 
cb = colorbar(); 
ylabel(cb,'RMS error $\varepsilon_{90\%}$ (cm)','FontSize',10,'interpreter', 'latex');
shading interp;
xlabel('Error on $\mathbf{n}_{t,j}$ ($^{\circ}$)','interpreter','latex'); 
ylabel('Error on $\mathbf{n}_{t,k}$ ($^{\circ}$)','interpreter','latex');





% figure;
% surf(X_r,Y_r,error_RMS'.*100); view([0 90]);
% xlim([-2,2]); ylim([-2,2]);
% xlabel('x (m)'); ylabel('y (m)');
% clbr = colorbar; clbr.Label.String = 'RMS error (cm)';
% 
% figure; 
% plot(delta_z.*100,delta_x{21,21}.*100, delta_z.*100, delta_x{11,21}.*100, delta_z.*100, delta_x{1,21}.*100);
% xlabel('\delta h (cm)'); ylabel('\delta x (cm)'); grid on;
% legend('x = 0 m','x = 1 m','x = 2 m', 'Location', 'southEast');
% 
% figure;
% surf(X_r,Y_r,reshape(error_RMS_K{12},41,41)'.*100); view([0 90]);
% xlim([-2,2]); ylim([-2,2]);
% xlabel('x (m)'); ylabel('y (m)');
% clbr = colorbar; clbr.Label.String = 'RMS error (cm)';
% 
% figure;
% surf(X_r,Y_r,reshape(error_RMS_K{end},41,41)'.*100); view([0 90]);
% xlim([-2,2]); ylim([-2,2]);
% xlabel('x (m)'); ylabel('y (m)');
% clbr = colorbar; clbr.Label.String = 'RMS error (cm)';
% 
% figure;
% plot(delta_K.*100, error_RMS_K_Pos1.*100, delta_K.*100, error_RMS_K_Pos2.*100, delta_K.*100, error_RMS_K_Pos3.*100);
% xlabel('\delta K (%)'); ylabel('RMS error (cm)'); grid on;
% legend('Point of coordinates (-2,-2)','Point of coordinates (0,0)','Point of coordinates (2,2)');
% 
% figure;
% surf(X_r,Y_r,reshape(error_RMS_theta{13},41,41)'.*100); view([0 90]);
% xlim([-2,2]); ylim([-2,2]);
% xlabel('x (m)'); ylabel('y (m)');
% clbr = colorbar; clbr.Label.String = 'RMS error (cm)';

% figure;
% plot(X_r, error_RMS_theta1.*100, X_r, error_RMS_theta2.*100, X_r, error_RMS_theta3.*100, ...
%      X_r, error_RMS_theta4.*100, X_r, error_RMS_theta5.*100, X_r, error_RMS_theta6.*100, ...
%      X_r, error_RMS_theta7.*100, X_r, error_RMS_theta8.*100);
% xlabel('x (m)'); ylabel('RMS error (cm)'); grid on;
% legend('\delta\theta = -5°','\delta\theta = -2.5°','\delta\theta = -1°', '\delta\theta = -0.5°','\delta\theta = 0.5°','\delta\theta = 1°','\delta\theta = 2.5°','\delta\theta = 5°');

% figure;
% plot(X_r, error_RMS_theta2.*100, X_r, error_RMS_theta3.*100, ...
%      X_r, error_RMS_theta4.*100, X_r, error_RMS_theta5.*100, X_r, error_RMS_theta6.*100, ...
%      X_r, error_RMS_theta7.*100);
% xlabel('x (m)'); ylabel('RMS error (cm)'); grid on;
% legend('\delta\theta = -2.5°','\delta\theta = -1°', '\delta\theta = -0.5°','\delta\theta = 0.5°','\delta\theta = 1°','\delta\theta = 2.5°');

