function h_tw = t_f(param_t, i_t, param_w, i_w)
% t_f computes the gain between a given transmitter and a wall reflector.
%
% Input parameters:
%   - param_t: Parámetros de los transmisores.
%   - i_t: Índice del transmisor.
%   - param_w: Parámetros de la sala.
%   - i_w: Índice del reflector.
%
% Output:
%   - h_tw: Ganancia entre el transmisor y el reflector.

%% INITIALIZACIÓN DE PARÁMETROS
T   = param_t{1}(i_t,:);
n_t = param_t{2}(i_t,:);
m   = param_t{3}(i_t);
WR  = param_w{1}(i_w,:);
n_w = param_w{2};
dA  = param_w{3};
L = param_w{4}; W = param_w{5}; H = param_w{6};

%% CÁLCULO DE LA GANANCIA entre TX y REFLECTOR
d_tw = norm(WR - T);
v_tw = (WR - T) / d_tw;
cos_theta = dot(n_t, v_tw);
if (WR(2) == -W/2)
    A = dA(1);
    cos_psi = dot(n_w(1,:), -v_tw);
elseif (WR(1) == -L/2)
    A = dA(2);
    cos_psi = dot(n_w(2,:), -v_tw);
elseif (WR(2) == W/2)
    A = dA(3);
    cos_psi = dot(n_w(3,:), -v_tw);
elseif (WR(1) == L/2)
    A = dA(4);
    cos_psi = dot(n_w(4,:), -v_tw);
elseif (WR(3) == 0)
    A = dA(5);
    cos_psi = dot(n_w(5,:), -v_tw);
elseif (WR(3) == -H)
    A = dA(6);
    cos_psi = dot(n_w(6,:), -v_tw);
end

if (cos_theta > 0)
    h_tw = (m + 1) * A / (2 * pi * d_tw^2) * abs(cos_theta)^m * abs(cos_psi);
else
    h_tw = 0;
end

end
