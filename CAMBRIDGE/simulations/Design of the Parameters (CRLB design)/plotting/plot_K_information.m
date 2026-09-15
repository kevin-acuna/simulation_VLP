function figures = plot_K_information(r, style)
if nargin < 2
    style = ieee_plot_style();
end
figures = [plot_K_coverage_mechanisms(r, style), plot_K_PEB_mechanisms(r, style), plot_K_normalized_information(r, style)];
end
