%% FigBound_vs_SNR_envelope.m
% IEEE TCOM — Direction & Position Error Bounds vs. SNR.
% Envelope-highlight design:
%   * Shaded band   → range spanned by K=Kmin..Kmax (worst→best)
%   * Dotted edges  → Kmin (top of band) and Kmax (bottom of band)
%   * Bold curve    → K=Khighlight (recommended operating point)
% Dual y-axis: DEB [°] (left, blue) and PEB [cm] (right, orange).
%
% Hyperparameters (top of script):
%   METRIC      : 'rms' or 'p90'
%   SNR_dB      : vector of SNR values [dB]
%   K_VALUES    : full set of K to compute (used for envelope)
%   K_HIGHLIGHT : K value to plot as bold accent (default 5)
%   PHI_HALF    : LED half-power angle [°] (fixed)
%
% Output (in outputs/):
%   Bound_vs_SNR_envelope_<METRIC>.{png,pdf,eps}
%   Bound_vs_SNR_envelope_<METRIC>_data.mat   (cache)
%
% Author: Kevin Acuña
close all; clear variables; clc;

%% ===== HYPERPARAMETERS =====
METRIC      = 'rms';                 % 'rms' or 'p90'
SNR_dB      = -30:5:30;              % SNR sweep [dB]
K_VALUES    = 3:9;                   % K range for envelope
K_HIGHLIGHT = 5;                     % accent curve
PHI_HALF    = 45;                    % LED half-power angle [°]

SAVE_OUTPUT = true;
RECOMPUTE   = true;

%% ===== PATHS =====
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = fileparts(which('FigBound_vs_SNR_envelope'));
end
core_dir  = fullfile(script_dir, '..', 'core');
param_dir = fullfile(script_dir, '..', 'estimators');
out_dir   = fullfile(script_dir, 'outputs');
data_file = fullfile(out_dir, sprintf('Bound_vs_SNR_envelope_%s_data.mat', METRIC));
addpath(core_dir); addpath(param_dir);
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

%% ===== SYSTEM PARAMETERS =====
run('system_params.m');
T       = [0; 0; 2];
FOV_rad = deg2rad(FOV);
m_lamb  = -log(2) / log(cosd(PHI_HALF));

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

%% ===== NOISE LEVELS =====
% Scale base sigma² so that SNR=0 dB matches the noise floor used in the rest of the paper.
% SNR_lin = sigma2_ref / sigma2  =>  sigma2(SNR) = sigma2_ref * 10^(-SNR/10)
sigma2_ref    = sigma2;                               % from system_params.m
SNR_lin       = 10.^(SNR_dB/10);
sigma2_values = sigma2_ref ./ SNR_lin;
nSNR  = numel(SNR_dB);
nK    = numel(K_VALUES);

%% ===== COMPUTE / LOAD =====
if ~RECOMPUTE && exist(data_file, 'file')
    fprintf('Loading cached results from %s\n', data_file);
    S = load(data_file);
    deb_mat = S.deb_mat;   peb_mat = S.peb_mat;
else
    deb_mat = nan(nSNR, nK);  % deg
    peb_mat = nan(nSNR, nK);  % cm
    warning('off','MATLAB:nearlySingularMatrix');

    fprintf('\nComputing bounds (%d SNR × %d K = %d combos × %d positions × 2 bounds)\n', ...
        nSNR, nK, nSNR*nK, N_pos);
    total_t0 = tic;

    for ik = 1:nK
        K_i = K_VALUES(ik);
        nt  = ori2nt(ori_map(K_i), K_i);

        for is = 1:nSNR
            s2 = sigma2_values(is);
            t0 = tic;
            deb_vals = nan(N_pos,1);
            peb_vals = nan(N_pos,1);
            for j = 1:N_pos
                R = positions(:,j);
                d = DEB_complete(R, nt, T, P_t, m_lamb, A_det, ...
                                 0, FOV_rad, s2, N_samples);
                p = PEB_complete(R, nt, T, P_t, m_lamb, A_det, ...
                                 0, FOV_rad, s2, N_samples);
                if isfinite(d) && isreal(d) && d > 0
                    deb_vals(j) = d;
                end
                if isfinite(p) && isreal(p) && p > 0
                    peb_vals(j) = p;
                end
            end
            deb_vals = deb_vals(isfinite(deb_vals));
            peb_vals = peb_vals(isfinite(peb_vals));
            deb_mat(is, ik) = aggregate_metric(rad2deg(deb_vals), METRIC);
            peb_mat(is, ik) = aggregate_metric(peb_vals * 100,    METRIC);
            fprintf('  K=%d  SNR=%+3.0f dB  DEB=%7.3f°  PEB=%8.2f cm  (%.1fs)\n', ...
                K_i, SNR_dB(is), deb_mat(is,ik), peb_mat(is,ik), toc(t0));
        end
    end

    warning('on','MATLAB:nearlySingularMatrix');
    fprintf('Total time: %.1f s\n', toc(total_t0));

    if SAVE_OUTPUT
        save(data_file, 'deb_mat', 'peb_mat', 'SNR_dB', 'K_VALUES', ...
                        'METRIC', 'PHI_HALF', 'sigma2_values');
    end
end

%% ===== ENVELOPES =====
deb_max = max(deb_mat, [], 2);   % worst (= K_min)
deb_min = min(deb_mat, [], 2);   % best  (= K_max)
peb_max = max(peb_mat, [], 2);
peb_min = min(peb_mat, [], 2);

ihl = find(K_VALUES == K_HIGHLIGHT, 1);
if isempty(ihl)
    error('K_HIGHLIGHT=%d not in K_VALUES', K_HIGHLIGHT);
end
deb_hl = deb_mat(:, ihl);
peb_hl = peb_mat(:, ihl);

ikmin = find(K_VALUES == min(K_VALUES), 1);
ikmax = find(K_VALUES == max(K_VALUES), 1);
deb_kmin = deb_mat(:, ikmin);
deb_kmax = deb_mat(:, ikmax);
peb_kmin = peb_mat(:, ikmin);
peb_kmax = peb_mat(:, ikmax);

%% ===== METRIC LABELS =====
switch lower(METRIC)
    case 'rms', metric_lbl = 'RMS';
    case 'p90', metric_lbl = 'P_{90}';
    otherwise,  metric_lbl = upper(METRIC);
end

%% ===== FIGURE =====
fig = figure('Units','inches','Position',[0.5 0.5 3.5*1.2 2.7*1.2],'Color','w');
ax  = axes(fig);

% Two complementary colours (deuteranopia-safe pair from MATLAB default cycle)
c_deb = [0.000, 0.447, 0.741];   % blue
c_peb = [0.850, 0.325, 0.098];   % orange

x_band = [SNR_dB, fliplr(SNR_dB)];

% --------- LEFT axis: DEB ---------
yyaxis left
hold(ax,'on');
% Band
y_band_deb = [deb_max(:).', fliplr(deb_min(:).')];
hb_deb = patch(x_band, y_band_deb, c_deb, ...
    'FaceAlpha', 0.16, 'EdgeColor', 'none', ...
    'HandleVisibility','off');
% Dotted envelope edges
plot(SNR_dB, deb_kmin, ':', 'Color', c_deb*0.85, 'LineWidth', 0.6, ...
    'HandleVisibility','off');
plot(SNR_dB, deb_kmax, ':', 'Color', c_deb*0.85, 'LineWidth', 0.6, ...
    'HandleVisibility','off');
% Highlight K curve
h_deb_hl = plot(SNR_dB, deb_hl, '-o', ...
    'Color', c_deb, 'MarkerFaceColor', c_deb, ...
    'LineWidth', 1.6, 'MarkerSize', 5);
set(gca,'YScale','log');
ylabel(sprintf('%s-DEB [$^\\circ$]', metric_lbl), ...
    'Interpreter','latex','FontSize',10);
ax.YAxis(1).Color = c_deb;

% --------- RIGHT axis: PEB ---------
yyaxis right
% Band
y_band_peb = [peb_max(:).', fliplr(peb_min(:).')];
hb_peb = patch(x_band, y_band_peb, c_peb, ...
    'FaceAlpha', 0.16, 'EdgeColor', 'none', ...
    'HandleVisibility','off');
% Dotted envelope edges
plot(SNR_dB, peb_kmin, ':', 'Color', c_peb*0.85, 'LineWidth', 0.6, ...
    'HandleVisibility','off');
plot(SNR_dB, peb_kmax, ':', 'Color', c_peb*0.85, 'LineWidth', 0.6, ...
    'HandleVisibility','off');
% Highlight K curve
h_peb_hl = plot(SNR_dB, peb_hl, '--s', ...
    'Color', c_peb, 'MarkerFaceColor', 'w', ...
    'LineWidth', 1.6, 'MarkerSize', 5);
set(gca,'YScale','log');
ylabel(sprintf('%s-PEB [cm]', metric_lbl), ...
    'Interpreter','latex','FontSize',10);
ax.YAxis(2).Color = c_peb;

% --------- Common formatting ---------
xlabel('SNR [dB]','Interpreter','latex','FontSize',10);
xlim([SNR_dB(1), SNR_dB(end)]);
xticks(SNR_dB(1):10:SNR_dB(end));
grid(ax,'on'); grid(ax,'minor');
set(ax,'GridLineStyle',':','GridAlpha',0.30, ...
       'MinorGridLineStyle',':','MinorGridAlpha',0.10, ...
       'FontName','Times New Roman','FontSize',9, ...
       'TickLabelInterpreter','latex','LineWidth',0.8,'Box','on');

% --------- Equal-decade y-axes (visual parallelism + offset) ---------
% Both bounds scale as 1/sqrt(SNR_lin), so on log-log they are exactly
% parallel. We force both yyaxes to span the SAME number of decades so this
% physical parallelism is preserved visually. In addition, the data centre
% of each axis is placed at a different vertical fraction (LEFT_FRAC vs
% RIGHT_FRAC) so the DEB and PEB highlight curves are visually separated.
LEFT_FRAC  = 0.40;   % DEB data centred at 30% from the bottom (curves low)
RIGHT_FRAC = 0.60;   % PEB data centred at 70% from the bottom (curves high)

deb_data_min = min(deb_min);   deb_data_max = max(deb_max);
peb_data_min = min(peb_min);   peb_data_max = max(peb_max);
ndec_data = max(log10(deb_data_max/deb_data_min), ...
                log10(peb_data_max/peb_data_min));
ndec_axis = max(ceil(ndec_data) + 2, 5);     % extra headroom for offset

% Snap each axis to integer-decade boundaries so ticks ALIGN horizontally
% on both axes (key for clean dual-axis log–log plots).
yc_left   = sqrt(deb_data_min*deb_data_max);
yc_right  = sqrt(peb_data_min*peb_data_max);
left_bot  = round(log10(yc_left)  - LEFT_FRAC *ndec_axis);
right_bot = round(log10(yc_right) - RIGHT_FRAC*ndec_axis);
left_bot=-2;
yyaxis left
yL = [10^left_bot, 10^(left_bot + ndec_axis)];
ylim(yL);
yticks(10.^(left_bot : (left_bot + ndec_axis)));

yyaxis right
yR = [10^right_bot, 10^(right_bot + ndec_axis)];
ylim(yR);
yticks(10.^(right_bot : (right_bot + ndec_axis)));

% --------- Legend (logical pairing: highlight first, then bands) ---------
h_band_deb_proxy = patch(NaN, NaN, c_deb, 'FaceAlpha', 0.16, 'EdgeColor','none');
h_band_peb_proxy = patch(NaN, NaN, c_peb, 'FaceAlpha', 0.16, 'EdgeColor','none');

leg_h = [h_deb_hl, h_peb_hl, h_band_deb_proxy, h_band_peb_proxy];
leg_lbl = { ...
    sprintf('DEB, $K{=}%d$', K_HIGHLIGHT), ...
    sprintf('PEB, $K{=}%d$', K_HIGHLIGHT), ...
    sprintf('DEB band, $K{\\in}[%d,%d]$', min(K_VALUES), max(K_VALUES)), ...
    sprintf('PEB band, $K{\\in}[%d,%d]$', min(K_VALUES), max(K_VALUES)) };
lg = legend(leg_h, leg_lbl, ...
    'Interpreter','latex','FontSize',7,'Location','northeast', ...
    'NumColumns',2,'Box','on');
lg.ItemTokenSize = [14, 12];

hold(ax,'off');

%% ===== EXPORT =====
if SAVE_OUTPUT
    name = sprintf('Bound_vs_SNR_envelope_%s', METRIC);
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
