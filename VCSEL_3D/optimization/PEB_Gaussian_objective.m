function fitness = PEB_Gaussian_objective(orientation_vector, system_params, receiver_positions)
% PEB_Gaussian_objective - GA fitness for localization-oriented codebook design
%
% Encodes the coverage-accuracy trade-off (paper_plan §6.2) as a single scalar to
% MINIMIZE. Uncovered positions are clamped to a penalty PEB, so improving either
% coverage OR local accuracy lowers the fitness.
%
% INPUTS:
%   orientation_vector : 1x(2K) vector [theta1, rho1, ..., thetaK, rhoK] in DEGREES
%                        (nadir-referenced: n = [sin t cos r; sin t sin r; -cos t])
%   system_params      : struct with fields
%                          T, Pt, theta_div (rad), A_det, Psi_FOV (rad), sigma2, N, nr,
%                          SNR_min_dB, PEB_max_cov,
%                          PEB_penalty (m, e.g. 2.0), metric ('p90'|'mean'|'rms'|'max'),
%                          min_sep_deg (e.g. 3)
%   receiver_positions : 3xP testbed positions
%
% OUTPUT:
%   fitness : scalar (m) to minimize

K = numel(orientation_vector) / 2;

%% Orientation vector -> 3D unit vectors
nt = zeros(3, K);
for i = 1:K
    t = deg2rad(orientation_vector(2*i-1));
    r = deg2rad(orientation_vector(2*i));
    nt(:, i) = [sin(t)*cos(r); sin(t)*sin(r); -cos(t)];
end

%% Penalize degenerate configurations (near-duplicate / rank-deficient beams)
min_sep = getfielddef(system_params, 'min_sep_deg', 3);
PEB_penalty = getfielddef(system_params, 'PEB_penalty', 2.0);
for i = 1:K-1
    for j = i+1:K
        c = max(min(dot(nt(:,i), nt(:,j)), 1), -1);
        ang = rad2deg(acos(c));
        if ang < min_sep
            fitness = PEB_penalty * (2 + (min_sep - ang));   % strongly discouraged
            return;
        end
    end
end
if K >= 3 && rank(nt) < 3
    fitness = PEB_penalty * 3;
    return;
end

%% Evaluate coverage + PEB over the testbed
params = struct('T', system_params.T, 'Pt', system_params.Pt, ...
    'A_det', system_params.A_det, 'Psi_FOV', system_params.Psi_FOV, ...
    'sigma2', system_params.sigma2, 'N', system_params.N, 'nr', system_params.nr, ...
    'SNR_min_dB', system_params.SNR_min_dB, 'PEB_max_cov', system_params.PEB_max_cov);

warning('off', 'all');
try
    res = evaluate_codebook(nt, system_params.theta_div, receiver_positions, params);
catch
    warning('on', 'all');
    fitness = PEB_penalty * 3;
    return;
end
warning('on', 'all');

%% Effective PEB with outage clamp -> aggregate
eff = res.PEB;                        % 1xP (Inf on singular/outage)
eff(~res.covered) = PEB_penalty;      % uncovered -> penalty
eff = min(eff, PEB_penalty);          % cap covered-but-large too

metric = getfielddef(system_params, 'metric', 'mean');
switch lower(metric)
    case 'mean', fitness = mean(eff);
    case 'rms',  fitness = sqrt(mean(eff.^2));
    case 'p90',  fitness = prctile(eff, 90);
    case 'max',  fitness = max(eff);
    otherwise,   fitness = prctile(eff, 90);
end
end

function v = getfielddef(s, f, d)
if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
