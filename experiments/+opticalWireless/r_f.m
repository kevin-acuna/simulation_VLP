function h_wr = r_f(param_w, i_w, param_r, x, y, z)
% r_f computes the gain between a wall reflector and the receiver.
%
% Input parameters:
%   - param_w: Parámetros de la sala.
%   - i_w: Índice del reflector.
%   - param_r: Parámetros del receptor.
%   - x, y, z: Coordenadas del receptor.
%
% Output:
%   - h_wr: Ganancia entre el reflector y el receptor.

%% INITIALIZACIÓN DE PARÁMETROS
WR = param_w{1}(i_w,:);
n_w = param_w{2};
L = param_w{4}; W = param_w{5}; H = param_w{6};
A_det = param_r{1};
n_r = param_r{2};
FOV = param_r{3};
R = [x, y, z];

%% CÁLCULO DE LA GANANCIA entre REFLECTOR y RECEPTOR
d_wr = norm(R - WR);
v_wr = (R - WR) / d_wr;
if (WR(2) == -W/2)
    cos_theta = dot(n_w(1,:), v_wr);
elseif (WR(1) == -L/2)
    cos_theta = dot(n_w(2,:), v_wr);
elseif (WR(2) == W/2)
    cos_theta = dot(n_w(3,:), v_wr);
elseif (WR(1) == L/2)
    cos_theta = dot(n_w(4,:), v_wr);
elseif (WR(3) == 0)
    cos_theta = dot(n_w(5,:), v_wr);
elseif (WR(3) == -H)
    cos_theta = dot(n_w(6,:), v_wr);
end
cos_psi = dot(n_r, -v_wr);
if (abs(acosd(cos_psi)) <= FOV)
    h_wr = A_det / (pi * d_wr^2) * abs(cos_theta) * abs(cos_psi);
else
    h_wr = 0;
end

end
