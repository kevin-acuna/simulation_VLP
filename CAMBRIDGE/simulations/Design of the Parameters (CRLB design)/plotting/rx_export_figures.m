function rx_export_figures(figures, output_dir, style)
if style.export
    assert(isfolder(output_dir), 'cambridge:OutputDirectory', 'Figure destination must already exist.');
end
for fig = figures(:)'
    if style.export
        name = fig.UserData.export_name;
        stem = fullfile(output_dir, name);
        assert(~isfile([stem '.pdf']) && ~isfile([stem '.png']) && ~isfile([stem '.fig']), ...
            'cambridge:ExistingFigure', 'Refusing to overwrite figures. Use replot_experiment for a new rendering directory.');
        drawnow;
        exportgraphics(fig, [stem '.pdf'], 'ContentType', 'vector', 'BackgroundColor', 'white', 'Padding', 8);
        exportgraphics(fig, [stem '.png'], 'Resolution', style.resolution_dpi, 'BackgroundColor', 'white', 'Padding', 8);
        savefig(fig, [stem '.fig']);
    end
    if ~style.keep_open
        close(fig);
    end
end
end
