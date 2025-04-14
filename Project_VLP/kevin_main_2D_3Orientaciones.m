
clc, clear
import opticalWireless.*

n_t_s = [ 5, 0, 5, 120, 5, 240 ]; % coordenadas esfericas de 3 orientaciones

N0 = 10^(-21); % Nivel de ruido
step = 0.1; % Distance between each receiving point (m)
N_n_t = 3; % Number of different orientations of the Tx


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                    Main Simulation Parameters                     %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------------------------%
% LIGHT SOURCES CORE SIMULATION PARAMETERS %
%------------------------------------------%
P_t = 0.405;
theta_half = 45;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                         Room Parameters                           %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
L = 2.4; W = 2.4; H = 2; % Length, width and height of the room (m)
i_t = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                          AP Parameters                            %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------%
% LIGHT SOURCES GEOMETRY %
%------------------------%
m_t = -log(2)./log(cosd(theta_half)); % Lambertian order of emission
coord_t = [0 0 0]; % Positions of the light sources

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
testbed = [-1.2 1.2 -1.2 1.2]; % Testbed in format [-xlim xlim -ylim ylim]
X_r = testbed(1):step:testbed(2); % Range of Rx points along x axis
Y_r = testbed(3):step:testbed(4); % Range of Rx points along y axis
N_rx = length(X_r); N_ry = length(Y_r); % Number of reception points simulated along the x and y axis
[x_real, y_real] = meshgrid(X_r, Y_r);
z_ref = 0.96; % Height of the receiver plane from the ground (m)
z = z_ref-H; % z = -1.04; % Height of the Rx points ("-" because coordinates system origin at the center of the ceiling)
if( abs(z) > H )
    fprintf('ERROR: The receiver plane is out of the room.\n');
    return
end
z_real = z*ones(size(x_real));
param_r = {A_det, n_r, FOV}; % Vector of the Rx parameters used for channel simulation

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                         Simulation Core                           %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
H_LOS = zeros(N_rx,N_ry,N_n_t);
P_r = zeros(N_rx,N_ry,N_n_t);
P_r_real = zeros(N_rx,N_ry,N_n_t);
%SNR = cell(1,length(theta));

[theta_n_t_1, theta_n_t_2, theta_n_t_3] = deal(n_t_s(1), n_t_s(3), n_t_s(5));
[rho_n_t_1, rho_n_t_2, rho_n_t_3] = deal(n_t_s(2), n_t_s(4), n_t_s(6));

n_t_1 = [sind(theta_n_t_1)*cosd(rho_n_t_1), sind(theta_n_t_1)*sind(rho_n_t_1), -cosd(theta_n_t_1)];
n_t_2 = [sind(theta_n_t_2)*cosd(rho_n_t_2), sind(theta_n_t_2)*sind(rho_n_t_2), -cosd(theta_n_t_2)];
n_t_3 = [sind(theta_n_t_3)*cosd(rho_n_t_3), sind(theta_n_t_3)*sind(rho_n_t_3), -cosd(theta_n_t_3)];
n_t = [n_t_1;n_t_2;n_t_3];

    % Calculo perse
    a = n_t(:,1); b = n_t(:,2); c = n_t(:,3); % Intermediate variables added for consistency with the work document
    for i_n = 1:size(n_t,1)
        param_t = {coord_t, n_t(i_n,:), m_t};
        for r_x = 1:N_rx  %parfor
            for r_y = 1:N_ry
                
                x = X_r(r_x); y = Y_r(r_y);
                
                % Considering only LOS:
                H_LOS(r_x,r_y,i_n) = h_LOS(param_t, i_t, param_r, x, y, z);
                P_r_real(r_x,r_y,i_n) = H_LOS(r_x,r_y,i_n)*P_t;

                s_r = (R_pd*P_r_real(r_x,r_y,i_n)).*ones(1,10000) + sqrt(sigma2_tot)*randn(1,10000);
                Pr_elec = sum(s_r.^2)./length(s_r); % Electrical power of the received signal (W or A²)
                P_r(r_x,r_y,i_n) = sqrt(Pr_elec)/R_pd; % Estimation of the optical power collected by the PD (W)
                SNR(r_x,r_y,i_n) = 10*log10( (R_pd*P_r_real(r_x,r_y,i_n))^2/sigma2_tot );
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

    rmsError = sqrt((x_real'-x_est).^2+(y_real'-y_est).^2);
    [f_RMS,x_RMS] = ecdf(rmsError(:));
    cdf90_RMS = x_RMS(max(find(f_RMS<0.9)))

    SNR_dB = mean(SNR(:))
    
figure(1)
scatter3(x_real, y_real, z_real, 'o', 'MarkerEdgeColor', "k"); hold on;
scatter3(x_est, y_est, z_real, 'x', 'MarkerEdgeColor', [0.8500 0.3250 0.0980]); hold on;
xlim([testbed(1)-0.1,testbed(2)+0.1]);
ylim([testbed(3)-0.1,testbed(4)+0.1]);
zlim([-2,0])

grid on;
xlabel('x (m)'); ylabel('y (m)');
quiver3(0,0, 0, n_t(1,1), n_t(1,2), n_t(1,3), 0.5, 'r', 'LineWidth', 1)
quiver3(0,0, 0, n_t(2,1), n_t(2,2), n_t(2,3), 0.5, 'r', 'LineWidth', 1)
quiver3(0,0, 0, n_t(3,1), n_t(3,2), n_t(3,3), 0.5, 'r', 'LineWidth', 1)
hold off;