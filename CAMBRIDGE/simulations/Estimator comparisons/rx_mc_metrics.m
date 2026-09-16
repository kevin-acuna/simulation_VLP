function r = rx_mc_metrics(r)
P = size(r.errors_m, 1);
T = size(r.errors_m, 2);
M = size(r.errors_m, 3);
r.rmse_per_position_m = reshape(sqrt(mean(r.errors_m.^2, 2)), P, M);
values = nan(M, 10);
for im = 1:M
    errors = r.errors_m(:, :, im);
    valid = isfinite(errors);
    conditional = NaN;
    if any(valid, 'all')
        conditional = sqrt(mean(errors(valid).^2));
    end
    full = sqrt(mean(errors.^2, 'all'));
    bias = NaN;
    interval = [NaN NaN];
    if all(valid, 'all')
        delta = r.estimates_m(:, :, :, im)-reshape(r.positions_m, 3, P, 1);
        bias = sqrt(mean(sum(mean(delta, 3).^2, 1)));
        se_mse = sqrt(sum(var(errors.^2, 0, 2)/T))/P;
        se_rmse = se_mse/(2*max(full, realmin));
        interval = [max(0, full-1.96*se_rmse), full+1.96*se_rmse];
    end
    dir = r.direction_errors_deg(:, :, im);
    radial = r.range_errors_m(:, :, im);
    dir_rms = sqrt(mean(dir(valid).^2));
    radial_rms = sqrt(mean(radial(valid).^2));
    peb_rms = sqrt(mean(r.peb_m.^2));
    values(im, :) = [100*full, 100*conditional, 100*(1-mean(valid, 'all')), ...
        100*bias, 100*peb_rms, conditional/peb_rms, 100*interval, dir_rms, 100*radial_rms];
end
r.table = array2table(values, 'VariableNames', {'RMSE_full_cm', 'RMSE_success_cm', 'Failure_percent', ...
    'RMS_bias_cm', 'RMS_PEB_cm', 'RMSE_success_over_PEB', 'MC_CI95_low_cm', 'MC_CI95_high_cm', ...
    'DirectionRMSE_deg', 'RangeRMSE_cm'});
r.table = addvars(r.table, string(r.experiment.methods(:)), 'Before', 1, 'NewVariableNames', 'Method');
end
