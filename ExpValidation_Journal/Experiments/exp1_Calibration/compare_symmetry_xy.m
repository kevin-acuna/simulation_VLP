clear; close all; clc;

%% ==================== CONFIGURACION ====================
session      = '20260722_165901';   % subcarpeta de datos en sub0_axis_sweep
angle_offset = 0;                    % alineacion 0 mecanico vs 0 optico [deg]
normalize    = true;                 % graficar normalizado al maximo
save_figures = false;

fontName = 'Times New Roman';
fontSize = 13;
cOrig = [0.00 0.45 0.74];            % rama original (azul)
cMirr = [0.85 0.33 0.10];            % rama reflejada (naranja)

%% ==================== CARGAR DATOS ====================
folder  = fileparts(mfilename('fullpath'));
if isempty(folder); folder = pwd; end
dataDir = fullfile(folder, 'sub0_axis_sweep', session);
file_x  = fullfile(dataDir, 'data_x.csv');   % barrido en el eje X
file_y  = fullfile(dataDir, 'data_y.csv');   % barrido en el eje Y
assert(isfile(file_x), 'No existe el archivo: %s', file_x);
assert(isfile(file_y), 'No existe el archivo: %s', file_y);

Tx = readtable(file_x);   % columnas: axis_angle (deg), v_mean (V), ...
Ty = readtable(file_y);

ang_x = Tx.axis_angle + angle_offset;   v_x = Tx.v_mean;
ang_y = Ty.axis_angle + angle_offset;   v_y = Ty.v_mean;

if normalize
    vscale = max([v_x; v_y]);
    v_x = v_x / vscale;   v_y = v_y / vscale;
    ylab = 'Normalized intensity  R(\theta)';
else
    ylab = 'v_{mean} (V)';
end

%% ==================== FIGURA (ejes X e Y) ====================
f = figure('Color','w','Position',[120 100 1150 780]);
tl = tiledlayout(f, 2, 2, 'TileSpacing','compact', 'Padding','compact');

rmse_x = plot_axis_symmetry(tl, ang_x, v_x, 'X axis', angle_offset, ylab, fontName, fontSize, cOrig, cMirr);
rmse_y = plot_axis_symmetry(tl, ang_y, v_y, 'Y axis', angle_offset, ylab, fontName, fontSize, cOrig, cMirr);

title(tl, 'LED pattern symmetry about 0^\circ', ...
      'FontName', fontName, 'FontSize', fontSize+2, 'FontWeight','bold');

fprintf('\n=== Simetria (RMSE del residuo original-reflejado) ===\n');
fprintf('  Eje X | RMSE = %.4f\n', rmse_x);
fprintf('  Eje Y | RMSE = %.4f\n', rmse_y);
fprintf('======================================================\n\n');

%% ==================== GUARDAR ====================
if save_figures
    outDir = fullfile(dataDir, 'figures');
    if ~exist(outDir,'dir'); mkdir(outDir); end
    exportgraphics(f, fullfile(outDir,'Fig_XY_Symmetry.png'), 'Resolution',300, 'BackgroundColor','white');
    exportgraphics(f, fullfile(outDir,'Fig_XY_Symmetry.pdf'), 'ContentType','vector', 'BackgroundColor','white');
    fprintf('Figura guardada en: %s\n', outDir);
end

%% ==================== FUNCION LOCAL ====================
function rmse = plot_axis_symmetry(tl, ang, v, axis_name, angle_offset, ylab, fontName, fontSize, cOrig, cMirr)
% Compara la simetria doblando el patron sobre 0 grados: superpone la rama
% original con su reflejada (angulo -> -angulo) y grafica el residuo.
    [ang, idx] = sort(ang(:));   v = v(idx);
    ang_mirror = -ang;
    [ang_mirror, idxm] = sort(ang_mirror);   v_mirror = v(idxm);

    % Zona de solape y residuo (original - reflejado)
    lo = max(min(ang), min(ang_mirror));
    hi = min(max(ang), max(ang_mirror));
    mask = ang >= lo & ang <= hi;
    v_mirror_i = interp1(ang_mirror, v_mirror, ang(mask), 'linear');
    resid = v(mask) - v_mirror_i;
    rmse  = sqrt(mean(resid.^2, 'omitnan'));

    % ---------- Panel izquierdo: superposicion ----------
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    plot(ax, ang, v, '-o', 'LineWidth', 1.5, 'MarkerSize', 3.5, ...
         'Color', cOrig, 'MarkerFaceColor', cOrig, 'DisplayName', 'Original');
    plot(ax, ang_mirror, v_mirror, '-s', 'LineWidth', 1.5, 'MarkerSize', 3.5, ...
         'Color', cMirr, 'MarkerFaceColor', cMirr, ...
         'DisplayName', sprintf('Mirrored (offset %g\\circ)', angle_offset));
    xline(ax, 0, 'k--', 'HandleVisibility','off');
    xlabel(ax, 'Angle (\circ)', 'FontWeight','bold');
    ylabel(ax, ylab, 'FontWeight','bold');
    title(ax, sprintf('%s  |  RMSE = %.4f', axis_name, rmse));
    legend(ax, 'Location','northeast', 'FontSize', fontSize-2);
    xlim(ax, [-90 90]); xticks(ax, -90:30:90);
    set(ax, 'FontName', fontName, 'FontSize', fontSize, 'LineWidth', 1.0, 'Layer','top');

    % ---------- Panel derecho: residuo (asimetria) ----------
    ax2 = nexttile(tl); hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
    area(ax2, ang(mask), resid, 'FaceColor', [0.60 0.60 0.85], ...
         'EdgeColor','none', 'FaceAlpha', 0.6);
    plot(ax2, ang(mask), resid, '-', 'LineWidth', 1.4, 'Color', [0.25 0.25 0.5]);
    yline(ax2, 0, 'k-', 'LineWidth', 0.8);
    xline(ax2, 0, 'k--', 'HandleVisibility','off');
    xlabel(ax2, 'Angle (\circ)', 'FontWeight','bold');
    ylabel(ax2, 'Residual (original - mirrored)', 'FontWeight','bold');
    title(ax2, sprintf('%s  |  asymmetry', axis_name));
    xlim(ax2, [-90 90]); xticks(ax2, -90:30:90);
    set(ax2, 'FontName', fontName, 'FontSize', fontSize, 'LineWidth', 1.0, 'Layer','top');
end
