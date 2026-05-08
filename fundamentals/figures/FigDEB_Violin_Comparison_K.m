%% FigDEB_Violin_Comparison_K.m
% IEEE TCOM Figure: Split violin plot of DEB (optimized vs random)
% for K = 3..9 orientations. Uses DEB_complete.m for bound computation.
%
% Output: DEB_violin_comparison.png / .eps / .pdf
% Author: Kevin Acuña
close all; clear variables; clc;
rng(42);
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'core'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'estimators'));

%% ===== HYPERPARAMETERS =====
K_values       = 3:9;
N_realizations = 50;       % random sets per K
theta_max_rand = 70;       % max elevation for random orientations [deg]

% System (from system_params.m)
T        = [0; 0; 2];
P_t      = 0.405;
theta_half = 45;
m_t      = -log(2)/log(cosd(theta_half));
p = 4.8e-3; q = 5.5e-3;
A_det    = p*q;
FOV      = deg2rad(85);
sigma2   = 30e6*10^(-21.0);
N_samples = 1000;

% Room / testbed
L = 3; W = 3;
step = 0.2;       % grid step [m]
Hmax = 1.2; stepH = 0.2;

%% ===== DEB-OPTIMIZED ORIENTATIONS (from GA logs) =====
ori_opt = containers.Map('KeyType','int32','ValueType','any');
ori_opt(3) = [17.48,203.70, 17.22,332.20, 18.71,88.79];
ori_opt(4) = [29.88,315.03, 29.87,134.99, 29.87,45.03, 29.86,225.02];
ori_opt(5) = [0.10,74.22, 65.68,269.84, 65.73,179.90, 65.91,359.82, 65.88,89.91];
ori_opt(6) = [67.60,253.38, 66.63,321.05, 70.03,176.90, 0.12,274.29, 68.91,98.38, 66.82,24.94];
ori_opt(7) = [65.60,353.25, 2.46,10.07, 66.17,273.62, 64.59,196.54, 62.48,130.76, 2.56,191.66, 63.78,68.11];
ori_opt(8) = [67.61,67.08, 66.59,247.26, 2.79,39.70, 3.21,226.96, 64.71,2.81, 66.06,179.67, 66.89,298.24, 65.37,114.85];
ori_opt(9) = [66.06,165.39, 8.73,267.05, 66.75,273.80, 62.42,219.37, 64.16,21.63, 67.15,90.96, 13.90,105.06, 4.52,303.11, 62.04,330.31];

%% ===== GENERATE TESTBED =====
[X, Y, Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
X_r = X(:); Y_r = Y(:); Z_r = Z(:);
N_pos = length(X_r);
fprintf('Testbed: %d positions\n', N_pos);

%% ===== HELPER: orient vector → 3×K matrix =====
orient2mat = @(ori) cell2mat(arrayfun(@(i) ...
    [sind(ori(2*i-1))*cosd(ori(2*i)); ...
     sind(ori(2*i-1))*sind(ori(2*i)); ...
    -cosd(ori(2*i-1))], 1:length(ori)/2, 'UniformOutput', false));

%% ===== HELPER: compute DEB over testbed =====
function deb_vals = compute_deb_testbed(orientations, X_r, Y_r, Z_r, T, P_t, m_t, A_det, theta_half_rad, FOV, sigma2, N_samples, orient2mat)
    nt = orient2mat(orientations);
    N_pos = length(X_r);
    deb_vals = nan(N_pos, 1);
    for j = 1:N_pos
        R = [X_r(j); Y_r(j); Z_r(j)];
        val = DEB_complete(R, nt, T, P_t, m_t, A_det, theta_half_rad, FOV, sigma2, N_samples);
        if isfinite(val) && isreal(val) && val > 0
            deb_vals(j) = val;
        end
    end
    deb_vals = deb_vals(~isnan(deb_vals));
end

%% ===== COMPUTE DEB FOR EACH K =====
deb_optimized = cell(length(K_values), 1);
deb_random    = cell(length(K_values), 1);

theta_half_rad = deg2rad(theta_half);

for idx = 1:length(K_values)
    K = K_values(idx);
    fprintf('\n===== K = %d =====\n', K);
    
    % --- Optimized ---
    if ori_opt.isKey(K)
        fprintf('  Computing DEB (optimized)...');
        tic;
        deb_optimized{idx} = compute_deb_testbed(ori_opt(K), X_r, Y_r, Z_r, ...
            T, P_t, m_t, A_det, theta_half_rad, FOV, sigma2, N_samples, orient2mat);
        fprintf(' done (%.1fs), %d valid values\n', toc, length(deb_optimized{idx}));
    end
    
    % --- Random realizations ---
    fprintf('  Computing DEB (%d random sets): ', N_realizations);
    all_rand = [];
    for r = 1:N_realizations
        if mod(r, 10) == 0, fprintf('%d ', r); end
        % Random orientations: elevation uniform [0, theta_max_rand], azimuth [0, 360)
        ori_rand = zeros(1, 2*K);
        for n = 1:K
            ori_rand(2*n-1) = rand() * theta_max_rand;
            ori_rand(2*n)   = rand() * 360;
        end
        vals = compute_deb_testbed(ori_rand, X_r, Y_r, Z_r, ...
            T, P_t, m_t, A_det, theta_half_rad, FOV, sigma2, N_samples, orient2mat);
        all_rand = [all_rand; vals]; %#ok<AGROW>
    end
    deb_random{idx} = all_rand;
    fprintf('\n  Total random values: %d\n', length(all_rand));
end

%% ===== SAVE DATA (so plotting can be re-run without recomputing) =====
save_file = fullfile(fileparts(mfilename('fullpath')), 'DEB_violin_data.mat');
save(save_file, 'K_values', 'deb_optimized', 'deb_random', 'N_realizations');
fprintf('\nData saved to: %s\n', save_file);

%% ===== PLOT =====
% IEEE TCOM style: single-column width ~3.5in, double ~7in
fig = figure('Units','inches','Position',[1 1 7.16 3.5]);

% Colors
color_opt  = [0.298, 0.686, 0.314];   % green
color_rand = [0.957, 0.643, 0.376];   % orange

hold on;

for idx = 1:length(K_values)
    K = K_values(idx);
    x_center = K;
    
    data_opt  = rad2deg(deb_optimized{idx});  % convert to degrees
    data_rand = rad2deg(deb_random{idx});
    
    if isempty(data_opt) || isempty(data_rand), continue; end
    
    % --- Kernel density for violin shape ---
    y_lo = 0;
    y_hi = max([prctile(data_opt, 99.5), prctile(data_rand, 99.5)]);
    y_grid = linspace(y_lo, y_hi, 300);
    
    bw_opt  = 0.7 * std(data_opt)  * length(data_opt)^(-1/5);
    bw_rand = 0.7 * std(data_rand) * length(data_rand)^(-1/5);
    
    [f_opt, ~]  = ksdensity(data_opt,  y_grid, 'Bandwidth', bw_opt);
    [f_rand, ~] = ksdensity(data_rand, y_grid, 'Bandwidth', bw_rand);
    
    max_width = 0.38;
    f_opt_n  = f_opt  / max(f_opt)  * max_width;
    f_rand_n = f_rand / max(f_rand) * max_width;
    
    % Left half (optimized)
    fill([x_center - f_opt_n, fliplr(x_center*ones(size(f_opt_n)))], ...
         [y_grid, fliplr(y_grid)], color_opt, ...
         'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.4, 'FaceAlpha', 0.7);
    
    % Right half (random)
    fill([x_center*ones(size(f_rand_n)), fliplr(x_center + f_rand_n)], ...
         [y_grid, fliplr(y_grid)], color_rand, ...
         'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.4, 'FaceAlpha', 0.7);
    
    % --- Boxplot overlay ---
    bw = 0.06;
    
    % Optimized box
    q1o = prctile(data_opt, 25); medo = median(data_opt); q3o = prctile(data_opt, 75);
    p5o = prctile(data_opt, 5); p95o = prctile(data_opt, 95);
    xbo = x_center - 0.12;
    rectangle('Position', [xbo-bw/2, q1o, bw, q3o-q1o], ...
        'FaceColor', color_opt, 'EdgeColor', 'k', 'LineWidth', 0.5);
    line([xbo-bw/2, xbo+bw/2], [medo, medo], 'Color', 'k', 'LineWidth', 1);
    line([xbo, xbo], [q3o, p95o], 'Color', 'k', 'LineWidth', 0.5);
    line([xbo, xbo], [q1o, p5o], 'Color', 'k', 'LineWidth', 0.5);
    
    % Random box
    q1r = prctile(data_rand, 25); medr = median(data_rand); q3r = prctile(data_rand, 75);
    p5r = prctile(data_rand, 5); p95r = prctile(data_rand, 95);
    xbr = x_center + 0.12;
    rectangle('Position', [xbr-bw/2, q1r, bw, q3r-q1r], ...
        'FaceColor', color_rand, 'EdgeColor', 'k', 'LineWidth', 0.5);
    line([xbr-bw/2, xbr+bw/2], [medr, medr], 'Color', 'k', 'LineWidth', 1);
    line([xbr, xbr], [q3r, p95r], 'Color', 'k', 'LineWidth', 0.5);
    line([xbr, xbr], [q1r, p5r], 'Color', 'k', 'LineWidth', 0.5);
end

% Axis formatting (IEEE TCOM style)
set(gca, 'FontName', 'Times New Roman', 'FontSize', 9);
xlabel('Number of orientations ($K$)', 'Interpreter', 'latex', 'FontSize', 10);
ylabel('DEB [$^\circ$]', 'Interpreter', 'latex', 'FontSize', 10);
xlim([min(K_values)-0.5, max(K_values)+0.5]);
ylim([0, 6]);
xticks(K_values);
grid on;
set(gca, 'GridAlpha', 0.15, 'GridLineStyle', '-');
box on;

% Legend
h_opt  = patch(NaN, NaN, color_opt,  'FaceAlpha', 0.7, 'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.4);
h_rand = patch(NaN, NaN, color_rand, 'FaceAlpha', 0.7, 'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.4);
legend([h_opt, h_rand], {'Optimized', 'Random'}, ...
    'Location', 'northeast', 'FontSize', 8, 'Interpreter', 'latex', ...
    'Box', 'on');

% Export
out_dir = fullfile(fileparts(mfilename('fullpath')), 'outputs');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

exportgraphics(fig, fullfile(out_dir, 'DEB_violin_comparison.png'), 'Resolution', 600);
exportgraphics(fig, fullfile(out_dir, 'DEB_violin_comparison.pdf'), 'ContentType', 'vector');
fprintf('\nFigures exported to: %s\n', out_dir);

%% ===== SUMMARY TABLE =====
fprintf('\n============================================\n');
fprintf('  K   DEB_opt[°]  DEB_rand[°]  Improvement\n');
fprintf('--------------------------------------------\n');
for idx = 1:length(K_values)
    K = K_values(idx);
    d_opt  = rad2deg(deb_optimized{idx});
    d_rand = rad2deg(deb_random{idx});
    if ~isempty(d_opt) && ~isempty(d_rand)
        rms_opt  = sqrt(mean(d_opt.^2));
        rms_rand = sqrt(mean(d_rand.^2));
        improv   = (rms_rand - rms_opt) / rms_rand * 100;
        fprintf('  %d    %6.3f°     %6.3f°      %+.1f%%\n', K, rms_opt, rms_rand, improv);
    end
end
fprintf('============================================\n');
