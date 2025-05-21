function [x_est, y_est, x_real, y_real] = positionEstimator(n_t_s)
% GET_POSITION_ESTIMATES Obtiene las estimaciones de posición para un conjunto de orientaciones
%
%   n_t_s : vector con [theta_1, rho_1, theta_2, rho_2, ..., theta_n, rho_n]
%
%   Devuelve:
%     x_est, y_est: matrices con las coordenadas estimadas
%     x_real, y_real: matrices con las coordenadas reales
%
%   Esta función es similar a POM_WLS_RMSE pero devuelve las coordenadas
%   en lugar del error RMS.

    import opticalWireless.*
    import positionEstimators.*

    NLOS = 1; % Only LOS: NLOS=0, LOS+NLOS : NLOS=1

    %% 1) Preparar parámetros
    % Leer parámetros usando la función setupParameters
    params = setupParameters();
    
    L      = params.room.L;
    W      = params.room.W;
    H      = params.room.H;
    P_t    = params.P_t;
    m_t    = params.m_t;
    coord_t= params.coord_t;

    z_ref  = params.z_ref;
    p      = params.p; 
    q      = params.q;
    FOV    = params.FOV;
    n_r    = params.n_r;
    R_pd   = params.R_pd;

    N0     = params.N0;
    BW     = params.signalBandwidth;

    testbed= params.testbed;
    step   = params.step;

    % Ruido total
    sigma2_tot = BW * N0;


    %% 1.2) En el caso de NLOS se requieren otros parametros 
    % Se puede comentar si solo se usa LOS
    if (NLOS==1)
        N_wx = 24; % Number of wall reflectors considered along the x axis
        N_wy = 24; % Number of wall reflectors considered along the y axis
        N_wz = 20; % Number of wall reflectors considered along the z axis
    
        % ------------------------------------------
        bounceOrderDecomposition = 0;
        bounceOrder = 1; % Number of bounces taken into account for the finite response
        % ------------------------------------------
        
        N = 2*N_wx*N_wy + 2*N_wx*N_wz + 2*N_wy*N_wz; % Total number of wall reflectors in the rooom
        [reflectors, n_w, dA, ~, ~, ~, ~] = roomGenerator(L, W, H, N_wx, N_wy, N_wz, 0);
        reflectivity = 0.6;
        rho = [reflectivity.*ones(1,N-N_wy*N_wx), reflectivity.*ones(1,N_wy*N_wx)]; % Reflectivity factor of the wall reflectors
        G_rho = diag(rho); % Reflectivity matrix
        param_w = {reflectors, n_w, dA, L, W, H, G_rho};
        i_t = 1;
    
        iteration = 0;
    end

    %% 2) Construir las orientaciones a partir de n_t_s
    %    El número de orientaciones n = length(n_t_s)/2
    if mod(length(n_t_s),2)~=0
        error('n_t_s debe tener un número par de elementos [theta, rho].');
    end
    nPairs = length(n_t_s)/2;
    orientations = zeros(nPairs,3);  % nPairs x 3 (cada fila es un vector normal)

    for i = 1:nPairs
        theta = n_t_s(2*(i-1)+1);  % 1,3,5,...
        rho   = n_t_s(2*(i-1)+2);  % 2,4,6,...
        % Convertir a radianes si lo deseas, pero con sind/cosd es ok en grados:
        x_u = sind(theta)*cosd(rho);
        y_u = sind(theta)*sind(rho);
        z_u = -cosd(theta);
        orientations(i,:) = [x_u, y_u, z_u];
    end

    %% 3) Definir el plano de recepción
    X_r = testbed(1):step:testbed(2);
    Y_r = testbed(3):step:testbed(4);
    [x_real, y_real] = meshgrid(X_r, Y_r);
    z = z_ref - H;  % si el (0,0,0) es el techo en param_t

    N_rx = length(X_r);
    N_ry = length(Y_r);

    % Chequear que el plano no esté fuera de la sala
    if abs(z) > H
        error('La altura del plano Rx excede la sala (z=%f, H=%f).', z, H);
    end

    %% 4) Simular potencias medidas
    %    P_r  -> [N_rx x N_ry x nPairs]
    P_r = zeros(N_rx, N_ry, nPairs);

    % para el metodo 'WLS'
    SNR = zeros(N_rx, N_ry, nPairs);

    A_det = p*q;  % Área PD (simple) - si hay N_det, multiplícalo
    param_r = {A_det, n_r, FOV};

    if (NLOS==1)
        delete(gcp("nocreate"));
        profile = "Processes";
        localPoolNumWorkers = 4;
    end


    for i_n = 1:nPairs
        param_t = {coord_t, orientations(i_n,:), m_t};
        %for ix = 1:N_rx     %  LOS
        parfor ix = 1:N_rx   %  LOS + NLOS

            for iy = 1:N_ry
                x_pos = X_r(ix);
                y_pos = Y_r(iy);
                
                % ...............................
                % Only LOS escenario (Comentar en casos de LOS+NLOS
                % escenarios)
                % ...............................
%                 if (NLOS==0)
%                 [hVal, ~, ~, ~] = h_LOS(param_t, 1, param_r, x_pos, y_pos, z);
%                 P_los = hVal * P_t;  % potencia óptica ideal
%                 end

                % ...............................
                % LOS + NLOS
                % ...............................
                %if (NLOS==1)
                [H_LOS, H_NLOS, ~] = opticalWirelessChannel(param_t, i_t, param_w, param_r, x_pos, y_pos, z, bounceOrderDecomposition, bounceOrder);
                P_los = ( H_LOS+H_NLOS)*P_t; % P_r_real (renombrado a P_los por compatibilidad
                %end

                % Añadir ruido simulando (opcional):
                % supondremos s_r ~ N( (R_pd * P_los), sqrt(sigma2_tot) ), 
                % generamos un vector estadístico:
                s_r = (R_pd * P_los).*ones(1,10000) + sqrt(sigma2_tot)*randn(1,10000);
                Pr_elec = mean(s_r.^2); 
                P_r(ix, iy, i_n) = sqrt(Pr_elec)/R_pd;

                % para el metodo 'WLS'
                SNR(ix,iy,i_n) = 10*log10( (R_pd*P_los)^2/sigma2_tot );
                
                % Estatus de iteracion en la que se encuentra
                fprintf('orientation n°%.0f, x = %.1f m, y = %.1f m (%.2f/100)\n', i_n, x_pos, y_pos, round( (  (i_n-1)*N_rx*N_ry + (ix-1)*N_ry + iy )/(nPairs*N_rx*N_ry)*100 , 2) );
            end
        end
    end

    save workspace;
    %% 5) Llamar a la función de estimación WLS
    [x_est, y_est] = estimatePosition(P_r, orientations, m_t, 'Method', 'WLS', 'SNR', SNR);
    %[x_est, y_est] = estimatePosition(P_r, orientations, m_t, 'Method', 'LS');
end
