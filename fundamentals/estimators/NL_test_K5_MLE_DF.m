close all;
clear variables;
clc;

addpath('../core');

rng(42);

% =========================================================================
% CONFIGURACIÓN RÁPIDA
TEST_MODE = false; % Cambia a 'false' para la simulación completa (1792 ptos)
% =========================================================================

N_or = 5; 
receiver_mode = 'fixed';  

%% 1. System Parameters (shared)
system_params; 

T = [0 0 0]; H = 2;
orientations_K5 = orientations_NL_K5;
all_orientations{3} = orientations_K5;

n_t = zeros(N_or, 3);
for i = 1:N_or
    theta_i = all_orientations{N_or-2}(2*i-1);
    rho_i = all_orientations{N_or-2}(2*i);
    n_t(i,1) = sind(theta_i) * cosd(rho_i);
    n_t(i,2) = sind(theta_i) * sind(rho_i);
    n_t(i,3) = -cosd(theta_i);
end

%% 2. Receiver Positions
if strcmp(receiver_mode, 'fixed')
    if TEST_MODE
        [X, Y, Z] = meshgrid(-1.5:0.5:1.5, -1.5:0.5:1.5, -2:0.5:-0.8);
    else
        [X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, -H:stepH:-(H-Hmax));
    end
    X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
    N_pos = length(X_r);     
    fprintf('Usando %d posiciones fijas\n', N_pos);
else
    N_pos = 1000;
    X_r = -L/2 + L.*rand(1,N_pos);
    Y_r = -W/2 + W.*rand(1,N_pos);
    Z_r = -(0.8+Hmax*rand(1,N_pos)); 
end

param_r = {A_det, n_r, FOV}; 

%% 3. Simulations
P_r = cell(N_pos,N_or); 
P_r_noisy_mean = zeros(N_pos, N_or); 
v_tr = zeros(N_pos,3); 
v_tr_est = zeros(N_pos,3); 
d_tr = zeros(N_pos,1); 

fprintf('Generando potencias (Simulando Canal)...\n');
for i_pos = 1:N_pos
    x = X_r(i_pos); y = Y_r(i_pos); z = Z_r(i_pos);
    for i_dir = 1:size(n_t,1)
        param_t = {T, n_t(i_dir,:), P_t, m_t};
        [~, P_r{i_pos,i_dir}, v_tr(i_pos,:), d_tr(i_pos,1)] = OWC_LOS_channel(x, y, z, param_t, param_r);
        
        noisy_samples = P_r{i_pos,i_dir} + sqrt(sigma2).*randn(1,1000);
        P_r_noisy_mean(i_pos, i_dir) = mean(noisy_samples);
    end
end

% Opciones para el optimizador clásico (SQP es excelente para restricciones de igualdad como la esfera)
options = optimoptions('fmincon', 'Display', 'none', 'Algorithm', 'sqp'); 

fprintf('Iniciando optimización no lineal (MLE Direction-Finding)...\n');
for i_pos = 1:N_pos
    if mod(i_pos, 20) == 0 || i_pos == 1 || i_pos == N_pos
        fprintf('  --> Procesando posición %d / %d...\n', i_pos, N_pos);
    end

    x_real = X_r(i_pos); y_real = Y_r(i_pos); z_real = Z_r(i_pos);
    
    % Normalización de potencias
    p_means = P_r_noisy_mean(i_pos, :);
    max_p = max(p_means);
    if max_p <= 0; max_p = 1e-12; end 
    p_target = p_means / max_p; 

    % Inicialización: Vector del LED que dio más luz
    [~, max_idx] = max(p_target);
    best_n_t = n_t(max_idx, :); 
    
    % Variables de optimización: [x, y, z, eta]
    x0 = [best_n_t(1), best_n_t(2), best_n_t(3), 1.0]; 
    
    % Límites (Bounds): x,y en [-1,1]. z en [-1,0] (hacia abajo). eta > 0.
    lb = [-1, -1, -1, 1e-3];
    ub = [ 1,  1,  0, 10];
    
    % Llamada directa a fmincon
    obj_fcn = @(vars) mle_cost_function(vars, p_target, n_t, m_t);
    nonlcon = @(vars) sphere_constraint(vars);
    
    [sol, ~, ~] = fmincon(obj_fcn, x0, [], [], [], [], lb, ub, nonlcon, options);
    
    v_hat = sol(1:3);
    v_tr_est(i_pos,:) = v_hat / norm(v_hat); % Aseguramos norma 1 perfecta
    
    % Distance Recovery (Stage 2)
    param_t_axis = {T, v_tr_est(i_pos,:), P_t, m_t};
    param_r_axis = {A_det, -v_tr_est(i_pos,:), FOV}; 
    [~, P_r_axis(i_pos), ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis); 
    P_r_axis_noisy(i_pos,:) = P_r_axis(i_pos) + sqrt(sigma2).*randn(1,1000); 
    d_tr_est(i_pos) = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy(i_pos,:)))); 
    estPos(i_pos,:) = v_tr_est(i_pos,:).*d_tr_est(i_pos); 
end

fprintf('Simulación terminada.\n');

%% 4. Calculate Errors
realPos = [X_r ; Y_r ; Z_r]';
errorNLS = realPos - estPos;
errorNorm = zeros(length(errorNLS), 1);

for i = 1:length(errorNLS)
    errorNorm(i) = norm(errorNLS(i,:));
end
rms_error = sqrt(mean(errorNorm.^2))

%% 5. Plots
figure(1)
plot3(X_r , Y_r , Z_r, 'ok')
hold on
plot3(estPos(:,1),estPos(:,2),estPos(:,3),'ob')
title('Estimación de Posiciones en 3D')
grid on; view(3);

figure(2)
cdfplot(errorNorm.*1e2); hold on;
xlabel('RMS error [cm]'); ylabel('Empirical CDF'); xlim([0 10]);
title('CDF del Error 3D');
legend('Non-linear MLE estimator','Location','best');


% =========================================================================
% FUNCIONES LOCALES DEL OPTIMIZADOR
% =========================================================================

% Función de costo (MLE realístico)
function F = mle_cost_function(vars, p_target, n_t, m_t)
    v = vars(1:3)'; % Vector unitario estimado [x; y; z]
    eta = vars(4);  % Nuisance parameter
    
    F = 0;
    for i = 1:size(n_t, 1)
        Q_i = dot(n_t(i,:), v);
        
        % Física real: Si el Rx está detrás del plano del LED, la luz es 0.
        % Al usar max(0, Q_i), evitamos números complejos si m_t tiene decimales.
        Q_pos = max(0, Q_i); 
        
        F = F + (eta * Q_pos^m_t - p_target(i))^2;
    end
end

% Restricción de igualdad no lineal (Esfera Unitaria)
function [c, ceq] = sphere_constraint(vars)
    x = vars(1); y = vars(2); z = vars(3);
    c = []; % Sin desigualdades no lineales
    ceq = x^2 + y^2 + z^2 - 1; % Obligamos a que la suma de cuadrados sea 1
end