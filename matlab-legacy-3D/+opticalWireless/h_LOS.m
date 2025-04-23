function [h_LOS, d_tr, cos_phi, cos_psi] = h_LOS(param_t, i_t, param_r, x, y, z)
% h_LOS computes the line-of-sight gain between a transmitter and a receiver.
%
% Input parameters:
%   - param_t: Parámetros constantes de los transmisores.
%   - i_t: Índice del transmisor.
%   - param_r: Parámetros constantes del receptor.
%   - x, y, z: Coordenadas del receptor.
%
% Output parameters:
%   - h_LOS: Ganancia LOS.
%   - d_tr: Distancia entre Tx y Rx.
%   - cos_phi: Ángulo de irradiancia.
%   - cos_psi: Ángulo de incidencia.

%% INITIALIZACIÓN DE PARÁMETROS
T = param_t{1}(i_t,:);
n_t = param_t{2}(i_t,:);
m = param_t{3}(i_t);
A_det = param_r{1};
n_r = param_r{2};
FOV = param_r{3};
R = [x, y, z];

%% CÁLCULO DEL CANAL LOS
d_tr = sqrt(dot(R-T, R-T));
v_tr = (R - T) / norm(R-T);
cos_phi = dot(n_t, v_tr);
cos_psi = dot(n_r, -v_tr);
if (abs(acosd(cos_psi)) <= FOV && cos_phi > 0)
    h_LOS = (m + 1) * A_det / (2 * pi * d_tr^2) * abs(cos_phi)^m * abs(cos_psi);
else
    h_LOS = 0;
end

end
