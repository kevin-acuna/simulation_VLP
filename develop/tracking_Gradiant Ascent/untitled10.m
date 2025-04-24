% gradient_tracking_spsa.m
% METODO SPSA
% INICIANDO EN EL PUNTO (0,0)

clear; clc; close all;

%% Parámetros
H = 2; h = 1; m = 1.5; dt = 0.02; Tsim = 40;
alpha = 4;    % learning‐rate
c     = 0.01;    % tamaño de perturbación
sigma = 0; %0.005;   % ruido en P

% Trayectoria cuadrada en XY
vertices = [0.5,0.5; -0.5,0.5; -0.5,-0.5; 0.5,-0.5; 0.5,0.5];
numSteps = round(Tsim/dt);
path = interp1(linspace(0,1,5), vertices, linspace(0,1,numSteps), 'linear');
path = [path, repmat(h, numSteps,1)]';

% Posición y ángulos iniciales
R     = path(:,1);
Tpos  = [0;0;H];
d0    = R(:,1)-Tpos;

% theta = acos(-d0(3)/norm(d0))
% phi   = atan2(d0(2), d0(1))
theta = 0;
phi = 0;

% Simulación y gráfica
figure; axis equal; xlim([-1,1]); ylim([-1,1]); zlim([0,H+0.5]);
grid minor; hold on;
hRX  = plot3(R(1,1),R(2,1),R(3,1),'ro','LineWidth',2);
hTX  = quiver3(0,0,H,0,0,0,0,'b','LineWidth',2);
hTGT = plot3(0,0,h,'*k','MarkerSize',10);

readP = @(R,u) ( (R-Tpos)'*u )^m / norm(R-Tpos)^(m+3) + sigma*randn();

%% Bucle SPSA
for k = 1:numSteps
  R = path(:,k);
  % 1) Perturbación aleatoria
  Delta = 2*(rand(2,1)>0.5)-1;  % ±1
  th_p = theta + c*Delta(1);
  ph_p = phi   + c*Delta(2);
  u_p  = [sin(th_p)*cos(ph_p); sin(th_p)*sin(ph_p); -cos(th_p)];
  P_p  = readP(R, u_p);
  u_m  = [sin(theta-c*Delta(1))*cos(phi-c*Delta(2));
          sin(theta-c*Delta(1))*sin(phi-c*Delta(2));
          -cos(theta-c*Delta(1))];
  P_m  = readP(R, u_m);

  % 2) Estima gradiente SPSA
  g_est = [(P_p-P_m)/(2*c*Delta(1));
           (P_p-P_m)/(2*c*Delta(2))];

  % 3) Actualiza ángulos
  theta = theta + alpha * g_est(1) * dt;
  phi   = phi   + alpha * g_est(2) * dt;
  theta = min(max(theta,0),pi/2);
  phi   = mod(phi,2*pi);

  % 4) Graficar
  u    = [sin(theta)*cos(phi); sin(theta)*sin(phi); -cos(theta)];
  t_i  = (h-H)/u(3);
  P_tg = Tpos + t_i*u;
  set(hRX, 'XData',R(1),'YData',R(2),'ZData',R(3));
  set(hTX, 'UData',u(1),'VData',u(2),'WData',u(3));
  set(hTGT,'XData',P_tg(1),'YData',P_tg(2),'ZData',P_tg(3));
  view(0,90);  
  drawnow; pause(dt);
  
end
