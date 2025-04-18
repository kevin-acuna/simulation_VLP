function [channelGainLOS, channelGainNLOS, bounceOrderGain] = opticalWirelessChannel(param_t, i_t, param_w, param_r, x, y, z, bounceOrderDecomposition, bounceOrder)
% opticalWirelessChannel computes the LOS and NLOS gains of an optical wireless channel.
% (Incluye la cabecera original con la descripción y referencias)
%
% Input parameters:
%   - param_t: Parámetros constantes de los transmisores.
%   - i_t: Índice del transmisor a considerar.
%   - param_w: Parámetros constantes de la sala.
%   - param_r: Parámetros constantes del receptor.
%   - x, y, z: Coordenadas cartesianas del receptor.
%   - bounceOrderDecomposition: Activa el cómputo del aporte de cada orden de rebote.
%   - bounceOrder: Orden máximo de rebote a considerar.
%
% Output parameters:
%   - channelGainLOS: Ganancia del canal óptico de línea de vista.
%   - channelGainNLOS: Ganancia del canal óptico sin línea de vista.
%   - bounceOrderGain: Aporte de cada orden de rebote al canal NLOS.

%% INITIALIZACIÓN DE PARÁMETROS Y MATRICES
N = size(param_w{1},1); % Número de reflectores de las paredes
G_rho = param_w{7};      % Factores de reflectividad
I = eye(N);              % Matriz identidad
t = zeros(N,1);          % Enlaces Tx-reflectores
r = zeros(1,N);          % Enlaces reflectores-Rx
H = zeros(N,N);          % Enlaces entre reflectores
bounceOrderGain = zeros(1, bounceOrder);

%% CÁLCULO DE LA GANANCIA LOS
% Se utiliza la función h_LOS del paquete (llamada con prefijo)
[channelGainLOS, ~, ~, ~] = opticalWireless.h_LOS(param_t, i_t, param_r, x, y, z);

%% CÁLCULO DE LA GANANCIA NLOS (NÚMERO INFINITO DE REBOTES)
for i_w = 1:N
    t(i_w) = opticalWireless.t_f(param_t, i_t, param_w, i_w);
    r(i_w) = opticalWireless.r_f(param_w, i_w, param_r, x, y, z);
    for j_w = 1:N
        H(i_w,j_w) = opticalWireless.H_f(param_w, i_w, j_w);
    end
end
t(isnan(t)) = 0; r(isnan(r)) = 0; H(isnan(H)) = 0;
s_f = inv(I - H * G_rho);
s_f(isnan(s_f)) = 0;
channelGainNLOS = r * G_rho * s_f * t;

%% CÁLCULO DEL APORTE DE CADA ORDEN DE REBOTE (SI SE REQUIERE)
if bounceOrderDecomposition == 1
    for i_b = 1:bounceOrder
        bounceOrderGain(i_b) = r * G_rho * (H * G_rho)^(i_b-1) * t;
    end
end

end
