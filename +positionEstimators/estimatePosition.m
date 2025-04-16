function [x_est, y_est] = estimatePosition(P, orientations, m, varargin)
% ESTIMATEPOSITION Estima la posición (x,y) a partir de las potencias medidas.
%
%   Inputs:
%       P             : [Nrx, Nry, n] matriz (o cell) con n potencias medidos en cada (x_r,y_r).
%                       O puede ser un vector si se maneja 1 sola posición, etc.
%       orientations  : [n x 3] matriz con los vectores de orientación del Tx (n_t_i).
%       m             : exponente lambertiano.
%       varargin      : parámetros opcionales, por ejemplo:
%           - 'SNR'   : matriz/array de SNR asociado a cada potencia.
%           - 'Method': 'LS' (por defecto) o 'WLS'.
%
%   Outputs:
%       x_est, y_est  : estimaciones de la posición en el mismo grid en que se recibieron P
%                       (o en la dimensionalidad que corresponda).
%
%   Ejemplo de uso:
%       [x_est, y_est] = estimatePosition(P, orientations, m, 'SNR', SNR, 'Method','WLS');

    % Parseo de argumentos opcionales
    p = inputParser;
    addParameter(p, 'SNR', []);    % Por defecto, sin SNR
    addParameter(p, 'Method','LS'); % Por defecto, LS
    parse(p, varargin{:});
    SNR   = p.Results.SNR;
    method = p.Results.Method;

    % Asegurarse de que la tercera dimensión de P sea "n"
    % (o en su defecto, adaptarlo a tu forma de almacenar potencias).
    n = size(P, 3);
    if n < 2
        error('estimatePosition: No hay suficientes potencias (n<2).');
    end

    % Caso n=3 -> determinista (similar a tu ecuación cerrada)
    if n == 3 
        % Aplicas la fórmula "clásica" con K_ij, K_kl, etc.
        % Para ello necesitas indexar a,b,c de orientations: 
        %   a = orientations(:,1), b = orientations(:,2), c = orientations(:,3).
        %   P1 = P(:,:,1), P2 = P(:,:,2), P3 = P(:,:,3).
        % Devuelves x_est, y_est con la misma dimensión que la malla de P.
        [x_est, y_est] = positionEstimators.deterministic3Orientation(P, orientations, m);

    else
        % Caso n>3 -> LS o WLS
        switch upper(method)
            case 'LS'
                [x_est, y_est] = positionEstimators.estimatePositionLS(P, orientations, m);
            case 'WLS'
                if isempty(SNR)
                    warning('No se proporcionó SNR, se hará LS simple.');
                    [x_est, y_est] = positionEstimators.estimatePositionLS(P, orientations, m);
                else
                    [x_est, y_est] = positionEstimators.estimatePositionWLS(P, orientations, m, SNR);
                end
            otherwise
                error('Método de estimación no reconocido.');
        end
    end
end
