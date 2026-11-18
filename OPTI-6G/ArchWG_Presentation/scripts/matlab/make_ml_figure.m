% CDF of the 3D error in the 2 m x 2 m target zone: model-based NLS vs. ML correction
% (Extra-Trees, neural network), from results/ml_predictions.csv (scripts/ml_positioning.py).
function make_ml_figure()
here = fileparts(mfilename('fullpath')); presDir = fileparts(fileparts(here));
T = readtable(fullfile(presDir, 'results', 'ml_predictions.csv'), 'TextType', 'string');
z = T.in_zone == 1; v = z & T.kind == "vertical"; t = z & T.kind == "tilt";
C.blue = [0.16 0.38 0.74]; C.green = [0.30 0.62 0.25]; C.purple = [0.55 0.27 0.80]; C.red = [0.80 0.10 0.10]; C.gray = [0.45 0.45 0.45];
FS = 16; FN = 'Arial';
f = figure('Color','w','Units','inches','Position',[1 1 7.6 4.9],'Visible','off');
ax = axes(f); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
cols = {T.err_NLS_cm, T.err_hybrid_ET_cm, T.err_hybrid_NN_cm};
names = {'NLS (model only)', 'Extra-Trees', 'Neural network'};
cc = {C.blue, C.green, C.purple};
h = gobjects(0);
for k = 1:3
    h(end+1) = ecdf_(ax, cols{k}(v), cc{k}, '-', sprintf('%s, P90 = %.1f cm', names{k}, pct(cols{k}(v), 90))); %#ok<AGROW>
end
for k = 1:3
    ecdf_(ax, cols{k}(t), cc{k}, '--', '');
end
xline(ax, 5, '-', 'Color', C.red, 'LineWidth', 1.6, 'HandleVisibility','off');
yline(ax, 0.9, ':', 'Color', C.gray, 'LineWidth', 1.2, 'HandleVisibility','off');
text(ax, 5.3, 0.62, {'OPTI-6G target','P90 \leq 5 cm'}, 'Color', C.red, 'FontName', FN, 'FontSize', FS-3);
hv = plot(ax, NaN, NaN, 'k-', 'LineWidth', 2); ht = plot(ax, NaN, NaN, 'k--', 'LineWidth', 2);
legend(ax, [h hv ht], [cellfun(@(x) x, get(h,'DisplayName'), 'UniformOutput', false); {'vertical PD'; 'tilted PD'}], ...
    'Location','southeast','FontSize',FS-4);
xlim(ax,[0 12]); ylim(ax,[0 1]);
xlabel(ax,'3D position error [cm]'); ylabel(ax,'Empirical CDF');
set(ax,'FontName',FN,'FontSize',FS,'LineWidth',1.0,'Layer','top','GridAlpha',0.18);
exportgraphics(f, fullfile(presDir, 'figures', 'exp3_ml_cdf.png'), 'Resolution', 250, 'BackgroundColor', 'white');
close(f);
fprintf('zone vertical P90: NLS %.2f, ET %.2f, NN %.2f | tilt: %.2f %.2f %.2f\n', pct(cols{1}(v),90), pct(cols{2}(v),90), pct(cols{3}(v),90), ...
    pct(cols{1}(t),90), pct(cols{2}(t),90), pct(cols{3}(t),90));
fprintf('zone vertical median: NLS %.2f, ET %.2f, NN %.2f\n', pct(cols{1}(v),50), pct(cols{2}(v),50), pct(cols{3}(v),50));
end

function h = ecdf_(ax, e, col, ls, name)
e = sort(e(isfinite(e))); y = (1:numel(e))/numel(e);
h = stairs(ax, [0; e(:)], [0; y(:)], ls, 'Color', col, 'LineWidth', 2.2, 'DisplayName', name);
if isempty(name), h.HandleVisibility = 'off'; end
end

function q = pct(v, p)
v = sort(v(isfinite(v))); n = numel(v); x = ((1:n) - 0.5)/n*100;
q = interp1([0 x 100], [v(1); v(:); v(end)], p, 'linear');
end
