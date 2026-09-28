function mc = rx_K5_monte_carlo(result)
p = result.parameters;
e = result.spec;
selected = result.grid_results{2}.selections;
angles = cellfun(@(s) [s.optimal_tilt_deg s.minimum_acceptable_tilt_deg s.minimum_near_peak_tilt_deg], selected, 'UniformOutput', false);
tilts = [angles{:} result.grid_agreement_table.MinimumAcceptableBothGrids_deg' result.grid_agreement_table.MinimumNearPeakBothGrids_deg'];
tilts = unique(tilts(isfinite(tilts)));
mc.runs = {};
mc.table = table();
if isempty(tilts)
    return;
end
count = numel(tilts)*size(e.mc_positions_m, 2)*numel(result.orientation_std_values_deg);
mc.runs = cell(1, count);
rows = cell(1, count);
index = 0;
settings = struct('trials', e.mc_trials, 'seed', e.seed, 'methods', {e.methods}, ...
    'budget', e.budget, 'solver', struct(), 'mode', 'pose_measurement', 'structure', e.orientation_structure);
for tilt = tilts
    normals = rx_cone_normals(e.K, tilt, e.azimuth_offset_deg);
    for ip = 1:size(e.mc_positions_m, 2)
        pc = p;
        pc.environment.x_m = e.mc_positions_m(1, ip);
        pc.environment.y_m = e.mc_positions_m(2, ip);
        pc.environment.z_m = e.mc_positions_m(3, ip);
        for sigma = result.orientation_std_values_deg
            run = rx_sensitivity_run(pc, normals, settings, sigma^2);
            run.table.PositionIndex = repmat(ip, height(run.table), 1);
            run.table.Tilt_deg = repmat(tilt, height(run.table), 1);
            run.table.OrientationStd_deg = repmat(sigma, height(run.table), 1);
            run.table.ErrorWithinTarget_percent = 100*reshape(mean(run.errors_m<=rx_coverage_threshold(p)/100, [1 2]), [], 1);
            run.table.VisibilityDisagreement_percent = repmat(100*run.visibility_disagreement_fraction, height(run.table), 1);
            index = index+1;
            mc.runs{index} = run;
            rows{index} = run.table;
        end
    end
end
mc.table = vertcat(rows{:});
end
