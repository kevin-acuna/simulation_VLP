clc, clear all, close all

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

grid = 0.25;

% Set of K-orientation (K=3)
% inclination, azimuth
% set = [20,180,0,0,20,270];
% set = [30,225,50,200,50,245]; % Cover another cuarter
% set = [29.0000  225.0000   59.0000  207.0000   59.0000  243.0000];
% set = [66.0000  225.0000   32.0000  200.0000   32.0000  250.0000];
% %Q=[-1,0,-1,0]

% Q = [-0.75 0.75 -0.75 0.75];
% set = [12.0000  225.0000   30.0000  210.0000   30.0000  240.0000]; %Q= testbed

Q = [-1.50 -0.75 -0.75 0.00];
set = [38.0000  207   60.0000  181   60.0000  233];
% set = [22.0000  206.9395   65.0000  180.9395   65.0000  232.9395];
Ndir = length(set)/2;

for i_dir = 1:Ndir
    incl = set(i_dir*2-1);
    azim = set(i_dir*2);
    n_t(i_dir,:)=[sind(incl)*cosd(azim), sind(incl)*sind(azim), -cosd(incl)];
end


% n_t(1,:)=[0,0,-1]
% n_t(2,:)=[-sind(incl),0,-cosd(incl)]
% n_t(3,:)=[0,-sind(incl),-cosd(incl)]


n_r = [0,0,1];
FOV = 60;

% create points to evaluate
x = Q(1):grid:Q(2);
y = Q(3):grid:Q(4);
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
Relec = 7e6;

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
        S{i_pos,i_dir} = Relec*(Rp*Pt*h_LOS + w);
    end
end


%%
pos_est = zeros(Npos,3);
for i_pos = 1:Npos
    
    V_n1 = mean(S{i_pos,1});
    V_n2 = mean(S{i_pos,2});
    V_n3 = mean(S{i_pos,3});

    n_d = estimate_direction([V_n1,V_n2,V_n3], n_t, m, 'svd');
    escale = -h/n_d(3);
    pos_est(i_pos,:) = T + escale*n_d;

end

errors = sqrt(sum((pos - pos_est(:,1:2)).^2, 2))*100;
rmse = sqrt(mean(errors.^2));

%%

figure(1)
hold on
% Graficar posiciones
plot3(pos(:,1),pos(:,2),-h*ones(Npos,1),'ko','DisplayName','true','MarkerFaceColor',colorsMATLAB(1,:))
plot3(pos_est(:,1),pos_est(:,2),pos_est(:,3),'o','DisplayName','est')
% Graficar posiciones del transmisor
plot3(T(1),T(2),T(3),'ko','DisplayName','Transmisor T','MarkerFaceColor',colorsMATLAB(4,:))

% Añadir líneas punteadas entre posición real y estimada
for i = 1:Npos
    plot3([pos(i,1), pos_est(i,1)], ...
          [pos(i,2), pos_est(i,2)], ...
          [-h, pos_est(i,3)], ...
          'k--');
end


r_psi = h*tand(38);
viscircles(T(1:2), r_psi, 'Color', [0.2 0.2 0.2 0.5],'LineWidth',0.2);


r_psi_FOV=h*tand(60);
viscircles(T(1:2), r_psi_FOV, 'Color', [0.2 0.2 0.2 0.5],'LineWidth',0.2);

%circulo de referencia

axis([-2 2 -2 2 -2 0])
xlabel('X [m]')
ylabel('Y [m]')
zlabel('Z [m]')
legend('ground truth','estimation','AP OWP')
grid minor

