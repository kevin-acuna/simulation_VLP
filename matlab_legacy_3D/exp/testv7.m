%=======================================================================
%  det4P_definitivo.m   (única raíz física, K desconocido)
%=======================================================================
clear, clc
%% 1 · Escenario --------------------------------------------------------
H  = 2.0;           m = 1.5;
Rref  = [0.30 0.20 0.90];      % <-- prueba aquí cualquier posición
Ktrue = 0.8;

nT = [ 0 0 -1 ; ...
       sind(30) 0 -cosd(30) ; ...
      -sind(30)/2  sind(30)*sqrt(3)/2  -cosd(30) ; ...
      -sind(30)/2 -sind(30)*sqrt(3)/2  -cosd(30) ];

%% 2 · Potencias sin ruido ---------------------------------------------
d  = Rref - [0 0 H];  dn = norm(d);
cosPsi = (H-Rref(3))/dn;
P = zeros(4,1);
for i = 1:4
   cosPhi = dot(d,nT(i,:))/dn;
   P(i)   = Ktrue*(cosPhi^m)*cosPsi/dn^2;
end
disp('P(i) :'), disp(P.')

%% 3 · Línea candidata  p = p0 + α s  ----------------------------------
beta  = (P./P(1)).^(1/m);
Delta = nT(2:3,:) - beta(2:3).*nT(1,:);
M = Delta(:,1:3);   b = H*Delta(:,3);
p0 = M\b;                fprintf('p0 = [%g %g %g]\n', p0);
s  = null(M);  s=s/norm(s);  fprintf('s  = [%g %g %g]\n', s);

n1 = nT(1,:).';   n2 = nT(2,:).';
g  = @(a) ratioErr(a,p0,s,n1,n2,m,P(2)/P(1),H);

%% 4 · Búsqueda de raíces evitando discontinuidades --------------------
alphagrid = linspace(-10,10,8001);
vals = zeros(size(alphagrid));
mask = true(size(alphagrid));          % true = “válido para buscar”
epsSing = 1e-4;                        % umbral de singularidad
for k = 1:numel(alphagrid)
    a = alphagrid(k);
    dtemp = p0 + a*s - [0;0;H];
    cosPhi1 = dot(dtemp,n1)/norm(dtemp);
    if abs(cosPhi1) < epsSing
        mask(k) = false;               % saltar discontinuidad
    else
        vals(k) = g(a);
    end
end

idx = find(mask(1:end-1) & mask(2:end) & vals(1:end-1).*vals(2:end)<0);
roots = [];
for k = idx
    roots(end+1) = fzero(g,[alphagrid(k) alphagrid(k+1)]); %#ok<SAGROW>
end
roots = unique(round(roots,12));
fprintf('\nRaíces genuinas encontradas:\n'), disp(roots.')

%% 5 · Elegir la raíz física (0<z<H) y más cercana a p0  ----------------
best  = [];
for alpha = roots
   p   = p0 + alpha*s;
   z   = p(3);
   if z<=0 || z>=H, continue, end
   d   = p - [0;0;H];   dnEst = norm(d);
   cosPsiEst  = (H-z)/dnEst;
   cosPhi1Est = dot(d,n1)/dnEst;
   Kest = P(1)*dnEst^2/(cosPhi1Est^m*cosPsiEst);
   if Kest<=0, continue, end
   % verificar las 4 potencias
   ok = true;
   for i = 2:4
       cosPhi = dot(d,nT(i,:).')/dnEst;
       Ppred  = Kest*(cosPhi^m)*cosPsiEst/dnEst^2;
       ok = ok && abs(Ppred-P(i))<1e-12;
   end
   if ok, best = [alpha p.' Kest]; break, end
end

if isempty(best)
    error('No se encontró raíz física dentro del rango.');
end
alphaSel = best(1);  Rest = best(2:4);  Kest = best(5);
fprintf('α seleccionado  = %.6f\n\n', alphaSel);

%% 6 · Resultado y comprobación final ----------------------------------
fprintf('Referencia (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rref);
fprintf('Estimado   (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rest);
fprintf('Error posición     : %.2e m\n', norm(Rest-Rref));
fprintf('K real / estimado  : %.3f / %.3f\n', Ktrue, Kest);

%==================== funciones auxiliares =============================
function r = ratioErr(a,p0,s,n1,n2,m,ratioObs,H)
    p = p0 + a*s;
    d = p - [0;0;H];  dn = norm(d);
    cosPhi1 = dot(d,n1)/dn;
    cosPhi2 = dot(d,n2)/dn;
    r = (cosPhi2/cosPhi1)^m - ratioObs;
end
