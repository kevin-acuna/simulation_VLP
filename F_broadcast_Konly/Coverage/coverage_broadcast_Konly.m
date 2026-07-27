%% coverage_broadcast_Konly.m
% Positioning-service coverage for the BROADCAST (K-only) OWP proposal.
% Everything is recovered from the K steered-orientation measurements alone
% (no cooperative / distance-recovery measurement) via core/PEB_Konly.m.
%
% This is the light-weight coverage view (NOT the detailed study): it produces
% only two figures for a single operating point chosen by the user:
%     (1) cov_maps   : coverage map on the x-y plane at the analysis height
%     (2) cov_height : coverage fraction vs receiver height
%
% HYPERPARAMETERS (set by the user in the CONFIG block):
%     K               : number of measurements/orientations (5 or 9)
%     theta_half_deg  : LED half-power angle [deg]
%     z_analysis      : analysis height for the coverage map [m]
%
% Author: Cascade (for Kevin Acuna-Condori) — Project: Proposal F, Broadcast OWP

close all; clc; clear;

%% Paths
this_dir     = fileparts(mfilename('fullpath'));
project_root = fileparts(this_dir);
addpath(fullfile(project_root, 'core'));         % PEB_Konly
addpath(this_dir);                               % evaluate_coverage_Konly + params
% NOTE: parameters come from the COVERAGE-ONLY file below. Editing it affects
% ONLY this folder (it does NOT touch ../simulations/system_params_F.m).
system_params_coverage;                          % *** COVERAGE-ONLY parameters ***

% =====================================================================
%                          CONFIGURATION
% =====================================================================
% --- Operating point (hyperparameters) ---
theta_half_deg  = 36.7;      % LED half-power angle [deg]
z_analysis      = 1.0;         % analysis height for the coverage map [m]

% --- Orientation codebook (PASTE YOUR SET HERE) ---
% Paste a flat vector of [theta, phi] pairs in degrees (theta = tilt from
% nadir, phi = azimuth). The number of orientations K is derived AUTOMATICALLY
% as numel(orientation_set)/2 -- no need to set K by hand. Ready-made examples
% live in system_params_coverage.m (e.g. orientations_PEB_K5_QoS10).
orientation_set = orientation_PEB_K5_FINAL;

% --- Coverage QoS thresholds (a position is covered if BOTH are met) ---
PEB_max_cov = 0.1;           % max PEB_B to count as covered [m]
SNR_min_dB  = 10;             % min best-link SNR [dB]

% --- Grids ---
step_map    = 0.05;           % fine floor grid for the coverage map [m]
step_cov    = 0.1;           % grid for the coverage-vs-height sweep [m]
step_h      = 0.1;           % height step for the coverage-vs-height sweep [m]

% --- Coverage-map overlay (per-beam illumination footprints) ---
SHOW_BEAM_FOOTPRINTS = true;  % solid = SNR>=SNR_min footprint; dashed = -3 dB cone
SAVE_FIGS            = true; % true -> export PDF/PNG to Coverage/results/
% =====================================================================

%% Build the codebook and derived quantities
if mod(numel(orientation_set), 2) ~= 0
    error(['orientation_set must have an even number of entries: it is a ' ...
           'flat list of [theta,phi] pairs in degrees.']);
end
K  = numel(orientation_set) / 2;               % number of orientations (auto)
nt = orient_to_vectors(orientation_set);
m  = -log(2) / log(cosd(theta_half_deg));      % Lambertian order for this beam

prm = struct('T', T(:), 'nr', n_r(:), 'Pt', P_t, 'A_det', A_det, ...
    'Psi_FOV', deg2rad(FOV), 'sigma2', sigma2, 'N', N_samples, ...
    'PEB_max_cov', PEB_max_cov, 'SNR_min_dB', SNR_min_dB);

fprintf('Broadcast (K-only) coverage | K=%d | theta_half=%g deg | z=%.2f m\n', ...
    K, theta_half_deg, z_analysis);
fprintf('  PEB_max=%.0f cm | SNR_min=%d dB\n', PEB_max_cov*100, SNR_min_dB);

%% ===== Figure 1: coverage map (x-y) at z_analysis =====
xr = -L/2:step_map:L/2;   yr = -W/2:step_map:W/2;
[Xg, Yg] = meshgrid(xr, yr);
posMap   = [Xg(:)'; Yg(:)'; z_analysis*ones(1, numel(Xg))];
resMap   = evaluate_coverage_Konly(nt, m, posMap, prm);
mask     = reshape(resMap.covered, size(Xg));
covpc    = 100 * resMap.coverage;
fprintf('  cov_map coverage @ z=%.2f m : %.1f%%\n', z_analysis, covpc);

cmap2 = [1 1 1; 0.90 0.94 0.98];               % [uncovered (white) ; covered (faint blue)]
fig_maps = figure('Units','inches', 'Position',[1 1 3.1 2.9], 'Color','w');
ax = axes(fig_maps);
imagesc(ax, xr*100, yr*100, double(mask));
set(ax, 'YDir','normal'); colormap(ax, cmap2); clim(ax, [0 1]);
axis(ax, 'equal'); hold(ax, 'on');

if SHOW_BEAM_FOOTPRINTS
    bcol = turbo(max(K, 2));
    for i = 1:K
        [SNRdB, cosphi] = beam_snr_field(nt(:, i), m, Xg, Yg, z_analysis, prm);
        if any(SNRdB(:) >= SNR_min_dB)
            contour(ax, xr*100, yr*100, SNRdB, [SNR_min_dB SNR_min_dB], ...
                'LineColor', bcol(i,:), 'LineWidth', 1.1);
        end
        if any(cosphi(:) >= cosd(theta_half_deg))
            contour(ax, xr*100, yr*100, cosphi, [cosd(theta_half_deg) cosd(theta_half_deg)], ...
                'LineColor', bcol(i,:), 'LineStyle', '--', 'LineWidth', 0.6);
        end
    end
end

plot(ax, 0, 0, 'p', 'MarkerSize', 8, 'MarkerFaceColor', [1 0.85 0], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
text(ax, -L/2*100+8, W/2*100-14, sprintf('%.0f\\%%', covpc), 'Interpreter','latex', ...
    'FontSize', 9, 'FontWeight','bold', 'BackgroundColor',[1 1 1 0.6]);
hold(ax, 'off');
xlim(ax, [-L/2 L/2]*100); ylim(ax, [-W/2 W/2]*100);   % clamp to room (no de-scaling)
set(ax, 'FontName','Times New Roman', 'FontSize', 8, 'TickLabelInterpreter','latex', ...
    'Box','on', 'LineWidth', 0.5, 'XTick', [-150 0 150], 'YTick', [-150 0 150]);
xlabel(ax, '$x$ [cm]', 'Interpreter','latex', 'FontSize', 9);
ylabel(ax, '$y$ [cm]', 'Interpreter','latex', 'FontSize', 9);
title(ax, sprintf('Broadcast coverage @ $z=%.2f$ m ($K{=}%d$, $\\theta_{1/2}{=}%g^\\circ$)', ...
    z_analysis, K, theta_half_deg), 'Interpreter','latex', 'FontSize', 9);

%% ===== Figure 2: coverage vs height =====
xc = -L/2:step_cov:L/2;   yc = -W/2:step_cov:W/2;
[Xc, Yc] = meshgrid(xc, yc);
z_vals = 0:step_h:Hmax;
cov_z  = zeros(size(z_vals));
for iz = 1:numel(z_vals)
    pz = [Xc(:)'; Yc(:)'; z_vals(iz)*ones(1, numel(Xc))];
    r  = evaluate_coverage_Konly(nt, m, pz, prm);
    cov_z(iz) = 100 * r.coverage;
end

fig_height = figure('Units','inches', 'Position',[1 1 3.6 2.7], 'Color','w'); hold on;
plot(z_vals*100, cov_z, '-o', 'LineWidth', 1.4, 'MarkerSize', 4, ...
    'Color', [0.16 0.52 0.74], 'MarkerFaceColor', [0.16 0.52 0.74]);
xline(z_analysis*100, '--', 'Interpreter','latex', 'Color',[0.4 0.4 0.4]);
xlabel('Height $z$ [cm]', 'Interpreter','latex', 'FontSize', 9);
ylabel('Coverage [\%]', 'Interpreter','latex', 'FontSize', 9);
ylim([0 100]); grid on; box on;
set(gca, 'FontName','Times New Roman', 'FontSize', 8, 'TickLabelInterpreter','latex');
title(sprintf('Broadcast coverage vs height ($K{=}%d$, $\\theta_{1/2}{=}%g^\\circ$)', ...
    K, theta_half_deg), 'Interpreter','latex', 'FontSize', 9);

%% ===== Export =====
if SAVE_FIGS
    results_dir = fullfile(this_dir, 'results');
    if ~exist(results_dir, 'dir'), mkdir(results_dir); end
    th_str = strrep(sprintf('%g', theta_half_deg), '.', 'p');   % 36.7 -> 36p7 (clean filename)
    tag = sprintf('K%d_th%s_z%02d', K, th_str, round(z_analysis*100));
    exportgraphics(fig_maps,   fullfile(results_dir, ['cov_maps_'   tag '.png']), 'Resolution',600, 'BackgroundColor','white');
    exportgraphics(fig_maps,   fullfile(results_dir, ['cov_maps_'   tag '.pdf']), 'ContentType','vector', 'BackgroundColor','white');
    exportgraphics(fig_height, fullfile(results_dir, ['cov_height_' tag '.png']), 'Resolution',600, 'BackgroundColor','white');
    exportgraphics(fig_height, fullfile(results_dir, ['cov_height_' tag '.pdf']), 'ContentType','vector', 'BackgroundColor','white');
    fprintf('Figures exported to %s\n', results_dir);
end

%% ===== Local functions =====
function [SNRdB, cosphi] = beam_snr_field(nt_i, m, Xg, Yg, z, prm)
% Per-beam averaged-measurement SNR field (dB) and irradiance-angle cosine field
% on the analysis plane, for the Lambertian LED beam with axis nt_i.
    T  = prm.T;
    Cb = prm.Pt * (m + 1) * prm.A_det / (2 * pi);
    dx = Xg - T(1);  dy = Yg - T(2);  dz = z - T(3);
    d  = sqrt(dx.^2 + dy.^2 + dz.^2);

    cos_psi = -dz ./ d .* sign(prm.nr(3));    % nr assumed ~ [0;0;1]
    cphi    = (nt_i(1).*dx + nt_i(2).*dy + nt_i(3).*dz) ./ d;
    inFOV   = cos_psi > 0 & acos(min(1, max(-1, cos_psi))) <= prm.Psi_FOV;
    valid   = inFOV & cphi > 0;

    mu = zeros(size(d));
    mu(valid) = Cb .* cphi(valid).^m .* cos_psi(valid) ./ d(valid).^2;
    SNRlin = prm.N .* mu.^2 ./ prm.sigma2;

    SNRdB = -inf(size(d));
    pmask = SNRlin > 0;  SNRdB(pmask) = 10 * log10(SNRlin(pmask));

    cosphi = nan(size(d));
    cosphi(valid) = cphi(valid);
end
