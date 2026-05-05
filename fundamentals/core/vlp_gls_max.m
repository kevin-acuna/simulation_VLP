function d_hat = vlp_gls_max(nt, Praw, m, sigma2)
% VLP_GLS_MAX Generalized Least Squares estimator — max-power reference
% 
% Identical to vlp_gls except the reference orientation is the one with
% the highest mean received power (best SNR), rather than always using
% orientation 1.
%
% Inputs:
%   nt      : 3×n  — orientaciones n_t^(i) (columnas)
%   Praw    : N×n  — muestras de potencia P_r^(k,i)
%   m       : esc. Lambertiano
%   sigma2  : varianza común de cada muestra
%
% Output:
%   d_hat   : dirección 3×1 del Tx al Rx (normada)

[N,n]  = size(Praw);
mu_hat = mean(Praw,1).';          % μ̂_i  (n×1)

mu_hat = min(max(mu_hat, 0.00000000001), 1000);

% --- Reference: orientation with maximum mean power ---
[~, ref] = max(mu_hat);
mu_ref   = mu_hat(ref);

% Non-reference indices
idx  = setdiff(1:n, ref);
beta = (mu_hat(idx) / mu_ref).^(1/m);      % (n-1)×1

% ---------- 1. matriz de covarianza completa Σ_r ----------
diagVar = beta.^2 .* ( mu_hat(idx).^(-2) + mu_ref^(-2) );
Sigma_r = diag(diagVar) + (beta*beta.')*mu_ref^(-2) ...
          - diag(beta.^2*mu_ref^(-2));       % tamaño (n-1)×(n-1)

% ---------- 2. matriz A ----------
A = zeros(3, n-1);
for j = 1:length(idx)
    A(:,j) = nt(:,idx(j)) - beta(j)*nt(:,ref);
end

% ---------- 3. matriz de información M ----------
W   = inv(Sigma_r);                %  Σ_r^{-1}
M   = A * W * A.';                 %  3×3

% ---------- 4. autovector de menor autovalor ----------
[V,D]  = eig(M);
[~,ix] = min(diag(D));
d_hat  = V(:,ix) / norm(V(:,ix));  % unitario

% ---------- 5. signo coherente (hacia el receptor) ----------
if dot(d_hat, nt(:,ref)) < 0
    d_hat = -d_hat;
end
end
