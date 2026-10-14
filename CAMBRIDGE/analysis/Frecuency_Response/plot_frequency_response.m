% Frequency response of one LED measured by the PD (exp03).
% Reads frequency_response.csv (columns frequency_Hz, amplitude_mVrms) and plots the amplitude versus
% frequency, in linear units or in dB.
close all

%% Hyperparameters
csv_file        = fullfile(fileparts(mfilename('fullpath')), 'frequency_response.csv');
amplitude_scale = 'linear';           % 'linear' (mVrms) | 'dB' (20 log10(A / db_reference))
db_reference    = 1000;              % 'max' (0 dB at the maximum) | reference amplitude in mVrms (e.g. 1)
frequency_axis  = 'linear';           % 'linear' | 'log'
mark_peak       = true;               % mark the maximum of the response
mark_3db        = false;               % mark the -3 dB points around the maximum (interpolated)
mark_freqs_khz  = [300 500 700 900];  % vertical lines at these frequencies ([] = none)
show_markers    = true;               % dots at the measured frequencies
export_figures  = true;              % PNG (300 dpi) + FIG in output_dir (overwritten at every run)
output_dir      = fullfile(fileparts(csv_file), 'figures');

%% Load
data = readtable(csv_file);
f_khz = data.frequency_Hz/1e3;
amp = data.amplitude_mVrms;
[peak, k_peak] = max(amp);

switch amplitude_scale
    case 'linear'
        y = amp;
        y_label = 'Amplitude (mV_{rms})';
    case 'dB'
        if ischar(db_reference) || isstring(db_reference)
            reference = peak;
            y_label = 'Normalized amplitude (dB)';
        else
            reference = db_reference;
            y_label = 'Amplitude (dB)';
        end
        y = 20*log10(amp/reference);
    otherwise
        error('amplitude_scale must be ''linear'' or ''dB''.');
end

% -3 dB points: first crossings of peak/sqrt(2) on each side of the maximum
level = peak/sqrt(2);
f_low = NaN;
f_high = NaN;
i = find(amp(1:k_peak) < level, 1, 'last');
if ~isempty(i)
    f_low = interp1(amp(i:i+1), f_khz(i:i+1), level);
end
i = k_peak - 1 + find(amp(k_peak:end) < level, 1, 'first');
if ~isempty(i)
    f_high = interp1(amp(i-1:i), f_khz(i-1:i), level);
end
band = {sprintf('< %g', f_khz(1)), sprintf('> %g', f_khz(end))};
if isfinite(f_low)
    band{1} = sprintf('%.4g', f_low);
end
if isfinite(f_high)
    band{2} = sprintf('%.4g', f_high);
end
band_label = sprintf('-3 dB band: %s to %s kHz', band{:});
fprintf('%d points, %g-%g kHz\n', numel(f_khz), f_khz(1), f_khz(end));
fprintf('Maximum %.4g mVrms at %g kHz; %s\n', peak, f_khz(k_peak), band_label);
for f = mark_freqs_khz
    fprintf('  %g kHz: %.4g mVrms (%.2f dB from the maximum)\n', f, interp1(f_khz, amp, f), ...
        20*log10(interp1(f_khz, amp, f)/peak));
end

%% Plot
fig = figure('Name', 'Frequency response', 'Color', 'w', 'Position', [100 100 900 480]);
ax = axes(fig);
hold(ax, 'on');
for f = mark_freqs_khz
    xline(ax, f, ':', sprintf('%g kHz', f), 'Color', [0.5 0.5 0.5], 'LabelVerticalAlignment', 'bottom', ...
        'HandleVisibility', 'off');
end
if show_markers
    plot(ax, f_khz, y, '.-', 'LineWidth', 1, 'MarkerSize', 8, 'DisplayName', 'Measured');
else
    plot(ax, f_khz, y, '-', 'LineWidth', 1, 'DisplayName', 'Measured');
end
if mark_peak
    plot(ax, f_khz(k_peak), y(k_peak), 'kp', 'MarkerFaceColor', 'k', 'MarkerSize', 9, ...
        'DisplayName', sprintf('Maximum (%.4g mV_{rms} at %g kHz)', peak, f_khz(k_peak)));
end
if mark_3db && any(isfinite([f_low f_high]))
    y_3db = level;
    if strcmp(amplitude_scale, 'dB')
        y_3db = 20*log10(level/reference);
    end
    plot(ax, [f_low f_high], [y_3db y_3db], 'kv', 'MarkerFaceColor', 'w', 'DisplayName', band_label);
    yline(ax, y_3db, '--', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
end
set(ax, 'XScale', frequency_axis, 'Box', 'on');
grid(ax, 'on');
xlim(ax, [f_khz(1) f_khz(end)]);
xlabel(ax, 'Frequency (kHz)');
ylabel(ax, y_label);
%legend(ax, 'Location', 'best');

%% Export
if export_figures
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
    name = sprintf('frequency_response_%s', amplitude_scale);
    exportgraphics(fig, fullfile(output_dir, [name '.png']), 'Resolution', 300);
    savefig(fig, fullfile(output_dir, [name '.fig']));
    fprintf('Figure saved in %s\n', output_dir);
end
