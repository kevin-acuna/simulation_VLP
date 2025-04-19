% ===== File: test_position3D.m ==========================================
function test_position3D
    %--- Ajustes del experimento ----------------------------------------
    H  = 2.0;              % altura del LED
    m  = 2;              % orden lambertiano
    Rref = [0.40 0.25 1.10];% posición real (x_ref,y_ref,z_ref)
    Ktrue = 0.8;           % factor de escala (desconocido)
    
    %--- Orientaciones del LED (4 en total) -----------------------------
    nT = [ ...
        0           0           -1      ;  % vertical
        sind(30)    0           -cosd(30);
       -sind(30)/2  sind(30)*sqrt(3)/2  -cosd(30);
       -sind(30)/2 -sind(30)*sqrt(3)/2  -cosd(30)];
    
    %--- Potencias sin ruido -------------------------------------------
    P = zeros(1,4);
    d = Rref - [0 0 H];
    dNorm = norm(d);
    cosPsi = dot([0 0 1],-d)/dNorm;
    for i = 1:4
        cosPhi = dot(d,nT(i,:))/dNorm;
        P(i)   = Ktrue*(cosPhi^m)*cosPsi/dNorm^2;
    end
    
    %--- Estimación de (x,y,z,K) con las 4 potencias -------------------
    x0   = [0 0 0 0.1];                    % punto inicial para fsolve
    opts = optimoptions('fsolve','Display','off');
    vEst = fsolve(@(v) powerError(v,nT,P,m,H), x0, opts);
    xEst=vEst(1); yEst=vEst(2); zEst=vEst(3); KEst=vEst(4);
    
    %--- Resultados -----------------------------------------------------
    fprintf('\nReferencia : (%.3f, %.3f, %.3f) m\n', Rref);
    fprintf('Estimacion : (%.3f, %.3f, %.3f) m\n', xEst, yEst, zEst);
    fprintf('Error total: %.3e m\n', norm([xEst yEst zEst]-Rref));
    fprintf('K real/est : %.3f  /  %.3f\n\n', Ktrue, KEst);
end
% =======================================================================

% ===== File: powerError.m (función auxiliar) ===========================
function F = powerError(v, nT, P, m, H)
    x = v(1);  y = v(2);  z = v(3);  K = v(4);
    d = [x y z] - [0 0 H];
    dNorm  = sqrt(sum(d.^2));
    cosPsi = dot([0 0 1],-d)/dNorm;
    F = zeros(4,1);
    for i = 1:4
        cosPhi = dot(d,nT(i,:))/dNorm;
        F(i)   = K*(cosPhi^m)*cosPsi/dNorm^2 - P(i);
    end
end
% =======================================================================
