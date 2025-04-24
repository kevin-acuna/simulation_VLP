% gradient_tracking_spsa_realistic.m
% SPSA con tiempos de reorientación y velocidades configurables
% Hiperparametros: Tsim, sigma, punto inicial
clear; clc; close all;

%% Parámetros físicos
H       = 2;        % Altura TX
h       = 1;        % Altura RX
P_t     = 0.405;    % Potencia transmitida (W)
p       = 4.8e-3;   % Dimensions del PD
q       = 5.5e-3;
A_det   = p*q;      % Área detector (m^2)
theta_h = 45;       % Semiancho
m_lam   = -log(2)/log(cosd(theta_h));  % Orden lambertiano
C       = (m_lam+1)*A_det*P_t/(2*pi);

n_r     = [0;0;1];  % Normal del receptor

% sigma   = 0.01e-6;    % Ruido en P_meas
sigma = 0;

Tpos = [0;0;H];
%% Velocidades (hiper-parámetros)
v_rx = 3.0;   % Recepción: índices de path avanzados por iteración
w_tx = 2.0;   % Transmisor: radianes por segundo

%% Parámetros de SPSA y simulación
dt       = 0.02;         % Paso temporal (s)
Tsim     = 320;           % Tiempo total (s)
numSteps = round(Tsim/dt);
alpha    = 1000000;            % SPSA learning rate
c        = 0.01;         % Perturbación SPSA

%% Trayectoria cuadrada del receptor
vertices = [0.5,0.5;
           -0.5,0.5;
           -0.5,-0.5;
            0.5,-0.5;
            0.5,0.5];
path2D   = interp1(linspace(0,1,5), vertices, linspace(0,1,numSteps), 'linear');
path     = [path2D, repmat(h, numSteps,1)]';  % 3×N

%% Estados iniciales
idx_rx = 1;                  % índice flotante en path
R      = path(:,round(idx_rx));
theta  = 0; phi = 0;         % orientación inicial apuntando a (0,0)
% theta = 0.6155; phi= 0.7854;

%% Histórico
R_hist   = nan(3,numSteps);
Est_hist = nan(3,numSteps);

%% Figuras
figure('Color','w');
axis equal; grid minor;
xlim([-1 1]); ylim([-1 1]); zlim([0 H+0.5]);
view(0,90); hold on;
hRX      = plot3(NaN,NaN,NaN,'ro','LineWidth',1.5);
hPath    = plot3(NaN,NaN,NaN,'r-','LineWidth',1);
hTX      = quiver3(0,0,H,0,0,0,0,'b','LineWidth',2,'MaxHeadSize',1);
hTGT     = plot3(NaN,NaN,NaN,'k*','MarkerSize',8);
hEstPath = plot3(NaN,NaN,NaN,'k--','LineWidth',1.5);
hTextP   = text(-0.9,1.05,'','FontSize',12,'Color','k');

%% Función de potencia completa + ruido
readP = @(R,u) ...
    ( C * abs(dot((R-Tpos)/norm(R-Tpos),u))^m_lam ...
        * abs(dot(n_r, -(R-Tpos)/norm(R-Tpos))) ...
        / norm(R-Tpos)^2 ) + sigma*randn;

for k = 1:numSteps
    %% 1) Avanza receptor
    idx_rx = idx_rx + v_rx;
    idx_rx = min(idx_rx, numSteps);
    R      = path(:,round(idx_rx));
    R_hist(:,k) = R;
    
    %% 2) SPSA: definir perturbaciones
    Delta = 2*(rand(2,1)>0.5)-1;
    th_p  = theta + c*Delta(1);
    ph_p  = phi   + c*Delta(2);
    u_p   = [sin(th_p)*cos(ph_p);
             sin(th_p)*sin(ph_p);
            -cos(th_p)];
    % tiempo de reorientar TX a u_p
    ang_p = norm([th_p-theta; ph_p-phi]);
    tau_p = ang_p / w_tx;
    % receptor sigue moviéndose durante tau_p
    idx_rx = min(idx_rx + v_rx*(tau_p/dt), numSteps);
    R_p    = path(:,round(idx_rx));
    P_p    = readP(R_p, u_p);

    th_m  = theta - c*Delta(1);
    ph_m  = phi   - c*Delta(2);
    u_m   = [sin(th_m)*cos(ph_m);
             sin(th_m)*sin(ph_m);
            -cos(th_m)];
    ang_m = norm([th_m-theta; ph_m-phi]);
    tau_m = ang_m / w_tx;
    idx_rx = min(idx_rx + v_rx*(tau_m/dt), numSteps);
    R_m    = path(:,round(idx_rx));
    P_m    = readP(R_m, u_m);

    %% 3) Estima gradiente SPSA
    g_est = [ (P_p-P_m)/(2*c*Delta(1));
              (P_p-P_m)/(2*c*Delta(2)) ];

    %% 4) Actualiza orientación nominal (instantáneo)
    theta = theta + alpha*g_est(1)*dt;
    phi   = phi   + alpha*g_est(2)*dt;
    theta = min(max(theta,0),pi/2);
    phi   = mod(phi,2*pi);

    %% 5) Calcula estimación y potencia actual
    u     = [sin(theta)*cos(phi);
             sin(theta)*sin(phi);
            -cos(theta)];
    t_i   = (h-H)/u(3);
    Est   = Tpos + t_i*u;
    Est_hist(:,k) = Est;
    P_now = readP(R, u);

    %% 6) Actualiza gráficas
    set(hRX,     'XData',R(1),'YData',R(2),'ZData',R(3));
    set(hPath,   'XData',R_hist(1,1:k), 'YData',R_hist(2,1:k),'ZData', R_hist(3,1:k));
    set(hTX,     'UData',u(1), 'VData',u(2), 'WData',u(3));
    set(hTGT,    'XData',Est(1), 'YData',Est(2),'ZData',Est(3));
    set(hEstPath,'XData',Est_hist(1,1:k),'YData',Est_hist(2,1:k),'ZData', Est_hist(3,1:k));
    set(hTextP,  'String', sprintf('P = %.3f uW', P_now*1000000));

    drawnow; pause(dt);
end
