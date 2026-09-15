function r = study_coverage_geometry(p, e)
validateattributes(e.tilt_values_deg, {'numeric'}, {'vector', 'real', 'finite', '>=', 0, '<=', p.receiver.max_tilt_deg});
r.kind = 'coverage_geometry';
r.parameters = p;
r.spec = e;
[r.positions_m, r.grid] = rx_testbed(p);
v = p.transmitter.position_m-r.positions_m;
u = v./sqrt(sum(v.^2, 1));
alpha = acosd(max(-1, min(1, u(3, :))));
illuminated = -p.transmitter.normal'*u>0;
nt = numel(e.tilt_values_deg);
nf = numel(e.fov_values_deg);
r.peb_m = nan(size(r.positions_m, 2), nt, nf);
r.potential_coverage = zeros(nt, nf);
r.light_coverage = zeros(nt, nf);
r.target_coverage = zeros(nt, nf);
r.max_polar_angle_deg = max(alpha);
r.necessary_fov_deg = max(0, r.max_polar_angle_deg-e.tilt_values_deg);
r.all_visible_fov_deg = r.max_polar_angle_deg+e.tilt_values_deg;
pc = p;
pc.transmitter.half_angle_power_deg = e.half_angle_deg;
for it = 1:nt
    tilt = e.tilt_values_deg(it);
    normals = rx_cone_normals(e.K, tilt, e.azimuth_offset_deg);
    for jf = 1:nf
        pc.receiver.fov_deg = e.fov_values_deg(jf);
        [peb, info] = rx_peb(r.positions_m, normals, pc);
        r.peb_m(:, it, jf) = peb';
        r.light_coverage(it, jf) = mean(info.visible_count>0);
        r.potential_coverage(it, jf) = mean(illuminated & alpha<tilt+pc.receiver.fov_deg & tilt>0);
        r.target_coverage(it, jf) = mean(isfinite(peb) & peb<=e.target_peb_m);
    end
end
r = rx_summarize_study(r);
[T, F] = ndgrid(e.tilt_values_deg, e.fov_values_deg);
r.table = table(T(:), F(:), 100*r.light_coverage(:), 100*r.coverage(:), 100*r.potential_coverage(:), ...
    100*r.target_coverage(:), 100*r.rms_full_m(:), 100*r.nonregular_fraction(:), ...
    'VariableNames', {'Tilt_deg', 'FOV_deg', 'LightCoverage_percent', 'RegularCoverage_percent', ...
    'PotentialCoverage_percent', 'TargetCoverage_percent', 'RMS_full_cm', 'Nonregular_percent'});
end
