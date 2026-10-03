function pdf = compilar_informe()
root = gob_paths();
run_gob('report');
original = pwd; cleanup = onCleanup(@()cd(original));
cd(fullfile(root,'informe'));
for pass = 1:3
    [status,output] = system('pdflatex -interaction=nonstopmode -halt-on-error -output-directory=compilado INFORME.tex');
    if status~=0
        error('gob:Latex','PDF compilation failed:\n%s',output);
    end
end
pdf = fullfile(root,'informe','compilado','INFORME.pdf');
assert(isfile(pdf),'gob:Latex','The report PDF was not created.');
fprintf('Informe PDF: %s\n',pdf);
end
