function [C_nadir, info] = df_estimate_C_nadir(dataFile, m, T, opts)
% DF_ESTIMATE_C_NADIR  Sub-dataset-2-style radiometric constant.
%
%   [C_nadir, info] = df_estimate_C_nadir(dataFile, m, T, opts)
%
% Recovers C using ONLY the calibration-like geometry of sub-dataset 2:
%   * receiver directly BELOW the LED  ->  |x| <= xyTol and |y| <= xyTol
%   * LED pointing to the FLOOR (nadir) ->  nt_incl <= inclTol  (Q ~= 1)
%
% For each matching row (independent of the K_id subset used for DF):
%   d      = |pos - T|,           nd = (pos - T)/d          (Tx -> Rx)
%   Q      = max(0, nt . nd)      (~1 at the nadir under the LED)
%   cospsi = max(0, -nr . nd)     (=1 when the PD is vertical)
%   eta    = mu / Q^m ,           mu = v_mean - v_dark
%   C_row  = eta * d^2 / cospsi
% C_nadir = median(C_row) over the matching rows.
%
% This is the experimental analogue of sub-dataset 2 (PD under the LED, LED at
% nadir, at known distances). It does NOT rely on the full-codebook fit, so it
% is a cleaner physical calibration than df_estimate_C (which uses all points
% and orientations). Feed the result via cfg.C_opt for the DF distance stage.
%
% opts fields (all optional):
%   .xyTol     under-LED tolerance on |x|,|y| [m]   (default 0.03)
%   .inclTol   nadir tolerance on LED inclination [deg] (default 1.0)
%   .v_dark    dark voltage subtracted from v_mean [V] (default 0)
%   .scanKind  '' = any scan (default) | 'vertical' = only PD-at-zenith rows

    if nargin < 4 || isempty(opts), opts = struct(); end
    if ~isfield(opts,'xyTol')    || isempty(opts.xyTol),    opts.xyTol    = 0.03; end
    if ~isfield(opts,'inclTol')  || isempty(opts.inclTol),  opts.inclTol  = 1.0;  end
    if ~isfield(opts,'v_dark')   || isempty(opts.v_dark),   opts.v_dark   = 0;    end
    if ~isfield(opts,'scanKind'),                           opts.scanKind = '';   end
    T = T(:);

    Tbl = df_load_master(dataFile);
    if ~isempty(opts.scanKind)
        Tbl = Tbl(strcmpi(strtrim(Tbl.scan_kind), opts.scanKind), :);
    end

    under = abs(Tbl.x) <= opts.xyTol & abs(Tbl.y) <= opts.xyTol;
    nadir = abs(Tbl.nt_incl) <= opts.inclTol;
    sel   = under & nadir & isfinite(Tbl.v_mean);
    S = Tbl(sel, :);
    n = height(S);

    C_all = nan(n, 1);
    for j = 1:n
        pos  = [S.x(j); S.y(j); S.z(j)];
        dvec = pos - T; d = norm(dvec);
        if d < 1e-9, continue; end
        nd = dvec / d;
        nt = df_angles_to_nt(S.nt_incl(j), S.nt_az(j));
        nr = df_angles_to_nr(S.nr_incl(j), S.nr_az(j));
        Q      = max(0,  nt.' * nd);
        cospsi = max(0, -nr.' * nd);
        mu     = max(S.v_mean(j) - opts.v_dark, 1e-6);
        if Q > 1e-6 && cospsi > 1e-6
            eta = mu / Q^m;
            C_all(j) = eta * d^2 / cospsi;
        end
    end
    C_all   = C_all(isfinite(C_all));
    C_nadir = median(C_all);

    info = struct('n_rows', n, 'n_used', numel(C_all), 'C_all', C_all, ...
                  'xyTol', opts.xyTol, 'inclTol', opts.inclTol, ...
                  'scanKind', opts.scanKind);
end
