
h = gcf;                      % obtiene el handle de la figura activa
set(h,'Units','pixels');      % opcional: asegura unidades en píxeles
%set(h,'Position',[100 100 300 180]);  % [x y ancho alto] % mas horizontal
% set(h,'Position',[100 100 250 250]);  % GRAFICOS DE HEATMAP - PEQUEÑOS
set(h,'Position',[100 100 480 300]);  % [x y ancho alto]
%set(h,'Position',[100 100 150 150]);  % [x y ancho alto]
set(gcf, 'Color', 'white');
print('figures/figure.png', '-dpng', '-r300');

