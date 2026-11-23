function verify_against_paper()
% Checks that the published RSS tables of D2 and D3 (upload/*_RSS.csv) hold exactly the inputs of the manuscript
% pipeline (manuscript/figures/lib/pp_load_sites, which reads the original sessions) and reproduce its mean 3-D
% errors with the SQ response and the NLS estimator (paper_numbers.json: grid.final_demo_offset, random.test).
% Run from this folder after build_package.py:  matlab -batch "verify_against_paper"
here = fileparts(mfilename('fullpath'));
figdir = fullfile(fileparts(here), 'manuscript', 'figures');
addpath(fullfile(figdir, 'lib'));
cfg = pp_config();
addpath(cfg.sim);
cambridge_setup();
NUM = jsondecode(fileread(fullfile(figdir, 'paper_numbers.json')));
G = load(fullfile(figdir, 'grid_results.mat'), 'pf');
jf = find(cfg.led_freqs_khz == cfg.freq_khz);
sets = {'D2_grid', cfg.grid_dirs, inf(1, numel(cfg.grid_dirs)), G.pf, NUM.grid.final_demo_offset.err3d.mean
        'D3_blind_test', cfg.random_dirs, cfg.random_keep, pp_params(cfg, 'SQ', cfg.A, cfg.m, cfg.led_xy_mm), ...
        NUM.random.test.err3d.mean};
ok = true;
for s = 1:size(sets, 1)
    D = pp_load_sites(sets{s, 2}, cfg, sets{s, 3});
    T = readtable(fullfile(here, 'upload', [sets{s, 1} '_RSS.csv']), 'TextType', 'string');
    [~, T.campaign] = ismember(T.session, string(cellfun(@folder_name, sets{s, 2}, 'UniformOutput', false)));
    T = sortrows(T, {'campaign', 'site_id', 'k'});
    K = D.K;
    S = height(T)/K;
    xyz = reshape([T.X_m T.Y_m T.Z_m]', 3, K, S);
    truth = reshape(xyz(:, 1, :), 3, S);
    theta = reshape(T.alpha_deg, K, S);
    rss = reshape(T.rss_500kHz_V, K, S);
    n_err = 0;
    for i = 1:S
        rows = (i - 1)*K + (1:K);
        n_err = max(n_err, max(abs([T.nx(rows) T.ny(rows) T.nz(rows)]' - pp_normals(theta(:, i), cfg.offset_deg, ...
            cfg.tilt_deg)), [], 'all'));
    end
    d = [max(abs(truth - D.truth), [], 'all'), max(abs(theta - D.theta), [], 'all'), ...
         max(abs(rss - D.rss(:, :, jf)), [], 'all'), n_err];
    E = pp_estimate('SQ', 'NLS', rss, theta, cfg.offset_deg, cfg.tilt_deg, sets{s, 4});
    err = mean(100*vecnorm(E.r - truth));
    pass = S == size(D.truth, 2) && all(d(1:3) < 1e-9) && d(4) < 1e-6 && abs(err - sets{s, 5}) < 1e-9;
    ok = ok && pass;
    fprintf(['%s: %d positions (pipeline %d), K = %d | max difference: position %.1e m, angle %.1e deg, ' ...
             'RSS %.1e V, normal %.1e | mean 3-D error %.6f cm (pipeline %.6f cm) -> %s\n'], sets{s, 1}, S, ...
            size(D.truth, 2), K, d, err, sets{s, 5}, string(pass));
end
if ~ok
    error('verify_against_paper:Mismatch', 'The published tables differ from the inputs of the manuscript pipeline.');
end
fprintf('OK: the published tables reproduce the D2 and D3 results of the manuscript pipeline.\n');
end

function name = folder_name(d)
[~, name] = fileparts(d);
end
