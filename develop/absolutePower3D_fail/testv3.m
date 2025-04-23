%=======================================================================
%  det4P_demo.m  (versión robusta)
%=======================================================================
clear, clc
%% 1 · Datos básicos ----------------------------------------------------
H  = 2.0;   m = 1.5;
Rref  = [0.40 0.25 1.10];
Ktrue = 0.8;

nT = [ 0 0 -1 ;
       sind(30) 0 -cosd(30) ;
      -sind(30)/2  sind(30)*sqrt(3)/2  -cosd(30) ;
      -sind(30)/2 -sind(30)*sqrt(3)/2  -cosd(30) ];

%% 2 · Potencias sin ruido ---------------------------------------------
d  = Rref - [0 0 H];  dn = norm(d);
cosPsi = (H-Rref(3))/dn;
for i = 1:4
    cosPhi = dot(d,nT(i,:))/dn;
    P(i)   = Ktrue*(cosPhi^m)*cosPsi/dn^2;
end

%% 3 · Recta p = p0 + α s (dos ecuaciones lineales) --------------------
beta  = (P./P(1)).^(1/m);
Delta = nT(2:3,:) - beta(2:3)'.*nT(1,:);
M = Delta(:,1:3);            b = H*Delta(:,3);
p0 = M\b;                    s = null(M);  s = s/norm(s);

n1 = nT(1,:).';  n2 = nT(2,:).';

g  = @(a) ratioErr(a,p0,s,n1,n2,m,P(2)/P(1),H);

%% 4 · Hallar intervalo donde g cambia de signo ------------------------
alphas = linspace(-5,5,2001);         % explora ±5 m en la recta
vals   = arrayfun(g, alphas);
idx    = find(vals(1:end-1).*vals(2:end) < 0, 1);     % primer cruce de signo
if isempty(idx)
    error('No se encontró un cambio de signo de g(α). Amplía el intervalo.');
end
a1 = alphas(idx);   a2 = alphas(idx+1);               % [a1,a2] asegura signo opuesto

alphaStar = fzero(g, [a1 a2]);        % raíz garantizada

%% 5 · Posición y escala ------------------------------------------------
Rest = p0 + alphaStar*s;              % (x,y,z)
dEst = Rest - [0;0;H];   dnEst = norm(dEst);
cosPsiEst  = (H-Rest(3))/dnEst;
cosPhi1Est = dot(dEst,n1)/dnEst;
Kest = P(1)*dnEst^2/(cosPhi1Est^m*cosPsiEst);

%% 6 · Resultados -------------------------------------------------------
fprintf('\n--- DEMOSTRACIÓN DETERMINISTA ROBUSTA ---\n');
fprintf('Referencia (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rref);
fprintf('Estimado   (x,y,z) : (%.4f, %.4f, %.4f) m\n', Rest);
fprintf('Error total        : %.2e m\n', norm(Rest'-Rref));
fprintf('K real / estimado  : %.3f  /  %.3f\n', Ktrue, Kest);

%========== función escalar g(α) =======================================
function r = ratioErr(alpha,p0,s,n1,n2,m,ratioObs,H)
    p = p0 + alpha*s;
    d = p - [0;0;H];  dn = norm(d);
    cosPhi1 = dot(d,n1)/dn;
    cosPhi2 = dot(d,n2)/dn;
    r = (cosPhi2/cosPhi1)^m - ratioObs;
end
