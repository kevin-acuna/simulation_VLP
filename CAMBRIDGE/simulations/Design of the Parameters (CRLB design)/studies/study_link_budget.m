function r = study_link_budget(p, e)
validateattributes(e.power_values_W, {'numeric'}, {'vector', 'real', 'finite', 'positive'});
validateattributes(e.sample_values, {'numeric'}, {'vector', 'integer', 'positive'});
validateattributes(e.noise_std_scales, {'numeric'}, {'vector', 'real', 'finite', 'positive', 'nonempty'});
validateattributes(p.acquisition.samples_per_orientation, {'numeric'}, {'scalar', 'integer', 'positive'});
assert(~isempty(e.cases) && ~isempty(e.power_values_W) && ~isempty(e.sample_values), ...
    'cambridge:EmptyExperiment', 'Cases, powers and sample budgets cannot be empty.');
r.kind = 'link_budget';
r.parameters = p;
r.spec = e;
[r.positions_m, r.grid] = rx_testbed(p);
nw = numel(e.power_values_W);
nn = numel(e.sample_values);
ns = numel(e.noise_std_scales);
nc = numel(e.cases);
r.peb_m = nan(size(r.positions_m, 2), nw, nn, ns, nc);
r.target_coverage = zeros(nw, nn, ns, nc);
r.required_N_at_reference_power = nan(ns, nc);
for ic = 1:nc
    [pc, normals] = rx_case_parameters(p, e.cases(ic));
    r.spec.cases(ic).normals = normals;
    base = rx_peb(r.positions_m, normals, pc);
    q = rx_bound_quality(base, e.target_peb_m, e.min_target_coverage);
    for is = 1:ns
        r.required_N_at_reference_power(is, ic) = p.acquisition.samples_per_orientation*(q.required_scale*e.noise_std_scales(is))^2;
        for iw = 1:nw
            for in = 1:nn
                factor = (p.transmitter.power_W/e.power_values_W(iw))*e.noise_std_scales(is) ...
                    *sqrt(p.acquisition.samples_per_orientation/e.sample_values(in));
                values = base*factor;
                r.peb_m(:, iw, in, is, ic) = values';
                r.target_coverage(iw, in, is, ic) = mean(isfinite(values) & values<=e.target_peb_m);
            end
        end
    end
end
r = rx_summarize_study(r);
[W, N, S, C] = ndgrid(e.power_values_W, e.sample_values, e.noise_std_scales, 1:nc);
r.table = table(C(:), W(:), N(:), S(:), p.noise.variance_W2*S(:).^2, ...
    100*r.rms_full_m(:), 100*r.coverage(:), 100*r.target_coverage(:), ...
    'VariableNames', {'Case', 'Power_W', 'SamplesPerOrientation', 'NoiseStdScale', 'NoiseVariance_W2', ...
    'RMS_full_cm', 'RegularCoverage_percent', 'TargetCoverage_percent'});
r.table.Feasible = r.coverage(:)==1 & r.rms_full_m(:)<=e.target_peb_m & r.target_coverage(:)>=e.min_target_coverage;
end
