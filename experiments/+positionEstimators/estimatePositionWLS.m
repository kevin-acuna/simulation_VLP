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
            % Convertir SNR en dB a lineal para mejor ponderación
            snr_linear = 10^(snrVec(i)/10);
            
            % Limitar el SNR para evitar valores extremos
            w_i = min(max(snr_linear, 0.001), 1000);  % Limitar entre 0.001 y 1000
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
                
                % Normalizar los pesos para evitar problemas numéricos
                W_norm = W / max(W);
                
                % Aplicar un mínimo para evitar pesos cercanos a cero
                W_norm = max(W_norm, 1e-6);
                
                W_sqrt = sqrt(W_norm);
                A_w = diag(W_sqrt) * A;
                B_w = diag(W_sqrt) * B;
                
                % Usar SVD para resolver el sistema de forma más estable
                try
                    % Primer intento: solución mediante backslash
                    x_y = (A_w'*A_w)\(A_w'*B_w);
                    
                    % Verificar si la solución tiene valores NaN o Inf
                    if any(isnan(x_y)) || any(isinf(x_y))
                        % Si falla, usar SVD con pseudoinversa
                        x_y = pinv(A_w) * B_w;
                    end
                catch
                    % Si falla el backslash, usar pseudoinversa
                    x_y = pinv(A_w) * B_w;
                end
                
                % Verificar límites razonables para las estimaciones
                if all(abs(x_y) <= 10)  % Suponiendo que las posiciones están en un rango razonable
                    x_est(rxIdx, ryIdx) = x_y(1);
                    y_est(rxIdx, ryIdx) = x_y(2);
                else
                    x_est(rxIdx, ryIdx) = NaN;
                    y_est(rxIdx, ryIdx) = NaN;
                end
            end
        end
    end
end
