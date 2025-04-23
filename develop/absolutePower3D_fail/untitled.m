%-----------------------------------------------------------------------
%  test_position3D.m
%  -------------------------------------------------
%  Four absolute powers, global scale K unknown.
%  The script   1) creates the 4 noiseless powers
%               2) estimates (x,y,z,K)
%               3) compares with the reference values
%-----------------------------------------------------------------------
clear, clc

%% -----------  PARAMETERS ---------------------------------------------
H  = 2.0;          % LED height (m)
m  = 1.5;          % Lambertian order
Rref = [0.40 0.25 1.10];      % <-- change these to test other points
Ktrue = 0.8;                   % unknown scale

%% -----------  FOUR ORIENTATIONS  -------------------------------------
% vertical + 3 directions 30° tilted, 120° apart
nT = [ ...
     0         0        -1 ;                                % 1
     sind(30)  0       -cosd(30) ;                          % 2  (0°)
    -sind(30)/2   sind(30)*sqrt(3)/2   -cosd(30) ;          % 3  (120°)
    -sind(30)/2  -sind(30)*sqrt(3)/2   -cosd(30) ];         % 4  (240°)

%% -----------  NOISELESS POWERS ---------------------------------------
d   = Rref - [0 0 H];
dn  = norm(d);
cosPsi = dot([0 0 1], -d)/dn;
P = zeros(1,4);
for i = 1:4
    cosPhi = dot(d, nT(i,:))/dn;
    P(i)   = Ktrue * (abs(cosPhi)^m)*cosPsi/dn^2;
end

%% -----------  ESTIMATION  --------------------------------------------
%  decision variables  v = [x y z K]
lb = [-2 -2 0    0];          % bounds (room 4×4×2  &  K>0)
ub = [ 2  2 H    10];

bestErr = inf;
bestSol = [];
opts = optimoptions('lsqnonlin','Display','off');
for k = 1:25                         % multistart
    v0 = [ -1+2*rand(1,2)  H*rand  0.5+rand ];  %#ok<RAND>
    sol = lsqnonlin(@(v) errP4(v,nT,P,m,H), v0, lb, ub, opts);
    err = norm(sol(1:3)-Rref);        % position error
    if err < bestErr
        bestErr = err; bestSol = sol;
    end
end
xEst = bestSol(1);  yEst = bestSol(2);  zEst = bestSol(3);  KEst = bestSol(4);

%% -----------  RESULTS  ------------------------------------------------
fprintf('\nReferencia : (%.4f, %.4f, %.4f) m\n', Rref);
fprintf('Estimacion : (%.4f, %.4f, %.4f) m\n', xEst, yEst, zEst);
fprintf('Error total: %.3e  m\n', bestErr);
fprintf('K real/est : %.3f  /  %.3f\n\n', Ktrue, KEst);



%-----------------------------------------------------------------------
%  errP4.m   (called by lsqnonlin)
%-----------------------------------------------------------------------
function F = errP4(v, nT, P, m, H)
    x=v(1); y=v(2); z=v(3); K=v(4);
    d = [x y z] - [0 0 H];
    dn = norm(d);
    cosPsi = dot([0 0 1], -d)/dn;
    F = zeros(4,1);
    for i = 1:4
        cosPhi = dot(d, nT(i,:))/dn;
        F(i)   = K*(abs(cosPhi)^m)*cosPsi/dn^2 - P(i);
    end
end
