%% FigCDF_3D_Position.m
% IEEE TCOM — Empirical CDF of the 3D positioning error.
%
% Compares:
%   K=3   SVD baseline [Chassagne2025]  (single curve, no weighting)
%   K=5   GLS-opt orientations: GLS, WLS  |  DEB-opt: NLS, PEB  (solid)
%   K=9   GLS-opt orientations: GLS, WLS  |  DEB-opt: NLS, PEB  (dashed, if SHOW_K9=true)
%
% Data sources:
%   K=5 DEB-opt  : results/K5_3D_MC_1000_DEB-Optimized/K5_3D_MC_results.mat
%   K=5 GLS-opt  : results/K5_3D_MC_1000_GLS-Optimized/K5_3D_MC_results.mat
%   K=9 DEB-opt  : results/K9_3D_MC_1000_DEB-Optimized/K9_3D_MC_results.mat  (run first)
%   K=9 GLS-opt  : results/K9_3D_MC_1000_GLS-Optimized/K9_3D_MC_results.mat  (run first)
%   K=3 SVD      : results/SVD_K3.mat  (errorNormSVD [m])
%
% Output (in outputs/):
%   Fig_CDF_3D_position.{pdf,eps,png}
%
% Author: Kevin Acuña

close all; clear variables; clc;

%% ===== HYPERPARAMETERS =====
SAVE_OUTPUT = false;
SHOW_K9     = false;   % set true once K=9 MC results are available
factor  = 100;   % m → cm
XLIM_CM = 14;    % x-axis upper limit [cm]

%% ===== PATHS =====
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end

res_dir = fullfile(script_dir, '..', 'estimators', 'results');

file_k5_deb = fullfile(res_dir, 'K5_3D_MC_1000_DEB-Optimized', 'K5_3D_MC_results.mat');  % K=5 NLS, PEB
file_k5_gls = fullfile(res_dir, 'K5_3D_MC_1000_GLS-Optimized', 'K5_3D_MC_results.mat');  % K=5 GLS, WLS
file_k9_deb = fullfile(res_dir, 'K9_3D_MC_1000_DEB-Optimized', 'K9_3D_MC_results.mat');  % K=9 NLS, PEB
file_k9_gls = fullfile(res_dir, 'K9_3D_MC_1000_GLS-Optimized', 'K9_3D_MC_results.mat');  % K=9 GLS, WLS
file_k3_svd = fullfile(res_dir, 'SVD_K3.mat');

out_dir = fullfile(script_dir, 'outputs');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

%% ===== LOAD DATA =====
d_k5_deb = load(file_k5_deb);   % K=5 NLS + PEB
d_k5_gls = load(file_k5_gls);   % K=5 GLS + WLS
d3        = load(file_k3_svd);

% K=5 GLS / WLS
r_GLS5 = d_k5_gls.rmse_3D_GLS_pos(:) * factor;
r_WLS5 = d_k5_gls.rmse_3D_WLS_pos(:) * factor;

% K=5 NLS / PEB
r_NLS5 = d_k5_deb.rmse_3D_NL_pos(:) * factor;
r_PEB5 = d_k5_deb.PEB_pos(:)         * factor;
r_PEB5 = r_PEB5(isfinite(r_PEB5) & ~isnan(r_PEB5));

% K=3 SVD baseline
r_SVD = d3.errorNormSVD(:) * factor;
r_SVD = r_SVD(isfinite(r_SVD) & ~isnan(r_SVD));

M  = d_k5_deb.M_trials;

% K=9 (optional — requires prior MC runs)
if SHOW_K9
    d_k9_deb = load(file_k9_deb);
    d_k9_gls = load(file_k9_gls);
    r_GLS9 = d_k9_gls.rmse_3D_GLS_pos(:) * factor;
    r_WLS9 = d_k9_gls.rmse_3D_WLS_pos(:) * factor;
    r_NLS9 = d_k9_deb.rmse_3D_NL_pos(:)  * factor;
    r_PEB9 = d_k9_deb.PEB_pos(:)          * factor;
    r_PEB9 = r_PEB9(isfinite(r_PEB9) & ~isnan(r_PEB9));
end

%% ===== PRINT METRICS TABLE =====
fprintf('%s\n', repmat('=',1,65));
fprintf('  3D POSITIONING METRICS [cm] — M=%d MC trials, N=%d positions\n', M, d_k5_deb.N_pos);
fprintf('%s\n', repmat('=',1,65));
fprintf('  %-22s  %-10s  %-10s  %-10s\n', 'Method', 'RMSE', 'CDF90', 'APE');
fprintf('%s\n', repmat('-',1,65));
m_names = {'K=3 SVD (baseline)', 'K=5 GLS (GLS-opt)', 'K=5 WLS (GLS-opt)', ...
           'K=5 NLS (DEB-opt)', 'K=5 PEB (DEB-opt)'};
m_data  = {r_SVD, r_GLS5, r_WLS5, r_NLS5, r_PEB5};
if SHOW_K9
    m_names = [m_names, {'K=9 GLS (GLS-opt)','K=9 WLS (GLS-opt)', ...
                         'K=9 NLS (DEB-opt)','K=9 PEB (DEB-opt)'}];
    m_data  = [m_data,  {r_GLS9, r_WLS9, r_NLS9, r_PEB9}];
end
for k = 1:numel(m_names)
    s = cdf_metrics(m_data{k});
    fprintf('  %-22s  %-10.2f  %-10.2f  %-10.2f\n', m_names{k}, s.rmse, s.p90, s.ape);
end
fprintf('%s\n', repmat('=',1,65));

%% ===== STYLING =====
color_svd = [0.929, 0.694, 0.125];  % gold   — K=3 SVD baseline
color_gls = [0.000, 0.447, 0.741];  % blue   — GLS
color_wls = [0.850, 0.325, 0.098];  % orange — WLS
color_nls = [0.494, 0.184, 0.556];  % purple — NLS
color_peb = [0.466, 0.674, 0.188];  % green  — PEB (bound)

ax_fmt = {'FontName','Times New Roman','FontSize',9, ...
          'TickLabelInterpreter','latex','LineWidth',0.8,'Box','on', ...
          'GridLineStyle',':','GridAlpha',0.30, ...
          'MinorGridLineStyle',':','MinorGridAlpha',0.15};

%% ===== MAIN FIGURE =====
fig = figure('Units','inches','Position',[1 1 3.5 2.9],'Color','w');
ax  = axes(fig,'Position',[0.115 0.135 0.865 0.848]);
hold(ax,'on');

% --- K=3 SVD baseline (dash-dot, lighter weight) ---
[f,x] = ecdf(r_SVD);
h_svd = stairs(ax, x, f, '-.', 'Color', color_svd, 'LineWidth', 1.1);

% --- K=5: solid lines ---
[f,x] = ecdf(r_GLS5); h_gls5 = stairs(ax, x, f, '-',  'Color', color_gls, 'LineWidth', 1.4);
[f,x] = ecdf(r_WLS5); h_wls5 = stairs(ax, x, f, '-',  'Color', color_wls, 'LineWidth', 1.4);
[f,x] = ecdf(r_NLS5); h_nls5 = stairs(ax, x, f, '-',  'Color', color_nls, 'LineWidth', 1.4);
[f,x] = ecdf(r_PEB5); h_peb5 = stairs(ax, x, f, '-',  'Color', color_peb, 'LineWidth', 1.4);

% --- K=9: dashed lines (same colors) ---
if SHOW_K9
    [f,x] = ecdf(r_GLS9); h_gls9 = stairs(ax, x, f, '--', 'Color', color_gls, 'LineWidth', 1.4);
    [f,x] = ecdf(r_WLS9); h_wls9 = stairs(ax, x, f, '--', 'Color', color_wls, 'LineWidth', 1.4);
    [f,x] = ecdf(r_NLS9); h_nls9 = stairs(ax, x, f, '--', 'Color', color_nls, 'LineWidth', 1.4);
    [f,x] = ecdf(r_PEB9); h_peb9 = stairs(ax, x, f, '--', 'Color', color_peb, 'LineWidth', 1.4);
end

% 90th-percentile reference line
yline(ax, 0.9, ':', 'Color', [0.50 0.50 0.50], 'LineWidth', 0.6, 'HandleVisibility','off');

% --- Axes formatting ---
xlabel(ax, '3D positioning error [cm]', 'Interpreter','latex','FontSize',10);
ylabel(ax, 'Empirical CDF',             'Interpreter','latex','FontSize',10);
xlim(ax, [0, XLIM_CM]);
ylim(ax, [0, 1.02]);
set(ax, ax_fmt{:});
grid(ax,'on'); grid(ax,'minor');

% --- Legend ---
if SHOW_K9
    h_leg = [h_svd, h_gls5, h_wls5, h_nls5, h_peb5, h_gls9, h_wls9, h_nls9, h_peb9];
    leg_str = {'$K{=}3$, SVD [Chassagne~2025]', ...
               '$K{=}5$, GLS', '$K{=}5$, WLS', '$K{=}5$, NLS', '$K{=}5$, PEB (bound)', ...
               '$K{=}9$, GLS', '$K{=}9$, WLS', '$K{=}9$, NLS', '$K{=}9$, PEB (bound)'};
    lg = legend(ax, h_leg, leg_str, 'Interpreter','latex','FontSize',6.5, ...
        'Location','southeast','Box','on','NumColumns',2);
else
    lg = legend(ax, [h_svd, h_gls5, h_wls5, h_nls5, h_peb5], ...
        {'$K{=}3$, SVD [Chassagne~2025]', ...
         '$K{=}5$, GLS', '$K{=}5$, WLS', '$K{=}5$, NLS', '$K{=}5$, PEB (bound)'}, ...
        'Interpreter','latex','FontSize',7,'Location','southeast','Box','on');
end
lg.ItemTokenSize = [14, 12];

hold(ax,'off');


%% ===== EXPORT =====
if SAVE_OUTPUT
    k9tag = ''; if SHOW_K9, k9tag = '_K9'; end
    base = fullfile(out_dir, sprintf('Fig_CDF_3D_position%s_M%d', k9tag, M));
    exportgraphics(fig, [base,'.pdf'], 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig, [base,'.png'], 'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig, [base,'.eps'], 'ContentType','vector','BackgroundColor','white');
    fprintf('\nFigures exported to: %s\n', out_dir);
end

%% ===== LOCAL FUNCTIONS =====
function s = cdf_metrics(r)
    r = r(isfinite(r) & ~isnan(r));
    s.rmse = sqrt(mean(r.^2));
    s.p90  = prctile(r, 90);
    s.ape  = mean(r);
end
