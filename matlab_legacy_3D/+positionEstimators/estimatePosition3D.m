%======================================================================
%  estimatePosition3D.m   (package +positionEstimators)
%  ----------------------------------------------------
%  Estima (x,y,z) con 4 potencias absolutas cuando el
%  factor de escala K es desconocido.
%
%  Inputs
%     P         :  (Nx,Ny,Nz,4)   potencias simuladas sin ruido
%     nT        :  (4,3)          vectores de orientación del LED
%     m         :  orden lambertiano
%     H         :  altura del LED
%
%  Outputs      matrices del mismo tamaño Nx×Ny×Nz
%     x_est, y_est, z_est
%======================================================================
function [x_est, y_est, z_est] = estimatePosition3D(P, nT, m, H)

    % Pre‑allocate output arrays
    [x_est,y_est,z_est] = deal(zeros(size(P,1), size(P,2), size(P,3)));

    % Loop over each grid point
    for ix = 1:size(P,1)
    for iy = 1:size(P,2)
    for iz = 1:size(P,3)

        % Extract the 4 power measurements at this point
        Pvec = squeeze(P(ix,iy,iz,:)).';
        
        % Compute the three power ratios beta = (P2/P1)^(1/m), etc.
        beta = (Pvec(2:4)./Pvec(1)).^(1/m);

        % Build the linear system M * p0 = b (rank = 2)
        Delta = nT(2:4,:) - beta .* nT(1,:);  % 3×3
        M     = Delta(:,1:3);                % effectively rank 2
        b     = H * Delta(:,3);

        % (a) Solve for a particular point p0 via least squares
        p0 = M \ b;

        % (b) Find the null‑space direction s (kernel of M)
        s = null(M.','r');   % returns a 3×1 basis vector
        s = s / norm(s);

        % Define the line function v(alpha) = point on line minus LED height
        v = @(alpha) p0 + alpha*s - [0; 0; H];

        % Define the scalar residual enforcing the P1 equation:
        resid = @(alpha) ...
            Pvec(1) * (norm(v(alpha))^2) - ...
            (abs(dot(v(alpha), nT(1,:).' ) / norm(v(alpha))).^m) .* ...
            (abs(dot([0;0;1], -v(alpha)) / norm(v(alpha))));

        % Solve resid(alpha)=0 for the unique alpha
        alpha0   = 0;  % initial guess
        alphaSol = fzero(resid, alpha0);

        % Recover the estimated 3D point
        p_est = p0 + alphaSol * s;

        % Store results
        x_est(ix,iy,iz) = p_est(1);
        y_est(ix,iy,iz) = p_est(2);
        z_est(ix,iy,iz) = p_est(3);

    end
    end
    end
end
