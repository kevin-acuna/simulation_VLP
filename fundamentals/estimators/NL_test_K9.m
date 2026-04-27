close all;
clear variables;
clc;

addpath('../core');

rng(42);

N_or = 9; % Number of orientations
receiver_mode = 'fixed';  % 'fixed' or 'random'

%% 1. System Parameters (shared)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
system_params;         % Loads: P_t, theta_half, m_t, A_det, R_pd, FOV, n_r,
                       %        sigma2, C, L, W, Hmax, N_samples, step, stepH,
                       %        all_orientations, orientations_NL_K5/K9, etc.

% NL-specific: LED at origin, receiver below
T = [0 0 0]; H = 2;
alpha = n_r(1); beta = n_r(2); gamma = n_r(3);

% Use NL-optimized orientations (override PEB orientations for K=9)
orientations_K9 = orientations_NL_K9;
all_orientations{7} = orientations_K9;

% Convert orientations to cartesian vectors
n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = all_orientations{N_or-2}(2*i-1);
    rho_i = all_orientations{N_or-2}(2*i);
    n_t(i,1) = sind(theta_i) * cosd(rho_i);
    n_t(i,2) = sind(theta_i) * sind(rho_i);
    n_t(i,3) = -cosd(theta_i);
end

% Cartesian coordinates of the orientations vectors for K=9
a_i = n_t(1,1); b_i = n_t(1,2); c_i = n_t(1,3);
a_j = n_t(2,1); b_j = n_t(2,2); c_j = n_t(2,3);
a_k = n_t(3,1); b_k = n_t(3,2); c_k = n_t(3,3);
a_l = n_t(4,1); b_l = n_t(4,2); c_l = n_t(4,3);
a_m = n_t(5,1); b_m = n_t(5,2); c_m = n_t(5,3);
a_n = n_t(6,1); b_n = n_t(6,2); c_n = n_t(6,3);
a_o = n_t(7,1); b_o = n_t(7,2); c_o = n_t(7,3);
a_p = n_t(8,1); b_p = n_t(8,2); c_p = n_t(8,3);
a_q = n_t(9,1); b_q = n_t(9,2); c_q = n_t(9,3);

%% 2. Receiver Positions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if strcmp(receiver_mode, 'fixed')
    % Opción 1: Posiciones fijas
    % Generate 3D grid of positions
    [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, -H:stepH:-(H-Hmax));
    % Convert to vector form
    X_r = X(:)';
    Y_r = Y(:)';
    Z_r = Z(:)';
    % Count the number of positions
    N_pos = length(X_r);     
    fprintf('Usando %d posiciones fijas en grid (testbed)\n', N_pos);
else
    % Opción 2: Posiciones aleatorias
    N_pos = 1000; % Number of random Rx positions simulated
    fprintf('Usando %d posiciones aleatorias\n', N_pos);
    X_r = -L/2 + L.*rand(1,N_pos); % x-axis Rx coordinate
    Y_r = -W/2 + W.*rand(1,N_pos); % y-axis Rx coordinate
    Z_r = -(0.8+Hmax*rand(1,N_pos)); % z_r [0.. 1.2] ; T=(0,0,2)
    % Z_r = -(1.8+Hmax*rand(1,N_pos)); % z_r [0.. 1.2] ; T=(0,0,3)
end

param_r = {A_det, n_r, FOV}; % Vector of the Rx parameters used for channel simulation


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
for i_pos = 1:N_pos
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
for i_pos = 1:N_pos
    x_real = X_r(i_pos); y_real = Y_r(i_pos); z_real = Z_r(i_pos); % Real position of the Rx
    %--------------------------------------------------------------------------%
    % Case 1: Direct position estimation with non-linear least square approach %      
    %--------------------------------------------------------------------------%
    % 1. Definition of the parameters to estimate
    x = optimvar('x'); y = optimvar('y'); z = optimvar('z');

    % 2. Definition of the polynomials Q_i and L for K=9
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

    % 3. Definition of the objective functions F_i(x,y,z) for K=9
    F_i = sum( ( C.*L.*Q_i.^m_t - P_r_noisy{i_pos,1} ).^2 );
    F_j = sum( ( C.*L.*Q_j.^m_t - P_r_noisy{i_pos,2} ).^2 );
    F_k = sum( ( C.*L.*Q_k.^m_t - P_r_noisy{i_pos,3} ).^2 );
    F_l = sum( ( C.*L.*Q_l.^m_t - P_r_noisy{i_pos,4} ).^2 );
    F_m = sum( ( C.*L.*Q_m.^m_t - P_r_noisy{i_pos,5} ).^2 );
    F_n = sum( ( C.*L.*Q_n.^m_t - P_r_noisy{i_pos,6} ).^2 );
    F_o = sum( ( C.*L.*Q_o.^m_t - P_r_noisy{i_pos,7} ).^2 );
    F_p = sum( ( C.*L.*Q_p.^m_t - P_r_noisy{i_pos,8} ).^2 );
    F_q = sum( ( C.*L.*Q_q.^m_t - P_r_noisy{i_pos,9} ).^2 );

    % 4. Definition of the final objective function F(x,y,z) for K=9
    F = F_i + F_j + F_k + F_l + F_m + F_n + F_o + F_p + F_q;


    % 5. Definition of the optimization problem to solve
    prob = optimproblem('Objective',F);

    % 6. Definition of the constraints for K=9
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

    % 7. Addition of the constraints to the optimization problem for K=9
    prob.Constraints.Q1 = Q1Constraint;
    prob.Constraints.Q2 = Q2Constraint;
    prob.Constraints.Q3 = Q3Constraint;
    prob.Constraints.Q4 = Q4Constraint;
    prob.Constraints.Q5 = Q5Constraint;
    prob.Constraints.Q6 = Q6Constraint;
    prob.Constraints.Q7 = Q7Constraint;
    prob.Constraints.Q8 = Q8Constraint;
    prob.Constraints.Q9 = Q9Constraint;
    prob.Constraints.L = LConstraint;
    % prob.Constraints.sphereConstraint = sphereConstraint; % Commented because otherwise prevents the optimization algorithm to converge

    % 8. Estimation of the unit vector from Tx to Rx
    x0.x = 0; x0.y = 0; x0.z = -1; % Initial guess 
    tic;
    [sol,fval] = solve(prob,x0); % Non-linear optimization problem resolution
    v_hat = [sol.x, sol.y, sol.z]; % Solution reached
    v_tr_est(i_pos,:) = v_hat./norm(v_hat); % Normalized solution, i.e. estimate of the unit vector from Tx to Rx
    tiempo_ejecucion = toc;
    time_NL = [time_NL; tiempo_ejecucion];
    
    % 9. Estimation of the Rx coordinates from the estimated v_tr
    param_t_axis = {T, v_tr_est(i_pos,:), P_t, m_t};
    param_r_axis = {A_det, -v_tr_est(i_pos,:), FOV}; % Vector of the Rx parameters used for channel simulation
    [~, P_r_axis(i_pos), ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis); % Computation of the real received power if Tx and Rx oriented toward v_tr_est and -v_tr_est respectively
    P_r_axis_noisy(i_pos,:) = P_r_axis(i_pos) + sqrt(sigma2).*randn(1,1000); % Corresponding noise power observed [W]
    d_tr_est(i_pos) = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy(i_pos,:)))); % Estimated absolute distance (case with noise) [m]
    estPos(i_pos,:) = v_tr_est(i_pos,:).*d_tr_est(i_pos); % Estimated coordinates of the Rx

end


%%
realPos = [X_r ; Y_r ; Z_r]';

errorNLS = realPos - estPos;

for i = 1:length(errorNLS)
    errorNorm(i) = norm(errorNLS(i,:));
end

rms_error = sqrt(mean(errorNorm.^2))

%% 
figure(1)
plot3(X_r , Y_r , Z_r, 'ok')
hold on
plot3(estPos(:,1),estPos(:,2),estPos(:,3),'ob')


%%
figure(2)
cdfplot(errorNorm.*1e2); hold on;
xlabel('RMS error [cm]'); ylabel('Empirical cumulative distribution function'); xlim([0 10])
legend('Non-linear estimator K=9','Location','best');

save 'K9_NL.mat' errorNorm time_NL
