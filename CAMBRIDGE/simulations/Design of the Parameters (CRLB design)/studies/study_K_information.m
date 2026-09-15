function r = study_K_information(p, e)
validateattributes(e.K_values, {'numeric'}, {'vector', 'integer', 'positive', 'nonempty', 'increasing'});
validateattributes(e.tilt_deg, {'numeric'}, {'scalar', '>=', 0, '<=', p.receiver.max_tilt_deg});
r.kind = 'K_information';
r.parameters = p;
r.spec = e;
[r.positions_m, r.grid] = rx_testbed(p);
nk = numel(e.K_values);
np = numel(e.patterns);
nf = numel(e.fov_values_deg);
nb = numel(e.budgets);
r.peb_m = nan(size(r.positions_m, 2), nk, np, nf, nb);
r.light_coverage = zeros(nk, np, nf, nb);
r.target_coverage = zeros(nk, np, nf, nb);
r.axis_peb_m = nan(nk, np, nf, nb);
r.axis_fim_per_m2 = nan(3, 3, nk, np, nf, nb);
r.sample_counts = cell(nk, nb);
r.normals = cell(nk, np);
pc = p;
pc.transmitter.half_angle_power_deg = e.half_angle_deg;
for ik = 1:nk
    for ip = 1:np
        normals = rx_capped_pattern(e.K_values(ik), e.tilt_deg, e.patterns{ip}, e.azimuth_offset_deg, 'maximum');
        r.normals{ik, ip} = normals;
        for jf = 1:nf
            pc.receiver.fov_deg = e.fov_values_deg(jf);
            for ib = 1:nb
                counts = rx_sample_counts(e.K_values(ik), p, e.budgets{ib});
                [peb, info] = rx_peb(r.positions_m, normals, pc, counts);
                r.peb_m(:, ik, ip, jf, ib) = peb';
                r.light_coverage(ik, ip, jf, ib) = mean(info.visible_count>0);
                r.target_coverage(ik, ip, jf, ib) = mean(isfinite(peb) & peb<=e.target_peb_m);
                [r.axis_peb_m(ik, ip, jf, ib), axis_info] = rx_peb(e.reference_position_m, normals, pc, counts);
                r.axis_fim_per_m2(:, :, ik, ip, jf, ib) = axis_info.fim_per_m2;
                r.sample_counts{ik, ib} = counts;
            end
        end
    end
end
r = rx_summarize_study(r);
[K, P, F, B] = ndgrid(e.K_values, 1:np, e.fov_values_deg, 1:nb);
patterns = string(e.patterns);
budgets = string(e.budgets);
r.table = table(K(:), reshape(patterns(P(:)), [], 1), F(:), reshape(budgets(B(:)), [], 1), ...
    100*r.rms_full_m(:), 100*r.rms_conditional_m(:), 100*r.light_coverage(:), 100*r.coverage(:), ...
    100*r.target_coverage(:), 100*r.axis_peb_m(:), 'VariableNames', ...
    {'K', 'Pattern', 'FOV_deg', 'Budget', 'RMS_full_cm', 'RMS_conditional_cm', 'LightCoverage_percent', ...
    'RegularCoverage_percent', 'TargetCoverage_percent', 'AxisPEB_cm'});
end
