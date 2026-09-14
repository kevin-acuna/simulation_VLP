function gob_report_tables(outputDir,root)
if nargin<2, root = gob_paths(); end
gob_verify_results(outputDir);
manifest = load(fullfile(outputDir,'manifest.mat'));
t = gob_read_table(fullfile(outputDir,'tablas','summary.csv'));
assert(height(t)==25,'gob:Report','The complete report requires all 25 cases.');
tests = load(fullfile(root,'pruebas','ultimo_resultado.mat'));
assert(all([tests.result.Passed]),'gob:Report','Run and pass the MATLAB tests first.');
sens = gob_read_table(fullfile(outputDir,'tablas','robustness.csv'));
rays = gob_read_table(fullfile(outputDir,'tablas','ray_validation.csv'));
generated = fullfile(root,'informe','generado');
[~,folder] = fileparts(outputDir);
macros = ["\graphicspath{{../resultados/"+folder+"/figuras/}}"; ...
    "\newcommand{\DirectorioResultados}{\path{resultados/"+folder+"}}"; ...
    "\newcommand{\NumeroCasos}{"+height(t)+"}"; ...
    "\newcommand{\NumeroEnsayos}{"+sum(t.count)+"}"; ...
    "\newcommand{\NumeroSensibilidad}{"+sum(sens.count)+"}"; ...
    "\newcommand{\NumeroPruebas}{"+numel(tests.result)+"}"];
items = {"TilePdos","tile_baseline_core_2d","p95_m";"TilePtres","tile_baseline_core_3d","p95_m"; ...
    "TileFrontera","tile_baseline_core_3d","boundary_max_m";"ParFrontera","tile_convex_core_3d","boundary_max_m"; ...
    "GridPdos","grid_convex_core_2d","p95_m";"GridPtres","grid_convex_core_3d","p95_m"; ...
    "GridFrontera","grid_convex_core_3d","boundary_max_m";"TileNovenoPtres","tile_baseline_ninth_3d","p95_m"; ...
    "GridOriginalPtres","grid_baseline_full_3d","p95_m";"GananciaLibrePtres","tile_baseline_core_3d_unknown_gain","p95_m"};
for k = 1:size(items,1)
    value = t.(items{k,3})(t.case_name==items{k,2});
    macros(end+1) = "\newcommand{\"+items{k,1}+"}{"+num(1000*value)+"}";
end
writelines(macros,fullfile(generated,'macros.tex'),'Encoding','UTF-8');
lines = ["\begin{tabular}{lrrrr}\toprule";"Arquitectura & $K$ & Lado base [m] & P95 2D [mm] & P95 3D [mm]\\\midrule"];
bases = {"Un tile mínimo","tile_baseline_core",1,.9;"Un tile ampliado","tile_convex_core",2,1.2;"Nueve tiles, $21^\circ$","grid_convex_core",2,3.6};
for k = 1:3
    a = t.p95_m(t.case_name==bases{k,2}+"_2d"); b = t.p95_m(t.case_name==bases{k,2}+"_3d");
    lines(end+1) = bases{k,1}+" & "+bases{k,3}+" & "+bases{k,4}+" & "+num(1000*a)+" & "+num(1000*b)+" \\";
end
writelines([lines;"\bottomrule\end{tabular}"],fullfile(generated,'resumen_principal.tex'),'Encoding','UTF-8');
lines = ["\begingroup\small\setlength{\tabcolsep}{3pt}";"\begin{longtable}{lp{7.0cm}rrlp{2.5cm}}\toprule"; ...
    "ID & Nombre del caso & Dim. & Base [m] & Dom. & $R$ [mm]\\\midrule\endhead"];
for k = 1:numel(manifest.cases)
    c = manifest.cases(k); domain = "P"; if c.frustum, domain = "T"; end
    lines(end+1) = compose('C%02d',k)+" & \path{"+c.name+"} & "+c.dimensions+" & "+num(2*c.half_width)+ ...
        " & "+domain+" & "+strjoin(compose('%g',1000*c.config.radii),', ')+" \\";
end
writelines([lines;"\bottomrule\end{longtable}\endgroup"],fullfile(generated,'catalogo.tex'),'Encoding','UTF-8');
lines = ["\begin{longtable}{lrrrrr}\toprule"; ...
    "ID & Mediana [mm] & P95 [mm] & RMSE [mm] & Máximo [mm] & $<10$ cm [\%]\\\midrule\endhead"];
info = ["\begin{longtable}{lrrrr}\toprule"; ...
    "ID & Frontera máx. [mm] & P95 PEB [mm] & PEB $<10$ cm [\%] & Rango completo [\%]\\\midrule\endhead"];
for k = 1:height(t)
    r = t(t.case_name==manifest.cases(k).name,:); id = compose('C%02d',k);
    lines(end+1) = id+" & "+num(1000*r.median_m)+" & "+num(1000*r.p95_m)+" & "+num(1000*r.rmse_m)+ ...
        " & "+num(1000*r.max_m)+" & "+num(100*r.fraction_error_10cm)+" \\";
    info(end+1) = id+" & "+num(1000*r.boundary_max_m)+" & "+num(1000*r.grid_peb_p95_m)+ ...
        " & "+num(100*r.grid_fraction_peb_10cm)+" & "+num(100*r.grid_fraction_full_rank)+" \\";
end
writelines([lines;"\bottomrule\end{longtable}"],fullfile(generated,'resultados_completos.tex'),'Encoding','UTF-8');
writelines([info;"\bottomrule\end{longtable}"],fullfile(generated,'fronteras_informacion.tex'),'Encoding','UTF-8');
labels = ["Control concordante","Ganancia +2\%","Calibración por VCSEL 1\%","Fondo residual 0.1 nW", ...
    "Inclinación PD $3^\circ$","Curvatura +0.1\%","Curvatura +1\%","Borde +0.1 mm"];
s = sens(sens.case_name=="tile_baseline_core_3d",:);
lines = ["\begin{tabular}{lrr}\toprule";"Perturbación & P95 [mm] & RMSE [mm]\\\midrule"];
for k = 1:height(s), lines(end+1) = labels(k)+" & "+num(s.p95_m(k)*1000)+" & "+num(s.rmse_m(k)*1000)+" \\"; end
writelines([lines;"\bottomrule\end{tabular}"],fullfile(generated,'sensibilidad_nucleo.tex'),'Encoding','UTF-8');
s = rays(rays.channel_1based==1,:);
lines = ["\begin{tabular}{rrrrr}\toprule";"$R$ [mm] & Radio menor/ABCD & Radio mayor/ABCD & Centroide [mm] & TIR [\%]\\\midrule"];
for k = 1:height(s)
    lines(end+1) = num(s.radius_mm(k))+" & "+num(s.minor_width_ratio(k))+" & "+num(s.major_width_ratio(k))+ ...
        " & "+num(s.centroid_offset_mm(k))+" & "+num(100*s.tir_fraction(k))+" \\";
end
writelines([lines;"\bottomrule\end{tabular}"],fullfile(generated,'rayos_esquina.tex'),'Encoding','UTF-8');
pythonRoot = fullfile(fileparts(root),'simulations','results');
a = readtable(fullfile(pythonRoot,'summary_tile.csv'),'TextType','string','VariableNamingRule','preserve');
b = readtable(fullfile(pythonRoot,'summary_grid.csv'),'TextType','string','VariableNamingRule','preserve'); old = [a;b];
selected = ["tile_baseline_core_3d","tile_convex_core_3d","grid_convex_core_3d","tile_baseline_ninth_3d"];
lines = ["\begin{table}[H]\centering\begin{tabular}{p{6.6cm}rr}\toprule"; ...
    "Caso & P95 Python [mm] & P95 MATLAB [mm]\\\midrule"];
for k = 1:numel(selected)
    first = old.p95_m(string(old{:,1})==selected(k)); second = t.p95_m(t.case_name==selected(k));
    lines(end+1) = "\path{"+selected(k)+"} & "+num(1000*first)+" & "+num(1000*second)+" \\";
end
writelines([lines;"\bottomrule\end{tabular}\caption{Comparación de realizaciones independientes, no equivalencia muestra a muestra.}\end{table}"], ...
    fullfile(generated,'comparacion_python.tex'),'Encoding','UTF-8');
fprintf('Tablas y macros del informe generadas desde %s\n',outputDir);
end

function text = num(value)
if isinf(value), text = "$\infty$"; elseif isnan(value), text = "---"; else, text = string(sprintf('%.3g',value)); end
end
