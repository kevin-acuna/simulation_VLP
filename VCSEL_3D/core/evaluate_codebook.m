function res = evaluate_codebook(nt, theta_div, positions, params)
% EVALUATE_CODEBOOK  Coverage + PEB statistics of a codebook over a testbed
%
% For every testbed position this computes the Gaussian broadcast PEB and the
% peak averaged-measurement SNR, then applies the coverage criterion:
%   covered  <=>  isfinite(PEB) AND PEB <= PEB_max_cov AND maxSNR_dB >= SNR_min_dB
%
% INPUTS:
%   nt        : 3xK unit orientation vectors (columns)
%   theta_div : divergence half-angle (RADIANS)
%   positions : 3xP testbed positions [x; y; z]
%   params    : struct with fields
%                 T, Pt, A_det, Psi_FOV (rad), sigma2, N, nr,
%                 SNR_min_dB, PEB_max_cov
%
% OUTPUT (struct res):
%   res.PEB          : 1xP PEB per position (m), Inf/NaN where undefined
%   res.maxSNR_dB    : 1xP peak SNR per position (dB)
%   res.covered      : 1xP logical coverage mask
%   res.coverage     : scalar covered fraction (0..1)
%   res.outage       : 1 - coverage
%   res.mean_peb     : mean PEB over covered positions (m)
%   res.p90_peb      : 90th-percentile PEB over covered positions (m)
%   res.median_peb   : median PEB over covered positions (m)
%   res.mean_snr_dB  : mean peak SNR over covered positions (dB)

P = size(positions, 2);
K = size(nt, 2);

T       = params.T(:);
Pt      = params.Pt;
A_det   = params.A_det;
Psi_FOV = params.Psi_FOV;
sigma2  = params.sigma2;
N       = params.N;
nr      = params.nr(:);

PEB_arr    = inf(1, P);
maxSNR_dB  = -inf(1, P);

sigma_avg2 = sigma2 / N;   % variance of the averaged measurement

for ip = 1:P
    R = positions(:, ip);

    % --- Peak received power across orientations (for SNR / coverage) ---
    mu_max = 0;
    for i = 1:K
        mu_i = gaussian_channel(R, nt(:, i), T, Pt, theta_div, A_det, Psi_FOV, nr);
        if mu_i > mu_max, mu_max = mu_i; end
    end
    if mu_max > 0
        snr_lin = mu_max^2 / sigma_avg2;
        maxSNR_dB(ip) = 10 * log10(snr_lin);
    end

    % --- Broadcast PEB ---
    pv = PEB_Gaussian(R, nt, T, Pt, theta_div, A_det, Psi_FOV, sigma2, N, nr);
    if isreal(pv) && isfinite(pv) && pv > 0
        PEB_arr(ip) = pv;
    end
end

covered = isfinite(PEB_arr) & (PEB_arr <= params.PEB_max_cov) ...
        & (maxSNR_dB >= params.SNR_min_dB);

res.PEB         = PEB_arr;
res.maxSNR_dB   = maxSNR_dB;
res.covered     = covered;
res.coverage    = mean(covered);
res.outage      = 1 - res.coverage;

if any(covered)
    pc = PEB_arr(covered);
    res.mean_peb    = mean(pc);
    res.p90_peb     = prctile(pc, 90);
    res.median_peb  = median(pc);
    res.mean_snr_dB = mean(maxSNR_dB(covered));
else
    res.mean_peb = NaN; res.p90_peb = NaN; res.median_peb = NaN; res.mean_snr_dB = NaN;
end
end
