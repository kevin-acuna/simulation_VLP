function PEB = vlp_peb(theta, nt, T, m, K, sigma2)
%-----------------------------------------------------------------
% theta   : 3×1  [x; y; z]  -> posición del receptor (m)
% nt      : 3×n  matriz cuyas columnas son n_t^(i) (unitarias)
% T       : 3×1  posición del LED  [0;0;H] (m)
% m       : orden Lambertiano
% K       : constante radiométrica  P_t(m+1)A_det/(2π)  (W·m^{m+3})
% sigma2  : varianza del ruido de una sola muestra  (W^2)
%-----------------------------------------------------------------
% devuelve:
% PEB     : Cramér–Rao Position Error Bound  (m RMS)
%-----------------------------------------------------------------

% --------- 1. Preparativos -------------------------------------
d  = theta - T;               % vector enlace  (3×1)
nr = [0;0;1];                 % normal del receptor (vertical)
cr = nr.'*(-d);               % cos(psi) = H - z
normd = norm(d);
n     = size(nt,2);

I = zeros(3);                 % FIM de 3×3

% --------- 2. Bucle sobre orientaciones -------------------------
for i = 1:n
    nt_i  = nt(:,i);                         % columna i-ésima
    ci    = nt_i.'*d;                        % n_t^(i)·d
    % ------- gradiente g_i (ec. (27)) -------
    g_i = ( ...
         m * ci^(m-1) * cr / normd^(m+3)      * nt_i ...
      - (m+3) * ci^m     * cr / normd^(m+5)   * d ...
      -           ci^m        / normd^(m+3)   * nr );
    % ------- acumular FIM --------------------
    I = I + (K^2/sigma2) * (g_i * g_i.');
end

% --------- 3. PEB -----------------------------------------------
PEB = sqrt(trace(inv(I)));     % ec. (29)
end
