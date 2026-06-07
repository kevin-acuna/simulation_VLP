%% sim01_pattern_comparison.m — Radiation Pattern Comparison (Linear Scale)
%
% Compares the angular radiation profiles of:
%   - Lambertian LED: cos^m(phi) for Phi_1/2 = 45 deg
%   - Gaussian VCSEL: exp(-2*(phi/theta_div)^2) for multiple theta_div
%
% Linear scale only.
%
% Author: Kevin Acuna-Condori
% Date: 7 Jun 2026
% Project: VCSEL Gaussian OWP

clear; clc; close all;

%% System Parameters
system_params_VCSEL;

% =========================================================================
% HYPERPARAMETERS
% =========================================================================
phi_range = linspace(0, 90, 500);    % Angular range [deg]
theta_div_plot = [5, 10, 15, 20, 30]; % Divergence angles to plot [deg]
SAVE_FIGS = true;
% =========================================================================

%% Compute radiation patterns

% Lambertian LED: R(phi) = cos^m(phi)
R_LED = cosd(phi_range).^m_LED;

% Gaussian VCSEL: R(phi) = exp(-2*(phi/theta_div)^2)
R_VCSEL = zeros(length(theta_div_plot), length(phi_range));
for it = 1:length(theta_div_plot)
    td = theta_div_plot(it);
    R_VCSEL(it,:) = exp(-2*(phi_range/td).^2);
end

%% Figure: Linear scale
fig = figure('Units','inches', 'Position',[1 1 3.5 2.6], 'Color','w');
hold on;

% VCSEL curves
colors_vcsel = lines(length(theta_div_plot));
h_vcsel = gobjects(length(theta_div_plot),1);
for it = 1:length(theta_div_plot)
    h_vcsel(it) = plot(phi_range, R_VCSEL(it,:), '-', ...
        'LineWidth', 0.9, 'Color', colors_vcsel(it,:));
end

% LED curve (thick, black dashed)
h_led = plot(phi_range, R_LED, 'k--', 'LineWidth', 1.2);

% Formatting
xlabel('Emission angle $\phi$ [$^\circ$]', 'Interpreter','latex', 'FontSize', 8);
ylabel('Normalized radiation $R(\phi)$', 'Interpreter','latex', 'FontSize', 8);
xlim([0 90]);
ylim([0 1.05]);
grid on; box on;
set(gca, 'FontSize', 7, 'LineWidth', 0.5);

% Legend
leg_labels = arrayfun(@(td) sprintf('VCSEL $\\theta_{\\mathrm{div}}{=}%d^\\circ$', td), ...
    theta_div_plot, 'UniformOutput', false);
leg_labels{end+1} = sprintf('LED $\\Phi_{1/2}{=}%d^\\circ$', Phi_half_LED);
legend([h_vcsel; h_led], leg_labels, ...
    'Interpreter','latex', 'FontSize', 5.5, 'Location','northeast');

% Mark 1/e^2 level
yline(exp(-2), ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.4, ...
    'HandleVisibility', 'off');
text(75, exp(-2)+0.03, '$1/e^2$', 'Interpreter','latex', 'FontSize', 6, ...
    'Color', [0.5 0.5 0.5]);

% Mark half-power level
yline(0.5, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.4, ...
    'HandleVisibility', 'off');
text(75, 0.53, '$-3$ dB', 'Interpreter','latex', 'FontSize', 6, ...
    'Color', [0.5 0.5 0.5]);

hold off;

%% Save
results_dir = fullfile(pwd, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

if SAVE_FIGS
    exportgraphics(fig, fullfile(results_dir, 'Fig01_pattern_comparison_linear.pdf'), ...
        'ContentType','vector', 'BackgroundColor','white');
    exportgraphics(fig, fullfile(results_dir, 'Fig01_pattern_comparison_linear.png'), ...
        'Resolution', 600, 'BackgroundColor','white');
    fprintf('Figure saved (pdf/png) to: %s\n', results_dir);
end

%% Print key values
fprintf('\n=== Pattern Characteristics ===\n');
fprintf('%-20s  %10s  %10s\n', 'Source', 'HPBW [deg]', '1/e^2 [deg]');
fprintf('%s\n', repmat('-', 1, 44));

% LED HPBW
hpbw_led = 2 * Phi_half_LED;
fprintf('%-20s  %10.1f  %10.1f\n', sprintf('LED (m=%.1f)', m_LED), hpbw_led, ...
    2*acosd(exp(-2)^(1/m_LED)));

% VCSEL HPBW and 1/e^2
for it = 1:length(theta_div_plot)
    td = theta_div_plot(it);
    hpbw_vcsel = 2 * td * sqrt(log(2)/2);  % phi where R = 0.5
    fprintf('%-20s  %10.1f  %10.1f\n', ...
        sprintf('VCSEL (td=%d deg)', td), hpbw_vcsel, 2*td);
end
