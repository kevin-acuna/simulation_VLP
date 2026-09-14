function r = study_inclination(p, e)
validateattributes(e.K, {'numeric'}, {'scalar', 'integer', 'positive'});
validateattributes(e.half_angles_deg, {'numeric'}, {'vector', 'real', 'finite', 'nonempty', '>', 0, '<', 90});
validateattributes(e.fov_values_deg, {'numeric'}, {'vector', 'real', 'finite', 'nonempty', '>', 0, '<=', 90});
validateattributes(e.tilt_values_deg, {'numeric'}, {'vector', 'real', 'finite', 'nonempty', '>=', 0, '<=', p.receiver.max_tilt_deg});
r.kind = 'inclination';
r.parameters = p;
r.spec = e;
[r.positions_m, r.grid] = rx_testbed(p);
nt = numel(e.tilt_values_deg);
nf = numel(e.fov_values_deg);
nh = numel(e.half_angles_deg);
r.peb_m = nan(size(r.positions_m, 2), nt, nf, nh);
for ih = 1:nh
    ph = p;
    ph.transmitter.half_angle_power_deg = e.half_angles_deg(ih);
    for jf = 1:nf
        ph.receiver.fov_deg = e.fov_values_deg(jf);
        for it = 1:nt
            normals = rx_cone_normals(e.K, e.tilt_values_deg(it), e.azimuth_offset_deg);
            r.peb_m(:, it, jf, ih) = rx_peb(r.positions_m, normals, ph)';
        end
    end
end
r = rx_summarize_study(r);
[T, F, H] = ndgrid(e.tilt_values_deg, e.fov_values_deg, e.half_angles_deg);
r.table = table(H(:), F(:), T(:), 100*r.rms_full_m(:), 100*r.rms_conditional_m(:), ...
    100*r.coverage(:), 100*r.nonregular_fraction(:), 'VariableNames', ...
    {'HalfAngle_deg', 'FOV_deg', 'Tilt_deg', 'RMS_full_cm', 'RMS_conditional_cm', 'Coverage_percent', 'Nonregular_percent'});
end
