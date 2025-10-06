function y = fermi_cap_profile(theta_deg)
% FERMI_CAP_PROFILE  Ventana "Fermi-cap" simétrica con coeficientes ajustados.
%   y = fermi_cap_profile(theta_deg)
%   I(theta) = C + A / (1 + exp((|theta-mu| - theta0)/s))
%
% Coeficientes (de tu ajuste):
A      = 95.501001;  % [%]
C      =  0.543664;  % [%]
mu     = -0.127503;  % [deg]
theta0 = 44.266863;  % [deg]  (semi-anchura de la meseta)
s      =  7.429640;  % [deg]  (suavidad de borde)

theta = theta_deg;
y = C + A ./ (1 + exp( (abs(theta - mu) - theta0) ./ s ));
end
