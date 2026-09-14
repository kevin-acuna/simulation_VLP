function r = study_heatmap(p, e)
validateattributes(e.heights_m, {'numeric'}, {'vector', 'real', 'finite', 'nonempty'});
validateattributes(e.grid_step_m, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
assert(~isempty(e.cases), 'cambridge:EmptyExperiment', 'At least one case is required.');
r.kind = 'heatmap';
r.parameters = p;
r.spec = e;
r.x_m = linspace(min(p.environment.x_m), max(p.environment.x_m), ...
    ceil(range(p.environment.x_m)/e.grid_step_m)+1);
r.y_m = linspace(min(p.environment.y_m), max(p.environment.y_m), ...
    ceil(range(p.environment.y_m)/e.grid_step_m)+1);
[X, Y] = meshgrid(r.x_m, r.y_m);
nh = numel(e.heights_m);
nc = numel(e.cases);
r.peb_m = nan(numel(X), nh, nc);
r.positions_m = nan(3, numel(X), nh);
for iz = 1:nh
    positions = [X(:)'; Y(:)'; repmat(e.heights_m(iz), 1, numel(X))];
    r.positions_m(:, :, iz) = positions;
    for ic = 1:nc
        [pc, normals] = rx_case_parameters(p, e.cases(ic));
        r.spec.cases(ic).normals = normals;
        r.peb_m(:, iz, ic) = rx_peb(positions, normals, pc)';
    end
end
r = rx_summarize_study(r);
[H, C] = ndgrid(e.heights_m, 1:nc);
r.table = table(C(:), H(:), 100*r.rms_full_m(:), 100*r.rms_conditional_m(:), ...
    100*r.coverage(:), 100*r.nonregular_fraction(:), 'VariableNames', ...
    {'Case', 'Height_m', 'RMS_full_cm', 'RMS_conditional_cm', 'Coverage_percent', 'Nonregular_percent'});
end
