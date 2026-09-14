function rx_write_design_tables(r, output_dir)
writetable(r.summary, fullfile(output_dir, 'best_configurations.csv'));
writetable(r.tilt.table, fullfile(output_dir, 'inclination_sweep.csv'));
writetable(r.K.table, fullfile(output_dir, 'K_sweep.csv'));
writetable(r.area.table, fullfile(output_dir, 'area_sweep.csv'));
for ih = 1:numel(r.best)
    b = r.best(ih);
    n = b.normals;
    t = table((1:size(n, 2))', acosd(max(-1, min(1, n(3, :))))', mod(atan2d(n(2, :), n(1, :)), 360)', n(1, :)', n(2, :)', n(3, :)', ...
        'VariableNames', {'Orientation', 'Tilt_deg', 'Azimuth_deg', 'nx', 'ny', 'nz'});
    writetable(t, fullfile(output_dir, sprintf('orientations_Phi%g.csv', b.half_angle_deg)));
end
end
