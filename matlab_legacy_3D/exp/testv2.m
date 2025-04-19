%=======================================================================
%  det4P_demo.m  (versión corregida)
%=======================================================================
clear, clc
%% 1 · Datos del problema (idénticos) -----------------------------------
H  = 2.0;     m = 1.5;
Rref  = [0.40 0.25 1.10];
Ktrue = 0.8;
nT = [ 0 0 -1 ;
       sind(30) 0 -cosd(30) ;
      -sind(30)/2  sind(30)*sqrt(3)/2  -cosd(30) ;
      -sind(30)/2 -sind(30)*sqrt(3)/2  -cosd(30) ];

%% 2 · Potencias sin ruido ---------------------------------------------
d  = Rref - [0 0 H];   dn = norm(d);
cosPsi = (H - Rref(3))/dn;
for i = 1:4
   cosPhi = dot(d,nT(i,:))/dn;
   P(i)   = Ktrue*(cosPhi^m)*cosPsi/dn^2;
end

%% 3 · Recta p = p0 + α s  (dos ecuaciones lineales) -------------------
beta  = (P./P(1)).^(1/m);
Delta = nT(2:3,:) - beta(2:3)'.*nT(1,:);
M = Delta(:,1:3);   b = H*Delta(:,3);

p0 = M\b;                 % -> 3×1  (columna)   🔧
s  = null(M);             % -> 3×1  (columna)
s  = s/norm(s);           % normaliza            🔧

%% 4 · Ecuación escalar g(α) = 0 (ratio P2/P1) --------------------------
%   n1 y n2 también como columnas (3×1)                                   🔧
n1 = nT(1,:).';   n2 = nT(2,:).';          

g  = @(alpha) ratioError(alpha,p0,s,n1,n2,m,P(2)/P(1),H);
alphaStar = fzero(g, 0);                  % raíz única

%% 5 · Recuperación de posición y K ------------------------------------
Rest = p0 + alphaStar*s;                  % 3×1
dEst = Rest - [0;0;H];                    dnEst = norm(dEst);
cosPsiEst  = (H-Rest(3))/dnEst;
cosPhi1Est = dot(dEst,n1)/dnEst;
Kest = P(1)*dnEst^2/(cosPhi1Est^m*cosPsiEst);

%% 6 · Resultados -------------------------------------------------------
fprintf('\n--- DEMOSTRACIÓN DETERMINISTA ---\n');
fprintf('Referencia (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rref);
fprintf('Estimado   (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rest);
fprintf('Error total        : %.3e m\n', norm(Rest'-Rref));
fprintf('K real / estimado  : %.3f  /  %.3f\n', Ktrue, Kest);

%==================== función escalar g(α) =============================
function r = ratioError(alpha,p0,s,n1,n2,m,ratioObs,H)
    p  = p0 + alpha*s;                     % 3×1
    d  = p - [0;0;H];
    dn = norm(d);
    cosPhi1 = dot(d,n1)/dn;
    cosPhi2 = dot(d,n2)/dn;
    r = (cosPhi2/cosPhi1)^m - ratioObs;    % g(α)
end
