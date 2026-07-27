function [C_emp, C_all] = df_estimate_C(inst, m)
% DF_ESTIMATE_C  Empirical voltage-domain radiometric constant from GT.
%
%   [C_emp, C_all] = df_estimate_C(inst, m)
%
% The measured mean voltage is proportional to received optical power, so the
% radiometric constant C in the broadcast model lives in "volt units". When an
% independent C calibration (sub-dataset 2) is not yet available, we recover an
% empirical C from THIS dataset using ground truth:
%
%   Model : mu_i  = eta * Q_i^m ,   Q_i = max(0, n_{t,i} . nd_true)
%           eta   = C * cos(psi_true) / d_true^2
%   MLE   : eta_hat = sum(mu_i * Q_i^m) / sum(Q_i^{2m})   (using TRUE direction)
%   => C_j = eta_hat * d_true^2 / cos(psi_true)
%
% C_emp is the median of the per-instance C_j (robust to outliers). This is a
% self-consistency calibration: it removes the global scale bias so that the
% distance/position figures reveal the *scatter* of the model across the room.
% Replace with the sub-dataset 2 constant once measured (cfg.C_opt).

    n = numel(inst);
    C_all = nan(n, 1);
    for j = 1:n
        s = inst(j);
        Q  = max(0, (s.nt.' * s.nd_true)).';   % 1xK, true direction
        Qm = Q.^m; Q2m = Q.^(2*m);
        denom = sum(Q2m);
        if denom < 1e-30, continue; end
        eta_true = sum(s.mu .* Qm) / denom;
        cospsi   = max(0, -s.nr.' * s.nd_true);
        if eta_true > 0 && cospsi > 1e-6
            C_all(j) = eta_true * s.d_true^2 / cospsi;
        end
    end
    C_emp = median(C_all(isfinite(C_all)));
end
