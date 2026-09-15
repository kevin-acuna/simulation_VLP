function refinement = rx_refine_capped_pattern(positions, normals, p, counts, e)
quality = rx_bound_quality(rx_peb(positions, normals, p, counts), e.target_peb_m, e.min_target_coverage);
refinement = struct('normals', normals, 'initial_score', quality.required_scale, ...
    'final_score', quality.required_scale, 'history', [0 quality.required_scale], 'evaluations', 1);
if ~e.refine_selected || ~isfinite(quality.required_scale)
    return;
end
assert(numel(e.refinement_tilt_steps_deg)==numel(e.refinement_azimuth_steps_deg), ...
    'cambridge:RefinementSteps', 'Tilt and azimuth step lists must have the same length.');
angles = [acosd(max(-1, min(1, normals(3, :)))); mod(atan2d(normals(2, :), normals(1, :)), 360)];
for level = 1:numel(e.refinement_tilt_steps_deg)
    steps = [e.refinement_tilt_steps_deg(level), e.refinement_azimuth_steps_deg(level)];
    for pass = 1:e.refinement_passes
        changed = false;
        for i = 1:size(normals, 2)
            for coordinate = 1:2
                if coordinate==1 && strcmp(e.tilt_constraint, 'fixed')
                    continue;
                end
                best = angles;
                score = refinement.final_score;
                for sign = [-1 1]
                    trial = angles;
                    trial(coordinate, i) = trial(coordinate, i)+sign*steps(coordinate);
                    if trial(1, i)<0 || trial(1, i)>e.tilt_deg
                        continue;
                    end
                    trial(2, i) = mod(trial(2, i), 360);
                    q = rx_bound_quality(rx_peb(positions, rx_normals(trial(1, :), trial(2, :)), p, counts), ...
                        e.target_peb_m, e.min_target_coverage);
                    refinement.evaluations = refinement.evaluations+1;
                    if q.required_scale<score*(1-p.design.improvement_relative_tolerance)
                        best = trial;
                        score = q.required_scale;
                    end
                end
                if score<refinement.final_score
                    angles = best;
                    refinement.final_score = score;
                    refinement.history(end+1, :) = [refinement.evaluations score];
                    changed = true;
                end
            end
        end
        if ~changed
            break;
        end
    end
end
refinement.normals = rx_normals(angles(1, :), angles(2, :));
end
