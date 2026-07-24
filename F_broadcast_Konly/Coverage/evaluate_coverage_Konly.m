function res = evaluate_coverage_Konly(nt, m, positions, prm)
%EVALUATE_COVERAGE_KONLY  Positioning-service coverage for the broadcast (K-only) OWP.
%
%   Evaluates, over a set of receiver positions, the broadcast Position Error
%   Bound PEB_B (using ONLY the K steered-orientation measurements, via
%   PEB_Konly) plus the per-position best link SNR, and flags a position as
%   "covered" when it meets both QoS thresholds:
%
%       covered  <=>  isfinite(PEB_B) & PEB_B <= prm.PEB_max_cov
%                                     & maxSNR_dB >= prm.SNR_min_dB
%
%   INPUTS
%     nt        : 3xK matrix of unit LED orientation vectors (nadir-referenced)
%     m         : Lambertian order (from the half-power angle)
%     positions : 3xP matrix of receiver positions [x;y;z] (m)
%     prm       : struct with fields
%                   T (3x1), nr (3x1), Pt, A_det, Psi_FOV (rad), sigma2, N,
%                   PEB_max_cov (m), SNR_min_dB (dB)
%
%   OUTPUT (struct)
%     res.covered  : 1xP logical coverage mask
%     res.coverage : scalar coverage fraction (mean of covered)
%     res.peb      : 1xP PEB_B values (m)
%     res.snr_dB   : 1xP best per-position link SNR (dB)

    P      = size(positions, 2);
    peb    = inf(1, P);
    snr_dB = -inf(1, P);

    for j = 1:P
        R = positions(:, j);
        peb(j)    = PEB_Konly(R, nt, prm.T, prm.Pt, m, prm.A_det, ...
                              prm.Psi_FOV, prm.sigma2, prm.N, prm.nr);
        snr_dB(j) = max_beam_snr_dB(nt, m, R, prm);
    end

    covered = isfinite(peb) & (peb <= prm.PEB_max_cov) & (snr_dB >= prm.SNR_min_dB);

    res.covered  = covered;
    res.coverage = mean(covered);
    res.peb      = peb;
    res.snr_dB   = snr_dB;
end

function s = max_beam_snr_dB(nt, m, R, prm)
% Best averaged-measurement SNR (dB) across the K beams at position R.
    dvec = R - prm.T;  d = norm(dvec);
    cos_psi = (prm.nr.' * (-dvec)) / d;
    if cos_psi <= 0 || acos(min(1, max(-1, cos_psi))) > prm.Psi_FOV
        s = -inf; return;                      % outside receiver FOV
    end
    C    = prm.Pt * (m + 1) * prm.A_det / (2*pi);
    best = 0;
    for i = 1:size(nt, 2)
        cphi = (nt(:, i).' * dvec) / d;
        if cphi > 0
            best = max(best, C * cphi^m * cos_psi / d^2);
        end
    end
    if best <= 0
        s = -inf;
    else
        s = 10 * log10(prm.N * best^2 / prm.sigma2);
    end
end
