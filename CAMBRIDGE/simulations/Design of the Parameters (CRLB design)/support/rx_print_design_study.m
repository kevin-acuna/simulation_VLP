function rx_print_design_study(kind, p, e)
fprintf('\n============================================================\nCAMBRIDGE | %s\n', upper(kind));
fprintf('BASE SYSTEM (swept quantities are explicitly listed below)\n');
fprintf('Receiver angular order m_R = %.6g\n', rx_receiver_order(p));
fprintf('Room [m]: %s; LED position [m]: %s; LED normal: %s\n', ...
    mat2str(p.environment.room_size_m'), mat2str(p.transmitter.position_m'), mat2str(p.transmitter.normal'));
fprintf('P_t = %.6g W; reference A_PD = %.6g mm^2; R_p = %.6g A/W; T_s = %g; g = %g\n', ...
    p.transmitter.power_W, 1e6*p.receiver.area_m2, p.receiver.responsivity_A_per_W, ...
    p.receiver.filter_transmission, p.receiver.optical_gain);
fprintf('Reference sigma^2 = %.6g W^2/sample; N_i = %d; fixed-total option M = %d\n', ...
    p.noise.variance_W2, p.acquisition.samples_per_orientation, p.acquisition.total_samples);
fprintf('Grid: x=%s; y=%s; z=%s m (%d positions)\n', mat2str(p.environment.x_m, 6), ...
    mat2str(p.environment.y_m, 6), mat2str(p.environment.z_m, 6), ...
    numel(p.environment.x_m)*numel(p.environment.y_m)*numel(p.environment.z_m));
fprintf('SVD relative tolerance = %g; boundary cosine tolerance = %g\n', ...
    p.numerics.rank_relative_tolerance, p.numerics.boundary_cosine_tolerance);
fprintf('Target PEB = %.6g cm. This is a theoretical bound, not achieved estimator error.\n', 100*e.target_peb_m);
fprintf('SWEPT VARIABLES AND FROZEN GEOMETRY\n');
switch kind
    case 'tilt_feasibility'
        fprintf('Tilt constraint = %s; tilt = %g deg; no normal may exceed this angle.\n', e.tilt_constraint, e.tilt_deg);
        fprintf('Half-power [deg]: %s; FOV [deg]: %s; K: %s\n', mat2str(e.half_angles_deg), mat2str(e.fov_values_deg), mat2str(e.K_values));
        fprintf('Area [mm^2]: %s; patterns: %s\n', mat2str(e.area_values_mm2), strjoin(e.patterns, ', '));
        fprintf('Budgets: %s; azimuth offset = %g deg\n', strjoin(e.budgets, ', '), e.azimuth_offset_deg);
        fprintf('Feasible means 100%% regular coverage, RMS<=target, and at least %.1f%% of positions with PEB<=target.\n', 100*e.min_target_coverage);
        fprintf('Area scaling is exact ONLY under the fixed optical noise model.\n');
        fprintf('Selected-pattern refinement enabled: %d. Selection minimizes samples, then area, then K, then RMS.\n', e.refine_selected);
    case 'K_information'
        fprintf('Fixed tilt = %g deg; half-power = %g deg; A_PD stays fixed.\n', e.tilt_deg, e.half_angle_deg);
        fprintf('K: %s; FOV [deg]: %s; patterns: %s\n', mat2str(e.K_values), mat2str(e.fov_values_deg), strjoin(e.patterns, ', '));
        fprintf('Budgets: %s; reference position [m]: %s\n', strjoin(e.budgets, ', '), mat2str(e.reference_position_m'));
        fprintf('Golden prefixes and repeated triplets are nested; regenerated uniform cones are NOT nested.\n');
    case 'link_budget'
        disp(rx_case_table(e.cases, kind, p));
        fprintf('Power [W]: %s; samples/orientation: %s; noise STANDARD-DEVIATION multipliers: %s\n', ...
            mat2str(e.power_values_W), mat2str(e.sample_values), mat2str(e.noise_std_scales));
        fprintf('Area, FOV and normal matrices stay fixed. Variance multipliers are the squares of the listed noise scales.\n');
        fprintf('Required budget enforces RMS<=target and %.1f%% target-PEB coverage.\n', 100*e.min_target_coverage);
    case 'coverage_geometry'
        fprintf('Fixed K=%d, half-power=%g deg, A_PD=%.6g mm^2.\n', e.K, e.half_angle_deg, p.receiver.area_m2*1e6);
        fprintf('Tilt [deg]: %s; FOV [deg]: %s\n', mat2str(e.tilt_values_deg), mat2str(e.fov_values_deg));
        fprintf('The geometric envelope is an optimistic upper bound, not the coverage of a finite codebook.\n');
end
fprintf('Regular 3D coverage, one-visible-ray coverage and target-PEB coverage are different quantities.\n');
fprintf('LOS, calibrated gain, known global normals, stationary PD, constant optical noise.\n');
fprintf('============================================================\n');
end
