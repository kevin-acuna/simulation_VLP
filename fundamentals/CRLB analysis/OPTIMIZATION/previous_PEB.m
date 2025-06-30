function PEB = previous_PEB(theta, nt, T, m, K, sigma2, N, Nb)
    %-----------------------------------------------------------------
    % theta   : 3×1  [x; y; z]      -> posición Rx (m)
    % nt      : 3×n  orientaciones unitarias consideradas en la fase-1
    % T       : 3×1  posición Tx [0;0;H] (m)
    % m       : orden Lambertiano
    % K       : constante radiométrica  P_t (m+1)A_det/(2π)
    % sigma2  : varianza de UNA única muestra (W²)
    % N       : nº de muestras promediadas en cada orientación de la fase-1
    % Nb      : nº de muestras promediadas en la orientación *beam-steered*
    %-----------------------------------------------------------------
    % Devuelve: PEB  =  √tr{ I⁻¹ }  (m RMS)  con ambas fases incluidas
    %-----------------------------------------------------------------
    
    % -------- 1. Geometría ------------------------------------------
    d      = theta - T;            % vector Tx→Rx (3×1)
    nr     = [0;0;1];              % normal del receptor (arriba)
    cr     = nr.'*(-d);            % cos(ψ)=H−z
    normd  = norm(d);
    n      = size(nt,2);
    
    % Dirección "real" para la orientación beam-steered
    d_unit = d / normd;            % = v_tr  (3×1)
    
    % -------- 2. Fisher Information Matrix --------------------------
    I = zeros(3);                  % inicializa FIM
    
    % --- (a) Orientaciones de la fase-1 -----------------------------
    for i = 1:n
        nt_i = nt(:,i);
        ci   = nt_i.'*d;           % cos(φ_i)*‖d‖

        % cos_phi_i = ci / normd;    % cos(phi_i)
        % cos_psi   = (nr.'*(-d)) / normd;
        % psi       = acosd(abs(cos_psi));
        % % -- FILTRO GEOMÉTRICO ------------------------------------------ %
        % if psi > 85 || cos_phi_i <= 0          % << filtro
        %     continue                                % << filtro
        % end                                         % << filtro
        % % ----------------------------------------------------------------

        
        g_i  = ( ...
               m     * ci^(m-1) * cr / normd^(m+3) * nt_i ...
            - (m+3)  * ci^m     * cr / normd^(m+5) * d     ...
            -             ci^m      / normd^(m+3) * nr );
        I = I + (N * K^2 / sigma2) * (g_i * g_i.');
    end
    
    % --- (b) Orientación beam-steered -------------------------------
    % nt_beam =  d_unit   ;   cosφ = 1,  cosψ = 1
    % En beam-steering, el receptor también apunta al transmisor
    ci_b  = normd;                 % n_t·d  = ‖d‖  (porque cosφ=1)
    cr_b  = normd;                 % n_r·(-d) = ‖d‖ (porque cosψ=1)
    nr = -d_unit; 

    g_b   = ( ...
            m     * ci_b^(m-1) * cr_b / normd^(m+3) * d_unit ...
          - (m+3) * ci_b^m     * cr_b / normd^(m+5) * d      ...
          -            ci_b^m         / normd^(m+3) * nr );
    I = I + (Nb * K^2 / sigma2) * (g_b * g_b.');   % contribución extra
    
    % -------- 3. PEB (RMS) ------------------------------------------
    PEB = sqrt(trace(inv(I)));      % √tr{I⁻¹}
    end
    