function params = setupParameters()

% SETUPPARAMETERS  Retorna una struct con parámetros globales de la simulación.

    % Ruido
    %  10^(-21.8) --- Low Level
    %  10^(-21.0) --- High Level
    params.N0 = 10^(-21.8);       % Nivel de ruido densidad espectral
    params.signalBandwidth = 30e6;

    % Parámetros de la sala
    params.room.L = 2.4;
    params.room.W = 2.4;
    params.room.H = 2.0;   % Altura del techo
    
    % Transmisor
    params.P_t = 0.405;    % Potencia Tx
    params.theta_half = 45;  % Semiángulo del LED
    % Exponente lambertiano
    params.m_t = -log(2)./log(cosd(params.theta_half));
    params.coord_t = [0 0 0];  % Posición del Tx
    
    % Receptor
    params.z_ref = [0.2 1.2];   % Altura del Rx sobre el piso
    params.p = 4.8e-3;          % Dimensión PD
    params.q = 5.5e-3;          % Dimensión PD
    params.FOV = 85;            % FOV del receptor
    params.n_r = [0, 0, 1];     % Normal del receptor
    params.R_pd = 0.63;         % Responsividad PD
    
    % Plano de recepción
    params.testbed = [-1.2 1.2 -1.2 1.2];  % (xmin xmax ymin ymax zmin zmax)
    params.step = 0.1;
end
