%% Run GLS, WLS, and NL-MLE Estimators for VLP — Direction-Finding Only
% This script runs the linear (GLS, WLS) and non-linear (MLE) direction 
% estimators, computes the angular error of the estimated 3D unit vectors, 
% compares them against the theoretical DEB (Direction Error Bound).
%
% Author: Kevin Acuña

close all; clear variables; clc;

% Add core functions to path
addpath('../core');

% =================================================
% HYPERPARAMETERS 
% =================================================
rng(42);
N_or = 5;               % Number of orientations
save_files = 0;         % 1 = save .mat files to results/
receiver_mode = 'fixed';% 'fixed' or 'random'

%% 1. System Parameters (shared)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
system_params;          % Loads: P_t, theta_half, m_t, A_det, R_pd, FOV, n_r,
                        %        sigma2, C, L, W, Hmax, N_samples, step, stepH,
                        %        all_orientations, K_values, etc.
T = [0, 0, 2];          % LED position 

% Convert orientations to cartesian vectors
n_t = zeros(N_or, 3);
for i = 1:N_or
    % STRICTLY use the standard orientations to match your previous script perfectly
    theta_i = all_orientations{N_or-2}(2*i-1);
    rho_i = all_orientations{N_or-2}(2*i);
    n_t(i,1) = sind(theta_i) * cosd(rho_i);
    n_t(i,2) = sind(theta_i) * sind(rho_i);
    n_t(i,3) = -cosd(theta_i);
end

%% 2. Generate Receiver Positions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if strcmp(receiver_mode, 'fixed')
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
    X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
    N_pos = length(X_r);
    fprintf('Using %d fixed grid positions (testbed)\n', N_pos);
else
    N_pos = 1000;
    X_r = -L/2 + L.*rand(1,N_pos);
    Y_r = -W/2 + W.*rand(1,N_pos);
    Z_r = Hmax*rand(1,N_pos);
    fprintf('Using %d random positions\n', N_pos);
end

param_r = {A_det, n_r, FOV};

%% 3. Simulation Core — Received Powers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
P_r = cell(N_pos, N_or);
P_r_noisy = cell(N_pos, N_or);
P_r_noisy_mean = zeros(N_pos, N_or);
v_tr = zeros(N_pos, 3);
SNR_avg = [];

fprintf('Generating observed powers (Simulating Channel)...\n');
for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:N_or
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), ~] = OWC_LOS_channel(x, y, z, param_t, param_r);
        
        % Generate noise and store directly (exactly identical random seed usage)
        noisy_samples = P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,N_samples);
        P_r_noisy{i_pos,i_dir} = noisy_samples;
        P_r_noisy_mean(i_pos, i_dir) = mean(noisy_samples);
        
        SNR_avg = [SNR_avg, ((R_pd*P_r{i_pos,i_dir})^2/(sigma2*R_pd^2))];
    end
end
fprintf('Average SNR: %.2f dB\n', 10*log10(mean(SNR_avg)));

%% 4. Direction Estimation (Stage 1 Only)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
v_tr_est_WLS = zeros(N_pos, 3);
v_tr_est_GLS = zeros(N_pos, 3);
v_tr_est_NL  = zeros(N_pos, 3);

time_WLS = []; time_GLS = []; time_NL = [];

% Options for NL-MLE fmincon
options_nl = optimoptions('fmincon', 'Display', 'none', 'Algorithm', 'sqp'); 

fprintf('Running Direction Estimators (WLS, GLS, NL-MLE)...\n');
for i_pos = 1:N_pos
    if mod(i_pos, 100) == 0 || i_pos == 1 || i_pos == N_pos
        fprintf('  --> Processing position %d / %d...\n', i_pos, N_pos);
    end
    
    % Prepare Raw matrix for linear estimators (Explicit transpose)
    P_raw = zeros(N_samples, N_or);
    for i_dir = 1:N_or
        P_raw(:, i_dir) = P_r_noisy{i_pos, i_dir}';
    end

    % -----------------------------------------------------------------
    % 4.1. WLS Estimator
    % -----------------------------------------------------------------
    tic;
    [d_hat_robust, ~, ~] = vlp_wls(n_t', P_raw, m_t);
    time_WLS = [time_WLS; toc];
    v_est = d_hat_robust';
    v_tr_est_WLS(i_pos,:) = v_est / norm(v_est); 

    % -----------------------------------------------------------------
    % 4.2. GLS Estimator
    % -----------------------------------------------------------------
    tic;
    [d_hat_gls] = vlp_gls(n_t', P_raw, m_t, sigma2);
    time_GLS = [time_GLS; toc];
    v_est = d_hat_gls';
    v_tr_est_GLS(i_pos,:) = v_est / norm(v_est); 

    % -----------------------------------------------------------------
    % 4.3. NL-MLE Estimator
    % -----------------------------------------------------------------
    tic;
    p_means = P_r_noisy_mean(i_pos, :);
    max_p = max(p_means);
    if max_p <= 0; max_p = 1e-12; end 
    p_target = p_means / max_p; 
    
    [~, max_idx] = max(p_target);
    best_n_t = n_t(max_idx, :); 
    
    x0 = [best_n_t(1), best_n_t(2), best_n_t(3), 1.0]; 
    lb = [-1, -1, -1, 1e-3];
    ub = [ 1,  1,  0, 10];
    
    obj_fcn = @(vars) mle_cost_function(vars, p_target, n_t, m_t);
    nonlcon = @(vars) sphere_constraint(vars);
    
    [sol, ~, ~] = fmincon(obj_fcn, x0, [], [], [], [], lb, ub, nonlcon, options_nl);
    
    v_hat = sol(1:3);
    v_tr_est_NL(i_pos,:) = v_hat / norm(v_hat); 
    time_NL = [time_NL; toc];
end

%% 5. Error Calculation + DEB (In Degrees)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
errorAngWLS = zeros(N_pos, 1);
errorAngGLS = zeros(N_pos, 1);
errorAngNL  = zeros(N_pos, 1);
errorAngDEB = zeros(1, N_pos);

rad2deg_factor = 180 / pi;

fprintf('Calculating errors and DEB...\n');
for i = 1:N_pos
    R_real = [X_r(i); Y_r(i); Z_r(i)];
    
    % True direction vector
    v_true = (R_real - T') / norm(R_real - T');
    
    % Empirical Errors: Chordal distance converted to degrees
    errorAngWLS(i) = norm(v_true - v_tr_est_WLS(i,:)') * rad2deg_factor;
    errorAngGLS(i) = norm(v_true - v_tr_est_GLS(i,:)') * rad2deg_factor;
    errorAngNL(i)  = norm(v_true - v_tr_est_NL(i,:)')  * rad2deg_factor;
    
    % Theoretical DEB
    deb_val = DEB_complete(R_real, n_t', T', P_t, m_t, A_det, deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples);
    
    if isreal(deb_val) && isfinite(deb_val)
        errorAngDEB(i) = deb_val * rad2deg_factor;
    else
        errorAngDEB(i) = NaN;
    end
end

rmseWLS = sqrt(mean(errorAngWLS.^2));
rmseGLS = sqrt(mean(errorAngGLS.^2));
rmseNL  = sqrt(mean(errorAngNL.^2));
rmseDEB = sqrt(nanmean(errorAngDEB.^2));

%% 6. Display Results
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('\n==== DIRECTION-FINDING RESULTS K=%d ====\n', N_or);
fprintf('RMSE (deg)  — WLS: %.3f° | GLS: %.3f° | NL-MLE: %.3f° | DEB: %.3f°\n', rmseWLS, rmseGLS, rmseNL, rmseDEB);
fprintf('CDF90 (deg) — WLS: %.3f° | GLS: %.3f° | NL-MLE: %.3f° | DEB: %.3f°\n', prctile(errorAngWLS,90), prctile(errorAngGLS,90), prctile(errorAngNL,90), prctile(errorAngDEB(~isnan(errorAngDEB)),90));
fprintf('Mean (deg)  — WLS: %.3f° | GLS: %.3f° | NL-MLE: %.3f° | DEB: %.3f°\n', mean(errorAngWLS), mean(errorAngGLS), mean(errorAngNL), nanmean(errorAngDEB));
fprintf('\nCOMPUTATIONAL LATENCY (Median Time per Position):\n');
fprintf('  WLS   : %.4f ms\n', median(time_WLS)*1000);
fprintf('  GLS   : %.4f ms\n', median(time_GLS)*1000);
fprintf('  NL-MLE: %.4f ms\n', median(time_NL)*1000);

%% 7. Comparative CDF Plot
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure('Name', 'CDF of Direction-Finding Error', 'Position', [100, 100, 600, 500]);
hold on;

color_gls = [0, 0.4470, 0.7410];     
color_wls = [0.8500, 0.3250, 0.0980];  
color_nl  = [0.4940, 0.1840, 0.5560];  
color_deb = [0.4660, 0.6740, 0.1880];  

[f, x] = ecdf(errorAngGLS); 
stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_gls);

[f, x] = ecdf(errorAngWLS); 
stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_wls);

[f, x] = ecdf(errorAngNL); 
stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_nl);

[f, x] = ecdf(errorAngDEB(~isnan(errorAngDEB))); 
stairs(x, f, '-', 'LineWidth', 1.5, 'Color', color_deb);

yline(0.9, '--', 'LineWidth', 0.8, 'Color', [0.5 0.5 0.5]);

xlabel('Angular Error [degrees]', 'Interpreter', 'latex', 'FontSize', 12);
ylabel('Empirical CDF', 'Interpreter', 'latex', 'FontSize', 12);
legend(sprintf('GLS (K=%d)', N_or), ...
       sprintf('WLS (K=%d)', N_or), ...
       sprintf('NL-MLE (K=%d)', N_or), ...
       sprintf('Theoretical DEB (K=%d)', N_or), ...
       'Location', 'southeast', 'Interpreter', 'latex', 'FontSize', 11);
title(sprintf('CDF of Direction-Finding Error (K=%d)', N_or), 'Interpreter', 'latex', 'FontSize', 14);
grid minor

%% 8. Save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if save_files == 1
    results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
    if ~exist(results_dir, 'dir'), mkdir(results_dir); end
    save(fullfile(results_dir, sprintf('K%d_DEB_ang_fixed.mat', N_or)), 'errorAngDEB')
    save(fullfile(results_dir, sprintf('K%d_GLS_ang_fixed.mat', N_or)), 'errorAngGLS', 'time_GLS')
    save(fullfile(results_dir, sprintf('K%d_WLS_ang_fixed.mat', N_or)), 'errorAngWLS', 'time_WLS')
    save(fullfile(results_dir, sprintf('K%d_NL_ang_fixed.mat', N_or)), 'errorAngNL', 'time_NL')
    fprintf('Saved all results to %s\n', results_dir);
end

% =========================================================================
% LOCAL FUNCTIONS FOR NL-MLE OPTIMIZER
% =========================================================================
function F = mle_cost_function(vars, p_target, n_t, m_t)
    v = vars(1:3)'; 
    eta = vars(4);  
    F = 0;
    for i = 1:size(n_t, 1)
        Q_i = dot(n_t(i,:), v);
        Q_pos = max(0, Q_i); 
        F = F + (eta * Q_pos^m_t - p_target(i))^2;
    end
end

function [c, ceq] = sphere_constraint(vars)
    x = vars(1); y = vars(2); z = vars(3);
    c = []; 
    ceq = x^2 + y^2 + z^2 - 1; 
end