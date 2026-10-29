function pp_export(fig, cfg, name)
% Vector PDF for the manuscript and a 200 dpi PNG for quick inspection; closes the figure.
exportgraphics(fig, fullfile(cfg.figdir, [name '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fig, fullfile(cfg.figdir, 'png', [name '.png']), 'Resolution', 200, 'BackgroundColor', 'white');
close(fig);
fprintf('  figure %s\n', name);
end
