function rx_print_experiment(kind, p, e)
if any(strcmp(kind, {'tilt_feasibility', 'K_information', 'link_budget', 'coverage_geometry'}))
    rx_print_design_study(kind, p, e);
    return;
end
fprintf('\n============================================================\n');
fprintf('CAMBRIDGE | %s | %s\n', upper(kind), char(datetime('now')));
fprintf('FIXED SYSTEM (case-specific optical parameters follow)\n');
fprintf('Receiver angular order m_R = %.6g\n', rx_receiver_order(p));
fprintf('Room [m]: %s | LED position [m]: %s | LED normal: %s\n', ...
    mat2str(p.environment.room_size_m'), mat2str(p.transmitter.position_m'), mat2str(p.transmitter.normal'));
fprintf('P_t = %.6g W | R_p = %.6g A/W | T_s = %.6g | optical gain = %.6g\n', ...
    p.transmitter.power_W, p.receiver.responsivity_A_per_W, p.receiver.filter_transmission, p.receiver.optical_gain);
fprintf('Noise: %s; sigma^2 = %.6g W^2 per sample\n', p.noise.model, p.noise.variance_W2);
fprintf('Maximum PD tilt = %.6g deg | SVD tolerance = %.3g | boundary tolerance = %.3g\n', ...
    p.receiver.max_tilt_deg, p.numerics.rank_relative_tolerance, p.numerics.boundary_cosine_tolerance);
if strcmp(kind, 'heatmap')
    fprintf('Map extent: x=[%g,%g], y=[%g,%g] m; requested step <= %g m\n', ...
        min(p.environment.x_m), max(p.environment.x_m), min(p.environment.y_m), max(p.environment.y_m), e.grid_step_m);
    fprintf('Every map uses a 3x3 position FIM: receiver height is NOT assumed known.\n');
else
    fprintf('Design grid: x=%s m\n             y=%s m\n             z=%s m\n', ...
        mat2str(p.environment.x_m, 6), mat2str(p.environment.y_m, 6), mat2str(p.environment.z_m, 6));
    fprintf('Number of positions: %d\n', numel(p.environment.x_m)*numel(p.environment.y_m)*numel(p.environment.z_m));
end
if strcmp(kind, 'K')
    fprintf('Acquisition modes: %s\n', strjoin(e.budgets, ', '));
    if any(strcmp(e.budgets, 'per_orientation'))
        fprintf('  per_orientation: N_i=%d; total samples = K*N_i\n', p.acquisition.samples_per_orientation);
    end
    if any(strcmp(e.budgets, 'fixed_total'))
        fprintf('  fixed_total: M=%d; integer counts allocated separately at every K\n', p.acquisition.total_samples);
    end
else
    fprintf('N_i = %d samples/orientation | sample-mean standard deviation = %.6g W\n', ...
        p.acquisition.samples_per_orientation, sqrt(p.noise.variance_W2/p.acquisition.samples_per_orientation));
end
if strcmp(kind, 'inclination')
    fprintf('Fixed: K=%d | A_PD=%.6g mm^2 | azimuth offset=%g deg\n', ...
        e.K, p.receiver.area_m2*1e6, e.azimuth_offset_deg);
else
    fprintf('CASE SETTINGS (NaN = swept quantity or not applicable to an explicit pattern)\n');
    disp(rx_case_table(e.cases, kind, p));
    for i = 1:numel(e.cases)
        if strcmp(e.cases(i).family, 'explicit')
            n = e.cases(i).normals;
            fprintf('Case %d: frozen normal matrix (one row per orientation)\n', i);
            disp(array2table(n', 'VariableNames', {'nx', 'ny', 'nz'}));
        end
    end
end
fprintf('SWEPT VARIABLES\n');
switch kind
    case 'inclination'
        fprintf('  Half-power angles [deg]: %s\n  Lambertian orders: %s\n', ...
            mat2str(e.half_angles_deg), mat2str(-log(2)./log(cosd(e.half_angles_deg)), 6));
        fprintf('  FOV [deg]: %s\n  Inclination [deg]: %s\n', mat2str(e.fov_values_deg), mat2str(e.tilt_values_deg, 8));
    case 'K'
        fprintf('  K: %s; cones are regenerated, not nested, without re-optimizing tilt.\n', mat2str(e.K_values));
    case 'area'
        fprintf('  A_PD [mm^2]: %s; optical noise remains FIXED.\n', mat2str(e.area_values_mm2, 8));
    case 'heatmap'
        fprintf('  Display heights [m]: %s; x/y sweep the map extent.\n', mat2str(e.heights_m));
end
fprintf('Assumptions: LOS, calibrated gain, known global normals, stationary PD.\n');
fprintf('Local PEB: Inf = rank-deficient; NaN = nonregular boundary.\n');
fprintf('Full-domain RMS is Inf if ANY position lacks a finite regular bound.\n');
fprintf('============================================================\n');
end
