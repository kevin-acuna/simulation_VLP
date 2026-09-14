function study = rx_study_from_design(r, kind)
p = r.parameters;
study.kind = kind;
study.parameters = p;
switch kind
    case 'inclination'
        study.spec = struct('K', p.design.reference_K, 'half_angles_deg', p.design.half_angles_deg, ...
            'fov_values_deg', p.design.fov_values_deg, 'tilt_values_deg', p.design.tilt_values_deg, ...
            'azimuth_offset_deg', p.design.azimuth_offset_deg);
        study.peb_m = r.tilt.peb_m;
    case 'K'
        cases = rx_cone_cases(p, [r.best.half_angle_deg], [r.best.cone_tilt_deg], p.design.reference_K);
        for i = 1:numel(cases)
            cases(i).fov_deg = r.best(i).fov_deg;
        end
        study.spec = struct('cases', cases, 'K_values', p.design.K_values, 'budgets', {r.K.budgets});
        study.peb_m = r.K.peb_m;
    case 'area'
        study.spec = struct('cases', rx_cases_from_design(r), 'area_values_mm2', p.design.area_values_mm2);
        if isfield(r.area, 'peb_m')
            study.peb_m = r.area.peb_m;
        else
            np = numel(r.best(1).peb_m);
            study.peb_m = nan(np, numel(p.design.area_values_mm2), numel(r.best));
            for i = 1:numel(r.best)
                study.peb_m(:, :, i) = r.best(i).peb_m(:).*(p.receiver.area_m2*1e6./p.design.area_values_mm2(:)');
            end
        end
    case {'heatmap', 'heatmap_best'}
        study.kind = 'heatmap';
        study.x_m = r.heatmap.x_m;
        study.y_m = r.heatmap.y_m;
        if strcmp(kind, 'heatmap')
            study.spec = struct('cases', rx_cases_from_design(r), 'heights_m', r.heatmap.comparison_height_m);
            study.peb_m = reshape(r.heatmap.comparison_peb_m, numel(study.x_m)*numel(study.y_m), 1, []);
        else
            c = rx_cases_from_design(r, r.best_half_index);
            study.spec = struct('cases', [c c], 'heights_m', r.heatmap.heights_m);
            for i = 1:2
                study.spec.cases(i).area_m2 = r.heatmap.areas_mm2(i)*1e-6;
            end
            study.peb_m = reshape(r.heatmap.best_peb_m, numel(study.x_m)*numel(study.y_m), numel(r.heatmap.heights_m), 2);
        end
        study.spec.grid_step_m = p.output.heatmap_step_m;
    otherwise
        error('cambridge:ExperimentKind', 'Unknown stored design component: %s.', kind);
end
study = rx_summarize_study(study);
end
