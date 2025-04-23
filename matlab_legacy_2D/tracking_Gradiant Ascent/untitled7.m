% gradient_tracking_square_corrected.m
% Seguimiento con gradient-ascent e inclusión de atenuación 1/||d||^2.
% Receptor sigue un patrón cuadrado que pasa por (0.5,0.5).
% **************************************
% No usa de input la potencia
% **************************************
clear; clc; close all;

%% Parámetros de la simulación
H     = 2;       % Altura del TX
h     = 1;       % Altura fija del RX
m     = 1.5;     % Orden lambertiano
dt    = 0.02;    % Paso de tiempo (s) – más fino para mayor fidelidad
Tsim  = 40;      % Tiempo total (s)
alpha = 4;    % Learning‐rate reducido para evitar sobrepasos

%% Definir trayectoria cuadrada en el plano XY
vertices = [ 0.5,  0.5;
            -0.5,  0.5;
            -0.5, -0.5;
             0.5, -0.5;
             0.5,  0.5 ];
numSteps  = round(Tsim/dt);
numSeg    = size(vertices,1)-1;
ptsPerSeg = floor(numSteps/numSeg);
path      = zeros(numSteps,3);
idx = 1;
for i = 1:numSeg
    p1 = vertices(i,:);
    p2 = vertices(i+1,:);
    for k = 1:ptsPerSeg
        t = (k-1)/(ptsPerSeg-1);
        pt = (1-t)*p1 + t*p2;
        if idx <= numSteps
            path(idx,1:2) = pt;
            idx = idx + 1;
        end
    end
end
% Rellenar sobrantes con el último vértice
while idx <= numSteps
    path(idx,1:2) = vertices(end,:);
    idx = idx + 1;
end
path(:,3) = h;  % misma altura

%% Posición inicial y orientación
R     = path(1,:)';
T_pos = [0; 0; H];
d0    = R - T_pos;
theta = acos(-d0(3)/norm(d0));    % inclinación inicial
phi   = atan2(d0(2), d0(1));      % azimuth inicial

%% Preparar figura 3D
figure('Color','w');
axis equal;
xlim([-1 1]); ylim([-1 1]); zlim([0 H+0.5]);
grid on; view(3);
hold on;
xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
title('Seguimiento en patrón cuadrado (corrigido)');

% Dibujar receptor, vector TX, punto objetivo y línea de seguimiento
hRX = plot3(R(1),R(2),R(3),'ro','MarkerSize',8,'LineWidth',2);
u   = [sin(theta)*cos(phi); sin(theta)*sin(phi); -cos(theta)];
hTX = quiver3(0,0,H, u(1),u(2),u(3), 0, 'b','LineWidth',2,'MaxHeadSize',1);

% Cálculo inicial de punto 2D objetivo
t_int = (h - H)/u(3);
P_tgt = T_pos + t_int * u;
hTGT = plot3(P_tgt(1),P_tgt(2),P_tgt(3),'g*','MarkerSize',10);
hLine = plot3([0,P_tgt(1)], [0,P_tgt(2)], [H,P_tgt(3)], 'g--','LineWidth',1.5);

%% Bucle de simulación
for step = 1:numSteps
    % 1) Mover receptor
    R = path(step,:)';
    
    % 2) Vector de orientación actual
    u = [sin(theta)*cos(phi); sin(theta)*sin(phi); -cos(theta)];
    
    % 3) Gradiente de P(θ,ϕ) ∝ (d·u)^m / ||d||^2
    d_norm = norm(R - T_pos);
    d      = R - T_pos;
    inner  = d' * u;  % d·u
    
    % Derivadas parciales de u
    dudth = [ cos(theta)*cos(phi);
              cos(theta)*sin(phi);
              sin(theta) ];
    dudph = [-sin(theta)*sin(phi);
              sin(theta)*cos(phi);
              0];
    
    % Gradientes incluyendo atenuación 1/||d||^2 (constante en θ,ϕ)
    gth = m * inner^(m-1) * (d' * dudth) / (d_norm^2);
    gph = m * inner^(m-1) * (d' * dudph) / (d_norm^2);
    
    % 4) Actualizar ángulos
    theta = theta + alpha * gth * dt;
    phi   = phi   + alpha * gph * dt;
    theta = min(max(theta, 0), pi/2);
    phi   = mod(phi, 2*pi);
    
    % 5) Recalcular punto 2D objetivo
    u      = [sin(theta)*cos(phi); sin(theta)*sin(phi); -cos(theta)];
    t_int  = (h - H)/u(3);
    P_tgt  = T_pos + t_int * u;
    
    % 6) Actualizar gráficos
    set(hRX,  'XData', R(1),      'YData', R(2),      'ZData', R(3));
    set(hTX,  'UData', u(1),      'VData', u(2),      'WData', u(3));
    set(hTGT, 'XData', P_tgt(1),  'YData', P_tgt(2),  'ZData', P_tgt(3));
    set(hLine,'XData',[0,P_tgt(1)],'YData',[0,P_tgt(2)],'ZData',[H,P_tgt(3)]);
    
    drawnow;
    view(0,90)
    pause(dt);
end
