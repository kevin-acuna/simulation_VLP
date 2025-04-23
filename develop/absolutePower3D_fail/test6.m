%=======================================================================
%  det4P_clean.m  – determinista con selección de la raíz más cercana
%=======================================================================
clear, clc
%% 1 · Datos del escenario ---------------------------------------------
H  = 2.0;   m = 1.5;
Rref  = [0.30 0.20 0.90];         % <-- cambia a placer
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

%% 3 · Dos cocientes  ->  recta p = p0 + α s ---------------------------
beta  = (P./P(1)).^(1/m);
Delta = nT(2:3,:) - beta(2:3).*nT(1,:);
M = Delta(:,1:3);    b = H*Delta(:,3);
p0 = M\b;            s  = null(M);  s=s/norm(s);

n1 = nT(1,:).';   n2 = nT(2,:).';
g  = @(a) ratioErr(a,p0,s,n1,n2,m,P(2)/P(1),H);

%% 4 · Todas las raíces de g(α) en ±10 m -------------------------------
alphagrid = linspace(-10,10,4001);
vals = arrayfun(g, alphagrid);
idx  = find(vals(1:end-1).*vals(2:end) < 0);
roots = [];
for k = idx
    roots(end+1) = fzero(g,[alphagrid(k) alphagrid(k+1)]); %#ok<SAGROW>
end
roots = unique(round(roots,12));
fprintf('\nRaíces físicas de g(α) encontradas:  α =\n'), disp(roots.')

%% 5 · Seleccionar la raíz más próxima a p0  ---------------------------
[~,kmin] = min(abs(roots));      alphaSel = roots(kmin);
Rest = p0 + alphaSel*s;
fprintf('Raíz elegida (mínimo |α|) -> α = %.6f\n', alphaSel)

%% 6 · Recuperar K ------------------------------------------------------
dEst = Rest - [0;0;H];  dnEst = norm(dEst);
cosPsiEst  = (H-Rest(3))/dnEst;
cosPhi1Est = dot(dEst,n1)/dnEst;
Kest = P(1)*dnEst^2/(cosPhi1Est^m*cosPsiEst);

%% 7 · (Opcional) usar fsolve para las 4 ecuaciones --------------------
F = @(v) sys4(v,nT,P,m,H);
v0 = [Rest.' Kest];
v  = fsolve(F, v0, optimoptions('fsolve','Display','off'));
Rest2 = v(1:3);   Kest2 = v(4);

%% 8 · Resultados -------------------------------------------------------
Ppred = zeros(4,1);
for i = 1:4
    cosPhi = dot(dEst,nT(i,:).')/dnEst;
    Ppred(i) = Kest*(cosPhi^m)*cosPsiEst/dnEst^2;
end

fprintf('\nP reales  : '), disp(P.')
fprintf('P predich : '), disp(Ppred.')
fprintf('-------------------------------------------------------------\n');
fprintf('Referencia (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rref);
fprintf('Estimado   (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rest);
fprintf('Error posición     : %.2e m\n', norm(Rest'-Rref));
fprintf('K real / est.      : %.3f  /  %.3f\n', Ktrue, Kest);
fprintf('fsolve (refino)    : (%.4f,%.4f,%.4f)  K=%.3f\n', Rest2, Kest2);

%================ funciones auxiliares ==================================
function r = ratioErr(a,p0,s,n1,n2,m,ratioObs,H)
    p = p0 + a*s;
    d = p - [0;0;H];  dn = norm(d);
    cosPhi1 = dot(d,n1)/dn;
    cosPhi2 = dot(d,n2)/dn;
    r = (cosPhi2/cosPhi1)^m - ratioObs;
end

function F = sys4(v,nT,P,m,H)
    x=v(1); y=v(2); z=v(3); K=v(4);
    d = [x;y;z] - [0;0;H]; dn = norm(d);
    cosPsi = (H-z)/dn;
    F = zeros(4,1);
    for i=1:4
        cosPhi = dot(d,nT(i,:).')/dn;
        F(i) = K*(cosPhi^m)*cosPsi/dn^2 - P(i);
    end
end
