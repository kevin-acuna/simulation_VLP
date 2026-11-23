% Minimal example: read an RSS table, read the raw waveform of one record and recompute its RSS.
% Run it from the folder that holds the downloaded files, with the archives extracted in the same folder
% (read_npz.m must be in that folder or on the MATLAB path). Requires MATLAB R2019b or later.
root = fileparts(mfilename('fullpath'));    % folder with the *_RSS.csv files and the extracted archives
freqs_khz = [300 500 700 900];               % nominal modulation frequencies of the four LEDs

T = readtable(fullfile(root, 'D2_grid_RSS.csv'), 'TextType', 'string');
fprintf('D2: %d records at %d positions\n', height(T), height(unique(T(:, {'session', 'site_id'}))));
r = T(1, :);
fprintf('First record: X = %.3f m, Y = %.3f m, Z = %.5f m, stage angle %.4f deg, PD normal (%.6f, %.6f, %.6f)\n', ...
    r.X_m, r.Y_m, r.Z_m, r.alpha_deg, r.nx, r.ny, r.nz);

wave = fullfile(root, 'D2_grid', r.session, 'wave', sprintf('m%05d.npz', r.meas_id));
if ~isfile(wave)
    error('%s not found: extract D2_grid.zip into %s to read the raw waveforms.', wave, root);
end
z = read_npz(wave);
v = (double(z.codes) - z.y_reference).*z.y_increment + z.y_origin;   % volts, one row per record
N = size(v, 2);
fprintf('Raw waveform: %d samples at %g MSa/s\n', N, z.fs/1e6);
x = v - mean(v, 2);
n = (0:N - 1)';
for f = freqs_khz
    y = sqrt(2)*abs(x*exp(-2i*pi*f*1e3*n/z.fs))/N;   % digital lock-in at f over the whole record
    fprintf('  %d kHz LED: RSS recomputed %.6g V, in the table %.6g V\n', f, y(1), r.(sprintf('rss_%dkHz_V', f)));
end
