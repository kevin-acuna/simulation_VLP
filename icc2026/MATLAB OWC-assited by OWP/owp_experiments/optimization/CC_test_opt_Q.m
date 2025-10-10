clc, clear all, close all
rng(10)
colorsMATLAB = [0.0000 0.4470 0.7410 ;... 
                0.8500 0.3250 0.0980 ;...
                0.9290 0.6940 0.1250 ;...
                0.4940 0.1840 0.5560 ;...
                0.4660 0.6740 0.1880 ;...
                0.3010 0.7450 0.9330 ;...
                0.6350 0.0780 0.1840];

% Intrasture
T = [0.4,0.4,0];
h = 2 - 0.75;
FOV = 60;

opt = load('set_opt_per_Q.mat');
Q = opt.Q;
set = opt.orientations;
gridstep = 0.25;

NQ = size(Q,1);
Ndir = size(set,2)/2;

pos_true_general = [];
pos_est_general = [];

for i_Q = 1:NQ

    
    for i_dir = 1:Ndir
        incl = set(i_Q, i_dir*2-1);
        azim = set(i_Q, i_dir*2);
        n_t(i_dir,:)=[sind(incl)*cosd(azim), sind(incl)*sind(azim), -cosd(incl)];
    end

    n_r = [0,0,1];

    % create points to evaluate
    x = Q(i_Q,1):gridstep:Q(i_Q,2);
    y = Q(i_Q,3):gridstep:Q(i_Q,4);
    [px,py] = meshgrid(x,y);
    px = px(:); py=py(:);
    pos = [px,py];
    Npos = size(pos,1);
    
    % Parameters
    Pt = 0.405;
    Rp = 0.6;
    m = 1.52;
    p = 4.8e-3; q = 5.5e-3; 
    N_det = 1; 
    A_det = p*q*N_det;
    G_elec = 1e6;
    sigma2 = 30e6*10^(-21.0);
    
    % Model
    S=cell(Npos,Ndir);
    for i_pos = 1:Npos
        for i_dir = 1:Ndir
            
            R = [pos(i_pos,:),-h];
            v_tr = (R-T)./norm(R-T);
            d = norm(R-T);
    
            cos_phi = dot(n_t(i_dir,:),v_tr);
            phi = acosd(cos_phi);
            
            cos_psi = dot(n_r,-v_tr);
            psi = acosd(cos_psi);
    
            C = (m+1)*A_det/(2*pi); % constant
            %g_phi = cos_phi^m; % modelo de irradianza del LED
            g_phi = irradiance(phi,'poly');
            
            if psi <= FOV
                h_LOS = C*g_phi*cos_psi./d^2;
            else
                h_LOS = 0;
            end
            w = sqrt(sigma2).*randn(1,1000);
            S{i_pos,i_dir} = G_elec*(Rp*Pt*h_LOS + w);
        end
    end

    pos_est = zeros(Npos,3);
    for i_pos = 1:Npos
        
        V_n1 = mean(S{i_pos,1});  V_n1 = min(max(V_n1, 0.00000001), 100);
        V_n2 = mean(S{i_pos,2});  V_n2 = min(max(V_n2, 0.00000001), 100);
        V_n3 = mean(S{i_pos,3});  V_n3 = min(max(V_n3, 0.00000001), 100);
    
        n_d = estimate_direction([V_n1,V_n2,V_n3], n_t, m, 'svd');
        escale = -h/n_d(3);
        pos_est(i_pos,:) = T + escale*n_d;
    
    end

    
    pos_true_general = [pos_true_general;pos];
    pos_est_general = [ pos_est_general; pos_est ];

    figure(1)
    hold on
    plot3(pos(:,1),pos(:,2),-h*ones(Npos,1),'ko','DisplayName','true','MarkerFaceColor',colorsMATLAB(1,:))
    plot3(pos_est(:,1),pos_est(:,2),pos_est(:,3),'o','DisplayName','est')
    plot3(T(1),T(2),T(3),'ko','DisplayName','Transmisor T','MarkerFaceColor',colorsMATLAB(4,:))
    
    % Añadir líneas punteadas entre posición real y estimada
    for i = 1:Npos
        plot3([pos(i,1), pos_est(i,1)], ...
              [pos(i,2), pos_est(i,2)], ...
              [-h, pos_est(i,3)], ...
              'k--');
    end
    axis([-2 2 -2 2 -2 0])
    

    rectangle('Position', [Q(i_Q,1), Q(i_Q,3), Q(i_Q,2)-Q(i_Q,1), Q(i_Q,4)-Q(i_Q,3)], 'EdgeColor', [0.2 0.2 0.2 0.5], 'LineWidth', 0.2);


end

r_phi_c=h*tand(60);
viscircles(T(1:2), r_phi_c, 'Color', [0.2 0.2 0.2 0.5],'LineWidth',0.2);

xlabel('X [m]')
ylabel('Y [m]')
zlabel('Z [m]')
legend('ground truth','estimation','AP OWP')
grid minor


index =find(pos_true_general(:,1)==-1.5 & pos_true_general(:,2)==-0.75);
pos_true_general(index,:)=[];
pos_est_general(index,:)=[];

errors = sqrt(sum((pos_true_general - pos_est_general(:,1:2)).^2, 2))*100;
rmse = sqrt(mean(errors.^2));
fprintf('RMSE: %.2f cm\n', rmse);
fprintf('APE: %.2f cm\n', mean(errors));
fprintf('MAX: %.2f cm\n', max(errors));
fprintf('MIN: %.2f cm\n', min(errors));





