% test_C_known_corrected.m
% FUNCIONA

clear; clc; close all;

%% 1. Parámetros
H   = 2.0;       % Altura Tx
h   = 0.8;       % Altura Rx
C   = 0.5;       % Constante C = P_t*(m+1)*A_det/(2*pi)
m   = 1.5;       % Orden Lambertiano
K   = C*(H - h); % Constante combinada

%% 2. Orientaciones Tx
n1 = [ 0;  0; -1 ];               % Vertical
% Segunda orientación: inclinada 20° elevación, phi=45° acimut
theta2 = 20; phi2 = 45;
n2 = [ sind(theta2)*cosd(phi2);
       sind(theta2)*sind(phi2);
      -cosd(theta2) ];

%% 3. Posición «real» del Rx
x_true = 0.8;
y_true = 0.1;
d_true = [x_true; y_true; h - H];
d_norm = norm(d_true);

%% 4. Cálculo de P1, P2 (lambertiano completo)
cosphi1 = (n1.' * d_true) / d_norm;
cosphi2 = (n2.' * d_true) / d_norm;
cospsi  = ([0 0 1] * (-d_true)) / d_norm;

P1 = C * cosphi1^m * cospsi / d_norm^2;
P2 = C * cosphi2^m * cospsi / d_norm^2;

%% 5. Razón r = (P1/P2)^(1/m)
r = (P1 / P2)^(1/m);

%% 6. Definimos el sistema en (x,y):
%   I)  (n1 - r·n2)'·[x;y;h-H] = 0
%  II)  P1*||d||^(m+3) = K*(n1'·d)^m
fun = @(xy) [
    (n1(1)-r*n2(1))*xy(1) + (n1(2)-r*n2(2))*xy(2) + (n1(3)-r*n2(3))*(h-H);
    P1*((xy(1))^2 + (xy(2))^2 + (h-H)^2)^((m+3)/2) ...
      - K*(n1(1)*xy(1) + n1(2)*xy(2) + n1(3)*(h-H))^m
];

%% 7. Resolución con fsolve (inicializar cerca de la verdadera)
opts   = optimoptions('fsolve','Display','off','FunctionTolerance',1e-12);
xy0    = [x_true; y_true] + 0.1*[-1;1];  % punto inicial cercano
xy_est = fsolve(fun, xy0, opts);
x_est = xy_est(1);
y_est = xy_est(2);

%% 8. Resultados
fprintf('Posición real:     x = %+0.4f, y = %+0.4f\n', x_true, y_true);
fprintf('Posición estimada: x = %+0.4f, y = %+0.4f\n', x_est,   y_est);
fprintf('Error 2D:          %.2e m\n', norm([x_est; y_est] - [x_true; y_true]));
