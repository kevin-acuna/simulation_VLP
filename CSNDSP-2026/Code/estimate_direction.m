function n_d = estimate_direction( measures, n_t, m_t, method)
% measures is a vector = [v1,v2,v3,...,vK] 
% n_t is a matrix composed by a orientation vectors in each row n_t=[n_1;n_2;...;n_K];
% m_t is the lambertiar order
% method : svd, gls, wls, nl

    if strcmp(method,'svd')
        
        V_n1 = measures(1);
        V_n2 = measures(2);
        V_n3 = measures(3);
        
        n_t_1 = n_t(1,:);
        n_t_2 = n_t(2,:);
        n_t_3 = n_t(3,:);
        
        [a_i,b_i,c_i] = deal(n_t_1(1), n_t_1(2), n_t_1(3));
        [a_j,b_j,c_j] = deal(n_t_2(1), n_t_2(2), n_t_2(3));
        [a_k,b_k,c_k] = deal(n_t_3(1), n_t_3(2), n_t_3(3));

        % Ratios
        K_ij = (V_n1/V_n2)^(1/m_t);
        K_jk = (V_n2/V_n3)^(1/m_t);
        K_ik = (V_n1/V_n3)^(1/m_t);
    
        % Bastian SVD
        alpha_ij = a_i - K_ij*a_j;
        alpha_jk = a_j - K_jk*a_k;
        alpha_ik = a_i - K_ik*a_k;
        beta_ij = b_i - K_ij*b_j;
        beta_jk = b_j - K_jk*b_k;
        beta_ik = b_i - K_ik*b_k;
        gamma_ij = c_i - K_ij*c_j;
        gamma_jk = c_j - K_jk*c_k;
        gamma_ik = c_i - K_ik*c_k;
    
        eigenVectorsSVD  = null( [alpha_ij, beta_ij, gamma_ij;
                                          alpha_jk, beta_jk, gamma_jk;
                                          alpha_ik, beta_ik, gamma_ik]);
    
    
        n_d = -eigenVectorsSVD';
        n_d = n_d/norm(n_d);

    else
        n_d = [0,0,0];
    end

end