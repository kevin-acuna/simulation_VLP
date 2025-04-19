%=======================================================================
%  det4P_solver.m — determinismo con 4 potencias absolutas (K descon.)
%=======================================================================
clear, clc
%% 1 · Escenario --------------------------------------------------------
H  = 2.0;      m = 1.5;
Rref  = [0.30 0.50 0.20];       % << posición de prueba
Ktrue = 0.4;

% Orientaciones (vertical + 3 inclinadas 30°, 120° apartadas)
nT = [ 0 0 -1 ;
       sind(30) 0 -cosd(30) ;
      -sind(30)/2  sind(30)*sqrt(3)/2  -cosd(30) ;
      -sind(30)/2 -sind(30)*sqrt(3)/2  -cosd(30) ];

%% 2 · Potencias sin ruido ---------------------------------------------
d  = Rref - [0 0 H];  dn = norm(d);
cosPsi = (H-Rref(3))/dn;
P = zeros(4,1);
for i = 1:4
    cosPhi = dot(d,nT(i,:))/dn;
    P(i)   = Ktrue*(cosPhi^m)*cosPsi/dn^2;
end
disp('Potencias P(i) :' ), disp(P.')

%% 3 · p0 + s·α a partir de los ratios  P2/P1 , P3/P1 ------------------
% Solo se requiere 3 orientaciones
beta  = (P./P(1)).^(1/m);                 % 4×1
Delta = nT(2:3,:) - beta(2:3).*nT(1,:);
M = Delta(:,1:3);  b = H*Delta(:,3);
p0 = M\b;          
s  = null(M);  s = s/norm(s); % Direccion unitaria Transmisor a Receptor

fprintf('p0 = [%g %g %g]\n', p0)
fprintf('s  = [%g %g %g]\n', s)

%% 4 · Starting point para fsolve  -------------------------------------
%   altura intermedia (α = 0)
z0 = p0(3);
if z0<=0 || z0>=H
    % si cae fuera, toma α pequeño para dejar z ~ 0.5*H
    alpha0 = (0.5*H - z0)/s(3);
else
    alpha0 = 0;
end
v0 = [ (p0 + alpha0*s).'   1 ];    % (x,y,z,K) inicial
fprintf('Punto inicial fsolve  v0 = [%g %g %g %g]\n', v0)

%% 5 · Resolver las 4 ecuaciones en bloque -----------------------------
F = @(v) sys4(v,nT,P,m,H);

opts = optimoptions('fsolve','Display','iter',...
                    'TolFun',1e-14,'TolX',1e-14);
[v,~,flag] = fsolve(F, v0, opts);

if flag<=0
    error('fsolve no convergió (flag=%d).',flag);
end

Rest = v(1:3);  Kest = v(4);

%% 6 · Comprobaciones LOS ----------------------------------------------
dEst = Rest - [0 0 H];  dnEst = norm(dEst);
LOS_ok = true;
for i=1:4
    if dot(dEst,nT(i,:))/dnEst <= 0, LOS_ok=false; break, end
end
if ~LOS_ok
   error('La solución encontrada no cumple LOS en las 4 orientaciones.');
end

%% 7 · Resultados -------------------------------------------------------
Ppred = zeros(4,1);
cosPsiEst = (H-Rest(3))/dnEst;
for i=1:4
   cosPhi = dot(dEst,nT(i,:))/dnEst;
   Ppred(i)= Kest*(cosPhi^m)*cosPsiEst/dnEst^2;
end

fprintf('\nP reales  : '), disp(P.')
fprintf('P predich : '), disp(Ppred.')
fprintf('-------------------------------------------------------------\n');
fprintf('Referencia (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rref);
fprintf('Estimado   (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rest);
fprintf('Error posición     : %.2e m\n', norm(Rest-Rref));
fprintf('K real / est.      : %.3f  /  %.3f\n', Ktrue, Kest);

%================== función de residuo  (4 potencias) ==================
function F = sys4(v,nT,P,m,H)
    x=v(1); y=v(2); z=v(3); K=v(4);
    d = [x y z] - [0 0 H];  dn = norm(d);
    cosPsi = (H-z)/dn;
    F = zeros(4,1);
    for i=1:4
        cosPhi = dot(d,nT(i,:))/dn;
        F(i) = K*(cosPhi^m)*cosPsi/dn^2 - P(i);
    end
end
