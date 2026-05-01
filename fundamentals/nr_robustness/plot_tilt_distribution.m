%% plot_tilt_distribution.m
% Visualize the truncated half-normal distribution used for random receiver
% tilt sampling. Helps choose sigma_tilt and theta_max_tilt.
%
% Author: Kevin Acuña

close all; clear; clc;

% =========================================================================
% PARAMETERS TO EXPLORE
% =========================================================================
sigma_candidates   = 5:10;   % [deg] — one curve per sigma
theta_max_tilt     = 35;               % [deg] — truncation limit (vertical line)
N_samples_mc       = 100000;           % Monte Carlo samples for empirical distribution
% =========================================================================

theta_vec = linspace(0, theta_max_tilt + 5, 500);

colors = lines(length(sigma_candidates));

%% Fig 1 — PDF curves (theoretical truncated half-normal)
fig1 = figure('Name', 'Tilt Distribution PDF', 'Position', [50, 100, 700, 480]);
hold on;

leg_str = {};
for k = 1:length(sigma_candidates)
    sig = sigma_candidates(k);

    % PDF of |N(0, sig^2)| = 2 * normpdf(x, 0, sig) for x >= 0
    pdf_raw  = 2 * normpdf(theta_vec, 0, sig);

    % Normalization constant for truncation at theta_max
    Z = 2 * normcdf(theta_max_tilt, 0, sig) - 1;   % P(|X| <= theta_max)
    pdf_trunc = pdf_raw / Z;
    pdf_trunc(theta_vec > theta_max_tilt) = 0;

    plot(theta_vec, pdf_trunc, '-', 'LineWidth', 2, 'Color', colors(k,:));
    leg_str{end+1} = sprintf('$\\sigma = %d^\\circ$', sig);
end

xline(theta_max_tilt, '--k', 'LineWidth', 1.2, 'Label', ...
    sprintf('$\\theta_{\\max} = %d^\\circ$', theta_max_tilt), ...
    'Interpreter', 'latex', 'FontSize', 11, 'LabelVerticalAlignment', 'bottom');

xlabel('Receiver Tilt $\theta_{\mathrm{tilt}}$ [deg]', 'Interpreter', 'latex', 'FontSize', 13);
ylabel('PDF', 'Interpreter', 'latex', 'FontSize', 13);
title('Truncated Half-Normal Distribution for Receiver Tilt', ...
    'Interpreter', 'latex', 'FontSize', 14);
legend(leg_str, 'Location', 'northeast', 'Interpreter', 'latex', 'FontSize', 11);
xlim([0, theta_max_tilt + 5]);
ylim([0, inf]);
grid on; box on;
hold off;

%% Fig 2 — CDF curves
fig2 = figure('Name', 'Tilt Distribution CDF', 'Position', [100, 100, 700, 480]);
hold on;

for k = 1:length(sigma_candidates)
    sig = sigma_candidates(k);

    cdf_raw   = 2 * normcdf(theta_vec, 0, sig) - 1;
    Z         = 2 * normcdf(theta_max_tilt, 0, sig) - 1;
    cdf_trunc = cdf_raw / Z;
    cdf_trunc(theta_vec > theta_max_tilt) = 1;

    plot(theta_vec, cdf_trunc, '-', 'LineWidth', 2, 'Color', colors(k,:));
end

xline(theta_max_tilt, '--k', 'LineWidth', 1.2);
yline(0.5,  ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0);
yline(0.9,  ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0);
yline(0.95, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0);

text(theta_max_tilt + 0.3, 0.50, '50\%', 'Interpreter', 'latex', 'FontSize', 10, 'Color', [0.4 0.4 0.4]);
text(theta_max_tilt + 0.3, 0.90, '90\%', 'Interpreter', 'latex', 'FontSize', 10, 'Color', [0.4 0.4 0.4]);
text(theta_max_tilt + 0.3, 0.95, '95\%', 'Interpreter', 'latex', 'FontSize', 10, 'Color', [0.4 0.4 0.4]);

xlabel('Receiver Tilt $\theta_{\mathrm{tilt}}$ [deg]', 'Interpreter', 'latex', 'FontSize', 13);
ylabel('CDF', 'Interpreter', 'latex', 'FontSize', 13);
title('CDF of Truncated Half-Normal Tilt Distribution', ...
    'Interpreter', 'latex', 'FontSize', 14);

leg_str2 = {};
for k = 1:length(sigma_candidates)
    leg_str2{end+1} = sprintf('$\\sigma = %d^\\circ$', sigma_candidates(k));
end
legend(leg_str2, 'Location', 'southeast', 'Interpreter', 'latex', 'FontSize', 11);
xlim([0, theta_max_tilt + 5]);
grid on; box on;
hold off;

%% Fig 3 — Empirical samples histogram (for one chosen sigma)
sig_chosen = 5;   % <-- change this to inspect a specific sigma
Z_chosen = 2 * normcdf(theta_max_tilt, 0, sig_chosen) - 1;

samples = zeros(N_samples_mc, 1);
for i = 1:N_samples_mc
    s = abs(sig_chosen * randn());
    while s > theta_max_tilt
        s = abs(sig_chosen * randn());
    end
    samples(i) = s;
end

fig3 = figure('Name', sprintf('Empirical Histogram sigma=%d', sig_chosen), ...
    'Position', [150, 100, 700, 480]);
hold on;
histogram(samples, 60, 'Normalization', 'pdf', ...
    'FaceColor', [0.3, 0.6, 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.7);

% Overlay theoretical PDF
pdf_th = 2 * normpdf(theta_vec, 0, sig_chosen) / Z_chosen;
pdf_th(theta_vec > theta_max_tilt) = 0;
plot(theta_vec, pdf_th, 'r-', 'LineWidth', 2.5);

xline(theta_max_tilt, '--k', 'LineWidth', 1.5);
xlabel('Receiver Tilt $\theta_{\mathrm{tilt}}$ [deg]', 'Interpreter', 'latex', 'FontSize', 13);
ylabel('PDF', 'Interpreter', 'latex', 'FontSize', 13);
title(sprintf('Empirical vs Theoretical PDF ($\\sigma = %d^\\circ$, $N = 10^5$ samples)', sig_chosen), ...
    'Interpreter', 'latex', 'FontSize', 14);
legend({'Empirical (histogram)', 'Theoretical'}, ...
    'Interpreter', 'latex', 'FontSize', 11, 'Location', 'northeast');
grid on; box on;
hold off;

%% Console summary table
fprintf('%s\n', repmat('=', 1, 70));
fprintf('  TRUNCATED HALF-NORMAL STATISTICS (theta_max = %d deg)\n', theta_max_tilt);
fprintf('%s\n', repmat('=', 1, 70));
fprintf('  %-8s  %-10s  %-10s  %-12s  %-12s  %-10s\n', ...
    'sigma', 'Mean [°]', 'Median [°]', 'P(θ<5°) [%]', 'P(θ<10°) [%]', 'Rej. rate');
fprintf('%s\n', repmat('-', 1, 70));
for k = 1:length(sigma_candidates)
    sig = sigma_candidates(k);
    Z   = 2 * normcdf(theta_max_tilt, 0, sig) - 1;

    % Mean of truncated half-normal
    mean_th = sig * sqrt(2/pi) * (1 - exp(-theta_max_tilt^2/(2*sig^2))) / Z;

    % Median (solve CDF = 0.5)
    cdf_at = @(t) (2*normcdf(t,0,sig)-1)/Z;
    med_th  = fzero(@(t) cdf_at(t) - 0.5, sig);

    p5  = cdf_at(5)  * 100;
    p10 = cdf_at(10) * 100;
    rej = (1 - Z) * 100;

    fprintf('  %-8d  %-10.2f  %-10.2f  %-12.1f  %-12.1f  %-10.2f%%\n', ...
        sig, mean_th, med_th, p5, p10, rej);
end
fprintf('%s\n', repmat('=', 1, 70));
