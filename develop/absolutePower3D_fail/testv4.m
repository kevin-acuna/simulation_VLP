%=======================================================================
%  det4P_final.m  – resolución determinista robusta con 4 potencias
%=======================================================================
clear, clc
%% 1 · Datos del problema ----------------------------------------------
H  = 2.0;   m = 1.5;
Rref  = [0.40 0.25 1.10];        % pos. real
Ktrue = 0.8;                     % escala desconocida

% Orientaciones del LED
nT = [ 0 0 -1 ; ...
       sind(30) 0 -cosd(30) ; ...
      -sind(30)/2  sind(30)*sqrt(3)/2  -cosd(30) ; ...
      -sind(30)/2 -sind(30)*sqrt(3)/2  -cosd(30) ];

%% 2 · Potencias sin ruido ---------------------------------------------
d  = Rref - [0 0 H];  dn = norm(d);
cosPsi = (H-Rref(3))/dn;
for i = 1:4
   cosPhi = dot(d,nT(i,:))/dn;
   P(i)   = Ktrue*(cosPhi^m)*cosPsi/dn^2;
end

%% 3 · Recta  p = p0 + α s ---------------------------------------------
beta  = (P./P(1)).^(1/m);
Delta = nT(2:3,:) - beta(2:3)'.*nT(1,:);
M = Delta(:,1:3);     b = H*Delta(:,3);
p0 = M\b;                         % 3×1
s  = null(M);  s = s/norm(s);     % 3×1

n1 = nT(1,:).';      n2 = nT(2,:).';

g  = @(a) ratioErr(a,p0,s,n1,n2,m,P(2)/P(1),H);

%% 4 · Localizar TODAS las raíces dentro de ±10 m ----------------------
alphagrid = linspace(-10,10,4001);
sgn = sign(arrayfun(g,alphagrid));
cross = find(diff(sgn)~=0);                     % cambios de signo
roots = [];                                     % candidatas
for k = 1:numel(cross)
    a1 = alphagrid(cross(k));
    a2 = alphagrid(cross(k)+1);
    roots(end+1) = fzero(g,[a1 a2]);            %#ok<SAGROW>
end
roots = unique(round(roots,12));                % eliminar duplicados

%% 5 · Evaluar cada raíz y quedarse con la física ----------------------
good = [];
for alpha = roots
    p   = p0 + alpha*s;
    z   = p(3);
    if z<=0 || z>=H, continue, end              % fuera del cuarto
    d   = p - [0;0;H];  dn = norm(d);
    cosPsiEst = (H-z)/dn;
    cosPhi1Est= dot(d,n1)/dn;
    Kest = P(1)*dn^2/(cosPhi1Est^m*cosPsiEst);
    if Kest<=0, continue, end                   % no físico
    % comprobar las otras potencias
    ok = true;
    for i = 2:4
        cosPhi = dot(d,nT(i,:).')/dn;
        Ppred  = Kest*(cosPhi^m)*cosPsiEst/dn^2;
        ok = ok && abs(Ppred-P(i))<1e-12;
    end
    if ok, good = [p.' Kest]; break, end
end

%% 6 · Resultados -------------------------------------------------------
fprintf('\n--- SOLUCIÓN DETERMINISTA VALIDADA ---\n');
fprintf('Referencia (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rref);
fprintf('Estimado   (x,y,z) : (%.4f, %.4f, %.4f) m\n', good(1:3));
fprintf('Error total        : %.2e m\n', norm(good(1:3)-Rref));
fprintf('K real / estimado  : %.3f  /  %.3f\n', Ktrue, good(4));

%================ función g(α) ==========================================
function r = ratioErr(a,p0,s,n1,n2,m,ratioObs,H)
   p = p0 + a*s;
   d = p - [0;0;H];  dn = norm(d);
   cosPhi1 = dot(d,n1)/dn;
   cosPhi2 = dot(d,n2)/dn;
   r = (cosPhi2/cosPhi1)^m - ratioObs;
end
