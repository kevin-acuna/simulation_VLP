function res = evaluate_coverage_LED(nt, m, positions, params)
% EVALUATE_COVERAGE_LED  Positioning-service coverage + PEB statistics for a
% single Lambertian LED with K steered orientations (broadcast OWP framework).
%
% This is the LED counterpart of the VCSEL_3D analysis (core/evaluate_codebook.m).
% A testbed position is declared "covered" iff ALL of:
%     isfinite(PEB)                 (FIM full-rank / well-conditioned)
%     PEB       <= PEB_max_cov      (localization-accuracy QoS)
%     maxSNR_dB >= SNR_min_dB       (link/detectability QoS)
%
% The PEB is the Cramer-Rao bound from core/PEB_complete.m (K direction-finding
% orientations + 1 distance-recovery measurement). The peak SNR uses the
% Lambertian LOS channel of core/OWC_LOS_channel.m:
%     mu_i = Pt*(m+1)*A_det/(2*pi*d^2) * cos(phi_i)^m * cos(psi)
%     SNR  = N * max_i(mu_i)^2 / sigma2         (averaged-measurement SNR)
%
% INPUTS:
%   nt        : 3xK unit orientation vectors (columns), nadir-referenced
%   m         : Lambertian order, m = -log(2)/log(cos(theta_half))
%   positions : 3xP testbed positions [x; y; z]
%   params    : struct with fields
%                 T (3x1), Pt, A_det, theta_half (rad), Psi_FOV (rad),
%                 sigma2, N, nr (3x1), SNR_min_dB, PEB_max_cov
%
% OUTPUT (struct res):
%   res.PEB          : 1xP PEB per position (m), Inf where undefined
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

C = Pt * (m + 1) * A_det / (2 * pi);   % Lambertian radiometric constant

PEB_arr   = inf(1, P);
maxSNR_dB = -inf(1, P);

% PEB_complete emits (id-less) warnings on singular/ill-conditioned FIM; silence
% them during the sweep so the console is not flooded, then restore the state.
ws = warning('off', 'all');

for ip = 1:P
    R    = positions(:, ip);
    dvec = R - T;
    d    = norm(dvec);

    % --- Peak received power across orientations (for SNR / coverage gate) ---
    if d > 1e-9
        nd      = dvec / d;
        cos_psi = -(nr' * nd);                       % incidence cosine
        if cos_psi > 0 && acos(min(1, max(-1, cos_psi))) <= Psi_FOV
            mu_max = 0;
            for i = 1:K
                cphi = nt(:, i)' * nd;               % cos(phi_i)
                if cphi > 0
                    mu = C * cphi^m * cos_psi / d^2;
                    if mu > mu_max, mu_max = mu; end
                end
            end
            if mu_max > 0
                maxSNR_dB(ip) = 10 * log10(N * mu_max^2 / sigma2);
            end
        end
    end

    % --- Broadcast PEB (DF orientations + distance recovery) ---
    pv = PEB_complete(R, nt, T, Pt, m, A_det, params.theta_half, Psi_FOV, sigma2, N);
    if isreal(pv) && isfinite(pv) && pv > 0
        PEB_arr(ip) = pv;
    end
end

warning(ws);

covered = isfinite(PEB_arr) & (PEB_arr <= params.PEB_max_cov) ...
        & (maxSNR_dB >= params.SNR_min_dB);

res.PEB       = PEB_arr;
res.maxSNR_dB = maxSNR_dB;
res.covered   = covered;
res.coverage  = mean(covered);
res.outage    = 1 - res.coverage;

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
