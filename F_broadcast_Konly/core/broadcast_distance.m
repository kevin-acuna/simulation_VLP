function [d_hat, eta_hat, cos_psi_hat] = broadcast_distance(nd_hat, nt, mu_hat, m, C_opt, nr)
% BROADCAST_DISTANCE  Estimate distance from K power measurements (no K+1)
%
% Given the estimated direction nd_hat (from GLS/WLS/NLS) and the K mean
% powers, recovers the distance d using the amplitude parameter eta and
% the known receiver orientation nr (from IMU).
%
% Model: mu_i = eta * Q_i^m,  where Q_i = n_{t,i} . n_d
%        eta  = C * cos(psi) / d^2
%        => d = sqrt(C * cos(psi) / eta)
%
% The eta estimator is the MLE for eta given n_d under Gaussian noise:
%   eta_hat = sum(mu_hat_i * Q_hat_i^m) / sum(Q_hat_i^{2m})
%
% INPUTS:
%   nd_hat : 3x1 unit direction vector (estimated, from DF stage)
%   nt     : 3xK LED orientation vectors (columns)
%   mu_hat : 1xK or Kx1 mean received powers (sample means)
%   m      : scalar, Lambertian order
%   C_opt  : scalar, positive radiometric constant = P_t*(m+1)*A_det/(2*pi)
%   nr     : 3x1 receiver orientation vector (known, e.g. from IMU)
%
% OUTPUTS:
%   d_hat       : scalar, estimated distance [m]
%   eta_hat     : scalar, estimated amplitude parameter
%   cos_psi_hat : scalar, estimated incidence cosine

mu_hat = mu_hat(:)';  % Ensure row
nd_hat = nd_hat(:);   % Ensure column
nr = nr(:);
K = size(nt, 2);

%% 1. Compute direction cosines using estimated direction
Q_hat = zeros(1, K);
for i = 1:K
    Q_hat(i) = max(0, nt(:,i)' * nd_hat);  % Clip to non-negative
end

%% 2. MLE for eta given nd_hat
% eta_hat = argmin_eta sum(eta*Q_i^m - mu_i)^2
% Solution: eta_hat = sum(mu_i * Q_i^m) / sum(Q_i^{2m})
Q_m = Q_hat.^m;
Q_2m = Q_hat.^(2*m);

denom = sum(Q_2m);
if denom < 1e-30
    d_hat = Inf;
    eta_hat = NaN;
    cos_psi_hat = NaN;
    return;
end

eta_hat = sum(mu_hat .* Q_m) / denom;

%% 3. Incidence angle from known nr and estimated direction
cos_psi_hat = -nr' * nd_hat;

%% 4. Distance
if eta_hat <= 0 || cos_psi_hat <= 0
    d_hat = Inf;
    return;
end

d_hat = sqrt(C_opt * cos_psi_hat / eta_hat);

% Validate
if ~isreal(d_hat) || ~isfinite(d_hat) || d_hat <= 0
    d_hat = Inf;
end

end
