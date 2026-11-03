function make_isac_figures()
% Figures for an internal presentation (not in the paper): one raw record of the blind test D3 (live demo,
% K = 5) in time and in frequency, with the 500 kHz positioning tone highlighted. Same style as fig_spectrum.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'figures', 'lib'));
cfg = pp_config();
dirD3 = cfg.random_dirs{2};
t = readtable(fullfile(dirD3, 'points.csv'), 'VariableNamingRule', 'preserve');
[~, r] = max(t.('500kHz_wave_Vrms'));                     % record with the strongest 500 kHz tone
z = pp_read_npz(fullfile(dirD3, t.wave_file{r}));
v = (double(z.codes(1, :)) - double(z.y_reference(1)))*double(z.y_increment(1)) + double(z.y_origin(1));
fs = double(z.fs);
N = numel(v);
tt = (0:N - 1)/fs;
fprintf('D3 record %s (site %d, k %d): 500 kHz RSS %.2f mV\n', t.wave_file{r}, t.site_id(r), t.k(r), ...
    1e3*t.('500kHz_wave_Vrms')(r));
blue = [0 0.32 0.62];
red = [0.85 0.33 0.1];

% --- signal: full record (flicker of the room lights) and a 20-us zoom (LED tones)
fig = pp_figure(3.5, 3.0);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);
step = 50;
plot(ax, 1e3*tt(1:step:end), 1e3*v(1:step:end), '-', 'Color', blue, 'LineWidth', 0.5);
xlim(ax, [0 1e3*tt(end)]);
xlabel(ax, 'Time (ms)');
ylabel(ax, 'PD output (mV)');
title(ax, '(a) Full record, 100 ms', 'FontWeight', 'normal');
ax = nexttile(tl);
n = round(20e-6*fs);
i0 = round(N/2);
seg = v(i0:i0 + n - 1);
plot(ax, 1e6*(tt(i0:i0 + n - 1) - tt(i0)), 1e3*(seg - mean(seg)), '-o', 'Color', blue, 'LineWidth', 0.8, ...
    'MarkerSize', 2, 'MarkerFaceColor', blue);
xlim(ax, [0 20]);
xlabel(ax, 'Time ($\mu$s)');
ylabel(ax, 'PD output (mV)');
title(ax, '(b) 20-$\mu$s zoom (mean removed): 500 kHz tone', 'FontWeight', 'normal');
export(fig, here, 'isac_signal_D3');

% --- spectrum: maximum over 1-kHz groups of 10-Hz bins, 500 kHz highlighted
a = sqrt(2)*abs(fft(v))/N;
df = fs/N;
group = round(1e3/df);
m = floor(numel(a)/2/group)*group;
env = max(reshape(a(1:m), group, []), [], 1);
fk = ((0:numel(env) - 1) + 0.5)*group*df/1e3;
fig = pp_figure(3.5, 2.2);
ax = axes(fig);
semilogy(ax, fk, env, '-', 'Color', blue, 'LineWidth', 0.6);
hold(ax, 'on');
peak = max(env(abs(fk - 500) < 2));
text(ax, 500, 2.2*peak, '500 kHz', 'HorizontalAlignment', 'center', 'FontSize', 7);
xlim(ax, [0 1000]);
ylim(ax, [1e-6 1]);
xlabel(ax, 'Frequency (kHz)');
ylabel(ax, 'Amplitude (V rms per 10 Hz bin)');
export(fig, here, 'isac_spectrum_D3');
end

function export(fig, folder, name)
exportgraphics(fig, fullfile(folder, [name '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fig, fullfile(folder, [name '.png']), 'Resolution', 300, 'BackgroundColor', 'white');
close(fig);
fprintf('  figure %s\n', name);
end
