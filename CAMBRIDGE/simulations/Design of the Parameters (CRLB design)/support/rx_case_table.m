function t = rx_case_table(cases, kind)
half = [cases.half_angle_deg]';
K = [cases.K]';
area = 1e6*[cases.area_m2]';
if strcmp(kind, 'K')
    K(:) = NaN;
elseif strcmp(kind, 'area')
    area(:) = NaN;
end
t = table((1:numel(cases))', string({cases.label})', half, -log(2)./log(cosd(half)), ...
    [cases.fov_deg]', K, area, [cases.tilt_deg]', [cases.azimuth_offset_deg]', string({cases.family})', ...
    'VariableNames', {'Case', 'Label', 'HalfAngle_deg', 'LambertianOrder', 'FOV_deg', 'K', 'Area_mm2', 'ConeTilt_deg', 'AzimuthOffset_deg', 'Pattern'});
end
