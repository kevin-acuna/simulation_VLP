% gradient_tracking_spsa_visual.m
% MÉTODO SPSA con visualización de trayectorias y potencia completa
% Funciona apropiadamente

clear; clc; close all;

%% Parámetros físicos
H       = 2;        % altura Tx
h       = 1;        % altura Rx
m       = 1.5;      % orden lambertiano
P_t     = 0.405;    % potencia transmitida (W)
p       = 4.8e-3;   % dimensiones fotodiodo
q       = 5.5e-3;
A_det   = p*q;      % área detector (m^2)
theta_h = 45;       % semiancho
m_lam   = -log(2)/log(cosd(theta_h));  % Lambert order
C       = (m_lam+1)*A_det*P_t/(2*pi);

n_r     = [0;0;1];  % normal Rx (apunta hacia arriba)
sigma   = 0;    % ruido en la medición de potencia

%% Parámetros de SPSA y simulación
dt       = 0.02;    % paso temporal
Tsim     = 40;      % tiempo total
numSteps = round(Tsim/dt);
alpha    = 1000000;       % learning rate
c        = 0.01;    % perturbación SPSA

%% Trayectoria cuadrada del receptor
vertices = [0.5,0.5; -0.5,0.5; -0.5,-0.5; 0.5,-0.5; 0.5,0.5];
path2D   = interp1(linspace(0,1,5), vertices, linspace(0,1,numSteps), 'linear');
path     = [path2D, repmat(h, numSteps,1)]';  % 3×N

%% Inicialización de ángulos
R      = path(:,1);
Tpos   = [0;0;H];
theta  = 0;
phi    = 0;

%% Pre-alocar históricos
R_hist    = nan(3,numSteps);
Est_hist  = nan(3,numSteps);

%% Preparar figura
figure('Color','w');
axis equal;
xlim([-1 1]); ylim([-1 1]); zlim([0 H+0.5]);
grid minor; hold on;
view(0,90);
xlabel('X'); ylabel('Y'); zlabel('Z');
title('SPSA Tracking');

hRX       = plot3(NaN,NaN,NaN,'ro','MarkerSize',6,'LineWidth',1.5);
hPath     = plot3(NaN,NaN,NaN,'r-','LineWidth',1);
hTX       = quiver3(0,0,H,0,0,0,0,'b','LineWidth',2,'MaxHeadSize',1);
hTGT      = plot3(NaN,NaN,NaN,'k*','MarkerSize',8);
hEstPath  = plot3(NaN,NaN,NaN,'k--','LineWidth',1.5);

%% Función de lectura de potencia (modelo completo + ruido)
readP = @(R,u) ...
    (  C * abs(dot((R-Tpos)/norm(R-Tpos), u))^m_lam ...
       * abs(dot(n_r, - (R-Tpos)/norm(R-Tpos))) ...
       / norm(R-Tpos)^2 ) + sigma*randn;

% readP = @(R,u) ( (R-Tpos)'*u )^m / norm(R-Tpos)^(m+3) + sigma*randn();

%% Bucle SPSA
for k = 1:numSteps
    % Posición real del receptor
    R = path(:,k);
    R_hist(:,k) = R;
    
    % 1) Perturbaciones ±c
    Delta = 2*(rand(2,1)>0.5)-1;
    th_p  = theta + c*Delta(1);
    ph_p  = phi   + c*Delta(2);
    u_p   = [sin(th_p)*cos(ph_p); sin(th_p)*sin(ph_p); -cos(th_p)];
    P_p   = readP(R, u_p);
    
    th_m  = theta - c*Delta(1);
    ph_m  = phi   - c*Delta(2);
    u_m   = [sin(th_m)*cos(ph_m); sin(th_m)*sin(ph_m); -cos(th_m)];
    P_m   = readP(R, u_m);
    
    % 2) Estimación de gradiente SPSA
    g_est = [ (P_p-P_m)/(2*c*Delta(1));
              (P_p-P_m)/(2*c*Delta(2)) ];
    
    % 3) Actualización de ángulos
    theta = theta + alpha * g_est(1) * dt;
    phi   = phi   + alpha * g_est(2) * dt;
    theta = min(max(theta,0),pi/2);
    phi   = mod(phi,2*pi);
    
    % 4) Calcular orientación y punto objetivo
    u    = [sin(theta)*cos(phi); sin(theta)*sin(phi); -cos(theta)];
    t_i  = (h-H)/u(3);
    Est  = Tpos + t_i*u;
    Est_hist(:,k) = Est;
    
    % 5) Actualizar gráficas
    set(hRX,      'XData',R(1),           'YData',R(2),           'ZData',R(3));
    set(hPath,    'XData',R_hist(1,1:k),  'YData',R_hist(2,1:k),  'ZData',R_hist(3,1:k));
    set(hTX,      'UData',u(1),           'VData',u(2),           'WData',u(3));
    set(hTGT,     'XData',Est(1),         'YData',Est(2),         'ZData',Est(3));
    set(hEstPath, 'XData',Est_hist(1,1:k),'YData',Est_hist(2,1:k),'ZData',Est_hist(3,1:k));
    
    drawnow;
    pause(dt);
    
end

