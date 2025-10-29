
h = gcf;                      % obtiene el handle de la figura activa
set(h,'Units','pixels');      % opcional: asegura unidades en píxeles
set(h,'Position',[100 100 500 300]);  % [x y ancho alto]
%set(h,'Position',[100 100 600 600]);  % [x y ancho alto]

set(gcf, 'Color', 'white');
print('Figures/figure.png', '-dpng', '-r300');

