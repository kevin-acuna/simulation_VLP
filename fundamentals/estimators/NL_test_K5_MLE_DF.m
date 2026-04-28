close all;
clear variables;
clc;

addpath('../core');

rng(42);

N_or = 5; % Number of orientations
receiver_mode = 'fixed';  % 'fixed' or 'random'

%% 1. System Parameters (shared)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
system_params;         % Loads: P_t, theta_half, m_t, A_det, R_pd, FOV, n_r,
                       %        sigma2, C, L, W, Hmax, N_samples, step, stepH,
                       %        all_orientations, orientations_NL_K5/K9, etc.

% NL-specific: LED at origin, receiver below
T = [0 0 0]; H = 2;
alpha = n_r(1); beta = n_r(2); gamma = n_r(3);

% Use NL-optimized orientations (override PEB orientations for K=5)
orientations_K5 = orientations_NL_K5;
all_orientations{3} = orientations_K5;

% Convert orientations to cartesian vectors
n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = all_orientations{N_or-2}(2*i-1);
    rho_i = all_orientations{N_or-2}(2*i);
    n_t(i,1) = sind(theta_i) * cosd(rho_i);
    n_t(i,2) = sind(theta_i) * sind(rho_i);
    n_t(i,3) = -cosd(theta_i);
end

% Cartesian coordinates of the orientations vectors
a_i = n_t(1,1); b_i = n_t(1,2); c_i = n_t(1,3);
a_j = n_t(2,1); b_j = n_t(2,2); c_j = n_t(2,3);
a_k = n_t(3,1); b_k = n_t(3,2); c_k = n_t(3,3);
a_l = n_t(4,1); b_l = n_t(4,2); c_l = n_t(4,3);
a_m = n_t(5,1); b_m = n_t(5,2); c_m = n_t(5,3);

%% 2. Receiver Positions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if strcmp(receiver_mode, 'fixed')
    % Opción 1: Posiciones fijas
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, -H:stepH:-(H-Hmax));
    X_r = X(:)';
    Y_r = Y(:)';
    Z_r = Z(:)';
    N_pos = length(X_r);     
    fprintf('Usando %d posiciones fijas en grid (testbed)\n', N_pos);
else
    % Opción 2: Posiciones aleatorias
    N_pos = 1000;
    fprintf('Usando %d posiciones aleatorias\n', N_pos);
    X_r = -L/2 + L.*rand(1,N_pos);
    Y_r = -W/2 + W.*rand(1,N_pos);
    Z_r = -(0.8+Hmax*rand(1,N_pos)); 
end

param_r = {A_det, n_r, FOV}; 


%% Define Range of study
d=[X_r;Y_r;Z_r];
d_norm =d./sqrt(sum(d.^2));
cos_phi=n_t*d_norm;
phis = acosd(cos_phi);
max(phis);
sum(max(phis)>FOV)
sum((N_or-sum(phis>FOV))>=4)


%% 2. Simulations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                         Simulation Core                         %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
P_r = cell(N_pos,N_or); 
P_r_noisy = cell(N_pos,N_or); 
v_tr = zeros(N_pos,3); 
v_tr_est = zeros(N_pos,3); 
d_tr = zeros(N_pos,1); 

%-----------------------------------------------------%
% Step 1: Computation of the observed received powers %
%-----------------------------------------------------%
for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:size(n_t,1)
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), d_tr(i_pos,1)] = OWC_LOS_channel(x, y, z, param_t, param_r);
        
        % Normalize by -C as in your original formulation
        P_r_noisy{i_pos,i_dir} = (P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000))./(-C);
    end
end

%----------------------------------------%
% Step 2: Estimation of the Rx positions %
%----------------------------------------%
time_NL = [];
% Disable optimization display for speed
options = optimoptions('fmincon', 'Display', 'none'); 

for i_pos = 1:N_pos
    x_real = X_r(i_pos); y_real = Y_r(i_pos); z_real = Z_r(i_pos);
    
    %--------------------------------------------------------------------------%
    % MLE Direction estimation (True 2-Stage NL Approach)                      %      
    %--------------------------------------------------------------------------%
    % 1. Definition of the parameters (Spherical coords to enforce unit norm)
    % theta_var: tilt from the -Z axis downwards [0, pi/2]
    % phi_var: azimuth [ -pi, pi ]
    % eta_var: nuisance parameter absorbing distance and constant terms
    theta_var = optimvar('theta', 'LowerBound', 0, 'UpperBound', pi/2);
    phi_var   = optimvar('phi', 'LowerBound', -pi, 'UpperBound', pi);
    eta_var   = optimvar('eta', 'LowerBound', 1e-12); 

    % 2. Cartesian mapping (guarantees x^2 + y^2 + z^2 == 1)
    x = sin(theta_var) * cos(phi_var);
    y = sin(theta_var) * sin(phi_var);
    z = -cos(theta_var); % Negative because receiver is below LED

    % 3. Definition of the polynomials Q_i (Irradiance angles)
    Q_i = a_i*x + b_i*y + c_i*z;
    Q_j = a_j*x + b_j*y + c_j*z;
    Q_k = a_k*x + b_k*y + c_k*z;
    Q_l = a_l*x + b_l*y + c_l*z;
    Q_m = a_m*x + b_m*y + c_m*z;

    % 4. Objective functions F_i (MLE: Sum of squared errors against all samples)
    % Notice how 'eta_var' replaces the need to explicitly compute C/d^2 and L
    F_i = sum( ( eta_var .* Q_i.^m_t - P_r_noisy{i_pos,1} ).^2 );
    F_j = sum( ( eta_var .* Q_j.^m_t - P_r_noisy{i_pos,2} ).^2 );
    F_k = sum( ( eta_var .* Q_k.^m_t - P_r_noisy{i_pos,3} ).^2 );
    F_l = sum( ( eta_var .* Q_l.^m_t - P_r_noisy{i_pos,4} ).^2 );
    F_m = sum( ( eta_var .* Q_m.^m_t - P_r_noisy{i_pos,5} ).^2 );

    F = F_i + F_j + F_k + F_l + F_m;

    prob = optimproblem('Objective',F);

    % 5. Constraints: Irradiance angle must be positive (inside emission beam)
    % We no longer need the L constraint because z = -cos(theta) inherently ensures L <= 0
    prob.Constraints.Q1 = Q_i >= 0;
    prob.Constraints.Q2 = Q_j >= 0;
    prob.Constraints.Q3 = Q_k >= 0;
    prob.Constraints.Q4 = Q_l >= 0;
    prob.Constraints.Q5 = Q_m >= 0;

    % 6. Initial guess
    % Rough guess for eta based on the mean of the received powers
    mean_P_r = max(0, mean([mean(P_r_noisy{i_pos,1}), mean(P_r_noisy{i_pos,2}), mean(P_r_noisy{i_pos,3})]));
    
    x0.theta = 0;   % Pointing straight down initially
    x0.phi   = 0;
    x0.eta   = max(mean_P_r, 1e-6); % Ensure starting eta is strictly positive

    % 7. Resolution
    tic;
    [sol, ~, exitflag] = solve(prob, x0, 'Options', options);
    
    % Reconstruct the estimated Cartesian vector
    v_hat = [sin(sol.theta)*cos(sol.phi), sin(sol.theta)*sin(sol.phi), -cos(sol.theta)];
    
    v_tr_est(i_pos,:) = v_hat; % No need to divide by norm(v_hat) as it's perfectly 1
    tiempo_ejecucion = toc;
    time_NL = [time_NL; tiempo_ejecucion];
    
    % 8. Estimation of the Rx coordinates from the estimated v_tr (DISTANCE RECOVERY)
    param_t_axis = {T, v_tr_est(i_pos,:), P_t, m_t};
    param_r_axis = {A_det, -v_tr_est(i_pos,:), FOV}; 
    [~, P_r_axis(i_pos), ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis); 
    P_r_axis_noisy(i_pos,:) = P_r_axis(i_pos) + sqrt(sigma2).*randn(1,1000); 
    d_tr_est(i_pos) = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy(i_pos,:)))); 
    estPos(i_pos,:) = v_tr_est(i_pos,:).*d_tr_est(i_pos); 

end

%% Calculate Errors
realPos = [X_r ; Y_r ; Z_r]';
errorNLS = realPos - estPos;

for i = 1:length(errorNLS)
    errorNorm(i) = norm(errorNLS(i,:));
end

rms_error = sqrt(mean(errorNorm.^2))

%% Plots
figure(1)
plot3(X_r , Y_r , Z_r, 'ok')
hold on
plot3(estPos(:,1),estPos(:,2),estPos(:,3),'ob')

figure(2)
cdfplot(errorNorm.*1e2); hold on;
xlabel('RMS error [cm]'); ylabel('Empirical cumulative distribution function'); xlim([0 10])
legend('Non-linear MLE estimator of X','Location','best');