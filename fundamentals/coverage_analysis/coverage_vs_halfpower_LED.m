%% coverage_vs_halfpower_LED.m
% Positioning-service coverage analysis for the single-LED VLP scenario,
% mirroring the VCSEL_3D coverage study but for the Lambertian LED model.
%
% A position is "covered" iff (see evaluate_coverage_LED.m):
%     isfinite(PEB) AND PEB <= PEB_max_cov AND maxSNR_dB >= SNR_min_dB
%
% The HEADLINE study is coverage vs the LED half-power angle (theta_half),
% which sets the Lambertian order m = -log(2)/log(cos(theta_half)). Everything
% relevant is exposed in the CONFIGURATION block below.
%
% Figures produced:
%   Fig 1 : coverage [%] vs half-power angle (one curve per K)
%   Fig 2 : mean / P90 PEB vs half-power angle (one curve per K)
%   Fig 3 : binary coverage maps, grid (theta_half rows x K columns) at z_analysis
%   Fig 4 : coverage [%] vs receiver height, for a few half-power angles (fixed K)
%
% Uses: core/PEB_complete.m, estimators/system_params.m, evaluate_coverage_LED.m
% Author: (LED coverage analysis, sibling of VCSEL_3D/simulations/sim02_b)

close all; clear variables; clc;

%% ===== PATHS =====
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
core_dir  = fullfile(script_dir, '..', 'core');
param_dir = fullfile(script_dir, '..', 'estimators');
out_dir   = fullfile(script_dir, 'outputs');
addpath(core_dir); addpath(param_dir); addpath(script_dir);
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

% Load shared LED parameters + preset optimized orientation sets
run('system_params.m');     % provides P_t, A_det, FOV, sigma2, N_samples, L, W, Hmax,
                            % n_r, theta_half(default), and orientations_K3..K10

% =========================== CONFIGURATION ===========================
% --- Codebook (LED steered orientations) ---
codebook_mode = 'preset';    % 'preset' = optimized orientations_K{K} from system_params
                             % 'uniform'= area-uniform spherical-cap (sunflower) codebook
uniform_cap_deg = 60;        % cap half-angle for 'uniform' mode [deg]

% --- Half-power-angle study (the main variable) ---
theta_half_sweep = 10:5:80;  % half-power angles for the coverage/PEB curves [deg]
K_list           = [5, 9];   % K values for the curves (preset: must be in 3..10)

% --- Coverage-map grid (Fig 3) ---
theta_half_rows  = [20, 45, 70];   % half-power angles = map rows [deg]
K_cols           = [5, 9];         % K values = map columns (preset: 3..10)
z_analysis       = 0.8;            % height of the coverage maps [m]
step_map         = 0.05;           % fine floor grid for maps [m]
SHOW_BEAM_FOOTPRINTS = true;       % overlay each beam's SNR>=SNR_min footprint (solid)
SHOW_HALFPOWER_CONE  = true;       % overlay each beam's -3 dB (half-power) cone (dashed)

% --- Coverage-vs-height study (Fig 4) ---
K_zprofile       = 9;              % K used for coverage-vs-height
theta_half_zprof = [20, 45, 70];   % half-power angles for coverage-vs-height [deg]

% --- Coverage QoS thresholds (a position is covered if BOTH are met) ---
% NOTE: LED PEB is cm-level, so a loose threshold saturates coverage at 100%.
% 0.02 m (2 cm) reveals the beam-width tradeoff; raise it for a laxer QoS.
PEB_max_cov = 0.02;          % max PEB to count as covered [m]  (tunable QoS knob)
SNR_min_dB  = 10;            % min peak averaged-measurement SNR [dB]

% --- Testbed for the coverage/PEB curves (3D room volume) ---
step_cov    = 0.20;          % grid step for the 3D coverage testbed [m]
Zmax        = Hmax;          % max receiver height [m]

SAVE_FIGS   = false;         % true -> export PDF/PNG to outputs/
% =====================================================================

T       = [0; 0; 2];         % LED position (ceiling center), per fundamentals convention
FOV_rad = deg2rad(FOV);
n_r     = n_r(:);

params = struct('T', T, 'Pt', P_t, 'A_det', A_det, 'Psi_FOV', FOV_rad, ...
    'sigma2', sigma2, 'N', N_samples, 'nr', n_r, ...
    'SNR_min_dB', SNR_min_dB, 'PEB_max_cov', PEB_max_cov, 'theta_half', 0);

% Preset optimized orientation sets (PEB-optimized), indexed by K = 3..10
presets   = {orientations_K3, orientations_K4, orientations_K5, orientations_K6, ...
             orientations_K7, orientations_K8, orientations_K9, orientations_K10};
K_preset  = 3:10;

m_of = @(th_deg) -log(2) / log(cosd(th_deg));   % Lambertian order from half-power angle

fprintf('LED positioning-service coverage analysis\n');
fprintf('  codebook = %s | PEB_max = %.2f m | SNR_min = %g dB | T = [%.1f %.1f %.1f]\n', ...
    codebook_mode, PEB_max_cov, SNR_min_dB, T(1), T(2), T(3));

%% ===== 3D testbed for coverage/PEB curves =====
xc = -L/2:step_cov:L/2;  yc = -W/2:step_cov:W/2;  zc = 0:step_cov:Zmax;
[Xc, Yc, Zc] = ndgrid(xc, yc, zc);
pos3D = [Xc(:)'; Yc(:)'; Zc(:)'];
fprintf('  3D testbed: %d positions (%dx%dx%d)\n', size(pos3D,2), numel(xc), numel(yc), numel(zc));

%% ===== Figure 1 + 2 data: sweep half-power angle =====
nTh = numel(theta_half_sweep);
nK  = numel(K_list);
cov_curve  = zeros(nK, nTh);
mean_curve = nan(nK, nTh);
p90_curve  = nan(nK, nTh);

for ik = 1:nK
    K  = K_list(ik);
    nt = get_codebook(K, codebook_mode, presets, K_preset, uniform_cap_deg);
    for it = 1:nTh
        th = theta_half_sweep(it);
        params.theta_half = deg2rad(th);
        res = evaluate_coverage_LED(nt, m_of(th), pos3D, params);
        cov_curve(ik, it)  = 100 * res.coverage;
        mean_curve(ik, it) = res.mean_peb;
        p90_curve(ik, it)  = res.p90_peb;
    end
    [cmax, imax] = max(cov_curve(ik,:));
    fprintf('  K=%d done (peak coverage %.1f%% at theta_half=%d deg)\n', ...
        K, cmax, theta_half_sweep(imax));
end

colors = lines(nK);

% ---- Figure 1: coverage vs half-power angle ----
fig1 = figure('Units','inches', 'Position',[1 1 3.6 2.7], 'Color','w'); hold on;
h1 = gobjects(nK,1);
for ik = 1:nK
    h1(ik) = plot(theta_half_sweep, cov_curve(ik,:), '-o', 'LineWidth', 1.2, ...
        'MarkerSize', 4, 'Color', colors(ik,:), 'MarkerFaceColor', colors(ik,:));
end
xline(45, '--', '$\theta_{1/2}=45^\circ$', 'Interpreter','latex', ...
    'LabelVerticalAlignment','bottom', 'FontSize', 7, 'Color',[0.4 0.4 0.4]);
xlabel('Half-power angle $\theta_{1/2}$ [deg]', 'Interpreter','latex', 'FontSize', 9);
ylabel('Coverage [\%]', 'Interpreter','latex', 'FontSize', 9);
ylim([0 100]); grid on; box on; set(gca, 'FontSize', 8, 'TickLabelInterpreter','latex');
legend(h1, arrayfun(@(k) sprintf('$K=%d$', k), K_list, 'UniformOutput', false), ...
    'Interpreter','latex', 'FontSize', 8, 'Location','best');
title(sprintf('Positioning coverage vs LED beam width (PEB $\\leq %.2f$ m)', PEB_max_cov), ...
    'Interpreter','latex', 'FontSize', 9);

% ---- Figure 2: PEB (mean/P90) vs half-power angle ----
fig2 = figure('Units','inches', 'Position',[1 1 3.6 2.7], 'Color','w'); hold on;
h2 = gobjects(nK,1);
for ik = 1:nK
    h2(ik) = plot(theta_half_sweep, 100*mean_curve(ik,:), '-o', 'LineWidth', 1.2, ...
        'MarkerSize', 4, 'Color', colors(ik,:), 'MarkerFaceColor', colors(ik,:));
    plot(theta_half_sweep, 100*p90_curve(ik,:), '--s', 'LineWidth', 1.0, ...
        'MarkerSize', 3, 'Color', colors(ik,:));
end
xline(45, '--', '', 'Color',[0.4 0.4 0.4]);
xlabel('Half-power angle $\theta_{1/2}$ [deg]', 'Interpreter','latex', 'FontSize', 9);
ylabel('PEB over covered set [cm]', 'Interpreter','latex', 'FontSize', 9);
grid on; box on; set(gca, 'FontSize', 8, 'TickLabelInterpreter','latex', 'YScale','log');
legend(h2, arrayfun(@(k) sprintf('$K=%d$ (mean)', k), K_list, 'UniformOutput', false), ...
    'Interpreter','latex', 'FontSize', 8, 'Location','best');
title('PEB vs LED beam width (solid = mean, dashed = P90)', 'Interpreter','latex', 'FontSize', 9);

%% ===== Figure 3: coverage maps grid (theta_half x K) at z_analysis =====
xr = -L/2:step_map:L/2;  yr = -W/2:step_map:W/2;
[Xg, Yg] = meshgrid(xr, yr);
posMap = [Xg(:)'; Yg(:)'; z_analysis*ones(1, numel(Xg))];
nR = numel(theta_half_rows); nCc = numel(K_cols);
masks = cell(nR, nCc); covpc = zeros(nR, nCc);

for ir = 1:nR
    th = theta_half_rows(ir);
    params.theta_half = deg2rad(th);
    for ic = 1:nCc
        K  = K_cols(ic);
        nt = get_codebook(K, codebook_mode, presets, K_preset, uniform_cap_deg);
        res = evaluate_coverage_LED(nt, m_of(th), posMap, params);
        masks{ir, ic} = reshape(res.covered, size(Xg));
        covpc(ir, ic) = 100 * res.coverage;
    end
end

cmap2 = [0.93 0.93 0.93; 0.16 0.52 0.74];   % [uncovered ; covered]
fig3 = figure('Units','inches', 'Position',[0.5 0.5 1.9*nCc 1.95*nR], 'Color','w');
tl = tiledlayout(fig3, nR, nCc, 'TileSpacing','compact', 'Padding','compact');
for ir = 1:nR
    for ic = 1:nCc
        ax = nexttile(tl);
        imagesc(ax, xr*100, yr*100, double(masks{ir, ic}));
        set(ax, 'YDir','normal'); colormap(ax, cmap2); clim(ax, [0 1]);
        axis(ax, 'equal', 'tight'); hold(ax, 'on');

        % --- Per-beam illumination footprints (SNR>=SNR_min) + half-power cones ---
        if SHOW_BEAM_FOOTPRINTS || SHOW_HALFPOWER_CONE
            th_r = theta_half_rows(ir);  m_r = m_of(th_r);
            nt_p = get_codebook(K_cols(ic), codebook_mode, presets, K_preset, uniform_cap_deg);
            Kp   = size(nt_p, 2);  bcol = turbo(max(Kp, 2));
            for i = 1:Kp
                [SNRdB, cosphi] = beam_snr_field(nt_p(:, i), m_r, Xg, Yg, z_analysis, params);
                if SHOW_BEAM_FOOTPRINTS && any(SNRdB(:) >= SNR_min_dB)
                    contour(ax, xr*100, yr*100, SNRdB, [SNR_min_dB SNR_min_dB], ...
                        'LineColor', bcol(i,:), 'LineWidth', 1.1);
                end
                if SHOW_HALFPOWER_CONE && any(cosphi(:) >= cosd(th_r))
                    contour(ax, xr*100, yr*100, cosphi, [cosd(th_r) cosd(th_r)], ...
                        'LineColor', bcol(i,:), 'LineStyle', '--', 'LineWidth', 0.6);
                end
                % beam-axis intersection with the analysis plane
                tc = (z_analysis - params.T(3)) / nt_p(3, i);
                cx = params.T(1) + tc*nt_p(1, i);  cy = params.T(2) + tc*nt_p(2, i);
                plot(ax, cx*100, cy*100, '.', 'Color', bcol(i,:), 'MarkerSize', 9);
            end
        end

        plot(ax, 0, 0, 'p', 'MarkerSize', 7, 'MarkerFaceColor', [1 0.85 0], ...
            'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
        text(ax, -L/2*100+8, W/2*100-14, sprintf('%.0f\\%%', covpc(ir,ic)), ...
            'Interpreter','latex', 'FontSize', 7, 'FontWeight','bold', 'BackgroundColor',[1 1 1 0.6]);
        hold(ax, 'off');
        set(ax, 'FontName','Times New Roman', 'FontSize', 6, 'TickLabelInterpreter','latex', ...
            'Box','on', 'LineWidth', 0.5, 'XTick', [-150 0 150], 'YTick', [-150 0 150]);
        if ir == 1, title(ax, sprintf('$K{=}%d$', K_cols(ic)), 'Interpreter','latex', 'FontSize', 8); end
        if ic == 1
            ylabel(ax, sprintf('$\\theta_{1/2}{=}%d^\\circ$\\quad $y$ [cm]', theta_half_rows(ir)), ...
                'Interpreter','latex', 'FontSize', 7);
        end
        if ir == nR, xlabel(ax, '$x$ [cm]', 'Interpreter','latex', 'FontSize', 7); end
    end
end
title(tl, sprintf(['LED positioning coverage @ $z=%.1f$ m --- %s codebook ' ...
    '(blue = covered; solid = SNR$\\geq%g$ dB footprint; dashed = $-3$ dB cone)'], ...
    z_analysis, codebook_mode, SNR_min_dB), 'Interpreter','latex', 'FontSize', 9);

%% ===== Figure 4: coverage vs height, for a few half-power angles (fixed K) =====
z_vals = 0:0.1:Zmax;
nt_z   = get_codebook(K_zprofile, codebook_mode, presets, K_preset, uniform_cap_deg);
nThz   = numel(theta_half_zprof);
cov_z  = zeros(nThz, numel(z_vals));
colz   = lines(nThz);
for it = 1:nThz
    th = theta_half_zprof(it);
    params.theta_half = deg2rad(th);
    for iz = 1:numel(z_vals)
        pz  = [Xg(:)'; Yg(:)'; z_vals(iz)*ones(1, numel(Xg))];
        res = evaluate_coverage_LED(nt_z, m_of(th), pz, params);
        cov_z(it, iz) = 100 * res.coverage;
    end
end

fig4 = figure('Units','inches', 'Position',[1 1 3.6 2.7], 'Color','w'); hold on;
h4 = gobjects(nThz,1);
for it = 1:nThz
    h4(it) = plot(z_vals*100, cov_z(it,:), '-o', 'LineWidth', 1.2, ...
        'MarkerSize', 4, 'Color', colz(it,:), 'MarkerFaceColor', colz(it,:));
end
xlabel('Height $z$ [cm]', 'Interpreter','latex', 'FontSize', 9);
ylabel('Coverage [\%]', 'Interpreter','latex', 'FontSize', 9);
ylim([0 100]); grid on; box on; set(gca, 'FontSize', 8, 'TickLabelInterpreter','latex');
legend(h4, arrayfun(@(t) sprintf('$\\theta_{1/2}=%d^\\circ$', t), theta_half_zprof, ...
    'UniformOutput', false), 'Interpreter','latex', 'FontSize', 8, 'Location','best');
title(sprintf('Coverage vs height ($K=%d$)', K_zprofile), 'Interpreter','latex', 'FontSize', 9);

%% ===== Export =====
if SAVE_FIGS
    exportgraphics(fig1, fullfile(out_dir, 'LEDcov_vs_halfpower.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig1, fullfile(out_dir, 'LEDcov_vs_halfpower.png'), 'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig2, fullfile(out_dir, 'LEDpeb_vs_halfpower.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig2, fullfile(out_dir, 'LEDpeb_vs_halfpower.png'), 'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig3, fullfile(out_dir, 'LEDcov_maps.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig3, fullfile(out_dir, 'LEDcov_maps.png'), 'Resolution',600,'BackgroundColor','white');
    exportgraphics(fig4, fullfile(out_dir, 'LEDcov_vs_height.pdf'), 'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig4, fullfile(out_dir, 'LEDcov_vs_height.png'), 'Resolution',600,'BackgroundColor','white');
    fprintf('Figures saved to %s\n', out_dir);
end

%% ===== Summary =====
fprintf('\n=== Coverage [%%] vs half-power angle (3D testbed) ===\n');
fprintf('%-8s', 'K\\th1/2'); fprintf('%7d', theta_half_sweep); fprintf('\n');
for ik = 1:nK
    fprintf('%-8d', K_list(ik)); fprintf('%7.1f', cov_curve(ik,:)); fprintf('\n');
end

%% ------------------------- local functions -------------------------
function nt = get_codebook(K, mode, presets, K_preset, cap_deg)
% Return a 3xK matrix of unit orientation vectors for the requested K.
    switch lower(mode)
        case 'preset'
            idx = find(K_preset == K, 1);
            if isempty(idx)
                error('coverage:preset', ...
                    'No preset orientation set for K=%d (available: %s).', ...
                    K, mat2str(K_preset));
            end
            nt = ori2nt(presets{idx}, K);
        case 'uniform'
            nt = sunflower_codebook(K, cap_deg);
        otherwise
            error('coverage:mode', 'Unknown codebook_mode "%s".', mode);
    end
end

function nt = ori2nt(orientations, K)
% Convert [theta1,rho1,...,thetaK,rhoK] (deg) to 3xK nadir-referenced unit vectors.
    nt = zeros(3, K);
    for i = 1:K
        th = orientations(2*i-1); ph = orientations(2*i);
        nt(:, i) = [sind(th)*cosd(ph); sind(th)*sind(ph); -cosd(th)];
    end
end

function [SNRdB, cosphi] = beam_snr_field(nt_i, m, Xg, Yg, z, prm)
% Per-beam averaged-measurement SNR field (dB) and irradiance-angle cosine field
% on the analysis plane, for the Lambertian LED beam with axis nt_i.
    T  = prm.T;
    Cb = prm.Pt * (m + 1) * prm.A_det / (2 * pi);
    dx = Xg - T(1);  dy = Yg - T(2);  dz = z - T(3);
    d  = sqrt(dx.^2 + dy.^2 + dz.^2);

    cos_psi = -dz ./ d;                                   % nr = [0;0;1]
    cphi    = (nt_i(1).*dx + nt_i(2).*dy + nt_i(3).*dz) ./ d;
    inFOV   = cos_psi > 0 & acos(min(1, max(-1, cos_psi))) <= prm.Psi_FOV;
    valid   = inFOV & cphi > 0;

    mu = zeros(size(d));
    mu(valid) = Cb .* cphi(valid).^m .* cos_psi(valid) ./ d(valid).^2;
    SNRlin = prm.N .* mu.^2 ./ prm.sigma2;

    SNRdB = -inf(size(d));
    p = SNRlin > 0;  SNRdB(p) = 10 * log10(SNRlin(p));

    cosphi = nan(size(d));            % only defined where the beam is in front & in FOV
    cosphi(valid) = cphi(valid);
end

function nt = sunflower_codebook(K, cap_deg)
% Area-uniform Fibonacci-spiral codebook on a downward spherical cap.
    theta_cap = deg2rad(cap_deg);
    golden    = pi * (3 - sqrt(5));
    nt = zeros(3, K);
    for i = 1:K
        frac  = (i - 0.5) / K;
        theta = theta_cap * sqrt(frac);
        rho   = golden * (i - 1);
        nt(:, i) = [sin(theta)*cos(rho); sin(theta)*sin(rho); -cos(theta)];
    end
    nt = nt ./ vecnorm(nt);
end
