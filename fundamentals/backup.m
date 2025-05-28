    % 9. Estimation of the Rx coordinates from the estimated v_tr
    param_t_axis = {T, v_tr_est(i_pos,:), P_t, m_t};
    param_r_axis = {A_det, -v_tr_est(i_pos,:), FOV}; % Vector of the Rx parameters used for channel simulation
    [~, P_r_axis(i_pos), ~, ~] = OWC_LOS_channel(x_real, y_real, z_real, param_t_axis, param_r_axis); % Computation of the real received power if Tx and Rx oriented toward v_tr_est and -v_tr_est respectively
    P_r_axis_noisy(i_pos,:) = (R_pd.*P_r_axis(i_pos) + sqrt(sigma2).*randn(1,1000))./R_pd; % Corresponding noise power observed [W]
%     d_tr_est(i_pos) = sqrt(P_t*(m_t+1)*A_det/(2*pi*P_r_axis(i_pos))); % Estimated absolute distance (case without noise) [m]
    d_tr_est(i_pos) = sqrt(P_t*(m_t+1)*A_det/(2*pi*mean(P_r_axis_noisy(i_pos,:)))); % Estimated absolute distance (case with noise) [m]
    estPos(i_pos,:) = v_tr_est(i_pos,:).*d_tr_est(i_pos); % Estimated coordinates of the Rx