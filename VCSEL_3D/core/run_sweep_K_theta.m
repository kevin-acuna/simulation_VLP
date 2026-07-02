function S = run_sweep_K_theta(theta_div_deg_list, K_list, positions, params, theta_cap_deg, cb_type)
% RUN_SWEEP_K_THETA  Evaluate coverage + PEB over a grid of (K, theta_div)
%
% For each divergence angle and each number of orientations, a spherical-cap
% codebook is generated and scored over the testbed via evaluate_codebook.
% This is the workhorse behind sim02/sim03/sim04.
%
% INPUTS:
%   theta_div_deg_list : vector of divergence half-angles [deg]
%   K_list             : vector of orientation counts
%   positions          : 3xP testbed positions
%   params             : struct for evaluate_codebook (see that function)
%   theta_cap_deg      : codebook spherical-cap half-angle [deg]
%   cb_type            : codebook type for generate_codebook ('sunflower'/'rings')
%
% OUTPUT (struct S), all matrices sized [numel(theta) x numel(K)]:
%   S.theta_deg, S.K            : the sweep axes
%   S.coverage, S.outage        : fractions (0..1)
%   S.mean_peb, S.p90_peb, S.median_peb : PEB over covered region [m]
%   S.mean_snr_dB               : mean peak SNR over covered region [dB]
%   S.theta_cap_deg, S.cb_type  : provenance

if nargin < 6 || isempty(cb_type),      cb_type = 'sunflower'; end
if nargin < 5 || isempty(theta_cap_deg), theta_cap_deg = 50;   end

nT = numel(theta_div_deg_list);
nK = numel(K_list);

S.theta_deg     = theta_div_deg_list(:)';
S.K             = K_list(:)';
S.coverage      = zeros(nT, nK);
S.outage        = zeros(nT, nK);
S.mean_peb      = nan(nT, nK);
S.p90_peb       = nan(nT, nK);
S.median_peb    = nan(nT, nK);
S.mean_snr_dB   = nan(nT, nK);
S.theta_cap_deg = theta_cap_deg;
S.cb_type       = cb_type;

for it = 1:nT
    theta_div = deg2rad(theta_div_deg_list(it));
    for ik = 1:nK
        K = K_list(ik);
        nt = generate_codebook(K, theta_cap_deg, cb_type);
        r  = evaluate_codebook(nt, theta_div, positions, params);

        S.coverage(it, ik)    = r.coverage;
        S.outage(it, ik)      = r.outage;
        S.mean_peb(it, ik)    = r.mean_peb;
        S.p90_peb(it, ik)     = r.p90_peb;
        S.median_peb(it, ik)  = r.median_peb;
        S.mean_snr_dB(it, ik) = r.mean_snr_dB;

        fprintf('  theta=%2d deg, K=%2d : cov=%5.1f%%, meanPEB=%6.2f cm, P90PEB=%6.2f cm\n', ...
            theta_div_deg_list(it), K, 100*r.coverage, 100*r.mean_peb, 100*r.p90_peb);
    end
end
end
