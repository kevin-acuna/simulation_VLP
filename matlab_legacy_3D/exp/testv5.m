%=======================================================================
%  det4P_final.m  – resolución determinista robusta con 4 potencias
%=======================================================================
clear, clc
%% 1 · Datos del problema ----------------------------------------------
H  = 2.0;      m = 2;
Rref  = [0.30 0.2 0.90];          % posición real
Ktrue = 0.8;                       % escala global (desconocida)

% 4 orientaciones (vertical + 3 a 30° separados 120°)
nT = [ 0 0 -1 ;
       sind(30) 0 -cosd(30) ;
      -sind(30)/2  sind(30)*sqrt(3)/2  -cosd(30) ;
      -sind(30)/2 -sind(30)*sqrt(3)/2  -cosd(30) ];

%% 2 · Potencias sin ruido ---------------------------------------------
d  = Rref - [0 0 H];              dn = norm(d);
cosPsi = (H-Rref(3))/dn;
P = zeros(4,1);                    % ¡columna 4×1!
for i = 1:4
   cosPhi = dot(d,nT(i,:))/dn;
   P(i)   = Ktrue*(cosPhi^m)*cosPsi/dn^2;
end
disp('Potencias P(i) sin ruido:'),  disp(P.')

%% 3 · Dos cocientes  →  recta p = p0 + α s ----------------------------
beta  = (P./P(1)).^(1/m);          % 4×1 columna
Delta = nT(2:3,:) - beta(2:3).*nT(1,:);  % 2×3
M = Delta(:,1:3);   b = H*Delta(:,3);

p0 = M\b;        fprintf('\np0 (punto base)=\n'), disp(p0.')
s  = null(M);    s  = s/norm(s);
fprintf('Dirección s        =\n'), disp(s.')

%% 4 · g(α)=0  y búsqueda robusta de la raíz ---------------------------
n1 = nT(1,:).';          % columna 3×1
n2 = nT(2,:).';
g  = @(a) ratioErr(a,p0,s,n1,n2,m,P(2)/P(1),H);

alphagrid = linspace(-10,10,4001);
vals = arrayfun(g, alphagrid);
idx  = find(vals(1:end-1).*vals(2:end) < 0, 1);   % primer cruce de signo
if isempty(idx), error('Amplía el rango de α.'); end
a1 = alphagrid(idx);  a2 = alphagrid(idx+1);

alphaStar = fzero(g, [a1 a2]);
fprintf('α* encontrado      = %.6f\n', alphaStar)

%% 5 · Posición y K estimados ------------------------------------------
Rest = p0 + alphaStar*s;
dEst = Rest - [0;0;H];   dnEst = norm(dEst);
cosPsiEst  = (H-Rest(3))/dnEst;
cosPhi1Est = dot(dEst,n1)/dnEst;
Kest = P(1)*dnEst^2/(cosPhi1Est^m*cosPsiEst);

%% 6 · Verificación de las 4 potencias ---------------------------------
Ppred = zeros(4,1);
for i = 1:4
    cosPhi = dot(dEst,nT(i,:).')/dnEst;
    Ppred(i) = Kest*(cosPhi^m)*cosPsiEst/dnEst^2;
end
fprintf('\nP reales      : '), disp(P.')
fprintf('P predichas   : '), disp(Ppred.')
fprintf('Error máximo  : %.3e\n', max(abs(P-Ppred)))

%% 7 · Resultados finales ----------------------------------------------
fprintf('-------------------------------------------------------------\n');
fprintf('Referencia (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rref);
fprintf('Estimado   (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rest);
fprintf('Error total        : %.2e m\n', norm(Rest'-Rref));
fprintf('K real / estimado  : %.3f  /  %.3f\n', Ktrue, Kest);

%=================== función g(α) ======================================
function r = ratioErr(a,p0,s,n1,n2,m,ratioObs,H)
   p = p0 + a*s;
   d = p - [0;0;H];   dn = norm(d);
   cosPhi1 = dot(d,n1)/dn;
   cosPhi2 = dot(d,n2)/dn;
   r = (cosPhi2/cosPhi1)^m - ratioObs;
end
