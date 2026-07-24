%% visualize_received_power_3D.m
% 3D visualization of the RECEIVED OPTICAL POWER distribution produced by a
% single steered LED beam on a horizontal plane at height z.
%
% Purpose: the coverage maps show a 2D top-down cut at a given height. This
% script shows the same physics as a 3D surface (the "power landscape") so you
% can SEE how the received power concentrates/decays and relate it to coverage:
%   - the surface height/color   = received power P_rx (dBm) [or linear uW]
%   - the translucent red plane  = P_rx level equivalent to SNR = SNR_min
%     (surface poking ABOVE the plane = would pass the illumination/SNR gate)
%   - the contour under the surface (surfc) = the 2D cut, for direct comparison
%   - a compact 2D heatmap panel = the top-down view (as in the coverage maps)
%
% Received-power model (single Lambertian beam, receiver normal n_r):
%   P_rx(r) = Pt (m+1) A_det /(2 pi) * cos^m(phi) * cos(psi) / d^2
%
% HYPERPARAMETERS (CONFIG block):
%   z_analysis      : plane height [m]
%   theta_half_deg  : LED half-power angle [deg]  -> Lambertian order m
%   tilt_deg        : LED inclination from nadir [deg]  (0 = straight down)
%   azimuth_deg     : LED azimuth from +x axis [deg]
%
% Author: Cascade (for Kevin Acuna-Condori) — Project: Proposal F, Broadcast OWP

close all; clc; clear;

%% Paths
this_dir     = fileparts(mfilename('fullpath'));
project_root = fileparts(this_dir);
addpath(this_dir);                               % system_params_coverage
% NOTE: parameters come from the COVERAGE-ONLY file below. Editing it affects
% ONLY this folder (it does NOT touch ../simulations/system_params_F.m).
system_params_coverage;                          % *** COVERAGE-ONLY parameters ***

% =====================================================================
%                          CONFIGURATION
% =====================================================================
z_analysis      = 0.8;        % plane height [m]
theta_half_deg  = 36.7;         % LED half-power angle [deg]
tilt_deg        = 30;         % LED inclination from nadir [deg]
azimuth_deg     = 0;          % LED azimuth from +x axis [deg]

step_map        = 0.03;       % floor grid step [m]
POWER_IN_DBM    = false;       % true -> surface in dBm ; false -> linear microwatt
SHOW_SNR_PLANE  = true;       % draw the SNR_min-equivalent power plane
SNR_min_dB      = 10;         % SNR threshold used for the reference plane [dB]
SAVE_FIG        = false;      % true -> export PNG/PDF to Coverage/results/
% =====================================================================

%% Geometry and radiometric field
nt = [sind(tilt_deg)*cosd(azimuth_deg); ...
      sind(tilt_deg)*sind(azimuth_deg); ...
     -cosd(tilt_deg)];
m  = -log(2) / log(cosd(theta_half_deg));
C  = P_t * (m + 1) * A_det / (2*pi);
Tc = T(:);  nrc = n_r(:);

xr = -L/2:step_map:L/2;   yr = -W/2:step_map:W/2;
[X, Y] = meshgrid(xr, yr);
dx = X - Tc(1);  dy = Y - Tc(2);  dz = z_analysis - Tc(3);
d  = sqrt(dx.^2 + dy.^2 + dz.^2);

cos_psi = (nrc(1)*(-dx) + nrc(2)*(-dy) + nrc(3)*(-dz)) ./ d;   % incidence at PD
cos_phi = (nt(1)*dx + nt(2)*dy + nt(3)*dz) ./ d;               % irradiance at LED
valid   = (cos_psi > 0) & (acos(min(1,max(-1,cos_psi))) <= deg2rad(FOV)) & (cos_phi > 0);

Prx = zeros(size(d));                                          % received power [W]
Prx(valid) = C .* cos_phi(valid).^m .* cos_psi(valid) ./ d(valid).^2;
SNR_dB = -inf(size(d));
SNR_dB(valid) = 10*log10(N_samples .* Prx(valid).^2 ./ sigma2);

% Received-power threshold equivalent to SNR_min
Prx_thr    = sqrt(sigma2 / N_samples * 10^(SNR_min_dB/10));    % [W]
covfrac    = 100 * mean(SNR_dB(:) >= SNR_min_dB);

% Surface quantity (dBm or uW), NaN where no illumination (for clean gaps)
if POWER_IN_DBM
    Z        = 10*log10(Prx/1e-3);   Z(Prx <= 0) = NaN;        % dBm
    Zthr     = 10*log10(Prx_thr/1e-3);
    zlab     = '$P_{\mathrm{rx}}$ [dBm]';
else
    Z        = Prx*1e6;              Z(Prx <= 0) = NaN;         % microwatt
    Zthr     = Prx_thr*1e6;
    zlab     = '$P_{\mathrm{rx}}$ [$\mu$W]';
end

% Beam-axis intersection with the plane
tc = (z_analysis - Tc(3)) / nt(3);
cx = Tc(1) + tc*nt(1);   cy = Tc(2) + tc*nt(2);

fprintf('Received-power 3D | z=%.2f m | theta_half=%d deg | tilt=%d deg, az=%d deg\n', ...
    z_analysis, theta_half_deg, tilt_deg, azimuth_deg);
fprintf('  peak P_rx = %.3f uW (%.1f dBm) | SNR>=%d dB over %.1f%% of the plane\n', ...
    max(Prx(:))*1e6, 10*log10(max(Prx(:))/1e-3), SNR_min_dB, covfrac);

%% Figure: 3D surface (left) + 2D top-down cut (right)
fig = figure('Units','inches', 'Position',[1 1 8.4 3.6], 'Color','w');
tl  = tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');

% ---- (a) 3D power landscape ----
ax1 = nexttile(tl);
surfc(ax1, X*100, Y*100, Z, 'EdgeColor','none'); hold(ax1, 'on');
colormap(ax1, turbo); shading(ax1, 'interp');
if SHOW_SNR_PLANE
    [xx, yy] = meshgrid([-L/2 L/2]*100, [-W/2 W/2]*100);
    surf(ax1, xx, yy, Zthr*ones(2), 'FaceColor',[0.75 0.1 0.1], ...
        'FaceAlpha',0.18, 'EdgeColor',[0.6 0.1 0.1], 'LineStyle',':');
    text(ax1, -L/2*100, W/2*100, Zthr, sprintf(' SNR$_{\\min}=%d$ dB', SNR_min_dB), ...
        'Interpreter','latex', 'FontSize', 8, 'Color',[0.6 0.1 0.1], 'VerticalAlignment','bottom');
end
zc = max(Z(:));
plot3(ax1, cx*100, cy*100, zc, 'kv', 'MarkerFaceColor','w', 'MarkerSize',6, 'LineWidth',1);
hold(ax1, 'off'); grid(ax1, 'on'); view(ax1, -37, 32);
xlabel(ax1, '$x$ [cm]', 'Interpreter','latex', 'FontSize', 10);
ylabel(ax1, '$y$ [cm]', 'Interpreter','latex', 'FontSize', 10);
zlabel(ax1, zlab, 'Interpreter','latex', 'FontSize', 10);
cb1 = colorbar(ax1); cb1.Label.Interpreter = 'latex'; cb1.Label.String = zlab;
set(ax1, 'FontName','Times New Roman', 'FontSize', 8, 'TickLabelInterpreter','latex');
title(ax1, '(a) 3D received-power landscape', 'Interpreter','latex', 'FontSize', 10);

% ---- (b) 2D top-down cut (as in the coverage maps) ----
ax2 = nexttile(tl);
imagesc(ax2, xr*100, yr*100, Z); set(ax2, 'YDir','normal');
colormap(ax2, turbo); axis(ax2, 'equal','tight'); hold(ax2, 'on');
% illumination footprint (SNR>=SNR_min) and half-power (-3 dB) cone
if any(SNR_dB(:) >= SNR_min_dB)
    contour(ax2, xr*100, yr*100, SNR_dB, [SNR_min_dB SNR_min_dB], 'w-', 'LineWidth', 1.6);
end
if any(cos_phi(:) >= cosd(theta_half_deg))
    contour(ax2, xr*100, yr*100, cos_phi, [cosd(theta_half_deg) cosd(theta_half_deg)], ...
        'w--', 'LineWidth', 1.0);
end
plot(ax2, cx*100, cy*100, 'kv', 'MarkerFaceColor','w', 'MarkerSize',6, 'LineWidth',1);
plot(ax2, 0, 0, 'p', 'MarkerSize',9, 'MarkerFaceColor',[1 0.85 0], 'MarkerEdgeColor','k');
hold(ax2, 'off');
xlabel(ax2, '$x$ [cm]', 'Interpreter','latex', 'FontSize', 10);
ylabel(ax2, '$y$ [cm]', 'Interpreter','latex', 'FontSize', 10);
cb2 = colorbar(ax2); cb2.Label.Interpreter = 'latex'; cb2.Label.String = zlab;
set(ax2, 'FontName','Times New Roman', 'FontSize', 8, 'TickLabelInterpreter','latex', ...
    'XTick',[-150 0 150], 'YTick',[-150 0 150]);
title(ax2, sprintf('(b) 2D cut (solid: SNR$\\geq%d$ dB, dashed: $-3$ dB)', SNR_min_dB), ...
    'Interpreter','latex', 'FontSize', 10);

title(tl, sprintf(['Received power @ $z=%.2f$ m --- $\\theta_{1/2}{=}%d^\\circ$, ' ...
    'tilt$=%d^\\circ$, az$=%d^\\circ$'], z_analysis, theta_half_deg, tilt_deg, azimuth_deg), ...
    'Interpreter','latex', 'FontSize', 11);

%% Export
if SAVE_FIG
    results_dir = fullfile(this_dir, 'results');
    if ~exist(results_dir, 'dir'), mkdir(results_dir); end
    tag = sprintf('z%02d_th%d_tilt%d_az%d', round(z_analysis*100), theta_half_deg, tilt_deg, azimuth_deg);
    exportgraphics(fig, fullfile(results_dir, ['rx_power_3D_' tag '.png']), 'Resolution',600, 'BackgroundColor','white');
    exportgraphics(fig, fullfile(results_dir, ['rx_power_3D_' tag '.pdf']), 'ContentType','vector', 'BackgroundColor','white');
    fprintf('Figure exported to %s\n', results_dir);
end
