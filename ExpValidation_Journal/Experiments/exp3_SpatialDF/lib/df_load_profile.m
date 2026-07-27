function prof = df_load_profile(profileDir, vdark)
% DF_LOAD_PROFILE  Build the LED radiation profile R(theta) from sub0_axis_sweep.
%
%   prof = df_load_profile(profileDir, vdark)
%
% The sub-dataset-0 axis sweep (sub0_axis_sweep.cpp) records the PD voltage
% while the LED gimbal sweeps a signed angle from -90 to +90 deg along the X
% and/or Y axis, with the PD fixed directly below the LED. The signed
% axis_angle is exactly the OFF-AXIS angle theta between the LED optical axis
% and the LED->PD direction, so v_mean(theta) is the (unnormalized) radiation
% pattern R(theta). This is precisely the profile the NLS estimator can use in
% place of the Lambertian cos^m(theta) model.
%
% This function:
%   * reads data_x.csv and/or data_y.csv,
%   * subtracts the dark voltage (arg > metadata v_dark_mean > 0),
%   * folds the sweep to |theta|, averages the (+/-X, +/-Y) branches per 1-deg
%     bin and normalizes so R(0) = 1,
%   * fits a Lambertian order m (log-linear LS on the main lobe),
%   * returns an interpolant Rfun(theta_rad) on [0, pi/2] (0 beyond).
%
% Output struct fields:
%   .theta_deg, .R        normalized profile samples (R in [0,1])
%   .Rfun                 @(theta_rad) -> normalized radiance (clamped to [0,1])
%   .m_fit                fitted Lambertian order
%   .theta_half_deg       half-power angle (R = 0.5)
%   .vdark, .R0, .files   provenance

    if nargin < 2, vdark = []; end

    fx = fullfile(profileDir, 'data_x.csv');
    fy = fullfile(profileDir, 'data_y.csv');
    files = {};
    if isfile(fx), files{end+1} = fx; end
    if isfile(fy), files{end+1} = fy; end
    assert(~isempty(files), 'No data_x.csv / data_y.csv found in %s', profileDir);

    if isempty(vdark)
        vdark = local_read_vdark(fullfile(profileDir, 'metadata.txt'));
    end

    ang = []; v = [];
    for i = 1:numel(files)
        T = readtable(files{i});
        ang = [ang; T.axis_angle(:)];   %#ok<AGROW>
        v   = [v;   T.v_mean(:)];        %#ok<AGROW>
    end
    good = isfinite(ang) & isfinite(v);
    ang = ang(good); v = v(good);

    sig    = v - vdark;                 % dark-subtracted signal
    R0     = max(sig);                  % peak (theta ~ 0)
    if R0 <= 0, R0 = max(v); end
    Rn_raw = max(0, sig / R0);          % normalized, clamp >= 0
    th_abs = abs(ang);                  % fold to |theta|

    % average duplicate |theta| bins (the up-to-4 half-axes) at 1-deg resolution
    bins = round(th_abs);
    [thg, ~, ic] = unique(bins);
    Rn = accumarray(ic, Rn_raw, [], @mean);
    [thg, is] = sort(thg); Rn = Rn(is);
    keep = thg >= 0 & thg <= 90;
    thg = thg(keep); Rn = min(1, max(0, Rn(keep)));

    % --- Lambertian order fit: Rn = cos(theta)^m  (log-linear LS through origin)
    th_rad  = deg2rad(thg);
    fitsel  = thg >= 3 & thg <= 55 & Rn > 0.05;
    xlg = log(cos(th_rad(fitsel)));
    ylg = log(Rn(fitsel));
    m_fit = (xlg.' * ylg) / (xlg.' * xlg);

    % --- half-power angle (first downward crossing of 0.5)
    theta_half = local_cross(thg, Rn, 0.5);

    % --- interpolant on [0, pi/2], forced to 1 at 0 and 0 at 90 deg
    thq = [0; th_rad(:); pi/2];
    Rq  = [1; Rn(:);     0];
    [thq, iu] = unique(thq); Rq = Rq(iu);
    F = griddedInterpolant(thq, Rq, 'pchip', 'nearest');
    Rfun = @(th) max(0, min(1, F(min(max(th, 0), pi/2))));

    prof = struct('theta_deg', thg(:), 'R', Rn(:), 'Rfun', Rfun, ...
        'm_fit', m_fit, 'theta_half_deg', theta_half, ...
        'vdark', vdark, 'R0', R0, 'files', {files});
end

% --- locals ---------------------------------------------------------------
function vd = local_read_vdark(mfile)
    vd = 0;
    if ~isfile(mfile), return; end
    txt = fileread(mfile);
    tok = regexp(txt, 'v_dark_mean\s*=\s*([-\d.eE+]+)', 'tokens', 'once');
    if ~isempty(tok)
        x = str2double(tok{1});
        if isfinite(x), vd = x; end
    end
end

function xc = local_cross(x, y, lvl)
    xc = NaN;
    idx = find(y < lvl, 1, 'first');
    if isempty(idx) || idx == 1, return; end
    x1 = x(idx-1); x2 = x(idx);
    y1 = y(idx-1); y2 = y(idx);
    if y2 == y1, xc = x2; else, xc = x1 + (lvl - y1) * (x2 - x1) / (y2 - y1); end
end
