%% NL Estimator K=5 — DEBUGGED VERSION
% This is the debugged version of NL_test_K5.m
%
% CONCLUSION: The original NL code had NO bugs in its core algorithm.
%   The only difference vs the original is:
%   - use_mean hyperparameter (use sample mean instead of N individual samples)
%   - Angular error computation added
%   - Uses system_params.m for shared parameters
%
% NOTE: Even after fixing BUG-1, the NL is NOT the direction MLE.
%   It's an iterative baseline. GLS remains superior because it uses ratios
%   (which cancel d and n_r) with optimal weighting (Σ_β⁻¹).
%   See analysis_NL_CRLB.md for full theoretical justification.

close all;
clear variables;
clc;

addpath('../core');

rng(42);

N_or = 5;
receiver_mode = 'fixed';
use_mean = true;       % true: use sample mean (faster). false: use N individual samples (paper Eq.31)

%% 1. System Parameters (shared)
system_params;

% NL-specific
T = [0 0 0]; H = 2;
alpha = n_r(1); beta = n_r(2); gamma = n_r(3);

% NL-optimized orientations
orientations_K5 = orientations_NL_K5;
all_orientations{3} = orientations_K5;

% Convert orientations to cartesian
n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = all_orientations{N_or-2}(2*i-1);
    rho_i = all_orientations{N_or-2}(2*i);
    n_t(i,1) = sind(theta_i) * cosd(rho_i);
    n_t(i,2) = sind(theta_i) * sind(rho_i);
    n_t(i,3) = -cosd(theta_i);
end

a_i = n_t(1,1); b_i = n_t(1,2); c_i = n_t(1,3);
a_j = n_t(2,1); b_j = n_t(2,2); c_j = n_t(2,3);
a_k = n_t(3,1); b_k = n_t(3,2); c_k = n_t(3,3);
a_l = n_t(4,1); b_l = n_t(4,2); c_l = n_t(4,3);
a_m = n_t(5,1); b_m = n_t(5,2); c_m = n_t(5,3);

%% 2. Receiver Positions
if strcmp(receiver_mode, 'fixed')
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, -H:stepH:-(H-Hmax));
    X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
    N_pos = length(X_r);
    fprintf('Using %d fixed grid positions\n', N_pos);
else
    N_pos = 1000;
    X_r = -L/2 + L.*rand(1,N_pos);
    Y_r = -W/2 + W.*rand(1,N_pos);
    Z_r = -(0.8+Hmax*rand(1,N_pos));
    fprintf('Using %d random positions\n', N_pos);
end

param_r = {A_det, n_r, FOV};

%% 3. Compute Received Powers
P_r = cell(N_pos,N_or);
P_r_noisy = cell(N_pos,N_or);
v_tr = zeros(N_pos,3);
v_tr_est = zeros(N_pos,3);
d_tr = zeros(N_pos,1);

for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), d_tr(i_pos,1)] = OWC_LOS_channel(x, y, z, param_t, param_r);
       
        % Normalization by (-C) is kept — works with sphere constraint OFF
        P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1, N_samples))./(-C);
    end
end

%% 4. NL Direction Estimation
time_NL = [];
for i_pos = 1:N_pos
    x_real = X_r(i_pos); y_real = Y_r(i_pos); z_real = Z_r(i_pos);
    
    x = optimvar('x'); y = optimvar('y'); z = optimvar('z');

    Q_i = a_i.*x + b_i.*y + c_i.*z;
    Q_j = a_j.*x + b_j.*y + c_j.*z;
    Q_k = a_k.*x + b_k.*y + c_k.*z;
    Q_l = a_l.*x + b_l.*y + c_l.*z;
    Q_m = a_m.*x + b_m.*y + c_m.*z;
    L = alpha.*x + beta.*y + gamma.*z;

    % Cost function: model C*L*Q^m vs normalized data P_r_noisy
    if use_mean
        % Use sample mean (faster, statistically equivalent for Gaussian)
        F_i = ( C.*L.*Q_i.^m_t - mean(P_r_noisy{i_pos,1}) ).^2;
        F_j = ( C.*L.*Q_j.^m_t - mean(P_r_noisy{i_pos,2}) ).^2;
        F_k = ( C.*L.*Q_k.^m_t - mean(P_r_noisy{i_pos,3}) ).^2;
        F_l = ( C.*L.*Q_l.^m_t - mean(P_r_noisy{i_pos,4}) ).^2;
        F_m = ( C.*L.*Q_m.^m_t - mean(P_r_noisy{i_pos,5}) ).^2;
    else
        % Use N individual samples (paper Eq. 31)
        F_i = sum( ( C.*L.*Q_i.^m_t - P_r_noisy{i_pos,1} ).^2 );
        F_j = sum( ( C.*L.*Q_j.^m_t - P_r_noisy{i_pos,2} ).^2 );
        F_k = sum( ( C.*L.*Q_k.^m_t - P_r_noisy{i_pos,3} ).^2 );
        F_l = sum( ( C.*L.*Q_l.^m_t - P_r_noisy{i_pos,4} ).^2 );
        F_m = sum( ( C.*L.*Q_m.^m_t - P_r_noisy{i_pos,5} ).^2 );
    end

    F = F_i + F_j + F_k + F_l + F_m;

    prob = optimproblem('Objective',F);

    prob.Constraints.Q1 = Q_i >= 0;
    prob.Constraints.Q2 = Q_j >= 0;
    prob.Constraints.Q3 = Q_k >= 0;
    prob.Constraints.Q4 = Q_l >= 0;
    prob.Constraints.Q5 = Q_m >= 0;
    prob.Constraints.L = L <= 0;
    % Sphere constraint OFF — required for the normalization scheme to work
    % (optimizer uses ||n|| to absorb distance, post-hoc normalization extracts direction)

    x0.x = 0; x0.y = 0; x0.z = -1;
    tic;
    [sol,fval] = solve(prob,x0);
    v_hat = [sol.x, sol.y, sol.z];
    v_tr_est(i_pos,:) = v_hat./norm(v_hat);
    tiempo_ejecucion = toc;
    time_NL = [time_NL; tiempo_ejecucion];
    
    % Distance recovery (beamsteered)
    param_t_axis = {T, v_tr_est(i_pos,:), P_t, m_t};
    param_r_axis = {A_det, -v_tr_est(i_pos,:), FOV};
    [~, P_r_axis(i_pos), ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis);
    % Distance recovery noise (sigma2 already in W²)
    P_r_axis_noisy(i_pos,:) = P_r_axis(i_pos) + sqrt(sigma2).*randn(1, N_samples);
    d_tr_est(i_pos) = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy(i_pos,:))));
    estPos(i_pos,:) = v_tr_est(i_pos,:).*d_tr_est(i_pos);
end

%% 5. Error Calculation
realPos = [X_r; Y_r; Z_r]';
errorNLS = realPos - estPos;
errorNorm = zeros(1, N_pos);
for i = 1:N_pos
    errorNorm(i) = norm(errorNLS(i,:));
end

% Direction error (angular)
angular_error = zeros(1, N_pos);
for i = 1:N_pos
    angular_error(i) = acosd(min(1, max(-1, dot(v_tr_est(i,:), v_tr(i,:)))));
end

%% 6. Results
rms_error = sqrt(mean(errorNorm.^2));
rms_angular = sqrt(mean(angular_error.^2));

fprintf('\n==== DEBUGGED NL K=%d RESULTS ====\n', N_or);
fprintf('3D RMSE: %.4f m (%.2f cm)\n', rms_error, rms_error*100);
fprintf('CDF 90%%: %.2f cm\n', prctile(errorNorm*100, 90));
fprintf('APE:     %.2f cm\n', mean(errorNorm)*100);
fprintf('Angular RMSE: %.3f deg\n', rms_angular);
fprintf('Angular CDF90: %.3f deg\n', prctile(angular_error, 90));
fprintf('Median time: %.4f s\n', median(time_NL));

%% 7. Plots
figure(1)
cdfplot(errorNorm.*100); hold on;
xlabel('Positioning Error [cm]'); ylabel('CDF'); xlim([0 15])
title(sprintf('NL Debug K=%d — 3D Position Error', N_or));
grid on;

figure(2)
cdfplot(angular_error); hold on;
xlabel('Angular Error [deg]'); ylabel('CDF'); xlim([0 5])
title(sprintf('NL Debug K=%d — Direction Error', N_or));
grid on;

% save(fullfile('results', sprintf('K%d_NL_debug.mat', N_or)), 'errorNorm', 'angular_error', 'time_NL')
