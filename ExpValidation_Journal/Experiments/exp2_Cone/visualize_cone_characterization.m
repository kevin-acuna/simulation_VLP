% =========================================================================
%  visualize_cone_characterization.m
% -------------------------------------------------------------------------
%  Visualization of the radiometric characterization of an LED radiation
%  pattern (sub-dataset 1, axis B of ExpValidation_Journal).
%
%  The LED is steered to different inclination (phi_cmd) and azimuth
%  (azimuth_cmd) angles while the photodiode (PD) stays fixed at d = 1 m.
%  The recorded mean voltage (v_mean) is proportional to the LED radiant
%  intensity in that direction, so the sweep reconstructs the real
%  R(phi, azimuth) profile of the LED.
%
%  Generates:
%    (3D) Radiation lobe (balloon)               -> Fig_3D_RadiationLobe
%    (3D) Illumination cone/dome (fixed radius)  -> Fig_3D_IlluminationCone
%    (2D) Polar pattern R(phi) with azimuth cuts -> Fig_2D_PolarPattern
%    (2D) Cartesian R(phi) + Lambertian fit      -> Fig_2D_LambertianFit
%    (2D) Polar heatmap (top view)               -> Fig_2D_PolarHeatmap
%
%  Author: Kevin  |  Project: simulation_VLP / ExpValidation_Journal
% =========================================================================

clear; clc; close all;

%% ------------------------------------------------------------------ CONFIG
% Path to the data file. If left empty, the most recent session inside
% sub1_radiometric is used automatically.
cfg.dataFile       = '';          % e.g. fullfile(pwd,'sub1_radiometric','20260722_182801','data.csv')
cfg.subtractDark   = false;       % true => use (v_dark - v_mean); see note below
cfg.vDark          = 0.05;        % dark voltage [V]
cfg.saveFigures    = true;        % MASTER switch: save ALL images (PNG 300 dpi + PDF) or not
cfg.figFormats     = {'png','pdf'};
cfg.azimuthCutsDeg = 0:45:315;    % azimuth cuts shown in the polar pattern [deg]
cfg.fontName       = 'Times New Roman';
cfg.fontSize       = 14;
cfg.cmap           = turbo;       % perceptually uniform colormap

% NOTE on v_dark: subtracting the metadata dark value inverts the pattern
% (maximum off-axis), which is physically impossible for an LED. Hence
% v_mean is used DIRECTLY as radiant intensity. Keep cfg.subtractDark = false
% unless a valid dark measurement is available.

%% ------------------------------------------------------------- LOCATE DATA
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end

if isempty(cfg.dataFile)
    sessions = dir(fullfile(thisDir, 'sub1_radiometric', '2*'));
    sessions = sessions([sessions.isdir]);
    assert(~isempty(sessions), 'No sessions found in sub1_radiometric.');
    [~, idx] = max([sessions.datenum]);
    cfg.dataFile = fullfile(sessions(idx).folder, sessions(idx).name, 'data.csv');
end
assert(isfile(cfg.dataFile), 'File not found: %s', cfg.dataFile);
sessionDir = fileparts(cfg.dataFile);
outDir     = fullfile(sessionDir, 'figures');
if cfg.saveFigures && ~exist(outDir, 'dir'); mkdir(outDir); end
fprintf('Data      : %s\n', cfg.dataFile);
fprintf('Figures ->: %s\n', outDir);

%% --------------------------------------------------------------------- LOAD
T = readtable(cfg.dataFile);
phi = T.phi_cmd(:);           % commanded inclination [deg]
az  = T.azimuth_cmd(:);       % commanded azimuth      [deg]
V   = T.v_mean(:);            % mean voltage           [V]
if any(strcmp('v_std', T.Properties.VariableNames))
    Vstd = T.v_std(:);
else
    Vstd = zeros(size(V));
end

% Effective optical signal
if cfg.subtractDark
    signal = cfg.vDark - V;   % (only if the dark is properly characterized)
else
    signal = V;
end

%% ------------------------------------------- RECONSTRUCT GRID (phi x az)
phiU = unique(phi);                 % 0,2,...,70
azU  = unique(az);                  % 0,2,...,358
nP   = numel(phiU);
nA   = numel(azU);

Vg = nan(nP, nA);                   % voltage/signal on grid
Sg = nan(nP, nA);                   % standard deviation on grid
for k = 1:numel(signal)
    i = find(phiU == phi(k), 1);
    j = find(azU  == az(k),  1);
    Vg(i, j) = signal(k);
    Sg(i, j) = Vstd(k);
end

% Boresight (phi = 0) is usually recorded at a single azimuth: replicate by
% definition (at phi=0 the intensity is azimuth-independent).
row0 = find(phiU == 0, 1);
if ~isempty(row0)
    v0 = mean(Vg(row0, :), 'omitnan');
    Vg(row0, isnan(Vg(row0, :))) = v0;
end
% Fill isolated gaps by azimuthal interpolation
for i = 1:nP
    r = Vg(i, :);
    if any(isnan(r)) && any(~isnan(r))
        good = ~isnan(r);
        r(~good) = interp1(azU(good), r(good), azU(~good), 'linear', 'extrap');
        Vg(i, :) = r;
    end
end

%% ------------------------------------------ NORMALIZATION & 1D METRICS
Vmax   = max(Vg(:));
Rg     = Vg / Vmax;                 % normalized pattern [0,1]
Rmean  = mean(Rg, 2, 'omitnan');    % azimuthal average R(phi)
Rstd   = std(Rg, 0, 2, 'omitnan');  % azimuthal spread
Rmin   = min(Rg, [], 2, 'omitnan');
Rmax   = max(Rg, [], 2, 'omitnan');

% Half-power angle (HPBW): R = 0.5
phi_half = NaN;
if min(Rmean) < 0.5 && max(Rmean) > 0.5
    [Rm_s, is]  = sort(Rmean);          % ascending for monotonic interp1
    phiU_s      = phiU(is);
    [Rm_u, iu]  = unique(Rm_s);
    phi_half    = interp1(Rm_u, phiU_s(iu), 0.5, 'pchip');
end

% Lambertian fit R(phi) = cos^m(phi) (least squares in log scale)
phi_rad = deg2rad(phiU);
valid   = phi_rad > 0 & Rmean > 0.02 & cos(phi_rad) > 0;
xlog    = log(cos(phi_rad(valid)));
ylog    = log(Rmean(valid));
m_lamb  = sum(xlog .* ylog) / sum(xlog .^ 2);       % Lambertian order
% Theoretical Lambertian semi-angle for that m
phi_half_lamb = rad2deg(acos(2^(-1/m_lamb)));
m_lamb = -log(2)/log(cosd(phi_half));
Rfit    = cos(phi_rad) .^ m_lamb;

fprintf('\n--- Radiation pattern metrics ---\n');
fprintf('  V_max (boresight)       : %.4f V\n', Vmax);
fprintf('  Lambertian order m      : %.2f\n', m_lamb);
fprintf('  HPBW semi-angle (data)  : %.2f deg\n', phi_half);
fprintf('  HPBW semi-angle (Lamb.) : %.2f deg\n', phi_half_lamb);
fprintf('  Full width at -3 dB     : %.2f deg\n', 2*phi_half);
fprintf('---------------------------------\n\n');

%% ------------------------------------------ PLOT MESHES (closed azimuth)
azC   = [azU; azU(1) + 360];         % close azimuth (0 -> 360)
[AA, PP] = meshgrid(deg2rad(azC), deg2rad(phiU));
Rc    = [Rg, Rg(:, 1)];              % closed pattern
Vc    = [Vg, Vg(:, 1)];

% Cartesian coordinates of the radiation lobe (radius = R)
Xl = Rc .* sin(PP) .* cos(AA);
Yl = Rc .* sin(PP) .* sin(AA);
Zl = Rc .* cos(PP);

% Coordinates of the illumination cone/dome (fixed radius = 1, color = R)
Xc = sin(PP) .* cos(AA);
Yc = sin(PP) .* sin(AA);
Zc = cos(PP);

%% ============================ FIGURE 1: 3D RADIATION LOBE ================
f1 = newFig('3D radiation lobe', [100 100 760 640]);
surf(Xl, Yl, Zl, Rc, 'EdgeColor', 'none', 'FaceColor', 'interp', ...
     'FaceAlpha', 0.97);
hold on;
% Optical axis (boresight)
plot3([0 0], [0 0], [0 1.05], 'k--', 'LineWidth', 1.2);
text(0, 0, 1.12, 'Optical axis', 'HorizontalAlignment', 'center', ...
     'FontName', cfg.fontName, 'FontSize', cfg.fontSize-2, 'Interpreter','none');
hold off;
axis equal; grid on; box on;
colormap(gca, cfg.cmap);
cb = colorbar; cb.Label.String = 'Normalized intensity  R';
cb.Label.Interpreter = 'latex'; cb.Label.FontSize = cfg.fontSize;
xlabel('x', 'Interpreter','latex'); ylabel('y', 'Interpreter','latex');
zlabel('z  (optical axis)', 'Interpreter','latex');
title('3D LED radiation pattern  (radius $=R$)', 'Interpreter','latex');
view(135, 22); camlight headlight; lighting gouraud; material dull;
styleAxis(gca, cfg);

%% ==================== FIGURE 2: 3D ILLUMINATION CONE / DOME ==============
f2 = newFig('3D illumination cone', [140 120 760 640]);
surf(Xc, Yc, Zc, Rc, 'EdgeColor', 'none', 'FaceColor', 'interp');
hold on;
% Cone rays from the origin
th_ray = deg2rad(max(phiU));
for a = 0:45:315
    ar = deg2rad(a);
    plot3([0 sin(th_ray)*cos(ar)], [0 sin(th_ray)*sin(ar)], ...
          [0 cos(th_ray)], 'Color', [0.4 0.4 0.4], 'LineWidth', 0.6);
end
plot3(0, 0, 0, 'k.', 'MarkerSize', 14);
plot3([0 0], [0 0], [0 1.05], 'k--', 'LineWidth', 1.2);
hold off;
axis equal; grid on; box on;
colormap(gca, cfg.cmap);
cb = colorbar; cb.Label.String = 'Normalized intensity  R';
cb.Label.Interpreter = 'latex'; cb.Label.FontSize = cfg.fontSize;
xlabel('x', 'Interpreter','latex'); ylabel('y', 'Interpreter','latex');
zlabel('z  (optical axis)', 'Interpreter','latex');
title(sprintf('LED illumination cone  ($\\phi \\leq %d^\\circ$)', ...
      max(phiU)), 'Interpreter','latex');
view(135, 25); camlight headlight; lighting gouraud; material dull;
styleAxis(gca, cfg);

%% ==================== FIGURE 3: POLAR PATTERN R(phi) =====================
f3 = newFig('Polar pattern R(phi)', [180 140 720 680]);
% Representative azimuth cuts + azimuthal average
cutsDeg = cfg.azimuthCutsDeg;
pax = polaraxes; hold(pax, 'on');
colOrder = lines(numel(cutsDeg));
lg = strings(0);
for c = 1:numel(cutsDeg)
    [~, jc] = min(abs(azU - cutsDeg(c)));
    polarplot(pax, deg2rad(phiU), Rg(:, jc), '-', 'LineWidth', 1.2, ...
              'Color', colOrder(c,:));
    lg(end+1) = sprintf('Azimuth %d^\\circ', cutsDeg(c)); %#ok<SAGROW>
end
polarplot(pax, deg2rad(phiU), Rmean, 'k-', 'LineWidth', 2.4);
lg(end+1) = 'Azimuthal average';
pax.ThetaZeroLocation = 'top';
pax.ThetaDir          = 'clockwise';
pax.ThetaLim          = [0 max(phiU)+2];
pax.RLim              = [0 1];
pax.RTick             = 0:0.1:1;      % radial ticks every 0.1
pax.FontName          = cfg.fontName;
pax.FontSize          = cfg.fontSize - 1;
title(pax, 'Polar radiation pattern  R(\phi)', ...
      'FontName', cfg.fontName, 'FontSize', cfg.fontSize+1);
legend(pax, lg, 'Location', 'southoutside', 'NumColumns', 3, ...
       'FontSize', cfg.fontSize-3);

%% ============ FIGURE 4: CARTESIAN R(phi) + LAMBERTIAN FIT ================
f4 = newFig('R(phi) and Lambertian fit', [220 160 860 600]);
ax = axes; hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
% Azimuthal spread band (min-max)
fill([phiU; flipud(phiU)], [Rmin; flipud(Rmax)], [0.80 0.86 0.95], ...
     'EdgeColor', 'none', 'FaceAlpha', 0.6);
% Mean +- std
hMean = plot(phiU, Rmean, 'b-', 'LineWidth', 2.2);
plot(phiU, Rmean+Rstd, 'b:', 'LineWidth', 0.8);
plot(phiU, Rmean-Rstd, 'b:', 'LineWidth', 0.8);
% Lambertian fit
hFit = plot(phiU, Rfit, 'r--', 'LineWidth', 2.0);
% Half-power markers
if ~isnan(phi_half)
    yline(0.5, 'k:', 'LineWidth', 1.0);
    xline(phi_half, 'k-.', 'LineWidth', 1.2);
    plot(phi_half, 0.5, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
    text(phi_half+1, 0.54, sprintf('\\phi_{1/2}=%.1f^\\circ', phi_half), ...
         'FontName', cfg.fontName, 'FontSize', cfg.fontSize-1);
end
hold(ax, 'off');
xlabel('Irradiance angle  $\phi$ (deg)', 'Interpreter','latex');
ylabel('Normalized intensity  $R(\phi)$', 'Interpreter','latex');
title('Measured radiometric profile vs. Lambertian model', 'Interpreter','latex');
legend([hMean hFit], {'Measured (azimuthal mean $\pm$ envelope)', ...
       sprintf('Lambertian $\\cos^{%.1f}(\\phi)$', m_lamb)}, ...
       'Interpreter','latex', 'Location','northeast', 'FontSize', cfg.fontSize-1);
xlim([0 max(phiU)]); ylim([0 1.02]);
styleAxis(ax, cfg);

%% ============ FIGURE 5: POLAR HEATMAP (TOP VIEW) =========================
f5 = newFig('Polar heatmap (top view)', [260 180 760 680]);
% Flat surface in (x,y) with x=phi*cos(az), y=phi*sin(az); color=R
Xh = rad2deg(PP) .* cos(AA);   % radius = phi in degrees
Yh = rad2deg(PP) .* sin(AA);
surf(Xh, Yh, zeros(size(Rc)), Rc, 'EdgeColor', 'none');
view(2); axis equal tight; box on;
colormap(gca, cfg.cmap);
cb = colorbar; cb.Label.String = 'Normalized intensity  R';
cb.Label.Interpreter = 'latex'; cb.Label.FontSize = cfg.fontSize;
hold on;
% phi reference circles
for pr = 10:10:max(phiU)
    tt = linspace(0, 2*pi, 200);
    plot3(pr*cos(tt), pr*sin(tt), ones(size(tt)), ':', ...
          'Color', [1 1 1], 'LineWidth', 0.7);
    text(0, pr, 1, sprintf('%d^\\circ', pr), 'Color','w', ...
         'FontName', cfg.fontName, 'FontSize', cfg.fontSize-3, ...
         'HorizontalAlignment','center');
end
hold off;
xlabel('$\phi\cos(\mathrm{az})$ (deg)', 'Interpreter','latex');
ylabel('$\phi\sin(\mathrm{az})$ (deg)', 'Interpreter','latex');
title('Top view of the cone  (radius $=\phi$, color $=R$)', 'Interpreter','latex');
styleAxis(gca, cfg);

%% ------------------------------------------------------------- SAVE FIGURES
if cfg.saveFigures
    % Figures with dense meshes -> rasterized PDF (avoids huge files)
    saveFig(f1, fullfile(outDir, 'Fig_3D_RadiationLobe'),    cfg, true);
    saveFig(f2, fullfile(outDir, 'Fig_3D_IlluminationCone'), cfg, true);
    saveFig(f5, fullfile(outDir, 'Fig_2D_PolarHeatmap'),     cfg, true);
    % Line plots -> vector PDF (publication quality)
    saveFig(f3, fullfile(outDir, 'Fig_2D_PolarPattern'),     cfg, false);
    saveFig(f4, fullfile(outDir, 'Fig_2D_LambertianFit'),    cfg, false);
    fprintf('Figures saved to: %s\n', outDir);
else
    fprintf('Saving disabled (cfg.saveFigures = false).\n');
end

%% ==================== LOCAL FUNCTIONS ====================================
function f = newFig(name, pos)
    f = figure('Name', name, 'Color', 'w', 'Position', pos);
end

function styleAxis(ax, cfg)
    set(ax, 'FontName', cfg.fontName, 'FontSize', cfg.fontSize, ...
        'LineWidth', 1.0, 'Layer', 'top');
    ax.Title.FontSize  = cfg.fontSize + 1;
    ax.XLabel.FontSize = cfg.fontSize;
    ax.YLabel.FontSize = cfg.fontSize;
end

function saveFig(f, basePath, cfg, rasterPDF)
    if nargin < 4; rasterPDF = false; end
    set(f, 'Color', 'w');
    set(f, 'PaperPositionMode', 'auto');
    for k = 1:numel(cfg.figFormats)
        fmt = cfg.figFormats{k};
        switch lower(fmt)
            case 'png'
                exportgraphics(f, [basePath '.png'], 'Resolution', 300, ...
                               'BackgroundColor', 'white');
            case 'pdf'
                if rasterPDF
                    exportgraphics(f, [basePath '.pdf'], 'ContentType', 'image', ...
                                   'Resolution', 300, 'BackgroundColor', 'white');
                else
                    exportgraphics(f, [basePath '.pdf'], 'ContentType', 'vector', ...
                                   'BackgroundColor', 'white');
                end
            otherwise
                exportgraphics(f, [basePath '.' fmt], 'Resolution', 300);
        end
    end
end
