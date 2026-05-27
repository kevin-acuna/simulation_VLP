%% sim09_MC_broadcast_tilt.m — CDF: Broadcast 3D under 3 receiver tilts
%
% Runs the full broadcast MC pipeline (GLS/WLS/NLS + broadcast_distance)
% for a fixed K and 3 tilt angles. For each tilt, azimut is RMS-averaged
% over N_az directions (same Level-1 principle as sim06).
%
% Per-position RMSE = sqrt( (1/N_az) * sum_az[ (1/M) * sum_mc[err^2] ] )
%   Level 1: RMS over azimuts (average MSE, not mean of RMSE)
%   Then CDF over positions.
%
% Figure: CDF with tilt_1 (solid), tilt_2 (dashed), tilt_3 (dotted)
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
TEST_MODE    = false;
M_trials     = 10;
K_fixed      = 9;
tilt_angles  = [0, 10, 20];   % 3 tilt scenarios [deg]
N_az_mc      = 12;             % Azimut samples per tilt (every 30 deg)
save_files   = false;
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

%% Testbed
if TEST_MODE
    [X,Y,Z] = meshgrid(-1.5:0.5:1.5, -1.5:0.5:1.5, 0:0.6:1.2);
else
    [X,Y,Z] = meshgrid(-L/2:step:L/2, -W/2:step:W/2, 0:stepH:Hmax);
end
X_r = X(:)'; Y_r = Y(:)'; Z_r = Z(:)';
N_pos = length(X_r);

phi_az_range = linspace(0, 360 - 360/N_az_mc, N_az_mc);

%% Log
results_dir = fullfile(pwd, 'results', sprintf('tilt_K%d_MC%d', K_fixed, M_trials));
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
diary(fullfile(results_dir, sprintf('log_%s.txt', datestr(now,'yyyy-mm-dd_HH-MM-SS'))));

fprintf('%s\n', repmat('=',1,60));
fprintf('BROADCAST MC — TILT COMPARISON (K=%d)\n', K_fixed);
fprintf('Tilts: [%s] deg | N_az=%d | M=%d | N_pos=%d\n', ...
    num2str(tilt_angles), N_az_mc, M_trials, N_pos);
fprintf('%s\n\n', repmat('=',1,60));

%% Storage
nT = length(tilt_angles);
cm = 100;

all_rmse_GLS = cell(nT,1);
all_rmse_WLS = cell(nT,1);
all_rmse_NLS = cell(nT,1);
all_PEB_B    = cell(nT,1);

%% Main loop over tilts
for it = 1:nT
    theta_t = tilt_angles(it);
    fprintf('\n>>> Tilt = %d deg\n', theta_t);

    % Accumulate MSE over azimuts per position
    mse_GLS_sum = zeros(N_pos,1);
    mse_WLS_sum = zeros(N_pos,1);
    mse_NLS_sum = zeros(N_pos,1);
    peb2_sum    = zeros(N_pos,1);
    az_count    = zeros(N_pos,1);

    for i_az = 1:N_az_mc
        phi_az = phi_az_range(i_az);
        if theta_t == 0
            nr_tilted = [0; 0; 1];
        else
            nr_tilted = [sind(theta_t)*cosd(phi_az); ...
                         sind(theta_t)*sind(phi_az); ...
                         cosd(theta_t)];
        end
        nr_row = nr_tilted';
        param_r_ch = {A_det, nr_row, FOV};

        fprintf('  az=%3.0f deg ... ', phi_az);
        D = parallel.pool.DataQueue;
        
        mse_gls_az = zeros(N_pos,1);
        mse_wls_az = zeros(N_pos,1);
        mse_nls_az = zeros(N_pos,1);
        peb_az     = zeros(N_pos,1);

        parfor ip = 1:N_pos
            x = X_r(ip); y = Y_r(ip); z = Z_r(ip);
            realPos = [x, y, z];

            P_clean = zeros(1, K_fixed);
            for id = 1:K_fixed
                pt_ch = {T, nt_rows(id,:), P_t, m_t};
                [~, P_clean(id),~,~] = OWC_LOS_channel(x,y,z, pt_ch, param_r_ch);
            end

            pv = PEB_Konly([x;y;z], nt, T', P_t, m_t, A_det, ...
                deg2rad(FOV), sigma2, N_samples, nr_tilted);
            if isfinite(pv) && isreal(pv), peb_az(ip)=pv; else, peb_az(ip)=NaN; end

            se_gls=0; se_wls=0; se_nls=0;
            for mc = 1:M_trials
                Pr = repmat(P_clean, N_samples,1) + sqrt(sigma2).*randn(N_samples, K_fixed);
                mu_h = mean(Pr,1);

                nd_g = vlp_gls(nt, Pr, m_t, sigma2);
                [dg,~,~] = broadcast_distance(nd_g, nt, mu_h, m_t, C_opt, nr_tilted);
                ep = T + (nd_g'*dg);
                se_gls = se_gls + norm(realPos-ep)^2;

                nd_w = vlp_wls(nt, Pr, m_t);
                [dw,~,~] = broadcast_distance(nd_w, nt, mu_h, m_t, C_opt, nr_tilted);
                ep = T + (nd_w'*dw);
                se_wls = se_wls + norm(realPos-ep)^2;

                nd_n = vlp_nls_lm(nt, Pr, m_t);
                [dn,~,~] = broadcast_distance(nd_n, nt, mu_h, m_t, C_opt, nr_tilted);
                ep = T + (nd_n'*dn);
                se_nls = se_nls + norm(realPos-ep)^2;
            end
            mse_gls_az(ip) = se_gls / M_trials;
            mse_wls_az(ip) = se_wls / M_trials;
            mse_nls_az(ip) = se_nls / M_trials;
        end

        % Accumulate MSE across azimuts
        valid = isfinite(peb_az);
        mse_GLS_sum = mse_GLS_sum + mse_gls_az;
        mse_WLS_sum = mse_WLS_sum + mse_wls_az;
        mse_NLS_sum = mse_NLS_sum + mse_nls_az;
        peb2_sum    = peb2_sum + peb_az.^2;
        az_count    = az_count + double(valid);
        fprintf('done\n');
    end

    % RMS over azimuts per position: sqrt(mean_az[MSE])
    all_rmse_GLS{it} = sqrt(mse_GLS_sum / N_az_mc);
    all_rmse_WLS{it} = sqrt(mse_WLS_sum / N_az_mc);
    all_rmse_NLS{it} = sqrt(mse_NLS_sum / N_az_mc);
    all_PEB_B{it}    = sqrt(peb2_sum ./ max(az_count,1));

    v = all_rmse_NLS{it}(isfinite(all_rmse_NLS{it}));
    p = all_PEB_B{it}(isfinite(all_PEB_B{it}));
    fprintf('  Tilt=%d: NLS RMS=%.2f cm, PEB_B RMS=%.2f cm\n', ...
        theta_t, sqrt(mean(v.^2))*cm, sqrt(mean(p.^2))*cm);
end

%% Results table
fprintf('\n%s\n', repmat('=',1,70));
fprintf(' TILT COMPARISON (K=%d, M=%d)\n', K_fixed, M_trials);
fprintf('%s\n', repmat('=',1,70));
fprintf('%-6s %-10s %10s %10s %10s\n', 'Tilt', 'Method', 'RMSE[cm]', 'CDF90[cm]', 'APE[cm]');
fprintf('%s\n', repmat('-',1,70));
for it = 1:nT
    for method = {'GLS','WLS','NLS','PEB_B'}
        mn = method{1};
        switch mn
            case 'GLS', v=all_rmse_GLS{it};
            case 'WLS', v=all_rmse_WLS{it};
            case 'NLS', v=all_rmse_NLS{it};
            case 'PEB_B', v=all_PEB_B{it};
        end
        vv = v(isfinite(v));
        fprintf('%4d°  %-10s %10.2f %10.2f %10.2f\n', ...
            tilt_angles(it), mn, sqrt(mean(vv.^2))*cm, prctile(vv,90)*cm, mean(vv)*cm);
    end
    fprintf('%s\n', repmat('-',1,70));
end

%% CDF Figure
c_gls = [0.00, 0.45, 0.74];
c_wls = [0.85, 0.33, 0.10];
c_nls = [0.49, 0.18, 0.56];
c_peb = [0.47, 0.67, 0.19];
styles = {'-', '--', ':'};

figure('Position', [100,100,650,520]);
hold on;
leg_h = gobjects(0); leg_l = {};

for it = 1:nT
    ls = styles{it};

    [f,x]=ecdf(all_rmse_GLS{it}*cm);
    h=stairs(x,f,ls,'LineWidth',1.6,'Color',c_gls);
    leg_h(end+1)=h; leg_l{end+1}=sprintf('GLS ($\\theta_{\\mathrm{tilt}}{=}%d^\\circ$)',tilt_angles(it));

    [f,x]=ecdf(all_rmse_WLS{it}*cm);
    h=stairs(x,f,ls,'LineWidth',1.6,'Color',c_wls);
    leg_h(end+1)=h; leg_l{end+1}=sprintf('WLS ($\\theta_{\\mathrm{tilt}}{=}%d^\\circ$)',tilt_angles(it));

    [f,x]=ecdf(all_rmse_NLS{it}*cm);
    h=stairs(x,f,ls,'LineWidth',1.9,'Color',c_nls);
    leg_h(end+1)=h; leg_l{end+1}=sprintf('NLS ($\\theta_{\\mathrm{tilt}}{=}%d^\\circ$)',tilt_angles(it));

    v=all_PEB_B{it}; v=v(isfinite(v));
    [f,x]=ecdf(v*cm);
    h=stairs(x,f,ls,'LineWidth',1.6,'Color',c_peb);
    leg_h(end+1)=h; leg_l{end+1}=sprintf('$\\mathrm{PEB}_\\mathrm{B}$ ($\\theta_{\\mathrm{tilt}}{=}%d^\\circ$)',tilt_angles(it));
end

yline(0.9,':','LineWidth',0.5,'Color',[0.6 0.6 0.6],'HandleVisibility','off');
xlabel('3D Positioning Error [cm]','Interpreter','latex','FontSize',11);
ylabel('CDF','Interpreter','latex','FontSize',11);
legend(leg_h, leg_l, 'Interpreter','latex','FontSize',7, ...
    'Location','southeast','NumColumns',3);
title(sprintf('Broadcast 3D under Receiver Tilt ($K{=}%d$, $M{=}%d$)', ...
    K_fixed, M_trials), 'Interpreter','latex','FontSize',12);
grid minor; box on;
set(gca,'FontSize',9);

saveas(gcf, fullfile(results_dir, 'Fig09_CDF_tilt_comparison.png'));
saveas(gcf, fullfile(results_dir, 'Fig09_CDF_tilt_comparison.fig'));

%% Save
if save_files
    save(fullfile(results_dir, 'sim09_results.mat'), ...
        'all_rmse_GLS','all_rmse_WLS','all_rmse_NLS','all_PEB_B', ...
        'tilt_angles','K_fixed','M_trials','N_pos','N_az_mc');
end

diary off;
