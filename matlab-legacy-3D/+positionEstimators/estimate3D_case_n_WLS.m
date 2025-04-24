% +opticalWireless/estimate3DWLS.m
function [x_est, y_est, z_est] = estimate3D_case_n_WLS(P, orientations, C, m, n_r, T, SNR, varargin)
%ESTIMATE3DWLS  Estima (x,y,z) para n>3 orientaciones usando WLS robusto
%
%   [x_est, y_est, z_est] = estimate3DWLS(P, orientations, C, m, n_r, T, SNR)
%
%   Inputs:
%       - P           : [Nx, Ny, Nz, n] potencias medidas
%       - orientations: [n x 3] vectores unitarios del transmisor
%       - C           : constante escala C = P_t*(m+1)*A_det/(2*pi)
%       - m           : exponente lambertiano
%       - n_r         : [1 x 3] vector normal del receptor
%       - T           : [1 x 3] posición del transmisor
%       - SNR         : [Nx, Ny, Nz, n] SNR (en dB o lineal)
%   Optional parameters (Name-Value):
%       'SNRdB'      : true|false (default:true) indica si SNR está en dB
%       'WeightLimits': [w_min, w_max] (default:[1e-3,1e3]) límites de peso
%       'PosRange'   : scalar, rango máximo absoluto aceptable (default:Inf)
%
    % Parsear opcionales
    p = inputParser;
    addParameter(p, 'SNRdB', true);
    addParameter(p, 'WeightLimits', [1e-3,1e3]);
    addParameter(p, 'PosRange', Inf);
    parse(p, varargin{:});
    isDb    = p.Results.SNRdB;
    wlims   = p.Results.WeightLimits;
    posLim  = p.Results.PosRange;

    [Nx, Ny, Nz, n] = size(P);
    x_est = NaN(Nx, Ny, Nz);
    y_est = NaN(Nx, Ny, Nz);
    z_est = NaN(Nx, Ny, Nz);

    % Referencia para ratios
    n1 = orientations(1, :)';  % 3x1

    for ix = 1:Nx
        for iy = 1:Ny
            for iz = 1:Nz
                % Extraer vectores en este punto
                Pvec   = squeeze(P(ix,iy,iz,:));   % [n x 1]
                snrVec = squeeze(SNR(ix,iy,iz,:)); % [n x 1]
                % Validar
                if Pvec(1) <= 0 || all(snrVec <= 0)
                    continue;
                end
                % Convertir SNR a lineal si está en dB
                if isDb
                    w_raw = 10.^(snrVec/10);
                else
                    w_raw = snrVec;
                end
                % Limitar pesos y normalizar
                w_clipped = min(max(w_raw, wlims(1)), wlims(2));
                w_norm    = w_clipped / max(w_clipped);

                % 1) Calcular betas
                beta = (Pvec(2:end) ./ Pvec(1)).^(1/m);  % (n-1)x1

                % 2) Construir vectores de restricción a_i
                A_dir = zeros(3,3);
                for k = 2:n
                    ai = orientations(k,:)' - beta(k-1)*n1;  % 3x1
                    wk = w_norm(k);
                    A_dir = A_dir + wk * (ai*ai');
                end

                % 3) Hallar dirección d_hat como autovector de mínimo autovalor
                [V, D] = eig(A_dir);
                [~, idx] = min(diag(D));
                d_hat = V(:, idx);
                % Corregir signo
                if d_hat'*n1 < 0
                    d_hat = -d_hat;
                end
                d_hat = d_hat / norm(d_hat);

                % 4) Calcular lambdas individuales y combinar por WLS
                lambda_i = zeros(n,1);
                for k = 1:n
                    cos_phi = max(d_hat'*orientations(k,:)', 0);
                    cos_psi = max((-d_hat)'*n_r', 0);
                    lambda_i(k) = sqrt(C * cos_phi^m * cos_psi / Pvec(k));
                end
                lambda = sum(w_norm .* lambda_i) / sum(w_norm);

                % 5) Posición definida
                pos = T(:) + lambda * d_hat;
                if all(abs(pos) <= posLim)
                    x_est(ix,iy,iz) = pos(1);
                    y_est(ix,iy,iz) = pos(2);
                    z_est(ix,iy,iz) = pos(3);
                end
            end
        end
    end

    x_est = permute(x_est, [2,1,3]);
    y_est = permute(y_est, [2,1,3]);
    z_est = permute(z_est, [2,1,3]);
end

