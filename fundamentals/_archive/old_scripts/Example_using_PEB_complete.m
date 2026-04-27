%% Helper function to calculate Lambertian order from half-power angle
function m = lambertian_order(theta_half)
% Calculate Lambertian order from LED half-power angle
% m = -ln(2) / ln(cos(theta_half))
m = -log(2) / log(cos(theta_half));
end

%% Example usage function
% Example of how to use the PEB_complete function

% System parameters
T = [0; 0; 3];              % LED at 3m height
R = [1; 1; 0.8];            % Receiver position
Pt = 1;                     % 1W transmitted power
A_det = 1e-4;               % 1cm² photodiode area
theta_half = deg2rad(60);   % 60° half-power angle
m = lambertian_order(theta_half);
Psi_FOV = deg2rad(90);      % 90° field of view
sigma2 = 1e-12;             % Noise variance
N = 1000;                    % Samples per measurement

% Define K orientations (example: 4 orientations in different directions)
K = 4;
nt_orientations = zeros(3, K);
nt_orientations(:, 1) = [1; 0; -1] / norm([1; 0; -1]);    % Tilted towards +x
nt_orientations(:, 2) = [-1; 0; -1] / norm([-1; 0; -1]);  % Tilted towards -x
nt_orientations(:, 3) = [0; 1; -1] / norm([0; 1; -1]);    % Tilted towards +y
nt_orientations(:, 4) = [0; -1; -1] / norm([0; -1; -1]);  % Tilted towards -y

% Calculate PEB
PEB = PEB_complete(R, nt_orientations, T, Pt, m, A_det, theta_half, Psi_FOV, sigma2, N);

fprintf('Position Error Bound: %.4f m\n', PEB);
