%% explore_VCSEL_irradiance.m — Visualize VCSEL Gaussian Beam Irradiance
%
% Self-contained script to understand and visualize the VCSEL irradiance model.
%
% TWO MODELS COMPARED:
%
% MODEL A — Full Gaussian Beam (from the papers, Eqs. 5-9):
%   I(d, phi) = [2*P_t / (pi*w(d)^2)] * exp(-2*d^2*sin^2(phi) / w(d)^2)
%   w(d) = w0 * sqrt(1 + (lambda*d*cos(phi)/(pi*w0^2))^2)
%
%   This is the EXACT Gaussian beam propagation model. The beam spot size w(d)
%   grows with distance d. The irradiance depends on BOTH distance and angle.
%
% MODEL B — Far-field Gaussian approximation (our simplified model):
%   I(d, phi) ~ [P_t / (pi*theta_div^2*d^2)] * exp(-2*(phi/theta_div)^2)
%
%   This is valid in the FAR FIELD: d >> z_R (Rayleigh range).
%   In the far field: w(d) ≈ d*theta_div, so:
%     2/(pi*w^2) ≈ 2/(pi*theta_div^2*d^2)
%     d^2*sin^2(phi)/w^2 ≈ sin^2(phi)/theta_div^2 ≈ phi^2/theta_div^2 (small angle)
%
% CONCLUSION: Model B is Model A in the far-field limit. For indoor OWP
% (d = 1-3 m, z_R ~ 1-10 cm for typical VCSEL), we are ALWAYS in far field.
% Therefore Model B is appropriate.
%
% Author: Kevin Acuna-Condori
% Date: 8 Jun 2026

clear; clc; close all;

%% ========================================================================
% PARAMETERS — CHANGE THESE TO EXPLORE
% =========================================================================
P_t = 5e-3;           % Transmitted power [W]
lambda = 850e-9;      % Wavelength [m] (NIR VCSEL)
w0_values = [2e-6, 5e-6, 10e-6, 50e-6];  % Beam waist radius [m] (explore)

% Derived: divergence angle theta_div = lambda / (pi * w0)
% and Rayleigh range z_R = pi * w0^2 / lambda

% Room parameters
d_values = [0.5, 1.0, 1.5, 2.0, 2.5];  % Distances to evaluate [m]
phi_range = linspace(0, 30, 500);  % Emission angle [deg]
phi_rad = deg2rad(phi_range);

%% ========================================================================
% FIGURE 1: Show theta_div and z_R for different w0
% =========================================================================
fprintf('=== VCSEL Beam Parameters ===\n');
fprintf('%-10s  %12s  %12s  %12s\n', 'w0 [um]', 'theta_div [deg]', 'z_R [mm]', 'Far-field @ d>');
fprintf('%s\n', repmat('-', 1, 55));
for iw = 1:length(w0_values)
    w0 = w0_values(iw);
    theta_div = lambda / (pi * w0);  % half-angle divergence [rad]
    z_R = pi * w0^2 / lambda;        % Rayleigh range [m]
    fprintf('%-10.1f  %12.2f  %12.2f  %12.2f m\n', ...
        w0*1e6, rad2deg(theta_div), z_R*1e3, 5*z_R);
end

%% ========================================================================
% FIGURE 2: Compare Model A vs Model B for one w0 at multiple distances
% =========================================================================
w0 = 5e-6;  % 5 um beam waist (typical single-mode VCSEL)
theta_div_rad = lambda / (pi * w0);
z_R = pi * w0^2 / lambda;

fprintf('\n\nSelected w0 = %.1f um\n', w0*1e6);
fprintf('  theta_div = %.2f deg (%.4f rad)\n', rad2deg(theta_div_rad), theta_div_rad);
fprintf('  z_R = %.4f mm (Rayleigh range)\n', z_R*1e3);
fprintf('  Far-field condition: d >> %.2f mm → ALWAYS satisfied for d > 1 cm\n\n', z_R*1e3);

fig1 = figure('Units','inches', 'Position',[1 1 7 4], 'Color','w');

for id = 1:length(d_values)
    d = d_values(id);
    
    % --- Model A: Full Gaussian beam ---
    I_A = zeros(size(phi_rad));
    for ip = 1:length(phi_rad)
        phi = phi_rad(ip);
        % Beam radius at distance d along beam axis (using cos(phi) for axial distance)
        w_d = w0 * sqrt(1 + (lambda * d * cos(phi) / (pi * w0^2))^2);
        % Transverse displacement at distance d: r_perp = d * sin(phi)
        r_perp = d * sin(phi);
        % Intensity
        I_A(ip) = (2 * P_t) / (pi * w_d^2) * exp(-2 * r_perp^2 / w_d^2);
    end
    
    % --- Model B: Far-field approximation ---
    I_B = (2 * P_t) / (pi * (theta_div_rad * d)^2) * exp(-2*(phi_rad/theta_div_rad).^2);
    
    % Normalize both to boresight (phi=0) for shape comparison
    I_A_norm = I_A / I_A(1);
    I_B_norm = I_B / I_B(1);
    
    subplot(1, length(d_values), id);
    plot(phi_range, I_A_norm, 'b-', 'LineWidth', 1.2); hold on;
    plot(phi_range, I_B_norm, 'r--', 'LineWidth', 1.0);
    xlabel('$\phi$ [deg]', 'Interpreter','latex');
    if id == 1, ylabel('Normalized $I(\phi)/I(0)$', 'Interpreter','latex'); end
    title(sprintf('$d = %.1f$ m', d), 'Interpreter','latex');
    xlim([0 30]); ylim([0 1.05]);
    grid on; set(gca, 'FontSize', 7);
    if id == 1
        legend('Full (A)', 'Far-field (B)', 'FontSize', 6, 'Location','northeast');
    end
end
sgtitle(sprintf('Model A vs B ($w_0 = %d$ $\\mu$m, $\\theta_{div} = %.1f^\\circ$, $z_R = %.3f$ mm)', ...
    w0*1e6, rad2deg(theta_div_rad), z_R*1e3), 'Interpreter','latex', 'FontSize', 10);

%% ========================================================================
% FIGURE 3: Irradiance profile for different theta_div (using Model B)
% =========================================================================
% This is what matters for OWP: the angular shape at a given distance

theta_div_deg = [5, 10, 15, 20, 30];  % degrees
d_fixed = 2.0;  % typical ceiling-to-receiver distance [m]

fig2 = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w');
hold on;
colors = lines(length(theta_div_deg));

for it = 1:length(theta_div_deg)
    td = deg2rad(theta_div_deg(it));
    % Model B: I(phi) at distance d
    I_B = (2 * P_t) / (pi * (td * d_fixed)^2) * exp(-2*(phi_rad/td).^2);
    % Convert to received power (multiply by A_det, ignore cos(psi) for now)
    plot(phi_range, I_B * 1e3, '-', 'LineWidth', 1.0, 'Color', colors(it,:));
end

xlabel('Emission angle $\phi$ [deg]', 'Interpreter','latex', 'FontSize', 8);
ylabel('Irradiance $I(d,\phi)$ [mW/m$^2$]', 'Interpreter','latex', 'FontSize', 8);
legend(arrayfun(@(t) sprintf('$\\theta_{div}=%d^\\circ$', t), theta_div_deg, ...
    'UniformOutput', false), 'Interpreter','latex', 'FontSize', 6, 'Location','northeast');
grid on; box on;
set(gca, 'FontSize', 7, 'LineWidth', 0.5);
title(sprintf('VCSEL irradiance at $d=%.1f$ m ($P_t=%d$ mW)', d_fixed, P_t*1e3), ...
    'Interpreter','latex', 'FontSize', 9);

%% ========================================================================
% FIGURE 4: Absolute boresight power vs distance for different theta_div
% =========================================================================
d_range = linspace(0.5, 3, 100);

fig3 = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w');
hold on;

for it = 1:length(theta_div_deg)
    td = deg2rad(theta_div_deg(it));
    % Boresight irradiance (phi=0): I(d,0) = 2*P_t / (pi * theta_div^2 * d^2)
    I_boresight = (2 * P_t) ./ (pi * td^2 * d_range.^2);
    plot(d_range, I_boresight * 1e3, '-', 'LineWidth', 1.0, 'Color', colors(it,:));
end

xlabel('Distance $d$ [m]', 'Interpreter','latex', 'FontSize', 8);
ylabel('Boresight irradiance [mW/m$^2$]', 'Interpreter','latex', 'FontSize', 8);
set(gca, 'YScale', 'log');
legend(arrayfun(@(t) sprintf('$\\theta_{div}=%d^\\circ$', t), theta_div_deg, ...
    'UniformOutput', false), 'Interpreter','latex', 'FontSize', 6, 'Location','northeast');
grid on; box on;
set(gca, 'FontSize', 7, 'LineWidth', 0.5);
title('Boresight irradiance vs distance', 'Interpreter','latex', 'FontSize', 9);

%% ========================================================================
% FIGURE 5: Footprint radius on floor (H=2m, pointing down)
% =========================================================================
H = 2.0;  % ceiling height

fig4 = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w');
hold on;

for it = 1:length(theta_div_deg)
    td = theta_div_deg(it);
    % 1/e^2 radius on floor: r = H * tan(theta_div) ≈ H * theta_div (small angle)
    r_1e2 = H * tand(td);
    % -3dB radius: phi_{3dB} = theta_div * sqrt(ln2/2)
    phi_3dB = td * sqrt(log(2)/2);
    r_3dB = H * tand(phi_3dB);
    
    bar_data(it,:) = [r_3dB, r_1e2] * 100;  % in cm
end

b = bar(theta_div_deg, bar_data, 'grouped');
b(1).FaceColor = [0.2 0.5 0.8]; b(1).EdgeColor = 'none';
b(2).FaceColor = [0.8 0.3 0.2]; b(2).EdgeColor = 'none';
xlabel('$\theta_{div}$ [deg]', 'Interpreter','latex', 'FontSize', 8);
ylabel('Footprint radius on floor [cm]', 'Interpreter','latex', 'FontSize', 8);
legend({'$-3$ dB radius', '$1/e^2$ radius'}, 'Interpreter','latex', 'FontSize', 7);
grid on; box on;
set(gca, 'FontSize', 7, 'LineWidth', 0.5);
title(sprintf('Beam footprint at $H = %.1f$ m', H), 'Interpreter','latex', 'FontSize', 9);
% Add room half-width reference
yline(150, 'k--', 'Room edge (1.5 m)', 'FontSize', 6, 'LabelHorizontalAlignment', 'left');

%% ========================================================================
% SUMMARY TABLE
% =========================================================================
fprintf('\n=== VCSEL Footprint at H = %.1f m ===\n', H);
fprintf('%-12s  %12s  %12s  %15s\n', 'theta_div', 'r_{-3dB} [cm]', 'r_{1/e2} [cm]', 'Room coverage');
fprintf('%s\n', repmat('-', 1, 55));
for it = 1:length(theta_div_deg)
    td = theta_div_deg(it);
    r_1e2 = H * tand(td) * 100;
    phi_3dB = td * sqrt(log(2)/2);
    r_3dB = H * tand(phi_3dB) * 100;
    coverage_pct = min(100, (r_1e2/150)^2 * 100);  % approx circular/square
    fprintf('%-12d  %12.1f  %12.1f  %12.1f%%\n', td, r_3dB, r_1e2, coverage_pct);
end

fprintf('\n=== KEY INSIGHT ===\n');
fprintf('For indoor OWP (d > 0.5 m), the far-field Model B is excellent.\n');
fprintf('The full Gaussian beam (Model A) only matters for d < z_R (sub-mm range).\n');
fprintf('Our simplified model exp(-2*(phi/theta_div)^2) is physically correct.\n');
fprintf('The 1/(theta_div^2 * d^2) prefactor accounts for beam spreading.\n');
