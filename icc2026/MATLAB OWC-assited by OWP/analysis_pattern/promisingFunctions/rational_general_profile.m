function y = rational_general_profile(theta_deg)
% RATIONAL_GENERAL_PROFILE  Racional generalizado con coeficientes ajustados.
%   y = rational_general_profile(theta_deg)
%   I(theta) = C + A / (1 + |(theta-mu)/sigma|^p)^nu
%
% Coeficientes (de tu ajuste):
A     = 93.106697;  % [%]
C     =  1.853383;  % [%]
mu    = -0.127749;  % [deg]
sigma = 79.830026;  % [deg]
p     =  4.472945;  % [-]
nu    = 10.000000;  % [-]

theta = theta_deg;
y = C + A ./ ( (1 + abs((theta - mu)./sigma) .^ p) .^ nu );
end
