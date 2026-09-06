%% poc_rx_steered_3D.m — Proof of Concept: 3D positioning with a FIXED LED and a single REORIENTABLE PD
%
% Dual of the TCOM architecture: the LED is a fixed anchor and the PD is steered
% through K known orientations in the receiver BODY frame (2-DOF gimbal).
%
% Pipeline per receiver position:
%   Stage A (coarse, single pass) : vertical cone of K_A orientations -> linear LS -> u_hat^B
%   Stage B (adaptive, optional)  : cone of K_B orientations centred on u_hat^B  -> LS on ALL data
%   Position                      : u^W = R u^B, cos(phi) = -n_t.u^W, d = sqrt(C cos^m(phi)/eta), r = t - d u^W
%
% Outputs: console table (RMSE / APE / P90 per height, PEB), 3D testbed figure
% (ground truth vs estimates), CDF (estimator vs PEB), orientation-set figure.
%
% Author: Kevin Acuna-Condori
% Date:   04 Sep 2026
% Project: Cambridge — RX-steered single-anchor OWP

close all; clear; clc;
addpath(fileparts(mfilename('fullpath')));

% =========================================================================
% HYPERPARAMETERS
% =========================================================================
rng(42);
DESIGN        = 'vertical_cone';   % 'led_centred' (2-stage adaptive) | 'vertical_cone' | 'wang'
K_A           = 8;               % Stage A: orientations on the vertical cone
theta_A       = 30;              % Stage A: cone half-angle [deg] (safe w.r.t. FOV; = Wang's tilt)
ADD_NADIR_A   = true;            % Stage A: append the body-vertical orientation (K_A+1 measurements)
K_B           = 4;               % Stage B: orientations on the LED-centred cone
theta_B       = 63.4;            % Stage B: cone half-angle [deg]  (design rule tan(theta)=2)
FUSE_STAGES   = true;            % LS on Stage A + Stage B measurements (else Stage B only)

ATT_DEG       = [30, 5, -3];     % Body attitude [yaw, pitch, roll] in deg (KNOWN to the estimator)
ATT_ERR_DEG   = 0;               % Std of attitude error injected in the estimator [deg] (0 = perfect IMU)

M_trials      = 200;             % Monte Carlo trials per position (statistics)
DROPOUT_NSIG  = 4;               % Threshold = DROPOUT_NSIG * sqrt(sigma2/N): treat as out of FOV
SAVE_FIGS     = true;
PRINT_EVERY   = 100;             % Console progress step

% Optional override for batch comparisons:  setenv('POC_DESIGN','wang'); poc_rx_steered_3D
if ~isempty(getenv('POC_DESIGN')), DESIGN = getenv('POC_DESIGN'); end

%% 1. System parameters (separate file)
P = poc_params();
R_true = rotm_zyx(ATT_DEG(1), ATT_DEG(2), ATT_DEG(3));   % body -> world
thr = DROPOUT_NSIG * sqrt(P.sigma2_mean);

%% 2. Testbed
[X, Y, Z] = meshgrid(-P.L/2:P.step:P.L/2, -P.W/2:P.step:P.W/2, 0:P.stepH:P.Hmax);
realPos = [X(:), Y(:), Z(:)];
N_pos = size(realPos, 1);
heights = unique(realPos(:, 3));

results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

fprintf('%s\n', repmat('=', 1, 72));
fprintf('PoC — RX-STEERED SINGLE-ANCHOR OWP (3D)\n');
fprintf('%s\n', repmat('=', 1, 72));
fprintf('Design        : %s\n', DESIGN);
fprintf('Stage A       : K_A=%d, theta_A=%.1f deg, nadir=%d\n', K_A, theta_A, ADD_NADIR_A);
if strcmp(DESIGN, 'led_centred')
    fprintf('Stage B       : K_B=%d, theta_B=%.1f deg, fuse=%d\n', K_B, theta_B, FUSE_STAGES);
end
fprintf('Attitude      : yaw=%.1f pitch=%.1f roll=%.1f deg (err std %.2f deg)\n', ATT_DEG, ATT_ERR_DEG);
fprintf('LED           : t=[%.1f %.1f %.1f] m, Phi_half=%.0f deg (m=%.2f), P_t=%.3f W\n', P.t, P.Phi_half, P.m, P.P_t);
fprintf('PD            : FOV=%.0f deg, A=%.1f mm^2, N=%d, sigma2=%.2e W^2\n', P.FOV, P.A_det*1e6, P.N_samples, P.sigma2);
fprintf('Testbed       : %d positions, x,y in [%.1f,%.1f] step %.2f, z in {%s}\n', N_pos, -P.L/2, P.L/2, P.step, num2str(heights'));
fprintf('MC trials     : %d per position\n', M_trials);
fprintf('%s\n\n', repmat('=', 1, 72));

%% 3. Monte Carlo over the testbed
rmse_pos  = zeros(N_pos, 1);    % per-position RMS 3D error
ape_pos   = zeros(N_pos, 1);    % per-position mean 3D error
ang_rmse  = zeros(N_pos, 1);    % per-position RMS direction error [deg] (body frame)
peb_pos   = zeros(N_pos, 1);    % PEB with the final orientation set (Stage B centred on TRUE u)
est_single = zeros(N_pos, 3);   % one realisation for the 3D figure
fail_cnt  = zeros(N_pos, 1);    % trials with <3 usable measurements

N_A = rx_cone_normals([0; 0; 1], theta_A, K_A, 0, ADD_NADIR_A);   % body-frame normals, Stage A
tic;
for i = 1:N_pos
    r = realPos(i, :);
    [mu_A, ~, u_B_true] = rx_powers(r, R_true, N_A, P);

    % Bound for the final design (Stage B cone centred on the true u; Stage A fused if applicable)
    switch DESIGN
        case 'led_centred'
            N_B_true = rx_cone_normals(u_B_true, theta_B, K_B);
            if FUSE_STAGES, N_final_true = [N_A; N_B_true]; else, N_final_true = N_B_true; end
        otherwise
            N_final_true = N_A;
    end
    peb_pos(i) = rx_peb(r, R_true, N_final_true, P);

    err = zeros(M_trials, 1); ang = zeros(M_trials, 1);
    for mc = 1:M_trials
        % Attitude used by the estimator (perfect, or perturbed IMU)
        if ATT_ERR_DEG > 0
            e = ATT_ERR_DEG * randn(1, 3);
            R_est = rotm_zyx(ATT_DEG(1)+e(1), ATT_DEG(2)+e(2), ATT_DEG(3)+e(3));
        else
            R_est = R_true;
        end

        % ---- Stage A: coarse scan (sample means = mu + noise/sqrt(N))
        mu_A_hat = mu_A + sqrt(P.sigma2_mean) * randn(size(mu_A));
        [r_hat, u_B_hat, ~, ~, n_used] = rx_ls_position(mu_A_hat, N_A, R_est, P, thr);

        % ---- Stage B: LED-centred cone around the coarse estimate
        if strcmp(DESIGN, 'led_centred') && all(isfinite(u_B_hat))
            N_B = rx_cone_normals(u_B_hat, theta_B, K_B);
            mu_B = rx_powers(r, R_true, N_B, P);
            mu_B_hat = mu_B + sqrt(P.sigma2_mean) * randn(size(mu_B));
            if FUSE_STAGES
                [r_hat, u_B_hat, ~, ~, n_used] = rx_ls_position([mu_A_hat; mu_B_hat], [N_A; N_B], R_est, P, thr);
            else
                [r_hat, u_B_hat, ~, ~, n_used] = rx_ls_position(mu_B_hat, N_B, R_est, P, thr);
            end
        end

        if any(isnan(r_hat))
            fail_cnt(i) = fail_cnt(i) + 1;
            err(mc) = NaN; ang(mc) = NaN;
        else
            err(mc) = norm(r_hat - r);
            ang(mc) = acosd(min(1, max(-1, u_B_hat' * u_B_true)));
        end
        if mc == 1, est_single(i, :) = r_hat; end
    end
    ok = isfinite(err);
    rmse_pos(i) = sqrt(mean(err(ok).^2));
    ape_pos(i)  = mean(err(ok));
    ang_rmse(i) = sqrt(mean(ang(ok).^2));

    if mod(i, PRINT_EVERY) == 0 || i == 1 || i == N_pos
        fprintf('  position %4d / %d  (z=%.1f)  RMSE=%.2f cm  PEB=%.2f cm  DF=%.2f deg\n', ...
            i, N_pos, r(3), 100*rmse_pos(i), 100*peb_pos(i), ang_rmse(i));
    end
end
fprintf('Simulation done in %.1f s\n\n', toc);

%% 4. Results table
cm = 100;
fprintf('%s\n', repmat('=', 1, 72));
fprintf(' 3D POSITIONING RESULTS — %s  (M=%d trials/position)\n', upper(DESIGN), M_trials);
fprintf('%s\n', repmat('=', 1, 72));
fprintf('%-10s %10s %10s %10s | %10s %10s | %8s\n', 'Height', 'RMSE[cm]', 'APE[cm]', 'P90[cm]', 'PEB-RMS', 'PEB-P90', 'DF[deg]');
fprintf('%s\n', repmat('-', 1, 72));
for h = heights'
    sel = realPos(:, 3) == h;
    v = rmse_pos(sel); a = ape_pos(sel); pb = peb_pos(sel & isfinite(peb_pos)); df = ang_rmse(sel);
    fprintf('z=%.1f m    %10.2f %10.2f %10.2f | %10.2f %10.2f | %8.2f\n', h, ...
        sqrt(mean(v.^2))*cm, mean(a)*cm, prctile(v, 90)*cm, sqrt(mean(pb.^2))*cm, prctile(pb, 90)*cm, sqrt(mean(df.^2)));
end
fprintf('%s\n', repmat('-', 1, 72));
pb = peb_pos(isfinite(peb_pos));
fprintf('%-10s %10.2f %10.2f %10.2f | %10.2f %10.2f | %8.2f\n', 'ALL', ...
    sqrt(mean(rmse_pos.^2))*cm, mean(ape_pos)*cm, prctile(rmse_pos, 90)*cm, ...
    sqrt(mean(pb.^2))*cm, prctile(pb, 90)*cm, sqrt(mean(ang_rmse.^2)));
fprintf('%s\n', repmat('=', 1, 72));
fprintf('RMSE/PEB ratio (spatial RMS)   : %.3f\n', sqrt(mean(rmse_pos.^2)) / sqrt(mean(pb.^2)));
fprintf('Trials with <3 usable readings : %d of %d\n', sum(fail_cnt), N_pos*M_trials);
fprintf('Total measurements per fix     : %d\n', size(N_final_true, 1));

%% 5. Figure 1 — 3D testbed: ground truth vs estimates (one realisation)
color_gt  = [0.15, 0.15, 0.15];
color_est = [0.000, 0.447, 0.741];
color_led = [0.929, 0.694, 0.125];
ax_fmt = {'FontName','Times New Roman','FontSize',9,'TickLabelInterpreter','latex', ...
          'LineWidth',0.8,'Box','on','GridLineStyle',':','GridAlpha',0.30};

fig1 = figure('Units','inches','Position',[1 1 4.2 4.4],'Color','w');
ax = axes(fig1); hold(ax, 'on');
sx = reshape([realPos(:,1)'; est_single(:,1)'; nan(1,N_pos)], 1, []);
sy = reshape([realPos(:,2)'; est_single(:,2)'; nan(1,N_pos)], 1, []);
sz = reshape([realPos(:,3)'; est_single(:,3)'; nan(1,N_pos)], 1, []);
plot3(ax, sx, sy, sz, '-', 'Color', [0.72 0.72 0.72], 'LineWidth', 0.4, 'HandleVisibility', 'off');
h_gt  = plot3(ax, realPos(:,1), realPos(:,2), realPos(:,3), '+', 'Color', color_gt, 'MarkerSize', 3.5, 'LineWidth', 0.8, 'LineStyle', 'none');
h_est = plot3(ax, est_single(:,1), est_single(:,2), est_single(:,3), 'o', 'Color', color_est, 'MarkerSize', 3.5, 'LineWidth', 1.0, 'LineStyle', 'none');
h_led = plot3(ax, P.t(1), P.t(2), P.t(3), 'p', 'Color', color_led, 'MarkerFaceColor', color_led, 'MarkerSize', 10, 'LineStyle', 'none');
quiver3(ax, P.t(1), P.t(2), P.t(3), 0.4*P.n_t(1), 0.4*P.n_t(2), 0.4*P.n_t(3), 0, 'Color', color_led, 'LineWidth', 1.2, 'MaxHeadSize', 0.8, 'HandleVisibility', 'off');
set(ax, ax_fmt{:});
xlabel(ax, '$x$\,[m]', 'Interpreter','latex'); ylabel(ax, '$y$\,[m]', 'Interpreter','latex'); zlabel(ax, '$z$\,[m]', 'Interpreter','latex');
xlim(ax, [-P.L/2 P.L/2]); ylim(ax, [-P.W/2 P.W/2]); zlim(ax, [-0.05 P.t(3)+0.15]);
zticks(ax, [heights' P.t(3)]); grid(ax, 'on'); view(ax, 45, 28);
title(ax, sprintf('RX-steered 3D positioning (%s): single realisation, RMSE$_{\\rm all}$ = %.2f cm', ...
    strrep(DESIGN, '_', '\_'), 100*sqrt(mean(rmse_pos.^2))), 'Interpreter','latex','FontSize',9);
legend(ax, [h_led h_gt h_est], {'Fixed LED', 'Ground truth', 'LS estimate'}, 'Interpreter','latex', ...
    'FontSize', 8.5, 'Orientation','horizontal', 'Location','northoutside');
hold(ax, 'off');

%% 6. Figure 2 — CDF of the per-position RMSE vs PEB
fig2 = figure('Units','inches','Position',[5.5 1 3.5 2.6],'Color','w'); hold on;
[f, x] = ecdf(rmse_pos*cm); stairs(x, f, '-', 'LineWidth', 1.1, 'Color', color_est);
[f, x] = ecdf(pb*cm);       stairs(x, f, '--', 'LineWidth', 1.1, 'Color', [0.47 0.67 0.19]);
yline(0.9, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
xlabel('Per-position 3D RMSE [cm]', 'Interpreter','latex'); ylabel('CDF', 'Interpreter','latex');
legend({'LS estimator', 'PEB'}, 'Interpreter','latex', 'Location','southeast');
grid minor; box on; set(gca, 'FontSize', 8, 'TickLabelInterpreter','latex');
xlim([0 max(prctile(rmse_pos*cm, 99), 1)]);

%% 7. Figure 3 — Orientation sets at one example position (body frame) + heatmap at z=0.6
[~, i_ex] = min(sum((realPos - [0.9, 0.6, 0.6]).^2, 2));   % closest grid point to the example location
[~, ~, u_B_ex] = rx_powers(realPos(i_ex, :), R_true, N_A, P);
fig3 = figure('Units','inches','Position',[1 5.8 7.5 3.2],'Color','w');
subplot(1,2,1); hold on;
quiver3(0,0,0, u_B_ex(1), u_B_ex(2), u_B_ex(3), 0, 'Color', color_led, 'LineWidth', 2, 'MaxHeadSize', 0.5);
quiver3(zeros(size(N_A,1),1), zeros(size(N_A,1),1), zeros(size(N_A,1),1), N_A(:,1), N_A(:,2), N_A(:,3), 0, 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
leg = {'LED direction $\mathbf{u}^B$', sprintf('Stage A (vertical cone %.0f$^\\circ$)', theta_A)};
if strcmp(DESIGN, 'led_centred')
    N_B_ex = rx_cone_normals(u_B_ex, theta_B, K_B);
    quiver3(zeros(K_B,1), zeros(K_B,1), zeros(K_B,1), N_B_ex(:,1), N_B_ex(:,2), N_B_ex(:,3), 0, 'Color', color_est, 'LineWidth', 1.3);
    leg{end+1} = sprintf('Stage B (LED-centred cone %.1f$^\\circ$)', theta_B);
end
[sx, sy, sz] = sphere(24); surf(sx, sy, sz, 'FaceAlpha', 0.05, 'EdgeAlpha', 0.08, 'FaceColor', [0.5 0.5 0.5], 'HandleVisibility', 'off');
axis equal; view(40, 20); grid on; box on;
xlabel('$x_B$', 'Interpreter','latex'); ylabel('$y_B$', 'Interpreter','latex'); zlabel('$z_B$', 'Interpreter','latex');
title(sprintf('PD normals (body frame) at r=[%.1f %.1f %.1f] m', realPos(i_ex,:)), 'Interpreter','latex', 'FontSize', 9);
legend(leg, 'Interpreter','latex', 'FontSize', 7.5, 'Location','southoutside');

subplot(1,2,2);
z_map = 0.6; sel = abs(realPos(:,3) - z_map) < 1e-9;
xs = unique(realPos(:,1)); ys = unique(realPos(:,2));
Emap = reshape(rmse_pos(sel)*cm, numel(ys), numel(xs));
imagesc(xs, ys, Emap); axis xy equal tight; colormap(parula); cb = colorbar; cb.Label.String = 'RMSE [cm]';
hold on; plot(P.t(1), P.t(2), 'p', 'Color', 'w', 'MarkerFaceColor', color_led, 'MarkerSize', 10);
xlabel('$x$\,[m]', 'Interpreter','latex'); ylabel('$y$\,[m]', 'Interpreter','latex');
title(sprintf('Per-position RMSE at $z=%.1f$ m (PEB-RMS %.2f cm)', z_map, 100*sqrt(mean(peb_pos(sel).^2))), 'Interpreter','latex', 'FontSize', 9);
set(gca, 'TickLabelInterpreter','latex', 'FontSize', 8);

%% 8. Export
if SAVE_FIGS
    tag = sprintf('%s_KA%d_KB%d', DESIGN, K_A + ADD_NADIR_A, K_B * strcmp(DESIGN, 'led_centred'));
    exportgraphics(fig1, fullfile(results_dir, ['Fig1_testbed3D_' tag '.png']), 'Resolution', 300, 'BackgroundColor', 'white');
    exportgraphics(fig2, fullfile(results_dir, ['Fig2_CDF_' tag '.png']), 'Resolution', 300, 'BackgroundColor', 'white');
    exportgraphics(fig3, fullfile(results_dir, ['Fig3_orientations_heatmap_' tag '.png']), 'Resolution', 300, 'BackgroundColor', 'white');
    save(fullfile(results_dir, ['poc_results_' tag '.mat']), 'realPos', 'est_single', 'rmse_pos', 'ape_pos', 'ang_rmse', 'peb_pos', ...
        'DESIGN', 'K_A', 'theta_A', 'ADD_NADIR_A', 'K_B', 'theta_B', 'FUSE_STAGES', 'ATT_DEG', 'ATT_ERR_DEG', 'M_trials', 'P');
    fprintf('Figures and results saved to: %s\n', results_dir);
end
