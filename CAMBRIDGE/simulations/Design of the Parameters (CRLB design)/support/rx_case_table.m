function t = rx_case_table(cases, kind, p)
half = [cases.half_angle_deg]';
K = [cases.K]';
area = 1e6*[cases.area_m2]';
order = ones(numel(cases), 1);
if nargin>=3
    order(:) = rx_receiver_order(p);
end
if isfield(cases, 'm_R')
    order = [cases.m_R]';
end
if strcmp(kind, 'K')
    K(:) = NaN;
elseif strcmp(kind, 'area')
    area(:) = NaN;
end
t = table((1:numel(cases))', string({cases.label})', half, -log(2)./log(cosd(half)), order, ...
    [cases.fov_deg]', K, area, [cases.tilt_deg]', [cases.azimuth_offset_deg]', string({cases.family})', ...
    'VariableNames', {'Case', 'Label', 'HalfAngle_deg', 'LambertianOrder', 'ReceiverOrder', 'FOV_deg', 'K', 'Area_mm2', 'ConeTilt_deg', 'AzimuthOffset_deg', 'Pattern'});
end
