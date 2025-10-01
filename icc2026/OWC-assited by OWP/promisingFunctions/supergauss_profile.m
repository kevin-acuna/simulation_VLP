function y = supergauss_profile(theta_deg)
% SUPERGAUSS_PROFILE  Super-gaussiana con coeficientes ya ajustados.
%   y = supergauss_profile(theta_deg)
%   I(theta) = C + A * exp( - |(theta-mu)/sigma|^p )
%
% Coeficientes (de tu ajuste):
A     = 93.000197;   % [%]
C     =  2.156433;   % [%]
mu    = -0.127767;   % [deg]
sigma = 48.233202;   % [deg]
p     =  4.286240;   % [-]

theta = theta_deg;
y = C + A .* exp( -abs((theta - mu)./sigma) .^ p );
end
