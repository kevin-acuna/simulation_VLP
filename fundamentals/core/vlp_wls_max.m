function [d_hat, beta_hat, w] = vlp_wls_max(nt, Praw, m)
% VLP_WLS_MAX Weighted Least Squares estimator — max-power reference
% 
% Identical to vlp_wls except the reference orientation is the one with
% the highest mean received power (best SNR), rather than always using
% orientation 1.
%
% Inputs:
%   nt   : 3×n orientaciones del LED     (columna)
%   Praw : N×n matriz de potencias crudas (filas = muestras k)
%   m    : orden Lambertiano
% 
% Outputs:
%   d_hat    : dirección 3×1 (unitaria) del transmisor al receptor
%   beta_hat : (n-1)×1 razones estimadas
%   w        : (n-1)×1 pesos finales
% 

[N, n] = size(Praw);

% ---- 1. medias μ̂_i
mu_hat = mean(Praw, 1) .';          % n×1

mu_hat = min(max(mu_hat, 0.00000000001), 1000); % Limites minimos para la potencia media.

% --- Reference: orientation with maximum mean power ---
[~, ref] = max(mu_hat);
mu_ref   = mu_hat(ref);

% Non-reference indices
idx      = setdiff(1:n, ref);
beta_hat = (mu_hat(idx) / mu_ref).^(1/m);   % (n-1)×1

% ---- 2. pesos según la fórmula simplificada
denom = beta_hat.^2 .* ( mu_hat(idx).^(-2) + mu_ref^(-2) );
w     = 1 ./ denom;                 % (n-1)×1  (constante común omitida)

w = w/max(w);

% ---- 3. matriz M
M = zeros(3);
for j = 1:length(idx)
    ai = nt(:,idx(j)) - beta_hat(j)*nt(:,ref);
    M  = M + w(j) * (ai*ai.');
end

% ---- 4. autovector de menor autovalor
[V,D]  = eig(M);
[~,ix] = min(diag(D));
d_hat  = V(:,ix) / norm(V(:,ix));

% Corregir signo (direccion Tx → Rx)
if dot(d_hat, nt(:,ref)) < 0
    d_hat = -d_hat;                 
end
end
