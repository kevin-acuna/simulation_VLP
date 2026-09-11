function refinement = rx_refine_orientations(positions_m, p, K, cone_tilt_deg)
initial = rx_cone_normals(K, cone_tilt_deg, p.design.azimuth_offset_deg);
initial_peb = rx_peb(positions_m, initial, p);
initial_metrics = rx_design_metrics(initial_peb);
assert(isfinite(initial_metrics.rms_full_m), 'cambridge:RefinementSeed', 'Refinement requires a fully covered seed.');
refinement.normals = initial;
refinement.rms_full_m = initial_metrics.rms_full_m;
refinement.cone_rms_m = initial_metrics.rms_full_m;
refinement.history = [0 0 initial_metrics.rms_full_m];
refinement.evaluations = 1;
if ~p.design.refine_2dof
    return;
end
seeds = {initial, [[0; 0; 1], rx_cone_normals(K-1, cone_tilt_deg, p.design.azimuth_offset_deg)]};
for seed_index = 1:numel(seeds)
    normals = seeds{seed_index};
    angles = [acosd(max(-1, min(1, normals(3, :)))); mod(atan2d(normals(2, :), normals(1, :)), 360)];
    metrics = rx_design_metrics(rx_peb(positions_m, normals, p));
    score = metrics.rms_full_m;
    refinement.evaluations = refinement.evaluations+1;
    if ~isfinite(score)
        continue;
    end
    history = [seed_index refinement.evaluations score];
    for step = p.design.refinement_steps_deg
        for pass = 1:p.design.refinement_passes
            improved = false;
            for i = 1:K
                for coordinate = 1:2
                    best_angles = angles;
                    best_score = score;
                    for sign = [-1 1]
                        candidate = angles;
                        candidate(coordinate, i) = candidate(coordinate, i)+sign*step;
                        if coordinate==1
                            if candidate(1, i)<0 || candidate(1, i)>p.receiver.max_tilt_deg
                                continue;
                            end
                        else
                            candidate(2, i) = mod(candidate(2, i), 360);
                        end
                        metrics = rx_design_metrics(rx_peb(positions_m, rx_normals(candidate(1, :), candidate(2, :)), p));
                        refinement.evaluations = refinement.evaluations+1;
                        if metrics.rms_full_m<best_score*(1-p.design.improvement_relative_tolerance)
                            best_angles = candidate;
                            best_score = metrics.rms_full_m;
                        end
                    end
                    if best_score<score
                        improved = true;
                        angles = best_angles;
                        score = best_score;
                        history(end+1, :) = [seed_index refinement.evaluations score];
                    end
                end
            end
            if ~improved
                break;
            end
        end
    end
    refinement.history = [refinement.history; history];
    if score<refinement.rms_full_m
        refinement.rms_full_m = score;
        refinement.normals = rx_normals(angles(1, :), angles(2, :));
    end
end
end
