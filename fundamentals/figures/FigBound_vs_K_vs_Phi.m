%% FigBound_vs_K_vs_Phi.m
% IEEE TCOM — Direction & Position Error Bounds vs. K vs. Φ_{1/2}.
% Dual y-axis: DEB [°] (left) and PEB [cm] (right).
% Uses DEB-optimized orientation sets from system_params.m.
%
% Hyperparameters (top of script):
%   METRIC       : 'rms' (default) or 'p90' — aggregation across testbed positions
%   PHI_HALF_DEG : vector of LED half-power angles [°] to evaluate, e.g. [30 45 60]
%   K_VALUES     : vector of orientation counts to evaluate
%
% Output (in outputs/):
%   Bound_vs_K_vs_Phi_<METRIC>.{png,pdf,eps}
%   Bound_vs_K_vs_Phi_<METRIC>_data.mat   (cache)
%
% Author: Kevin Acuña
close all; clear variables; clc;

%% ===== HYPERPARAMETERS =====
METRIC       = 'rms';            % 'rms' or 'p90'
PHI_HALF_DEG = [45,60,75];     % LED half-power angles [°]
K_VALUES     = 3:9;              % number of orientations

SAVE_OUTPUT = true;              % export figures
RECOMPUTE   = true;              % false → load cached data

%% ===== PATHS =====
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = fileparts(which('FigBound_vs_K_vs_Phi'));
end
core_dir  = fullfile(script_dir, '..', 'core');
param_dir = fullfile(script_dir, '..', 'estimators');
out_dir   = fullfile(script_dir, 'outputs');
data_file = fullfile(out_dir, sprintf('Bound_vs_K_vs_Phi_%s_data.mat', METRIC));
addpath(core_dir); addpath(param_dir);
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

%% ===== SYSTEM PARAMETERS =====
run('system_params.m');
T       = [0; 0; 2];
FOV_rad = deg2rad(FOV);

% Orientation sets keyed by K
ori_map = containers.Map('KeyType','double','ValueType','any');
ori_map(3) = orientations_DEB_K3;
ori_map(4) = orientations_DEB_K4;
ori_map(5) = orientations_DEB_K5;
ori_map(6) = orientations_DEB_K6;
ori_map(7) = orientations_DEB_K7;
ori_map(8) = orientations_DEB_K8;
ori_map(9) = orientations_DEB_K9;

%% ===== TESTBED GRID =====
step = 0.2;
x_range = -L/2 : step : L/2;
y_range = -W/2 : step : W/2;
z_range = 0 : step : 1.2;
[Xg, Yg, Zg] = ndgrid(x_range, y_range, z_range);
positions = [Xg(:), Yg(:), Zg(:)].';
N_pos = size(positions, 2);
fprintf('Testbed: %d positions over 3x3x1.2 m³ (step=%.2f m)\n', N_pos, step);

%% ===== COMPUTE / LOAD =====
nK   = numel(K_VALUES);
nPhi = numel(PHI_HALF_DEG);

if ~RECOMPUTE && exist(data_file, 'file')
    fprintf('Loading cached results from %s\n', data_file);
    load(data_file, 'deb_mat', 'peb_mat');
else
    deb_mat = nan(nK, nPhi);   % deg
    peb_mat = nan(nK, nPhi);   % cm
    warning('off','MATLAB:nearlySingularMatrix');

    fprintf('\nComputing bounds (%d K × %d Phi = %d combinations)...\n', nK, nPhi, nK*nPhi);
    total_t0 = tic;

    for ip = 1:nPhi
        phi_h_deg = PHI_HALF_DEG(ip);
        m_local   = -log(2) / log(cosd(phi_h_deg));   % Lambertian order

        for ik = 1:nK
            K   = K_VALUES(ik);
            ori = ori_map(K);
            nt  = ori2nt(ori, K);

            t0 = tic;
            deb_vals = nan(N_pos, 1);
            peb_vals = nan(N_pos, 1);
            for j = 1:N_pos
                R = positions(:, j);
                d = DEB_complete(R, nt, T, P_t, m_local, A_det, ...
                                 0, FOV_rad, sigma2, N_samples);
                p = PEB_complete(R, nt, T, P_t, m_local, A_det, ...
                                 0, FOV_rad, sigma2, N_samples);
                if isfinite(d) && isreal(d) && d > 0
                    deb_vals(j) = d;
                end
                if isfinite(p) && isreal(p) && p > 0
                    peb_vals(j) = p;
                end
            end
            deb_vals = deb_vals(isfinite(deb_vals));
            peb_vals = peb_vals(isfinite(peb_vals));

            deb_mat(ik, ip) = aggregate_metric(rad2deg(deb_vals), METRIC);
            peb_mat(ik, ip) = aggregate_metric(peb_vals * 100,    METRIC);

            fprintf('  K=%d  Phi=%2d°  DEB=%6.3f°  PEB=%5.2f cm   (%.1fs)\n', ...
                K, phi_h_deg, deb_mat(ik,ip), peb_mat(ik,ip), toc(t0));
        end
    end

    warning('on','MATLAB:nearlySingularMatrix');
    fprintf('Total time: %.1f s\n', toc(total_t0));

    if SAVE_OUTPUT
        save(data_file, 'deb_mat', 'peb_mat', 'K_VALUES', 'PHI_HALF_DEG', 'METRIC');
    end
end

%% ===== METRIC LABELS =====
switch lower(METRIC)
    case 'rms', metric_lbl = 'RMS';
    case 'p90', metric_lbl = 'P_{90}';
    otherwise,  metric_lbl = upper(METRIC);
end

%% ===== FIGURE: dual-axis plot =====
fig = figure('Units','inches','Position',[0.5 0.5 3.5 2.7],'Color','w');
ax  = axes(fig);

% Colour palette (one colour per Phi value), perceptually ordered
colors = [
    0.000, 0.447, 0.741;   % blue       (Φ=30°)
    0.850, 0.325, 0.098;   % orange     (Φ=45°)
    0.466, 0.674, 0.188;   % green      (Φ=60°)
    0.494, 0.184, 0.556;   % purple     (extra slot)
    0.301, 0.745, 0.933;   % cyan       (extra slot)
];

% --- LEFT axis: DEB (solid + filled circle) ---
yyaxis left;
hold(ax,'on');
h_deb = gobjects(nPhi,1);
for ip = 1:nPhi
    c = colors(mod(ip-1,size(colors,1))+1, :);
    h_deb(ip) = plot(K_VALUES, deb_mat(:,ip), '-o', ...
        'Color', c, 'MarkerFaceColor', c, ...
        'LineWidth', 1.2, 'MarkerSize', 5);
end
ylabel(sprintf('%s-DEB [$^\\circ$]', metric_lbl), ...
    'Interpreter','latex','FontSize',10);
ax.YAxis(1).Color = [0 0 0];

% --- RIGHT axis: PEB (dashed + open square) ---
yyaxis right;
h_peb = gobjects(nPhi,1);
for ip = 1:nPhi
    c = colors(mod(ip-1,size(colors,1))+1, :);
    h_peb(ip) = plot(K_VALUES, peb_mat(:,ip), '--s', ...
        'Color', c, 'MarkerFaceColor', 'w', ...
        'LineWidth', 1.2, 'MarkerSize', 5);
end
ylabel(sprintf('%s-PEB [cm]', metric_lbl), ...
    'Interpreter','latex','FontSize',10);
ax.YAxis(2).Color = [0 0 0];

% --- Common formatting ---
xlabel('Number of orientations $K$','Interpreter','latex','FontSize',10);
xlim([min(K_VALUES)-0.3, max(K_VALUES)+0.3]);
xticks(K_VALUES);
grid(ax,'on'); grid(ax,'minor');
set(ax,'GridLineStyle',':','GridAlpha',0.30, ...
       'MinorGridLineStyle',':','MinorGridAlpha',0.10, ...
       'FontName','Times New Roman','FontSize',9, ...
       'TickLabelInterpreter','latex','LineWidth',0.8,'Box','on');

% --- Legend (combined: bound type × Phi) ---
% Two-block legend: solid=DEB, dashed=PEB; colours = Phi
% Build legend handles in interleaved order for compactness
leg_h     = gobjects(2*nPhi,1);
leg_lbl   = cell(2*nPhi,1);
for ip = 1:nPhi
    leg_h(ip)         = h_deb(ip);
    leg_lbl{ip}       = sprintf('DEB,~$\\Phi_{1/2}=%d^\\circ$',  PHI_HALF_DEG(ip));
    leg_h(nPhi+ip)    = h_peb(ip);
    leg_lbl{nPhi+ip}  = sprintf('PEB,~$\\Phi_{1/2}=%d^\\circ$',  PHI_HALF_DEG(ip));
end
lg = legend(leg_h, leg_lbl, ...
    'Interpreter','latex','FontSize',7,'Location','northeast', ...
    'NumColumns',2,'Box','on');
lg.ItemTokenSize = [12, 12];

hold(ax,'off');

%% ===== EXPORT =====
if SAVE_OUTPUT
    name = sprintf('Bound_vs_K_vs_Phi_%s', METRIC);
    exportgraphics(fig, fullfile(out_dir,[name,'.pdf']), ...
        'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig, fullfile(out_dir,[name,'.png']), ...
        'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig, fullfile(out_dir,[name,'.eps']), ...
        'ContentType','vector','BackgroundColor','white');
    fprintf('\nFigure exported to %s\n', out_dir);
end

%% ===== LOCAL FUNCTIONS =====

function nt = ori2nt(orientations, K)
    nt = zeros(3, K);
    for i = 1:K
        th = orientations(2*i-1); ph = orientations(2*i);
        nt(:,i) = [sind(th)*cosd(ph); sind(th)*sind(ph); -cosd(th)];
    end
end

function v = aggregate_metric(values, metric)
    if isempty(values)
        v = NaN; return;
    end
    switch lower(metric)
        case 'rms'
            v = sqrt(mean(values.^2));
        case 'p90'
            v = prctile(values, 90);
        otherwise
            error('Unknown metric: %s (use ''rms'' or ''p90'')', metric);
    end
end
