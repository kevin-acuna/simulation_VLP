function r = study_K(p, e)
validateattributes(e.K_values, {'numeric'}, {'vector', 'integer', 'positive', 'nonempty'});
assert(~isempty(e.cases) && ~isempty(e.budgets), 'cambridge:EmptyExperiment', 'Cases and budgets cannot be empty.');
assert(all(strcmp({e.cases.family}, 'uniform_cone')), 'cambridge:KRequiresCone', ...
    'The K sweep regenerates uniform cones; explicit orientation sets cannot be silently resized.');
r.kind = 'K';
r.parameters = p;
r.spec = e;
[r.positions_m, r.grid] = rx_testbed(p);
nk = numel(e.K_values);
nc = numel(e.cases);
nb = numel(e.budgets);
r.peb_m = nan(size(r.positions_m, 2), nk, nc, nb);
r.normals = cell(nk, nc);
r.sample_counts = cell(nk, nb);
for ic = 1:nc
    pc = rx_case_parameters(p, e.cases(ic));
    for ik = 1:nk
        normals = rx_cone_normals(e.K_values(ik), e.cases(ic).tilt_deg, e.cases(ic).azimuth_offset_deg);
        r.normals{ik, ic} = normals;
        for ib = 1:nb
            counts = rx_sample_counts(e.K_values(ik), p, e.budgets{ib});
            r.sample_counts{ik, ib} = counts;
            r.peb_m(:, ik, ic, ib) = rx_peb(r.positions_m, normals, pc, counts)';
        end
    end
end
r = rx_summarize_study(r);
[K, C, B] = ndgrid(e.K_values, 1:nc, 1:nb);
budget_names = string(e.budgets);
r.table = table(C(:), K(:), reshape(budget_names(B(:)), [], 1), ...
    100*r.rms_full_m(:), 100*r.rms_conditional_m(:), 100*r.coverage(:), ...
    'VariableNames', {'Case', 'K', 'Budget', 'RMS_full_cm', 'RMS_conditional_cm', 'Coverage_percent'});
end
