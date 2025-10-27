clear , close , clc

% Important
phi_max = 40; % maximo phi

% Parámetros
z = 0.75;      % altura del receptor
H = 2;        % altura transmisor
h = H - z;    % diferencia vertical

tilt = 20;                % inclinación [deg]
tilt_1 = 20;
azimuth_1 = 0;            % azimut [deg]
azimuth_2 = 120;            % azimut [deg]
azimuth_3 = 240;

n_r = [0,0,1]';           % normal receptor (mirando al techo)
n_t = [sind(tilt_1)*cosd(azimuth_1), sind(tilt_1)*sind(azimuth_1), -cosd(tilt_1);...
       sind(tilt)*cosd(azimuth_2), sind(tilt)*sind(azimuth_2), -cosd(tilt);...
       sind(tilt)*cosd(azimuth_3), sind(tilt)*sind(azimuth_3), -cosd(tilt)]'; % 3x2

T = [0,0,H]';             % posición del Tx

% Grilla 2D
dx = 0.01;
Rx = -2:dx:2;
Ry = -2:dx:2;
[XX,YY] = meshgrid(Rx,Ry);
NN = numel(XX);
R = [XX(:)'; YY(:)'; z*ones(1,NN)];  % puntos del receptor

d      = R - T;
d_norm = sqrt(sum(d.^2,1));
d_unit = d ./ d_norm;

cos_phi = n_t' * d_unit;        % 2xN (emisión para ambos modos)
phi     = acosd(cos_phi);        % 2xN

phi_c = (phi<=phi_max);
R_nt1 = R(:,phi_c(1,:)==1);
R_nt2 = R(:,phi_c(2,:)==1);
R_nt3 = R(:,phi_c(3,:)==1);
R_filter = R(:,sum(phi_c,1)==3);
length(R_filter)


% Rangos en X e Y
x_min = min(R_filter(1,:));  x_max = max(R_filter(1,:)); x_max-x_min
y_min = min(R_filter(2,:));  y_max = max(R_filter(2,:)); y_max-y_min
z0    = R_filter(3,1);       % misma Z que los puntos filtrados (todos iguales)

% ---------- (A) Rectángulo mínimo alineado a ejes ----------
Xr = [x_min, x_max, x_max, x_min, x_min];
Yr = [y_min, y_min, y_max, y_max, y_min];
Zr = z0 * ones(1,5);


% ---------- (B) AREA DESEADA ----------
x_min=-0.4; x_max=0.4;
y_min=x_min;
y_max=x_max;
Xrd = [x_min, x_max, x_max, x_min, x_min];
Yrd = [y_min, y_min, y_max, y_max, y_min];
Zrd = z0 * ones(1,5);



figure(1)
hold on
plot3(R_nt1(1,:),R_nt1(2,:),R_nt1(3,:),'o','LineWidth',0.5)
plot3(R_nt2(1,:),R_nt2(2,:),R_nt2(3,:),'o','LineWidth',0.5)
plot3(R_nt3(1,:),R_nt3(2,:),R_nt3(3,:),'o','LineWidth',0.5)
plot3(R_filter(1,:),R_filter(2,:),R_filter(3,:),'o','LineWidth',1)
plot3(0,0,0.75,'o','LineWidth',2,'Color','k')
plot3(Xr, Yr, Zr, '-','LineWidth',2,'Color','k')
plot3(Xrd, Yrd, Zrd, '-','LineWidth',2,'Color','r')
axis([-2 2 -2 2 0 2])
grid minor

% ref. como angulo angulo que forma el vector n_t_1 con en la esquina
phi_corner = acosd(h/sqrt(x_max^2 + y_max^2 + h^2))


%%
figure(1);
set(gcf, 'Color', 'white');
print(fullfile('figures', 'coverture.png'), '-dpng', '-r300');