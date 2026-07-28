clear; close all; clc;

%% ==================== CONFIGURACION ====================
% Orden del patron Lambertiano R(theta) = cos(theta)^m:
%   []  -> se ajusta automaticamente por minimos cuadrados
%   num -> fuerza ese valor (p.ej. 3.13)
m_user = 3.13;
v_dark = 0.05;

angle_offset  = 0;       % correccion 0 mecanico vs 0 optico [deg]
subtract_dark = false;   % restar v_dark de metadata (ver nota)
fit_range_deg = 70;      % rango |angulo| usado para ajustar m [deg]
save_figures  = true;    % guardar figuras (PNG 300 dpi + PDF)

fontName = 'Times New Roman';
fontSize = 13;
cX = [0.00 0.45 0.74];   % eje X (azul)
cY = [0.85 0.33 0.10];   % eje Y (naranja)
cL = [0.15 0.15 0.15];   % Lambertiano (gris/negro)

% NOTA: v_mean es proporcional a la intensidad radiante recibida (maximo en
% el boresight). Restar v_dark puede volver negativas las colas (donde la
% senal cae por debajo del dark medido), por eso subtract_dark = false.

%% ==================== CARGAR DATOS ====================
% La sesion define la subcarpeta de datos dentro de sub0_axis_sweep.
session = '20260722_165901';
folder  = fileparts(mfilename('fullpath'));
if isempty(folder); folder = pwd; end
dataDir = fullfile(folder, 'sub0_axis_sweep', session);
file_x  = fullfile(dataDir, 'data_x.csv');   % barrido en el eje X
file_y  = fullfile(dataDir, 'data_y.csv');   % barrido en el eje Y
assert(isfile(file_x), 'No existe el archivo: %s', file_x);
assert(isfile(file_y), 'No existe el archivo: %s', file_y);

Tx = readtable(file_x);   % columnas: axis_angle (deg), v_mean (V), ...
Ty = readtable(file_y);

[ang_x, ix] = sort(Tx.axis_angle + angle_offset);   v_x = Tx.v_mean(ix);
[ang_y, iy] = sort(Ty.axis_angle + angle_offset);   v_y = Ty.v_mean(iy);

% v_dark = read_dark(fullfile(dataDir, 'metadata.txt'));
if subtract_dark && ~isnan(v_dark)
    v_x = max(v_x - v_dark, 0);
    v_y = max(v_y - v_dark, 0);
end

%% ==================== NORMALIZACION Y AJUSTE ====================
Vmax = max([v_x; v_y]);
Rx   = v_x / Vmax;          % patron normalizado eje X
Ry   = v_y / Vmax;          % patron normalizado eje Y

if isempty(m_user)
    m = fit_lambertian_order([ang_x; ang_y], [Rx; Ry], fit_range_deg);
else
    m = m_user;
end

ang_lamb = linspace(-90, 90, 721).';
R_lamb   = cosd(ang_lamb).^m;
R_lamb(abs(ang_lamb) >= 90) = 0;

% Semiangulos a media potencia (-3 dB, R = 0.5)
[a1x, a2x] = half_power_angles(ang_x, Rx);
[a1y, a2y] = half_power_angles(ang_y, Ry);
phi_half_lamb = acosd(0.5^(1/m));

fprintf('\n=== Ajuste Lambertiano (barrido X/Y) ===\n');
fprintf('  Vmax                 : %.4f V\n', Vmax);
fprintf('  Orden Lambertiano m  : %.2f\n', m);
fprintf('  HPBW Lambertiano     : +/- %.2f deg  (ancho %.2f deg)\n', phi_half_lamb, 2*phi_half_lamb);
fprintf('  HPBW eje X           : [%.2f, %.2f] deg  (ancho %.2f deg)\n', a1x, a2x, a2x-a1x);
fprintf('  HPBW eje Y           : [%.2f, %.2f] deg  (ancho %.2f deg)\n', a1y, a2y, a2y-a1y);
fprintf('========================================\n\n');

%% ==================== FIGURA 1: LINEAL + dB ====================
f1 = figure('Color','w','Position',[120 120 1180 500]);
tl = tiledlayout(f1, 1, 2, 'TileSpacing','compact', 'Padding','compact');

% --- Panel A: escala lineal normalizada ---
ax1 = nexttile(tl); hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
plot(ax1, ang_lamb, R_lamb, '-',  'LineWidth', 2.4, 'Color', cL, ...
     'DisplayName', sprintf('Lambertian  $\\cos^{%.2f}\\theta$', m));
plot(ax1, ang_x, Rx, '-o', 'LineWidth', 1.4, 'MarkerSize', 3.5, ...
     'Color', cX, 'MarkerFaceColor', cX, 'DisplayName', 'X axis (measured)');
plot(ax1, ang_y, Ry, '-s', 'LineWidth', 1.4, 'MarkerSize', 3.5, ...
     'Color', cY, 'MarkerFaceColor', cY, 'DisplayName', 'Y axis (measured)');
yline(ax1, 0.5, ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0, 'HandleVisibility','off');
xline(ax1, 0, 'k--', 'HandleVisibility','off');
plot(ax1, [a1x a2x], [0.5 0.5], 'o', 'Color', cX, 'MarkerFaceColor','w', 'HandleVisibility','off');
plot(ax1, [a1y a2y], [0.5 0.5], 's', 'Color', cY, 'MarkerFaceColor','w', 'HandleVisibility','off');
xlabel(ax1, 'Angle $\theta$ (deg)', 'Interpreter','latex');
ylabel(ax1, 'Normalized intensity  $R(\theta)$', 'Interpreter','latex');
title(ax1, 'Linear scale', 'Interpreter','latex');
legend(ax1, 'Interpreter','latex', 'Location','northeast', 'FontSize', fontSize-2);
xlim(ax1, [-90 90]); ylim(ax1, [0 1.03]); xticks(ax1, -90:30:90);
styleAxis(ax1, fontName, fontSize);

% --- Panel B: escala en dB (revela colas y ancho de haz) ---
ax2 = nexttile(tl); hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
floorDB = -25;
toDB = @(R) max(10*log10(max(R, eps)), floorDB);
plot(ax2, ang_lamb, toDB(R_lamb), '-',  'LineWidth', 2.4, 'Color', cL, ...
     'DisplayName', sprintf('Lambertian  $\\cos^{%.2f}\\theta$', m));
plot(ax2, ang_x, toDB(Rx), '-o', 'LineWidth', 1.4, 'MarkerSize', 3.5, ...
     'Color', cX, 'MarkerFaceColor', cX, 'DisplayName', 'X axis (measured)');
plot(ax2, ang_y, toDB(Ry), '-s', 'LineWidth', 1.4, 'MarkerSize', 3.5, ...
     'Color', cY, 'MarkerFaceColor', cY, 'DisplayName', 'Y axis (measured)');
yline(ax2, -3, ':', '-3 dB', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0, ...
      'LabelHorizontalAlignment','left', 'Interpreter','none', 'HandleVisibility','off');
xline(ax2, 0, 'k--', 'HandleVisibility','off');
xlabel(ax2, 'Angle $\theta$ (deg)', 'Interpreter','latex');
ylabel(ax2, 'Normalized intensity (dB)', 'Interpreter','latex');
title(ax2, 'Logarithmic scale', 'Interpreter','latex');
legend(ax2, 'Interpreter','latex', 'Location','south', 'FontSize', fontSize-2);
xlim(ax2, [-90 90]); ylim(ax2, [floorDB 1]); xticks(ax2, -90:30:90);
styleAxis(ax2, fontName, fontSize);

title(tl, sprintf('LED radiation pattern: X/Y axes vs. Lambertian  (m = %.2f)', m), ...
      'Interpreter','latex', 'FontName', fontName, 'FontSize', fontSize+2);

%% ==================== FIGURA 2: VISTA POLAR ====================
f2 = figure('Color','w','Position',[160 160 700 660]);
pax = polaraxes(f2); hold(pax,'on');
polarplot(pax, deg2rad(ang_lamb), R_lamb, '-', 'LineWidth', 2.2, 'Color', cL, ...
          'DisplayName', sprintf('Lambertian (m=%.2f)', m));
polarplot(pax, deg2rad(ang_x), Rx, '-o', 'LineWidth', 1.3, 'MarkerSize', 3, ...
          'Color', cX, 'MarkerFaceColor', cX, 'DisplayName', 'X axis');
polarplot(pax, deg2rad(ang_y), Ry, '-s', 'LineWidth', 1.3, 'MarkerSize', 3, ...
          'Color', cY, 'MarkerFaceColor', cY, 'DisplayName', 'Y axis');
pax.ThetaZeroLocation = 'top';
pax.ThetaDir          = 'clockwise';
pax.ThetaLim          = [-90 90];
pax.ThetaTick         = -90:30:90;
pax.RLim              = [0 1];
pax.RTick             = 0:0.2:1;
pax.FontName          = fontName;
pax.FontSize          = fontSize-1;
title(pax, 'Radiation pattern (polar view)', 'FontName', fontName, 'FontSize', fontSize+1);
legend(pax, 'Location','southoutside', 'Orientation','horizontal', 'FontSize', fontSize-2);

%% ==================== GUARDAR ====================
if save_figures
    outDir = fullfile(dataDir, 'figures');
    if ~exist(outDir,'dir'); mkdir(outDir); end
    exportgraphics(f1, fullfile(outDir,'Fig_XY_Lambertian.png'), 'Resolution',300, 'BackgroundColor','white');
    exportgraphics(f1, fullfile(outDir,'Fig_XY_Lambertian.pdf'), 'ContentType','vector', 'BackgroundColor','white');
    exportgraphics(f2, fullfile(outDir,'Fig_XY_Polar.png'), 'Resolution',300, 'BackgroundColor','white');
    exportgraphics(f2, fullfile(outDir,'Fig_XY_Polar.pdf'), 'ContentType','vector', 'BackgroundColor','white');
    fprintf('Figuras guardadas en: %s\n', outDir);
end

%% ==================== FUNCIONES LOCALES ====================
function m = fit_lambertian_order(ang, R, rangeDeg)
% Ajusta R = cos(ang)^m por minimos cuadrados en escala log.
    ang = ang(:); R = R(:);
    mask = abs(ang) <= rangeDeg & R > 0.02 & abs(ang) < 89.9;
    x = log(cosd(ang(mask)));
    y = log(R(mask));
    good = isfinite(x) & isfinite(y) & x < -1e-9;   % excluye ang=0
    m = sum(x(good) .* y(good)) / sum(x(good) .^ 2);
end

function [a1, a2] = half_power_angles(ang, R)
% Angulos donde R cruza 0.5 (media potencia) a cada lado de 0.
    ang = ang(:); R = R(:);
    s = R - 0.5;
    idx = find(s(1:end-1) .* s(2:end) < 0);
    a1 = NaN; a2 = NaN;
    if isempty(idx); return; end
    cr = zeros(numel(idx), 1);
    for k = 1:numel(idx)
        i = idx(k);
        cr(k) = interp1(s(i:i+1), ang(i:i+1), 0, 'linear');
    end
    neg = cr(cr < 0);   pos = cr(cr > 0);
    if ~isempty(neg), a1 = max(neg); end
    if ~isempty(pos), a2 = min(pos); end
end

function v = read_dark(metaFile)
% Lee v_dark_mean de metadata.txt (NaN si no existe).
    v = NaN;
    if ~isfile(metaFile); return; end
    txt = fileread(metaFile);
    tok = regexp(txt, 'v_dark_mean\s*=\s*([-\d.eE]+)', 'tokens', 'once');
    if ~isempty(tok); v = str2double(tok{1}); end
end

function styleAxis(ax, fontName, fontSize)
    set(ax, 'FontName', fontName, 'FontSize', fontSize, 'LineWidth', 1.0, 'Layer', 'top');
end
