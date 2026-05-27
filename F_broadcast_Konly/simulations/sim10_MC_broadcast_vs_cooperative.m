%% sim10_MC_broadcast_vs_cooperative.m — CDF: Broadcast vs Cooperative
%
% Fixed K, fixed n_r = [0,0,1]. Compares two 3D positioning pipelines:
%
%   BROADCAST:    DF (GLS/NLS) → broadcast_distance(nd, K powers, n_r)
%                 Uses only K measurements. No PD reorientation.
%
%   COOPERATIVE:  DF (GLS/NLS) → steer LED to nd, reorient PD to -nd
%                 → new K+1 measurement with beam alignment → d = sqrt(C/P_{K+1})
%                 Uses K+1 measurements. PD reorientation required.
%
% Output: CDF with broadcast (solid) vs cooperative (dashed) for NLS only,
%         plus PEB_B and PEB_C as references.
%
% Author: Kevin Acuna-Condori
% Date: 27 May 2026
% Project: Proposal F — Broadcast OWP

close all; clear; clc;

%% Paths
addpath(fullfile(pwd, '..\core'));
addpath(fullfile(fileparts(pwd), '..', 'fundamentals', 'core'));

% =========================================================================
% HYPERPARAMETERS
% =========================================================================
rng(42);
TEST_MODE  = false;
M_trials   = 10;
K_fixed    = 9;
save_files = false;
SAVE_FIGS  = true;       % Export in IEEE format (pdf/png/eps)
% =========================================================================

%% Parallel Pool
fprintf('Setting up parallel pool...\n');
if isempty(gcp('nocreate')), pool = parpool('local'); else, pool = gcp; end
fprintf('Using %d workers.\n\n', pool.NumWorkers);

%% System Parameters
system_params_F;

K_idx = find(K_values == K_fixed);
if isempty(K_idx), error('No orientations for K=%d', K_fixed); end
nt = orient_to_vectors(all_orientations_DEB{K_idx});
nt_rows = nt';
nr_col = n_r';  % [0;0;1]

param_r_ch = {A_det, n_r, FOV};

%% Testbed
if TEST_MODE
    [X,Y,Z] = meshgrid(-1.5:0.5:1.5, -1.5:0.5:1.5, 0:0.6:1.2);
else
    [X,Y,Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
end
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);

%% Results directory
results_dir = fullfile(pwd, 'results', sprintf('bcast_vs_coop_K%d_MC%d', K_fixed, M_trials));
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
diary(fullfile(results_dir, sprintf('log_%s.txt', datestr(now,'yyyy-mm-dd_HH-MM-SS'))));

fprintf('%s\n', repmat('=',1,60));
fprintf('BROADCAST vs COOPERATIVE (K=%d, M=%d, N_pos=%d)\n', K_fixed, M_trials, N_pos);
fprintf('%s\n\n', repmat('=',1,60));

%% Preallocate
cm = 100;
% Broadcast pipeline
rmse_B_GLS = zeros(N_pos,1);
rmse_B_NLS = zeros(N_pos,1);
% Cooperative pipeline
rmse_C_GLS = zeros(N_pos,1);
rmse_C_NLS = zeros(N_pos,1);
% Bounds
PEB_B_arr = zeros(N_pos,1);
PEB_C_arr = zeros(N_pos,1);

%% MC Core
D = parallel.pool.DataQueue;
afterEach(D, @(p) fprintf('  pos %d / %d\n', p, N_pos));
total_tic = tic;

parfor ip = 1:N_pos
    x = X_r(ip); y = Y_r(ip); z = Z_r(ip);
    realPos = [x, y, z];
    R_real = [x; y; z];

    % Clean K powers (direction finding)
    P_clean = zeros(1, K_fixed);
    for id = 1:K_fixed
        pt = {T, nt_rows(id,:), P_t, m_t};
        [~, P_clean(id),~,~] = OWC_LOS_channel(x,y,z, pt, param_r_ch);
    end

    % PEB_B (broadcast)
    pv = PEB_Konly(R_real, nt, T', P_t, m_t, A_det, deg2rad(FOV), sigma2, N_samples, nr_col);
    if isfinite(pv) && isreal(pv), PEB_B_arr(ip)=pv; else, PEB_B_arr(ip)=NaN; end

    % PEB_C (cooperative)
    pc = PEB_complete(R_real, nt, T', P_t, m_t, A_det, deg2rad(theta_half), deg2rad(FOV), sigma2, N_samples);
    if isfinite(pc) && isreal(pc), PEB_C_arr(ip)=pc; else, PEB_C_arr(ip)=NaN; end

    % MC trials
    se_B_gls=0; se_B_nls=0;
    se_C_gls=0; se_C_nls=0;

    for mc = 1:M_trials
        % --- Shared: K noisy powers for DF ---
        P_raw = repmat(P_clean, N_samples,1) + sqrt(sigma2).*randn(N_samples, K_fixed);
        mu_hat = mean(P_raw, 1);

        % ========== GLS direction ==========
        nd_gls = vlp_gls(nt, P_raw, m_t, sigma2);
        v_gls = nd_gls' / norm(nd_gls);  % 1x3 row

        % Broadcast: distance from K powers + known n_r
        [d_B,~,~] = broadcast_distance(nd_gls, nt, mu_hat, m_t, C_opt, nr_col);
        ep_B = T + v_gls * d_B;
        se_B_gls = se_B_gls + norm(realPos - ep_B)^2;

        % Cooperative: steer LED→nd, reorient PD→-nd, new measurement
        pt_ax = {T, v_gls, P_t, m_t};
        pr_ax = {A_det, -v_gls, FOV};
        [~, P_ax,~,~] = OWC_LOS_channel(x,y,z, pt_ax, pr_ax);
        P_ax_noisy = P_ax + sqrt(sigma2).*randn(1, N_samples);
        d_C = sqrt(P_t*(m_t+1)*A_det / (2*pi*mean(P_ax_noisy)));
        ep_C = T + v_gls * d_C;
        se_C_gls = se_C_gls + norm(realPos - ep_C)^2;

        % ========== NLS direction ==========
        nd_nls = vlp_nls_lm(nt, P_raw, m_t);
        v_nls = nd_nls' / norm(nd_nls);

        % Broadcast
        [d_B,~,~] = broadcast_distance(nd_nls, nt, mu_hat, m_t, C_opt, nr_col);
        ep_B = T + v_nls * d_B;
        se_B_nls = se_B_nls + norm(realPos - ep_B)^2;

        % Cooperative
        pt_ax = {T, v_nls, P_t, m_t};
        pr_ax = {A_det, -v_nls, FOV};
        [~, P_ax,~,~] = OWC_LOS_channel(x,y,z, pt_ax, pr_ax);
        P_ax_noisy = P_ax + sqrt(sigma2).*randn(1, N_samples);
        d_C = sqrt(P_t*(m_t+1)*A_det / (2*pi*mean(P_ax_noisy)));
        ep_C = T + v_nls * d_C;
        se_C_nls = se_C_nls + norm(realPos - ep_C)^2;
    end

    rmse_B_GLS(ip) = sqrt(se_B_gls / M_trials);
    rmse_B_NLS(ip) = sqrt(se_B_nls / M_trials);
    rmse_C_GLS(ip) = sqrt(se_C_gls / M_trials);
    rmse_C_NLS(ip) = sqrt(se_C_nls / M_trials);

    if mod(ip,10)==0 || ip==1 || ip==N_pos, send(D,ip); end
end

total_time = toc(total_tic);

%% Results table
fprintf('\n%s\n', repmat('=',1,65));
fprintf(' BROADCAST vs COOPERATIVE (K=%d, M=%d)\n', K_fixed, M_trials);
fprintf('%s\n', repmat('=',1,65));
fprintf('%-22s %10s %10s %10s\n', 'Pipeline', 'RMSE[cm]', 'CDF90[cm]', 'APE[cm]');
fprintf('%s\n', repmat('-',1,65));
for entry = { ...
    {'GLS  + broadcast',  rmse_B_GLS}, ...
    {'GLS  + cooperative', rmse_C_GLS}, ...
    {'NLS  + broadcast',  rmse_B_NLS}, ...
    {'NLS  + cooperative', rmse_C_NLS}, ...
    {'PEB_B',             PEB_B_arr}, ...
    {'PEB_C',             PEB_C_arr}}
    e = entry{1};
    v = e{2}; v = v(isfinite(v));
    fprintf('%-22s %10.2f %10.2f %10.2f\n', e{1}, sqrt(mean(v.^2))*cm, prctile(v,90)*cm, mean(v)*cm);
end
fprintf('%s\n', repmat('-',1,65));
fprintf('Wall time: %.1f s\n', total_time);

%% CDF Figure
c_gls = [0.00, 0.45, 0.74];
c_nls = [0.49, 0.18, 0.56];
c_peb = [0.47, 0.67, 0.19];
c_coop = [0.85, 0.33, 0.10];

figure('Position', [100,100,650,520]);
hold on;

% Broadcast (solid)
[f,x]=ecdf(rmse_B_GLS*cm); h1=stairs(x,f,'-','LineWidth',1.6,'Color',c_gls);
[f,x]=ecdf(rmse_B_NLS*cm); h2=stairs(x,f,'-','LineWidth',1.9,'Color',c_nls);
v=PEB_B_arr(isfinite(PEB_B_arr));
[f,x]=ecdf(v*cm);           h3=stairs(x,f,'-','LineWidth',1.6,'Color',c_peb);

% Cooperative (dashed)
[f,x]=ecdf(rmse_C_GLS*cm); h4=stairs(x,f,'--','LineWidth',1.6,'Color',c_gls);
[f,x]=ecdf(rmse_C_NLS*cm); h5=stairs(x,f,'--','LineWidth',1.9,'Color',c_nls);
v=PEB_C_arr(isfinite(PEB_C_arr));
[f,x]=ecdf(v*cm);           h6=stairs(x,f,'--','LineWidth',1.6,'Color',c_peb);

yline(0.9,':','LineWidth',0.5,'Color',[0.6 0.6 0.6],'HandleVisibility','off');

xlabel('3D Positioning Error [cm]','Interpreter','latex','FontSize',11);
ylabel('CDF','Interpreter','latex','FontSize',11);
legend([h1,h2,h3, h4,h5,h6], ...
    {'GLS broadcast', 'NLS broadcast', '$\mathrm{PEB}_\mathrm{B}$', ...
     'GLS cooperative', 'NLS cooperative', '$\mathrm{PEB}_\mathrm{C}$'}, ...
    'Interpreter','latex','FontSize',8,'Location','southeast','NumColumns',2);
title(sprintf('Broadcast vs Cooperative ($K{=}%d$, $M{=}%d$, $\\mathbf{n}_r{=}[0,0,1]^T$)', ...
    K_fixed, M_trials), 'Interpreter','latex','FontSize',12);
grid minor; box on;
set(gca,'FontSize',9);

if SAVE_FIGS
    set(gcf, 'Units','inches', 'Position',[0.5 0.5 3.5 2.8]);
    exportgraphics(gcf, fullfile(results_dir, 'Fig10_CDF_bcast_vs_coop.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(gcf, fullfile(results_dir, 'Fig10_CDF_bcast_vs_coop.png'), 'Resolution',600,'BackgroundColor','white');
    exportgraphics(gcf, fullfile(results_dir, 'Fig10_CDF_bcast_vs_coop.eps'), 'ContentType','vector','BackgroundColor','white');
end

if save_files
    save(fullfile(results_dir, 'sim10_results.mat'), ...
        'rmse_B_GLS','rmse_B_NLS','rmse_C_GLS','rmse_C_NLS', ...
        'PEB_B_arr','PEB_C_arr','K_fixed','M_trials','N_pos');
end
diary off;
