%% Figure: 3D Position Estimates — GLS vs WLS
% Self-contained script: generates data with a COARSE testbed suitable for
% 3D visualization, runs GLS/WLS estimators, and plots the comparison.
%
% The testbed here uses step=0.25m, stepH=0.6m (fewer points, clearer plot).
% For the fine testbed used in Table IV / CDF, see estimators/run_GLS_WLS_estimator.m
%
% Requires: core/ in path (vlp_gls.m, vlp_wls.m, OWC_LOS_channel.m)
%
% Author: Kevin Acuña
% Split from original FigCompare3D_WLS_GLS.m — figure version with own data

close all; clear variables; clc;

addpath('../core');

% =================================================
% HYPERPARAMETERS — COARSE TESTBED FOR VISUALIZATION
% =================================================
rng(42);
N_or = 5;

L = 3; W = 3; Hmax = 1.2;
step = 0.25;    % coarser X,Y grid for clearer 3D plot
stepH = 0.6;    % coarser Z grid (3 heights: 0, 0.6, 1.2)

% =================================================
% ORIENTATIONS
% =================================================
orientations_K3=[35.40,140.13,33.31,36.38,29.58,262.70];
orientations_K4=[38.89,90.56,41.48,0.15,41.80,180.10,38.79,270.24];
orientations_K5=[0.10,211.14,50.55,89.96,50.66,179.99,50.37,359.93,50.59,269.96];
orientations_K6=[17.19,306.94,54.55,266.13,22.49,140.37,52.23,360.00,52.41,84.05,55.76,185.16];
orientations_K7=[58.91,355.65,53.77,170.74,27.75,43.75,5.36,305.88,54.35,96.46,35.10,220.04,54.78,278.61];
orientations_K8=[51.82,89.38,61.50,268.26,27.32,316.99,6.46,318.34,57.76,5.84,53.65,171.30,37.97,200.35,39.27,91.12];
orientations_K9=[0,28.15,56.92,178.69,36.54,266.83,33.86,182.29,42.20,78.36,53.07,97.46,57.91,359.73,37.07,355.08,58.23,272.07];
orientations_K10=[56.00,3.61,53.20,182.48,54.93,356.82,11.94,38.06,61.28,270.34,50.17,91.30,47.56,174.73,43.39,89.36,32.54,277.55,15.14,255.31];

all_orientations = {orientations_K3, orientations_K4, orientations_K5, orientations_K6, orientations_K7, orientations_K8, orientations_K9, orientations_K10};

%% 1. System Parameters
N_samples = 1000;
theta_half = 45;
P_t = 0.405;
T = [0, 0, 2];
m_t = -log(2)./log(cosd(theta_half));
p = 4.8e-3; q = 5.5e-3; N_det = 1;
A_det = p*q*N_det;
R_pd = 0.63;
FOV = 85;
n_r = [0, 0, 1];
sigma2 = 30e6*10^(-21.0);

n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = all_orientations{N_or-2}(2*i-1);
    rho_i = all_orientations{N_or-2}(2*i);
    n_t(i,1) = sind(theta_i) * cosd(rho_i);
    n_t(i,2) = sind(theta_i) * sind(rho_i);
    n_t(i,3) = -cosd(theta_i);
end

%% 2. Coarse Testbed
[X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);
fprintf('Coarse testbed: %d positions (step=%.2f, stepH=%.2f)\n', N_pos, step, stepH);

param_r = {A_det, n_r, FOV};

%% 3. Simulation + Estimation
estPosWLS = zeros(N_pos, 3);
estPosGLS = zeros(N_pos, 3);

for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    
    P_raw = zeros(N_samples, N_or);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r_i, ~, ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
        P_raw(:, i_dir) = P_r_i + sqrt(sigma2).*randn(N_samples,1);
    end

    % WLS
    [d_hat_wls, ~, ~] = vlp_wls(n_t', P_raw, m_t);
    v_wls = d_hat_wls';
    param_t_axis = {T, v_wls, P_t, m_t};
    param_r_axis = {A_det, -v_wls, FOV};
    [~, P_r_ax, ~, ~] = OWC_LOS_channel(x, y, z, param_t_axis, param_r_axis);
    P_r_ax_noisy = P_r_ax + sqrt(sigma2).*randn(1, N_samples);
    d_wls = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_ax_noisy)));
    estPosWLS(i_pos,:) = T + v_wls .* d_wls;

    % GLS
    [d_hat_gls] = vlp_gls(n_t', P_raw, m_t, sigma2);
    v_gls = d_hat_gls';
    param_t_axis = {T, v_gls, P_t, m_t};
    param_r_axis = {A_det, -v_gls, FOV};
    [~, P_r_ax, ~, ~] = OWC_LOS_channel(x, y, z, param_t_axis, param_r_axis);
    P_r_ax_noisy = P_r_ax + sqrt(sigma2).*randn(1, N_samples);
    d_gls = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_ax_noisy)));
    estPosGLS(i_pos,:) = T + v_gls .* d_gls;
end

realPos = [X_r; Y_r; Z_r]';

%% 4. Plot
figure('Position', [100, 100, 800, 600]);
plot3(realPos(:,1), realPos(:,2), realPos(:,3), 'ko', 'MarkerSize', 2); hold on;
plot3(estPosWLS(:,1), estPosWLS(:,2), estPosWLS(:,3), 'rs', 'MarkerSize', 2);
plot3(estPosGLS(:,1), estPosGLS(:,2), estPosGLS(:,3), 'bd', 'MarkerSize', 2);

xlabel('X [m]', 'Interpreter', 'latex');
ylabel('Y [m]', 'Interpreter', 'latex');
zlabel('Z [m]', 'Interpreter', 'latex');
legend('Reference', 'WLS', 'GLS', 'Interpreter', 'latex');
axis([-L/2 L/2 -W/2 W/2 min(Z_r)-0.1 max(Z_r)+0.1])
grid on;
view(68.96, 16.08);
ax = gca; ax.Box = 'on'; ax.LineWidth = 1;

set(gcf, 'Color', 'white');
output_path = fullfile(fileparts(mfilename('fullpath')), 'outputs', 'Fig_Comparison_3D.png');
print(output_path, '-dpng', '-r300');
fprintf('Figure saved to %s\n', output_path);
