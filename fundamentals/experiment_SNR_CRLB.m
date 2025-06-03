% This script evaluates how the RMS error of position estimation varies
% as the SNR increases from 10dB to 50dB, with 5dB increments.
% Based on main_3D_withNoise.m

clear; close all; clc;

rng(42); % For reproducibility

%% Parameters setup
% SNR range to evaluate
SNR_dB_range = 0:5:50; % From 10dB to 50dB with 5dB steps
num_SNR_points = length(SNR_dB_range);

% Room dimensions [m] - Matched with main_3D_withNoise.m
Lx = 2.4; Ly = 2.4; Lz = 2;

% Parameters of LED (Transmitter) - Matched with main_3D_withNoise.m
P_t = 0.405; % Optical power of LED [W]
theta_half = 45; % Semi-angle at half-power [°]
m_t = -log(2)./log(cosd(theta_half)); % Lambertian order of emission

% LED orientation vectors - One LED with different orientations
theta = 30; % Main angle of orientation [°]
n_t = [       0,              0,             -1;
              0,    sind(theta),   -cosd(theta);
    sind(theta),              0,   -cosd(theta);
   -sind(theta),              0,   -cosd(theta);
              0,   -sind(theta),   -cosd(theta);
          sqrt(2)/2*sind(theta),   sqrt(2)/2*sind(theta),  -cosd(theta);
          sqrt(2)/2*sind(theta),  -sqrt(2)/2*sind(theta),  -cosd(theta);
         -sqrt(2)/2*sind(theta),   sqrt(2)/2*sind(theta),  -cosd(theta);
         -sqrt(2)/2*sind(theta),  -sqrt(2)/2*sind(theta),  -cosd(theta)];

% Parameters of the receiver - Matched with main_3D_withNoise.m
p = 4.8e-3; q = 5.5e-3; % Dimensions of the rectangular photodiode [m]
N_det = 1; % Number of photodiodes
A_r = p*q*N_det; % Photoreceiver sensitive area [m²]
R_pd = 0.63; % Photosensitivity of the photodiode [A/W]
FOV = 85 * (pi/180); % Field of view of the photoreceiver [rad]
n_r = [0, 0, 1]; % Normal vector of the photoreceiver
param_r = {A_r, n_r, FOV};

% Transmitter parameters packed
T = [0;0;0]';

% Receiver positions (random in the room) [m]
N_pos = 1000; % Number of random positions as specified

% Generate random positions within the room
% The coordinate system has origin at LED position (0,0,0) and the room extends below and to sides
X_r = -Lx/2 + Lx.*rand(1, N_pos); % x-axis Rx coordinate (-Lx/2 to Lx/2)
Y_r = -Ly/2 + Ly.*rand(1, N_pos); % y-axis Rx coordinate (-Ly/2 to Ly/2)
Z_r = -(0.8+0.8*rand(1, N_pos)); % z-axis Rx coordinate (-0.8 to -1.6m)

% Number of orientations to use
N_or = 5; % Using all 9 orientations for the CRLB analysis

% Arrays to store results
RMSE_CRLB = zeros(num_SNR_points, 1);
PEB_positions = zeros(N_pos, num_SNR_points); % Store PEB for each position

%% Main loop - Vary SNR and calculate CRLB
for i_snr = 1:num_SNR_points
    current_SNR_dB = SNR_dB_range(i_snr);
    current_SNR_linear = 10^(current_SNR_dB/10);
    
    % Calculate sigma2 based on the desired SNR
    % Fixed base noise level from main_3D_withNoise.m
    base_sigma2 = 30e6*10^(-21.0)/(R_pd^2); % AWGN variance [A²] as in main file
    
    % Adjust noise for current SNR (will be used in position calculations)
    sigma2 = base_sigma2 * (10^(-current_SNR_dB/10));
    
    % Arrays to store the Fisher Information Matrix (FIM) for each position
    FIM_total = zeros(3, 3, N_pos);
    
    % Initialize array for position error bounds
    CRLB_pos = zeros(N_pos, 1);
    
    % Compute the CRLB for each position
    for i_pos = 1:N_pos
        % Get the receiver position
        theta = [X_r(i_pos); Y_r(i_pos); Z_r(i_pos)];
        
        % Extract the LED orientations for the first N_or orientations
        nt = n_t(1:N_or,:)';
        
        % Prepare parameters for vlp_peb function
        % LED/Transmitter position
        Tx = T';
        
        % Lambertian order
        m = m_t;
        
        % Radiometric constant as used in vlp_peb
        K = P_t*(m+1)*A_r/(2*pi);
        
        % Number of samples - using 1000 as in main_3D_withNoise.m
        N = 1000;
        
        % Calculate PEB (Position Error Bound) using analytical method
        PEB = vlp_peb_beam(theta, nt, Tx, m, K, sigma2, N, 1000);

        % Store the Fisher Information Matrix (not calculated in this approach)
        % Just store the inverse of PEB^2 for compatibility
        I_diagonal = 1/PEB^2;
        FIM_total(:,:,i_pos) = diag([I_diagonal, I_diagonal, I_diagonal]);
        
        % Store the PEB directly
        CRLB_pos(i_pos) = PEB;
    end
    
    % Count valid positions and store results for current SNR
    valid_positions = 0;
    
    for i_pos = 1:N_pos
        % Check if the PEB calculation was successful (not Inf or NaN)
        if isfinite(CRLB_pos(i_pos))
            valid_positions = valid_positions + 1;
            
            % Store the PEB for individual position analysis
            PEB_positions(i_pos, i_snr) = CRLB_pos(i_pos);
        else
            % If PEB is not valid, mark as invalid with NaN
            CRLB_pos(i_pos) = NaN;
            PEB_positions(i_pos, i_snr) = NaN;
        end
    end
    
    % Calculate RMSE over all valid positions (ignoring NaN values)
    valid_pos_data = CRLB_pos(~isnan(CRLB_pos));
    if ~isempty(valid_pos_data)
        RMSE_CRLB(i_snr) = sqrt(mean(valid_pos_data.^2));
    else
        RMSE_CRLB(i_snr) = NaN;
    end
    
    % Display progress
    fprintf('SNR = %.1f dB, RMSE CRLB = %.6f m, Valid positions: %d/%d\n', ...
        current_SNR_dB, RMSE_CRLB(i_snr), valid_positions, N_pos);
end

%% Plot the results

% Figure 1: RMSE vs SNR (overall results)
figure;
semilogy(SNR_dB_range, RMSE_CRLB, 'b-o', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('RMSE from CRLB (m)');
title('Average RMSE vs. SNR based on CRLB Analysis (1000 Positions)');
set(gca, 'FontSize', 12);

% Save the figure
saveas(gcf, 'CRLB_SNR_analysis.fig');
saveas(gcf, 'CRLB_SNR_analysis.png');

% Figure 2: Distribution of Position Error Bounds at different SNRs
figure;
colors = jet(num_SNR_points);
for i_snr = 1:num_SNR_points
    valid_data = PEB_positions(:, i_snr);
    valid_data = valid_data(~isnan(valid_data));
    if ~isempty(valid_data)
        % Create CDF of position errors
        [f, x] = ecdf(valid_data);
        plot(x, f, 'LineWidth', 1.5, 'Color', colors(i_snr,:));
        hold on;
    end
end
grid on;
xlabel('Position Error Bound (m)');
ylabel('Cumulative Probability');
title('CDF of Position Error Bounds at Different SNRs');

% Create legend
legend_entries = cell(num_SNR_points, 1);
for i = 1:num_SNR_points
    legend_entries{i} = sprintf('SNR = %.1f dB', SNR_dB_range(i));
end
legend(legend_entries, 'Location', 'southeast');
set(gca, 'FontSize', 12);

% Save the figure
saveas(gcf, 'CRLB_SNR_distribution.fig');
saveas(gcf, 'CRLB_SNR_distribution.png');

% Figure 3: Boxplot of Position Error Bounds
figure;
valid_data = PEB_positions;
boxplot(valid_data, 'Labels', cellstr(num2str(SNR_dB_range', 'SNR=%.1f dB')));
ylabel('Position Error Bound (m)');
title('Distribution of Position Error Bounds vs SNR');
set(gca, 'FontSize', 12);
ylim([0, 0.05]); % Adjust as needed for better visualization
grid on;

% Save the figure
saveas(gcf, 'CRLB_SNR_boxplot.fig');
saveas(gcf, 'CRLB_SNR_boxplot.png');

% Save the detailed results
save('CRLB_SNR_results.mat', 'SNR_dB_range', 'RMSE_CRLB', 'PEB_positions', 'X_r', 'Y_r', 'Z_r', 'N_or');

fprintf('Analysis complete. Results saved.\n');



function PEB = vlp_peb_beam(theta, nt, T, m, K, sigma2, N, Nb)
%-----------------------------------------------------------------
% theta   : 3×1  [x; y; z]      -> posición Rx (m)
% nt      : 3×n  orientaciones unitarias consideradas en la fase-1
% T       : 3×1  posición Tx [0;0;H] (m)
% m       : orden Lambertiano
% K       : constante radiométrica  P_t (m+1)A_det/(2π)
% sigma2  : varianza de UNA única muestra (W²)
% N       : nº de muestras promediadas en cada orientación de la fase-1
% Nb      : nº de muestras promediadas en la orientación *beam-steered*
%-----------------------------------------------------------------
% Devuelve: PEB  =  √tr{ I⁻¹ }  (m RMS)  con ambas fases incluidas
%-----------------------------------------------------------------

% -------- 1. Geometría ------------------------------------------
d      = theta - T;            % vector Tx→Rx (3×1)
nr     = [0;0;1];              % normal del receptor (arriba)
cr     = nr.'*(-d);            % cos(ψ)=H−z
normd  = norm(d);
n      = size(nt,2);

% Dirección "real" para la orientación beam-steered
d_unit = d / normd;            % = v_tr  (3×1)

% -------- 2. Fisher Information Matrix --------------------------
I = zeros(3);                  % inicializa FIM

% --- (a) Orientaciones de la fase-1 -----------------------------
for i = 1:n
    nt_i = nt(:,i);
    ci   = nt_i.'*d;           % cos(φ_i)*‖d‖
    g_i  = ( ...
           m     * ci^(m-1) * cr / normd^(m+3) * nt_i ...
        - (m+3)  * ci^m     * cr / normd^(m+5) * d     ...
        -             ci^m      / normd^(m+3) * nr );
    I = I + (N * K^2 / sigma2) * (g_i * g_i.');
end

% --- (b) Orientación beam-steered -------------------------------
% nt_beam =  d_unit   ;   cosφ = 1,  cosψ = 1
ci_b  = normd;                 % n_t·d  = ‖d‖  (porque cosφ=1)
cr_b  = cr;                    % sigue siendo H−z
g_b   = ( ...
        m     * ci_b^(m-1) * cr_b / normd^(m+3) * d_unit ...
      - (m+3) * ci_b^m     * cr_b / normd^(m+5) * d      ...
      -            ci_b^m         / normd^(m+3) * nr );
I = I + (Nb * K^2 / sigma2) * (g_b * g_b.');   % contribución extra

% -------- 3. PEB (RMS) ------------------------------------------
PEB = sqrt(trace(inv(I)));      % √tr{I⁻¹}
end
