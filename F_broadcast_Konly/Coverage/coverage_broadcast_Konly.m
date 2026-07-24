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
K               = 9;          % number of orientations/measurements: 5 or 9
theta_half_deg  = 36.7;         % LED half-power angle [deg]
z_analysis      = 1;        % analysis height for the coverage map [m]

% --- Optimized codebook to use (DEB/PEB-optimized for the broadcast proposal) ---
%   'DEB_45'       -> DEB-optimized at 45 deg    (K = 3..15)
%   'DEB_30'       -> DEB-optimized at 30 deg    (K = 3..10)
%   'PEB_37_QoS05' -> PEB-optimized at 36.7 deg, QoS=5 cm  (K = 5, 9)
%   'PEB_37_QoS10' -> PEB-optimized at 36.7 deg, QoS=10 cm (K = 5, 9)
orientation_preset = 'PEB_37_QoS05';

% --- Coverage QoS thresholds (a position is covered if BOTH are met) ---
PEB_max_cov = 0.05;           % max PEB_B to count as covered [m]
SNR_min_dB  = 10;             % min best-link SNR [dB]

% --- Grids ---
step_map    = 0.1;           % fine floor grid for the coverage map [m]
step_cov    = 0.1;           % grid for the coverage-vs-height sweep [m]
step_h      = 0.1;           % height step for the coverage-vs-height sweep [m]

% --- Coverage-map overlay (per-beam illumination footprints) ---
SHOW_BEAM_FOOTPRINTS = true;  % solid = SNR>=SNR_min footprint; dashed = -3 dB cone
SAVE_FIGS            = true; % true -> export PDF/PNG to Coverage/results/
% =====================================================================

%% Build the codebook and derived quantities
switch orientation_preset
    case 'DEB_45'
        presets = all_orientations_DEB;        Kvals = K_values;        % 3:15
    case 'DEB_30'
        presets = all_orientations_DEB_Phi30;  Kvals = K_values_Phi30;  % 3:10
    case 'PEB_37_QoS05'
        presets = all_orientations_PEB_QoS05;  Kvals = K_values_PEB;     % [5 9], QoS=5cm
    case 'PEB_37_QoS10'
        presets = all_orientations_PEB_QoS10;  Kvals = K_values_PEB;     % [5 9], QoS=10cm
    otherwise
        error('Unknown orientation_preset: %s', orientation_preset);
end
K_idx = find(Kvals == K, 1);
if isempty(K_idx)
    error('K=%d is not available in preset %s (available: %s).', ...
        K, orientation_preset, mat2str(Kvals));
end
nt = orient_to_vectors(presets{K_idx});
m  = -log(2) / log(cosd(theta_half_deg));      % Lambertian order for this beam

prm = struct('T', T(:), 'nr', n_r(:), 'Pt', P_t, 'A_det', A_det, ...
    'Psi_FOV', deg2rad(FOV), 'sigma2', sigma2, 'N', N_samples, ...
    'PEB_max_cov', PEB_max_cov, 'SNR_min_dB', SNR_min_dB);

fprintf('Broadcast (K-only) coverage | K=%d | theta_half=%d deg | z=%.2f m\n', ...
    K, theta_half_deg, z_analysis);
fprintf('  preset=%s | PEB_max=%.0f cm | SNR_min=%d dB\n', ...
    orientation_preset, PEB_max_cov*100, SNR_min_dB);

%% ===== Figure 1: coverage map (x-y) at z_analysis =====
xr = -L/2:step_map:L/2;   yr = -W/2:step_map:W/2;
[Xg, Yg] = meshgrid(xr, yr);
posMap   = [Xg(:)'; Yg(:)'; z_analysis*ones(1, numel(Xg))];
resMap   = evaluate_coverage_Konly(nt, m, posMap, prm);
mask     = reshape(resMap.covered, size(Xg));
covpc    = 100 * resMap.coverage;
fprintf('  cov_map coverage @ z=%.2f m : %.1f%%\n', z_analysis, covpc);

cmap2 = [0.93 0.93 0.93; 0.16 0.52 0.74];      % [uncovered ; covered]
fig_maps = figure('Units','inches', 'Position',[1 1 3.1 2.9], 'Color','w');
ax = axes(fig_maps);
imagesc(ax, xr*100, yr*100, double(mask));
set(ax, 'YDir','normal'); colormap(ax, cmap2); clim(ax, [0 1]);
axis(ax, 'equal', 'tight'); hold(ax, 'on');

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
        tc = (z_analysis - prm.T(3)) / nt(3, i);
        plot(ax, (prm.T(1)+tc*nt(1,i))*100, (prm.T(2)+tc*nt(2,i))*100, ...
            '.', 'Color', bcol(i,:), 'MarkerSize', 9);
    end
end

plot(ax, 0, 0, 'p', 'MarkerSize', 8, 'MarkerFaceColor', [1 0.85 0], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
text(ax, -L/2*100+8, W/2*100-14, sprintf('%.0f\\%%', covpc), 'Interpreter','latex', ...
    'FontSize', 9, 'FontWeight','bold', 'BackgroundColor',[1 1 1 0.6]);
hold(ax, 'off');
set(ax, 'FontName','Times New Roman', 'FontSize', 8, 'TickLabelInterpreter','latex', ...
    'Box','on', 'LineWidth', 0.5, 'XTick', [-150 0 150], 'YTick', [-150 0 150]);
xlabel(ax, '$x$ [cm]', 'Interpreter','latex', 'FontSize', 9);
ylabel(ax, '$y$ [cm]', 'Interpreter','latex', 'FontSize', 9);
title(ax, sprintf('Broadcast coverage @ $z=%.2f$ m ($K{=}%d$, $\\theta_{1/2}{=}%d^\\circ$)', ...
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
title(sprintf('Broadcast coverage vs height ($K{=}%d$, $\\theta_{1/2}{=}%d^\\circ$)', ...
    K, theta_half_deg), 'Interpreter','latex', 'FontSize', 9);

%% ===== Export =====
if SAVE_FIGS
    results_dir = fullfile(this_dir, 'results');
    if ~exist(results_dir, 'dir'), mkdir(results_dir); end
    tag = sprintf('K%d_th%d_z%02d', K, theta_half_deg, round(z_analysis*100));
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
