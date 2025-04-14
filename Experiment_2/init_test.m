% --------------------------------------------------------
% Ejemplo de cálculo de la orientación que maximiza Pr
% --------------------------------------------------------

clear; close all; clc;

% Parámetros:
H  = 3;               % Altura del transmisor (m)
h  = 1;               % Altura del receptor (m)
xo = 2;             % Posición X del receptor
yo = 0.0;             % Posición Y del receptor
m  = 2;               % Orden Lambertiano (ejemplo)

% Posiciones
T = [0; 0; H];        % Transmisor
R = [xo; yo; h];      % Receptor

% Vector desde T hasta R
r_vec = R - T;
d = norm(r_vec);      % Distancia entre T y R

% Orientación óptima (unitaria en la dirección T->R)
n_opt = r_vec / d;

% Visualizamos la orientación óptima
disp('Orientación óptima del transmisor (vector unitario):');
disp(n_opt.');

% --------------------------------------------------------
% Cálculo de la potencia recibida en función del ángulo
% --------------------------------------------------------
% Para ilustrar, barremos uno de los ángulos (azimuth) de la orientación
% y calculamos la potencia recibida, asumiendo un segundo ángulo (tilt).
% Después compararemos con la orientación óptima.

numPoints = 100;
azimuths = linspace(0, pi/2, numPoints);  % Angulo azimutal
tilt = 0;                              % Fijamos un tilt de ejemplo

Pr = zeros(1, numPoints);

% Función auxiliar para construir la orientación n_t
% a partir de azimut (phiA) y tilt (phiT).
orientTrans = @(phiA, phiT) [ ...
    sin(phiT)*cos(phiA); ...
    sin(phiT)*sin(phiA); ...
    -cos(phiT)           ...
];

for i=1:numPoints
    % Orientación para cada azimuth
    n_t = orientTrans(tilt, azimuths(i));
    
    % Ángulo entre n_t y r_vec (lo necesitamos para cos^m(phi))
    cosphi = dot(n_t, r_vec/d); % n_t es unitario, r_vec/d también
    if cosphi < 0
        % Si el ángulo es mayor de 90 grados, la cos es negativa
        % y, en un modelo Lambertiano ideal, aportaría 0 (LED no emite "hacia atrás")
        cosphi = 0;
    end
    
    % Potencia (ignorando constantes y asumiendo cos(psi)=1 para el receptor)
    Pr(i) = (cosphi^m) / (d^2);  
end

% Potencia con la orientación óptima
cosphi_opt = dot(n_opt, r_vec/d);
Pr_opt = (cosphi_opt^m) / (d^2)

% --------------------------------------------------------
% Graficar
% --------------------------------------------------------
figure;
plot(azimuths, Pr, 'LineWidth', 2); hold on;
plot([0, pi/2], [Pr_opt, Pr_opt], '--', 'LineWidth', 2);
xlabel('Azimuth (rad)');
ylabel('Potencia recibida (unidades arbitrarias)');
title('Variación de potencia recibida vs. azimut (tilt fijo)');
legend('Pr(\phi)','Pr óptima','Location','best');
grid on;
