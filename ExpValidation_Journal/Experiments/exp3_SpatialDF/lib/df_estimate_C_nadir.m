function [C_nadir, info] = df_estimate_C_nadir(dataFile, T, v_dark)
% DF_ESTIMATE_C_NADIR  Sub-dataset-2-style radiometric constant.
%
%   [C_nadir, info] = df_estimate_C_nadir(dataFile, T, v_dark)
%
% Recovers C using ONLY the strict calibration geometry of sub-dataset 2. The
% three selection criteria are FIXED (not tunable) by definition:
%   * receiver exactly UNDER the LED   ->  x == 0  and  y == 0  (z irrelevant)
%   * PD vertical (NOT tilted)         ->  scan_kind == 'vertical'
%   * LED pointing to the FLOOR        ->  nadir orientation (nt_incl == 0)
%
% With that geometry nd = [0;0;-1], hence Q = nt . nd = 1 and cos(psi) = 1, so
% the broadcast model collapses to the textbook sub-2 relation:
%
%   C = (v_mean - v_dark) * d^2 ,   d = |pos - T|
%
% C_nadir is the median over the matching rows (one per known distance). It is
% independent of cfg.K_id. Feed the result via cfg.C_opt for the DF distance
% stage.

    if nargin < 3 || isempty(v_dark), v_dark = 0; end
    T = T(:);

    Tbl = df_load_master(dataFile);
    isVert = strcmpi(strtrim(Tbl.scan_kind), 'vertical');   % PD not tilted
    under  = (Tbl.x == 0) & (Tbl.y == 0);                   % exactly under the LED
    nadir  = (Tbl.nt_incl == 0);                            % LED points to floor
    sel    = isVert & under & nadir & isfinite(Tbl.v_mean);
    S = Tbl(sel, :);
    n = height(S);

    C_all = nan(n, 1);
    for j = 1:n
        d = norm([S.x(j); S.y(j); S.z(j)] - T);   % Q = cos(psi) = 1 by construction
        if d < 1e-9, continue; end
        mu = max(S.v_mean(j) - v_dark, 1e-6);
        C_all(j) = mu * d^2;
    end
    C_all   = C_all(isfinite(C_all));
    C_nadir = median(C_all);

    info = struct('n_rows', n, 'n_used', numel(C_all), 'C_all', C_all);
end
