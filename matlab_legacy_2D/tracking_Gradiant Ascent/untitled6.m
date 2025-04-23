% gradient_tracking.m
clear; clc; close all;

%% Parámetros de la simulación
H = 2;            % Altura del TX
h = 1;            % Altura fija del RX
m = 1.5;          % Orden lambertiano
dt = 0.1;        % Paso de tiempo (s)
Tsim = 20;        % Tiempo total (s)
alpha = 0.1;      % Paso de gradient‐ascent

% Posición inicial del receptor (en el plano XY)
R = [0.5;  -0.5;  h];    
% Velocidad del receptor en XY (configurable)
v = [0.05; 0.05; 0];   % m/s, solo componentes x,y

% Transmisor en (0,0,H)
T_pos = [0;0;H];

% Orientación inicial: apuntando al receptor
d0 = R - T_pos;
theta = acos( -d0(3)/norm(d0) );     % inclination
phi   = atan2(d0(2), d0(1));         % azimuth

%% Preparar figura
figure('Color','w');
axis equal;
xlim([-2 2]); ylim([-2 2]); zlim([0 2.5]);
grid on; view(3);
hold on;
hRX = plot3(R(1),R(2),R(3),'ro','MarkerSize',8,'LineWidth',2);
hTX = quiver3(0,0,H,0,0,0,'b','LineWidth',2,'MaxHeadSize',1);

title('Seguimiento de haz por Gradient‐Ascent','FontSize',12);
xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');

%% Bucle de simulación
for t = 0:dt:Tsim
    % 1) Actualizar posición del receptor
    R = R + v*dt;
    
    % 2) Calcular vector unitario u(theta,phi)
    u = [ sin(theta)*cos(phi);
          sin(theta)*sin(phi);
         -cos(theta) ];
    
    % 3) Cálculo del gradiente de f = (d·u)^m
    d = R - T_pos;
    inner = d'*u;                % d·u
    % derivadas de u
    dudth = [cos(theta)*cos(phi);
             cos(theta)*sin(phi);
             sin(theta)];
    dudph = [-sin(theta)*sin(phi);
              sin(theta)*cos(phi);
              0];
    % gradiente
    gth = m * inner^(m-1) * (d' * dudth);
    gph = m * inner^(m-1) * (d' * dudph);
    
    % 4) Actualizar ángulos
    theta = theta + alpha * gth * dt;
    phi   = phi   + alpha * gph * dt;
    % limitar ángulos a rangos válidos
    theta = min(max(theta, 0), pi/2);
    phi = mod(phi, 2*pi);
    
    % 5) Actualizar gráficos
    set(hRX, 'XData', R(1), 'YData', R(2), 'ZData', R(3));
    % recalcular u y dibujar flecha
    u = [ sin(theta)*cos(phi);
          sin(theta)*sin(phi);
         -cos(theta) ];
    set(hTX, 'UData', u(1), 'VData', u(2), 'WData', u(3));
    view(0,90)
    drawnow;
end
