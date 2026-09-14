function r = study_area(p, e)
validateattributes(e.area_values_mm2, {'numeric'}, {'vector', 'real', 'finite', 'positive', 'nonempty'});
assert(~isempty(e.cases), 'cambridge:EmptyExperiment', 'At least one case is required.');
r.kind = 'area';
r.parameters = p;
r.spec = e;
[r.positions_m, r.grid] = rx_testbed(p);
na = numel(e.area_values_mm2);
nc = numel(e.cases);
r.peb_m = nan(size(r.positions_m, 2), na, nc);
for ic = 1:nc
    [pc, normals] = rx_case_parameters(p, e.cases(ic));
    r.spec.cases(ic).normals = normals;
    for ia = 1:na
        pc.receiver.area_m2 = e.area_values_mm2(ia)*1e-6;
        r.peb_m(:, ia, ic) = rx_peb(r.positions_m, normals, pc)';
    end
end
r = rx_summarize_study(r);
[A, C] = ndgrid(e.area_values_mm2, 1:nc);
r.table = table(C(:), A(:), 100*r.rms_full_m(:), 100*r.rms_conditional_m(:), 100*r.coverage(:), ...
    'VariableNames', {'Case', 'Area_mm2', 'RMS_full_cm', 'RMS_conditional_cm', 'Coverage_percent'});
end
