% gradient_tracking_power_input.m
% Seguimiento con gradient-ascent usando lecturas de potencia reales (con ruido).
% Receptor sigue un patrón cuadrado que pasa por (0.5,0.5).

clear; clc; close all;

%% Parámetros de la simulación
H           = 2;       % Altura del TX
h           = 1;       % Altura fija del RX
m           = 1.5;     % Orden lambertiano
dt          = 0.02;    % Paso de tiempo (s)
Tsim        = 40;      % Tiempo total (s)
alpha       = 5;    % Learning-rate
delta_ang   = 0.01;    % Variación angular para diferencias finitas (rad)
sigma_noise = 0.005;   % Desviación estándar del ruido en P

% Constante combinada C*(H-h)
Cgeom = 1;             % Podemos normalizar en 1 para el seguimiento relativo
A     = H - h;

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
while idx <= numSteps
    path(idx,1:2) = vertices(end,:);
    idx = idx + 1;
end
path(:,3) = h;

%% Posición inicial y orientación
R     = path(1,:)';
T_pos = [0; 0; H];
d0    = R - T_pos;
theta = acos(-d0(3)/norm(d0));    % inclinación
phi   = atan2(d0(2), d0(1));      % azimuth

%% Preparar figura 3D
figure('Color','w');
axis equal;
xlim([-1 1]); ylim([-1 1]); zlim([0 H+0.5]);
grid on; view(3);
hold on;
xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
title('Seguimiento con lecturas de potencia');

hRX   = plot3(R(1),R(2),R(3),'ro','MarkerSize',8,'LineWidth',2);
hTX   = quiver3(0,0,H,0,0,0,0,'b','LineWidth',2,'MaxHeadSize',1);
hTGT  = plot3(0,0,h,'g*','MarkerSize',10);
hLine = plot3([0,0],[0,0],[H,h],'g--','LineWidth',1.5);

%% Función de lectura de potencia con ruido
function P = readPower(R, u, H, h, m, Cgeom, A, sigma)
    d = R - [0;0;H];
    D = norm(d);
    % modelo completo: P = Cgeom * A * (d·u)^m / D^(m+3)
    P_ideal = Cgeom * A * (d' * u)^m / (D^(m+3));
    P = P_ideal + sigma * randn();
end

%% Bucle de simulación
for step = 1:numSteps
    R = path(step,:)';                      % mover receptor

    % dirección actual
    u = [sin(theta)*cos(phi); sin(theta)*sin(phi); -cos(theta)];

    % 1) lecturas reales de potencia
    P0 = readPower(R, u, H, h, m, Cgeom, A, sigma_noise);
    % lectura en theta+delta_ang
    u_thp = [sin(theta+delta_ang)*cos(phi); sin(theta+delta_ang)*sin(phi); -cos(theta+delta_ang)];
    P_thp = readPower(R, u_thp, H, h, m, Cgeom, A, sigma_noise);
    u_thm = [sin(theta-delta_ang)*cos(phi); sin(theta-delta_ang)*sin(phi); -cos(theta-delta_ang)];
    P_thm = readPower(R, u_thm, H, h, m, Cgeom, A, sigma_noise);
    % lectura en phi+delta_ang
    u_php = [sin(theta)*cos(phi+delta_ang); sin(theta)*sin(phi+delta_ang); -cos(theta)];
    P_php = readPower(R, u_php, H, h, m, Cgeom, A, sigma_noise);
    u_phm = [sin(theta)*cos(phi-delta_ang); sin(theta)*sin(phi-delta_ang); -cos(theta)];
    P_phm = readPower(R, u_phm, H, h, m, Cgeom, A, sigma_noise);

    % 2) estimar gradiente por diferencias finitas
    gth = (P_thp - P_thm) / (2*delta_ang);
    gph = (P_php - P_phm) / (2*delta_ang);

    % 3) actualizar ángulos
    theta = theta + alpha * gth * dt;
    phi   = phi   + alpha * gph * dt;
    theta = min(max(theta, 0), pi/2);
    phi   = mod(phi, 2*pi);

    % 4) recalcular objetivo
    u     = [sin(theta)*cos(phi); sin(theta)*sin(phi); -cos(theta)];
    t_int = (h - H)/u(3);
    P_tgt = T_pos + t_int * u;

    % 5) actualizar gráfico
    set(hRX,   'XData', R(1),     'YData', R(2),    'ZData', R(3));
    set(hTX,   'UData', u(1),     'VData', u(2),    'WData', u(3));
    set(hTGT,  'XData', P_tgt(1), 'YData', P_tgt(2),'ZData', P_tgt(3));
    set(hLine, 'XData',[0,P_tgt(1)],'YData',[0,P_tgt(2)],'ZData',[H,P_tgt(3)]);
    
    drawnow;
    view(0,90)
    pause(dt);
end
