    % --- datos de ejemplo ---
    clc, clear, close
    n_orientation=5;

    theta = 30;
    n_t = [       0,              0,             -1;
                  0,    sind(theta),   -cosd(theta);
        sind(theta),              0,   -cosd(theta);
       -sind(theta),              0,   -cosd(theta);
                  0,   -sind(theta),   -cosd(theta);
              sqrt(2)/2*sind(theta),   sqrt(2)/2*sind(theta),  -cosd(theta);
              sqrt(2)/2*sind(theta),  -sqrt(2)/2*sind(theta),  -cosd(theta);
             -sqrt(2)/2*sind(theta),   sqrt(2)/2*sind(theta),  -cosd(theta);
             -sqrt(2)/2*sind(theta),  -sqrt(2)/2*sind(theta),  -cosd(theta)]';


    R      = [-1.0418   ;-0.9302 ;  -1.5734];         % Rx (m)
    T      = [0; 0; 0];             % Tx (m)
    m      = 2;                     % LED semiancho ≈ 60°
    K      = 5.1051e-06;                % <<< 
    N = 1000 % El número de muestras
    sigma2 = 3.0000e-14/N;                % <<< 
    

    n_t = n_t(:,1:n_orientation)

    PEB = vlp_peb(R, n_t, T, m, K, sigma2);
    fprintf('CRLB (PEB) = %.2f cm\n', 100*PEB);


% Caso 1:
% R      = [-0.6349; -0.2604; -1.4549]; 
%       -0.6380   -0.2562   -1.4508 (estimado)
%        0.0030   -0.0043   -0.0041 (diferencia)
%        0.0067=0.67cm


% Caso 2:
% R      = [0.0834    0.4903   -1.3116]; 
%       0.0782    0.4908   -1.3105 (estimado)
%       error (RMS para 1 muestra): 0.0054=0.54cm

% Caso 3:
% R = [0.8255; 0.2821; -1.3921];
% e_GLS = 0.0059
% e_WLS = 

% R=[-1.0418   ;-0.9302 ;  -1.5734]
% e=0.0561