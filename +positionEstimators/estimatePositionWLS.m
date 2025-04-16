% +opticalWireless/estimatePositionWLS.m
function [x_est, y_est] = estimatePositionWLS(P, orientations, m, SNR, varargin)
%ESTIMATEPOSITIONWLS  Estima (x,y) por mínimos cuadrados ponderados (WLS).
%
%   [x_est, y_est] = estimatePositionWLS(P, orientations, m, SNR)
%
%   Inputs:
%       - P           : [N_x, N_y, n] potencias
%       - orientations: [n x 3] vectores de orientación
%       - m           : exponente lambertiano
%       - SNR         : [N_x, N_y, n] relación señal a ruido correspondiente a cada potencia
%       - varargin    : parámetros opcionales (por ejemplo 'z')
%
%   Outputs:
%       - x_est, y_est: [N_x, N_y] con la posición estimada
%
%   NOTA: la idea es igual a LS, pero cada ecuación se pondera con un peso
%         w_i ∝ SNR_i, de modo que mediciones con SNR alto pesan más en la
%         suma de mínimos cuadrados.

    p = inputParser;
    addParameter(p, 'z', -1.04);  % ejemplo de altura
    parse(p, varargin{:});
    zVal = p.Results.z;

    [N_x, N_y, n] = size(P);
    if n < 2
        error('WLS requires at least 2 orientations (n<2).');
    end

    n_tx = orientations(:,1);
    n_ty = orientations(:,2);
    n_tz = orientations(:,3);

    x_est = zeros(N_x, N_y);
    y_est = zeros(N_x, N_y);

    ref = 1;  % Tomamos la 1 como referencia

    for rxIdx = 1:N_x
        for ryIdx = 1:N_y

            p_vec  = squeeze(P(rxIdx, ryIdx, :));   % [n x 1]
            snrVec = squeeze(SNR(rxIdx, ryIdx, :)); % [n x 1]

            P_ref = p_vec(ref);
            if (P_ref <= 0) || all(snrVec <= 0)
                x_est(rxIdx, ryIdx) = NaN;
                y_est(rxIdx, ryIdx) = NaN;
                continue;
            end

            ratio = (p_vec ./ P_ref).^(1/m);

            A = [];
            B = [];
            W = [];  % diagonal de pesos

            for i = 1:n
                if i == ref
                    continue;
                end

                alpha_x = n_tx(i) - ratio(i)*n_tx(ref);
                alpha_y = n_ty(i) - ratio(i)*n_ty(ref);
                alpha_z = n_tz(i) - ratio(i)*n_tz(ref);

                % Ecuación => alpha_x*x + alpha_y*y + alpha_z*zVal = 0
                % => alpha_x*x + alpha_y*y = - alpha_z*zVal
                A = [A; alpha_x alpha_y];
                B = [B; -alpha_z*zVal];

                % Asumimos un peso ∝ SNR_i
                w_i = max(0, snrVec(i));  % en caso de SNR<0 => clamp
                W = [W; w_i];
            end

            if rank(A) < 2
                x_est(rxIdx, ryIdx) = NaN;
                y_est(rxIdx, ryIdx) = NaN;
            else
                % WLS => min sum_i w_i*(A_i*[x;y]-B_i)^2
                % => A'_W = sqrt(W)*A, B'_W = sqrt(W)*B
                % => [x;y] = inv(A'_W^T * A'_W)* A'_W^T * B'_W
                % Con 'W' diagonal => implementamos vector W en la diag
                W_sqrt = sqrt(W);
                A_w = diag(W_sqrt)*A;
                B_w = diag(W_sqrt)*B;

                x_y = (A_w'*A_w)\(A_w'*B_w);
                x_est(rxIdx, ryIdx) = x_y(1);
                y_est(rxIdx, ryIdx) = x_y(2);
            end
        end
    end
end
