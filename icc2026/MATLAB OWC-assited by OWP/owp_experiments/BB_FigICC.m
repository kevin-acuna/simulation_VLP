clc, clear all, close all
% =================================================================
% CONFIGURACION
% =================================================================
data = readtable('db_complete.csv'); %database
h    = 2 - 0.75; % diferencia de alturas entre T y R.
T    = [0.4,0.4,0]';
T_c  = [0,0,0]';
Q    = [0 0.8 0 0.8]; % Area de trabajo
% =================================================================

colorsMATLAB = [0.0000 0.4470 0.7410 ;... 
                0.8500 0.3250 0.0980 ;...
                0.9290 0.6940 0.1250 ;...
                0.4940 0.1840 0.5560 ;...
                0.4660 0.6740 0.1880 ;...
                0.3010 0.7450 0.9330 ;...
                0.6350 0.0780 0.1840];

% Obtener sample_id únicos (cada uno identifica un conjunto de mediciones)
unique_samples = unique(data.sample_id);
n_positions = length(unique_samples);

fprintf('Total de mediciones únicas (sample_id): %d\n\n', n_positions);
orientation_set = [20 0 20 120 20 240]; % for "database icc2026" 
Ndir = length(orientation_set)/2;
for i_dir = 1:Ndir
    incl = orientation_set(i_dir*2-1);
    azim = orientation_set(i_dir*2);
    n_t(i_dir,:)=[sind(incl)*cosd(azim), sind(incl)*sind(azim), -cosd(incl)];
end

%%
a_i = n_t(1,1); b_i = n_t(1,2); c_i = n_t(1,3);
a_j = n_t(2,1); b_j = n_t(2,2); c_j = n_t(2,3);
a_k = n_t(3,1); b_k = n_t(3,2); c_k = n_t(3,3);

m_t = 1.52; %mejor con un background de V_bg = 0.04; nt_2=18
V_bg = 0.0411;
results = [];

% for m_t = 1:0.01:4  % puedo añadir la busqueda para el menor RMSE
for m_t = 1.53

    pos_true = zeros(n_positions,3);
    pos_est_owp = zeros(n_positions,3);
    
    % Evaluacion por cada sample_id
    for p = 1:n_positions
        sample_id = unique_samples{p};
        
        % Filtrar datos para este sample_id
        pos_data = data(strcmp(data.sample_id, sample_id), :);
        
        % Obtener coordenadas de la primera fila (todas tienen la misma posición)
        pos_x = pos_data.x(1);
        pos_y = pos_data.y(1);
        pos_z = pos_data.z(1);
        
        % Ordenar por orientación (asumiendo K1, K2, K3 en orden de inclinación y azimuth)
        pos_data = sortrows(pos_data, {'inclinacion', 'azimuth'});
        
        if inrangeQ( Q, pos_x, pos_y)
            pos_true(p,:) = [pos_x, pos_y, -h ];
            
            V_k1 = pos_data.mean(1) + V_bg;
            V_k2 = pos_data.mean(2) + V_bg;
            V_k3 = pos_data.mean(3) + V_bg;

            % Para "database_icc2026"
            V_k1 = 1.0625*V_k1;
            V_k2 = 0.9815*V_k2;
            V_k3 = 0.9616*V_k3;
             
            % Calcular ratios
        %     b_k2_val = V_k2 / V_k1;
        %     b_k3_val = V_k3 / V_k1;
        
        %     % Mostrar información
        %     fprintf('Posición %d: (%.2f, %.2f, %.2f)\n', p, pos_x, pos_y, pos_z);
        %     fprintf('  V_K1 = %.4f V\n', V_k1);
        %     fprintf('  V_K2 = %.4f V\n', V_k2);
        %     fprintf('  V_K3 = %.4f V\n', V_k3);
        %     fprintf('  b_K2 = V_K2/V_K1 = %.4f\n', b_k2_val);
        %     fprintf('  b_K3 = V_K3/V_K1 = %.4f\n\n', b_k3_val);
        
            
            % Ratios
            K_ij = (V_k1/V_k2)^(1/m_t);
            K_jk = (V_k2/V_k3)^(1/m_t);
            K_ik = (V_k1/V_k3)^(1/m_t);
        
            % Bastian SVD
            alpha_ij = a_i - K_ij*a_j;
            alpha_jk = a_j - K_jk*a_k;
            alpha_ik = a_i - K_ik*a_k;
            beta_ij = b_i - K_ij*b_j;
            beta_jk = b_j - K_jk*b_k;
            beta_ik = b_i - K_ik*b_k;
            gamma_ij = c_i - K_ij*c_j;
            gamma_jk = c_j - K_jk*c_k;
            gamma_ik = c_i - K_ik*c_k;
        
            eigenVectorsSVD  = null( [alpha_ij, beta_ij, gamma_ij;
                                              alpha_jk, beta_jk, gamma_jk;
                                              alpha_ik, beta_ik, gamma_ik]);
        
        
            n_d = -eigenVectorsSVD;
            escale = -h/n_d(3);
            pos_est_owp(p,:) = (T + escale*n_d)';
        else
            pos_est_owp(p,:) = [NaN, NaN, NaN ];
        end
    end

    % Calcular errores
    errors = sqrt(sum((pos_true - pos_est_owp).^2, 2))*100;
    errors = errors(~isnan(errors));
    rmse = sqrt(mean(errors.^2));
    fprintf('RMSE: %.2f cm, m_t: %.2f \n', rmse, m_t);
    
    results = [results; m_t rmse];
end

best = results(find(results(:,2)==min(results(:,2))),:)
m_t = best(1)

%%
disp("================================================")

errors = sqrt(sum((pos_true - pos_est_owp).^2, 2))*100;
errors = errors(~isnan(errors));
RMSE = sqrt(mean(errors.^2));
APE = mean(errors);
CDF90 = prctile(errors, 90);
fprintf('m_t: %.2f \n', m_t);
fprintf('RMSE: %.2f cm\n', RMSE);
fprintf('APE: %.2f cm\n', APE);
fprintf('CDF90: %.2f cm\n', CDF90);
fprintf('MAX: %.2f cm\n', max(errors));
fprintf('MIN: %.2f cm\n', min(errors));

%%
close
    
figure(1)
box on, grid on, hold on

plot3(pos_est_owp(:,1),pos_est_owp(:,2),pos_est_owp(:,3),...
     'ko','MarkerFaceColor',colorsMATLAB(5,:),'MarkerSize',4)
plot3(pos_true(:,1),pos_true(:,2),pos_true(:,3),...
     'ko','MarkerFaceColor',colorsMATLAB(1,:),'MarkerSize',4)
plot3(T(1),T(2),T(3),...
     'kp','MarkerFaceColor',colorsMATLAB(2,:),'MarkerSize',8)

% Añadir líneas punteadas entre posición real y estimada
for i = 1:n_positions
    plot3([pos_true(i,1), pos_est_owp(i,1)], ...
          [pos_true(i,2), pos_est_owp(i,2)], ...
          [pos_true(i,3), pos_est_owp(i,3)], ...
          '-','LineWidth', 0.25,'Color',[0 0 0 0.25]);
end

axis([0 0.8 0 0.8 -2 0])
xlabel('X [m]'), xticks(0:0.1:0.8)
ylabel('Y [m]'), yticks(0:0.1:0.8)
zlabel('Z [m]')
legend('Estimated','Ground-truth','LED','Location','eastoutside','Box','off')


