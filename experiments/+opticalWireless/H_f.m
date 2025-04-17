function h_ww = H_f(param_w, i_w, j_w)
% H_f computes the gain between two wall reflectors.
%
% Input parameters:
%   - param_w: Parámetros constantes de la sala.
%   - i_w: Índice del reflector transmisor.
%   - j_w: Índice del reflector receptor.
%
% Output parameter:
%   - h_ww: Ganancia entre los reflectores.

%% INITIALIZACIÓN DE PARÁMETROS
W_T = param_w{1}(i_w,:);
W_R = param_w{1}(j_w,:);
n_w = param_w{2};
dA = param_w{3};
L = param_w{4}; W = param_w{5}; H = param_w{6};

%% CÁLCULO DE LA GANANCIA ENTRE REFLECTORES
d_ww = norm(W_R - W_T);
v_ww = (W_R - W_T) / d_ww;

if (W_T(2) == -W/2)
    cos_theta = dot(n_w(1,:), v_ww);
    if (W_R(2) == -W/2)
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif (W_R(1) == -L/2)
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif (W_R(2) == W/2)
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif (W_R(1) == L/2)
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif (W_R(3) == 0)
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif (W_R(3) == -H)
        A = dA(6);
        cos_psi = dot(n_w(6,:), -v_ww);
    end

elseif (W_T(1) == -L/2)
    cos_theta = dot(n_w(2,:), v_ww);
    if (W_R(2) == -W/2)
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif (W_R(1) == -L/2)
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif (W_R(2) == W/2)
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif (W_R(1) == L/2)
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif (W_R(3) == 0)
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif (W_R(3) == -H)
        A = dA(6);
        cos_psi = dot(n_w(6,:), -v_ww);
    end

elseif (W_T(2) == W/2)
    cos_theta = dot(n_w(3,:), v_ww);
    if (W_R(2) == -W/2)
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif (W_R(1) == -L/2)
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif (W_R(2) == W/2)
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif (W_R(1) == L/2)
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif (W_R(3) == 0)
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif (W_R(3) == -H)
        A = dA(6);
        cos_psi = dot(n_w(6,:), -v_ww);
    end

elseif (W_T(1) == L/2)
    cos_theta = dot(n_w(4,:), v_ww);
    if (W_R(2) == -W/2)
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif (W_R(1) == -L/2)
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif (W_R(2) == W/2)
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif (W_R(1) == L/2)
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif (W_R(3) == 0)
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif (W_R(3) == -H)
        A = dA(6);
        cos_psi = dot(n_w(6,:), -v_ww);
    end

elseif (W_T(3) == 0)
    cos_theta = dot(n_w(5,:), v_ww);
    if (W_R(2) == -W/2)
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif (W_R(1) == -L/2)
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif (W_R(2) == W/2)
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif (W_R(1) == L/2)
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif (W_R(3) == 0)
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif (W_R(3) == -H)
        A = dA(6);
        cos_psi = dot(n_w(6,:), -v_ww);
    end

elseif (W_T(3) == -H)
    cos_theta = dot(n_w(6,:), v_ww);
    if (W_R(2) == -W/2)
        A = dA(1);
        cos_psi = dot(n_w(1,:), -v_ww);
    elseif (W_R(1) == -L/2)
        A = dA(2);
        cos_psi = dot(n_w(2,:), -v_ww);
    elseif (W_R(2) == W/2)
        A = dA(3);
        cos_psi = dot(n_w(3,:), -v_ww);
    elseif (W_R(1) == L/2)
        A = dA(4);
        cos_psi = dot(n_w(4,:), -v_ww);
    elseif (W_R(3) == 0)
        A = dA(5);
        cos_psi = dot(n_w(5,:), -v_ww);
    elseif (W_R(3) == -H)
        A = dA(6);
        cos_psi = dot(n_w(6,:), -v_ww);
    end

end

h_ww = A / (pi * d_ww^2) * abs(cos_theta) * abs(cos_psi);
end
