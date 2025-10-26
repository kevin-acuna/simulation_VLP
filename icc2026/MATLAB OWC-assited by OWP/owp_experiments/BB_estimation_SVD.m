clc, clear all, close all

% Conclusion:
% Se logra estimar con 4cm de error SI SOLO SI
% se ajusta las orientaciones para el area
% se elije el m_t apropiado entre 1.4 y 2
% se hace ajustes sobre la orientacion del transmisor 
%    ya que existen angulos que afectan bastante la estimación.
colorsMATLAB = [0.0000 0.4470 0.7410 ;... 
                0.8500 0.3250 0.0980 ;...
                0.9290 0.6940 0.1250 ;...
                0.4940 0.1840 0.5560 ;...
                0.4660 0.6740 0.1880 ;...
                0.3010 0.7450 0.9330 ;...
                0.6350 0.0780 0.1840];

data = readtable('database.csv');
unique_positions = unique(data(:, {'x', 'y', 'z'}), 'rows');
n_positions = height(unique_positions);
h = 2 - 0.75; % diferencia de alturas entre T y R.
T = [0.4,0.4,0]';
T_c = [0,0,0]';
fprintf('Total de posiciones únicas: %d\n\n', n_positions);

% Area de trabajo
Q = [0 1 0 1];


% ===============================================
% IMPORTANTE: CALIBRACIÓN DE LAS ORIENTACIONES
% ===============================================

% % Cartesian coordinates of the orientations vectors
% n_t(1,:)=[0,0,-1];
% n_t(2,:)=[-sind(20),0,-cosd(20)]; 
% % Calibrar este angulo, verificar!, en 15 el error es pequeño
% % esto puede deberse a una inclinación o algun desfase, etc.
% n_t(3,:)=[0,-sind(20),-cosd(20)];

% Orientaciones en formato [incl,azimuth,..]
% set = [38  207   60  181   60  233]; % real
% set = [33  207   60  181   60  233]; % ajustado para mejor resultado

set = [0 0 15 180 20 270];
Ndir = length(set)/2;
for i_dir = 1:Ndir
    incl = set(i_dir*2-1);
    azim = set(i_dir*2);
    n_t(i_dir,:)=[sind(incl)*cosd(azim), sind(incl)*sind(azim), -cosd(incl)];
end

%%
a_i = n_t(1,1); b_i = n_t(1,2); c_i = n_t(1,3);
a_j = n_t(2,1); b_j = n_t(2,2); c_j = n_t(2,3);
a_k = n_t(3,1); b_k = n_t(3,2); c_k = n_t(3,3);

% m_t = 1.43; %mejor con un background de V_bg = 0; nt_2=20
m_t = 1.52; %mejor con un background de V_bg = 0.04; nt_2=18
V_bg = 0.04;
results = [];

% for m_t = 1:0.01:4  % puedo añadir la busqueda para el menor RMSE
for m_t = 1.7

    pos_true = zeros(n_positions,3);
    pos_est_owp = zeros(n_positions,3);
    
    % Evaluacion por cada posicion
    for p = 1:n_positions
        pos_x = unique_positions.x(p);
        pos_y = unique_positions.y(p);
        pos_z = unique_positions.z(p);
        
        if inrangeQ( Q, pos_x, pos_y)
            pos_true(p,:) = [pos_x, pos_y, -h ];
            % Filtrar datos para esta posición
            pos_data = data(data.x == pos_x & data.y == pos_y & data.z == pos_z, :);    
            % Ordenar por orientación (asumiendo K1, K2, K3 en orden de inclinación y azimuth)
            pos_data = sortrows(pos_data, {'inclinacion', 'azimuth'});
            
            % Extraer voltajes (mean) de la tabla
            V_k1 = pos_data.mean(1) + V_bg;
            V_k2 = pos_data.mean(2) + V_bg;
            V_k3 = pos_data.mean(3) + V_bg;
            
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
    % fprintf('RMSE: %.2f cm\n', rmse);
    % fprintf('APE: %.2f cm\n', mean(errors));
    % fprintf('MAX: %.2f cm\n', max(errors));
    % fprintf('MIN: %.2f cm\n', min(errors));
    fprintf('RMSE: %.2f cm, m_t: %.2f \n', rmse, m_t);
    
    results = [results; m_t rmse];
end

best = results(find(results(:,2)==min(results(:,2))),:)
m_t = best(1)

%%
disp("================================================")
fprintf('m_t: %.2f \n', m_t);
fprintf('RMSE: %.2f cm\n', rmse);
fprintf('APE: %.2f cm\n', mean(errors));
fprintf('MAX: %.2f cm\n', max(errors));
fprintf('MIN: %.2f cm\n', min(errors));

bed = [-0.75,0.75,-0.75,0.75];
step= 0.25;
[TbX,TbY] = meshgrid(bed(1):step:bed(2), bed(3):step:bed(2) );


figure(1)
hold on
% Graficar posiciones
plot3(pos_true(:,1),pos_true(:,2),pos_true(:,3),'ko','DisplayName','true','MarkerFaceColor',colorsMATLAB(1,:))
plot3(pos_est_owp(:,1),pos_est_owp(:,2),pos_est_owp(:,3),'o','DisplayName','est')
% Graficar posiciones del transmisor
plot3(T(1),T(2),T(3),'ko','DisplayName','Transmisor T','MarkerFaceColor',colorsMATLAB(4,:))
plot3(T_c(1),T_c(2),T_c(3),'o','DisplayName','Centro T_c')

% Añadir líneas punteadas entre posición real y estimada
for i = 1:n_positions
    plot3([pos_true(i,1), pos_est_owp(i,1)], ...
          [pos_true(i,2), pos_est_owp(i,2)], ...
          [pos_true(i,3), pos_est_owp(i,3)], ...
          'k--');
end
plot(TbX,TbY,'o','Color',[0.2 0.2 0.2 0.5],'LineWidth',0.5)

r_phi_c=h*tand(40);
%circulo de referencia

viscircles(T(1:2)', r_phi_c, 'Color', [0.2 0.2 0.2 0.5],'LineWidth',0.2);

text( T(1)+r_phi_c , T(2), 'phi=40', ...
     'HorizontalAlignment', 'center', ...
     'VerticalAlignment', 'middle', ...
     'FontSize', 10, ...
     'Color', [0.2 0.2 0.2 0.5]);

axis([-2 2 -2 2 -2 0])
xlabel('X [m]')
ylabel('Y [m]')
zlabel('Z [m]')
legend('ground truth','estimation','AP OWP')
grid minor

%%
% figure(1);
% set(gcf, 'Color', 'white');
% print(fullfile('figures', 'estimation.png'), '-dpng', '-r300');
