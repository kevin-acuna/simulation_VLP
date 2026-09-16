function r = study_estimator_orders(p, e)
r.parameters = p;
r.experiment = e;
r.runs = cell(numel(e.m_R_values), numel(e.noise_std_scales));
rows = cell(size(r.runs));
for io = 1:numel(e.m_R_values)
    for is = 1:numel(e.noise_std_scales)
        pc = p;
        pc.receiver.m_R = e.m_R_values(io);
        pc.noise.variance_W2 = p.noise.variance_W2*e.noise_std_scales(is)^2;
        normals = rx_cone_normals(e.K, e.tilt_deg);
        rx_print_comparison(pc, normals, e);
        run = rx_monte_carlo(pc, pc, normals, e);
        r.runs{io, is} = run;
        rows{io, is} = addvars(run.table, repmat(pc.receiver.m_R, height(run.table), 1), ...
            repmat(e.noise_std_scales(is), height(run.table), 1), 'Before', 1, 'NewVariableNames', {'m_R', 'NoiseStdScale'});
    end
end
r.table = vertcat(rows{:});
end
