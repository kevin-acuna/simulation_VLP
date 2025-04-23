% +opticalWireless/estimatePositionLS.m
function [x_est, y_est] = estimatePositionLS(P, orientations, m, varargin)
%ESTIMATEPOSITIONLS  Estima (x,y) por mínimos cuadrados cuando hay n>3 orientaciones.
%
%   [x_est, y_est] = estimatePositionLS(P, orientations, m)
%
%   Inputs:
%       - P           : [N_x, N_y, n] potencias
%       - orientations: [n x 3] vectores de orientación (n_t_i)
%       - m           : exponente lambertiano
%       - varargin    : parámetros opcionales (por ejemplo la altura z, etc.)
%
%   Salidas:
%       - x_est, y_est: [N_x, N_y] con la posición estimada en cada punto.
%
%   NOTA: Este ejemplo asume que el Tx está en (0,0,0) y el Rx en (x,y,z),
%         con z conocido y fijo. Ajusta según tu proyecto.

    % Parseo de posibles parámetros opcionales
    p = inputParser;
    addParameter(p, 'z', -1.04);  % Altura por defecto (ejemplo)
    parse(p, varargin{:});
    zVal = p.Results.z;

    [N_x, N_y, n] = size(P);
    if n < 2
        error('LS requires at least 2 orientations (n<2).');
    end

    % Tomamos n_t_1 como la orientación de referencia
    % (Podrías elegir cualquier. Asumimos n_t_1 => orientation(1,:) ).
    ref = 1;

    % Extraemos n_t para cada i
    % orientations es [n x 3]. 
    n_tx = orientations(:,1);
    n_ty = orientations(:,2);
    n_tz = orientations(:,3);

    % Inicializamos salidas
    x_est = zeros(N_x, N_y);
    y_est = zeros(N_x, N_y);

    % Para cada punto (r_x, r_y) resolvemos en LS:
    for rxIdx = 1:N_x
        for ryIdx = 1:N_y

            % Extraemos las potencias en este pixel
            p_vec = squeeze(P(rxIdx, ryIdx, :));   % vector [n x 1]

            % Construimos ratios con respecto a la referencia 1
            % ratio_i = (P_i / P_ref)^(1/m)
            P_ref = p_vec(ref);
            if P_ref <= 0
                % Si la potencia de referencia es nula, la ecuación no se puede formar
                x_est(rxIdx, ryIdx) = NaN;
                y_est(rxIdx, ryIdx) = NaN;
                continue;
            end

            ratio = (p_vec ./ P_ref).^(1/m);  % [n x 1]

            % Planteamos las ecuaciones lineales:
            % (x, y) se busca tal que:
            %
            %   (n_ti - ratio_i * n_tRef) · ( [x; y; zVal] ) = 0
            %   expandido => x*(a_i - ratio_i*a_ref) + y*(b_i - ratio_i*b_ref) + zVal*(c_i - ratio_i*c_ref) = 0
            %
            % Repetimos i=2..n. (La fila i=ref no forma ecuación)
            A = []; B = [];
            for i = 1:n
                if i == ref
                    continue;  % no ecuación
                end

                alpha_x = n_tx(i) - ratio(i)*n_tx(ref);
                alpha_y = n_ty(i) - ratio(i)*n_ty(ref);
                alpha_z = n_tz(i) - ratio(i)*n_tz(ref);

                % Ecuación: alpha_x*x + alpha_y*y + alpha_z*zVal = 0
                % => alpha_x*x + alpha_y*y = - alpha_z*zVal
                A = [A; alpha_x alpha_y];
                B = [B; -alpha_z*zVal];
            end

            % Ahora resolvemos en LS => A*[x;y] ~ B
            % => [x;y] = (A^T A)^(-1) A^T B
            % (Asumiendo A es full rank).
            if rank(A) < 2
                % sistema degenerado
                x_est(rxIdx, ryIdx) = NaN;
                y_est(rxIdx, ryIdx) = NaN;
            else
                x_y = (A'*A)\(A'*B);
                x_est(rxIdx, ryIdx) = x_y(1);
                y_est(rxIdx, ryIdx) = x_y(2);
            end
        end
    end
end
