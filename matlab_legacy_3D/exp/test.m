%=======================================================================
%  det4P_demo.m
%  -------------------------------------------------
%  Demostración de que 4 potencias (sin ruido) bastan
%  para estimar (x,y,z) y K cuando K es desconocido.
%=======================================================================
clear, clc

%% 1 · PARÁMETROS DEL ESCENARIO
H  = 2.0;                 % altura del LED
m  = 1.5;                 % orden lambertiano
Rref  = [0.40 0.25 1.10]; % <-- posición real (x,y,z)
Ktrue = 0.8;              % escala global desconocida

% orientaciones del LED  (vertical + 3 a 30° separados 120°)
nT = [ ...
  0            0           -1 ;                                 % i = 1
  sind(30)     0           -cosd(30) ;                          % i = 2
 -sind(30)/2   sind(30)*sqrt(3)/2   -cosd(30) ;                 % i = 3
 -sind(30)/2  -sind(30)*sqrt(3)/2   -cosd(30) ];                % i = 4

%% 2 · POTENCIAS SIN RUIDO
d  = Rref - [0 0 H];    dn = norm(d);
cosPsi = (H - Rref(3)) / dn;          % igual a dot([0 0 1],-d)/dn
P = zeros(1,4);
for i = 1:4
    cosPhi = dot(d, nT(i,:))/dn;
    P(i)   = Ktrue * (cosPhi^m) * cosPsi / dn^2;
end

%% 3 · ECUACIONES LINEALES  (dos ratios  P2/P1  y  P3/P1)
beta = (P./P(1)).^(1/m);              % β_i = (P_i/P_1)^(1/m)
Delta = nT(2:3,:) - beta(2:3)'.*nT(1,:);   % filas 2 y 3
M = Delta(:,1:3);                     b = H*Delta(:,3);
p0 = M\b;                             % punto base de la recta
s  = null(M).';  s = s/norm(s);       % dirección de la recta (1×3)

%% 4 · ECUACIÓN ESCALAR  g(α)=0  (ratio P2/P1)
g = @(alpha) ratioError(alpha,p0,s,nT(1,:),nT(2,:),m,P(2)/P(1),H);

% búsqueda de la raíz (única) en un intervalo amplio
alphaStar = fzero(g, 1);              % inicia en 0  (vale para cualquier caso)

%% 5 · POSICIÓN Y ESCALA RECUPERADAS
Rest = p0 + alphaStar*s;              % (x,y,z)
dEst = Rest - [0 0 H];                dnEst = norm(dEst);
cosPsiEst  = (H-Rest(3))/dnEst;
cosPhi1Est = dot(dEst,nT(1,:))/dnEst;
Kest = P(1)*dnEst^2 / (cosPhi1Est^m * cosPsiEst);

%% 6 · RESULTADOS
fprintf('\n--- RESULTADO DETERMINISTA (4 potencias, K desconocido) ---\n');
fprintf('Referencia (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rref);
fprintf('Estimado   (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rest);
fprintf('Error posicional   : %.3e m\n', norm(Rest-Rref));
fprintf('K real / estimado  : %.3f  /  %.3f\n', Ktrue, Kest);
%=======================================================================

% ---------- función interna g(α)  ------------------------------------
function r = ratioError(alpha, p0, s, n1, n2, m, ratioObs, H)
    p  = p0 + alpha*s;
    d  = p - [0 0 H];         dn = norm(d);
    cosPhi1 = dot(d,n1)/dn;
    cosPhi2 = dot(d,n2)/dn;
    r = (cosPhi2/cosPhi1)^m - ratioObs;      % g(α)=0
end
