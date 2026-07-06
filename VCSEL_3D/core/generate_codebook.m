function nt = generate_codebook(K, theta_cap_deg, type)
% GENERATE_CODEBOOK  Build a set of K steered VCSEL orientations (nadir-referenced)
%
% Returns a 3xK matrix whose columns are unit orientation vectors pointing into
% a downward spherical cap of half-angle theta_cap (measured from nadir -z).
% This is the "uniform spherical-cap" baseline codebook of the research plan.
%
% INPUTS:
%   K             : number of orientations
%   theta_cap_deg : cap half-angle from nadir [deg]
%   type          : 'sunflower' (default) area-uniform Fibonacci spiral,
%                   'rings'     concentric rings + a boresight beam,
%                   'random'    area-uniform random beams in the cap
%                               (seed with rng() before calling for reproducibility),
%                   'dense'     naive uniform-ANGLE grid (scanning-style placement)
%
% OUTPUT:
%   nt : 3xK matrix of unit vectors. Nadir-referenced: n = [sin(t)cos(p); sin(t)sin(p); -cos(t)]
%
% NOTE: All beams point generally downward (negative z), consistent with a
%       ceiling-mounted steerable VCSEL and the F_broadcast_Konly convention.

if nargin < 3 || isempty(type)
    type = 'sunflower';
end
theta_cap = deg2rad(theta_cap_deg);
nt = zeros(3, K);

switch lower(type)
    case 'sunflower'
        % Area-uniform on the cap: polar angle ~ sqrt(fraction), golden-angle azimuth.
        golden = pi * (3 - sqrt(5));   % ~2.399963 rad
        for i = 1:K
            frac  = (i - 0.5) / K;             % in (0,1)
            theta = theta_cap * sqrt(frac);    % area-uniform mapping
            rho   = golden * (i - 1);
            nt(:, i) = [sin(theta)*cos(rho); sin(theta)*sin(rho); -cos(theta)];
        end

    case 'rings'
        % One boresight beam + concentric rings out to theta_cap.
        nt(:, 1) = [0; 0; -1];
        if K == 1, return; end
        n_rings = max(1, round(sqrt(K)));
        remaining = K - 1;
        idx = 2;
        for r = 1:n_rings
            theta = theta_cap * r / n_rings;
            n_this = round(remaining / (n_rings - r + 1));
            n_this = max(1, n_this);
            for j = 1:n_this
                if idx > K, break; end
                rho = 2*pi * (j - 1) / n_this + r * 0.4;  % offset each ring
                nt(:, idx) = [sin(theta)*cos(rho); sin(theta)*sin(rho); -cos(theta)];
                idx = idx + 1;
            end
            remaining = remaining - n_this;
        end
        % Fill any leftover (rounding) along the outer ring
        while idx <= K
            rho = 2*pi * rand;
            nt(:, idx) = [sin(theta_cap)*cos(rho); sin(theta_cap)*sin(rho); -cos(theta_cap)];
            idx = idx + 1;
        end

    case 'random'
        % Area-uniform random beams in the cap (baseline with placement variance).
        % Seed with rng() before calling for reproducible draws.
        for i = 1:K
            theta = theta_cap * sqrt(rand);   % area-uniform mapping
            rho   = 2*pi * rand;
            nt(:, i) = [sin(theta)*cos(rho); sin(theta)*sin(rho); -cos(theta)];
        end

    case 'dense'
        % Naive scanning-style placement: near-uniform grid in ANGLE (theta uniform,
        % NOT area-weighted), equal beams per ring. Oversamples near nadir vs area.
        n_rings = max(1, round(sqrt(K)));
        thetas  = linspace(theta_cap / n_rings, theta_cap, n_rings);
        edges   = round((0:n_rings) * K / n_rings);   % ~equal beams per ring
        idx = 1;
        for r = 1:n_rings
            nb = edges(r+1) - edges(r);
            for j = 1:nb
                if idx > K, break; end
                rho = 2*pi * (j - 1) / max(nb, 1) + 0.3*r;   % offset each ring
                nt(:, idx) = [sin(thetas(r))*cos(rho); sin(thetas(r))*sin(rho); -cos(thetas(r))];
                idx = idx + 1;
            end
        end
        while idx <= K   % fill any rounding leftover on the outer ring
            rho = 2*pi * (idx - 1) / K;
            nt(:, idx) = [sin(theta_cap)*cos(rho); sin(theta_cap)*sin(rho); -cos(theta_cap)];
            idx = idx + 1;
        end

    otherwise
        error('generate_codebook:type', 'Unknown codebook type "%s".', type);
end

% Normalize (guard against numerical drift)
nt = nt ./ vecnorm(nt);
end
