function generate_reference()
here = fileparts(mfilename('fullpath'));
sourceRelativePath = '../../../../simulations/PoC';
sourceDirectory = fullfile(here, sourceRelativePath);
assert(isfile(fullfile(sourceDirectory, 'poc_params.m')));
assert(isfile(fullfile(sourceDirectory, 'rx_powers.m')));
assert(isfile(fullfile(sourceDirectory, 'rotm_zyx.m')));
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(sourceDirectory);
baseline = poc_params();
specifications = {
    'center-baseline', [0 0 0], [0 0 0], 0, 0, struct();
    'height-030', [0 0 0.3], [0 0 0], 0, 0, struct();
    'height-060', [0 0 0.6], [0 0 0], 0, 0, struct();
    'height-120', [0 0 1.2], [0 0 0], 0, 0, struct();
    'lateral-x030', [0.3 0 0], [0 0 0], 0, 0, struct();
    'lateral-x150', [1.5 0 0], [0 0 0], 0, 0, struct();
    'lateral-negative-x-positive-y', [-1.2 0.9 0.6], [0 0 0], 0, 0, struct();
    'lateral-positive-x-negative-y', [0.9 -1.2 1.2], [0 0 0], 0, 0, struct();
    'tilt-30', [0 0 0], [0 0 0], 30, 0, struct();
    'tilt-75', [0 0 0], [0 0 0], 75, 0, struct();
    'tilt-84-inside', [0 0 0], [0 0 0], 84, 0, struct();
    'tilt-86-outside', [0 0 0], [0 0 0], 86, 0, struct();
    'tilt-120-backface', [0 0 0], [0 0 0], 120, 0, struct();
    'tilt-azimuth-45', [0.9 0.6 0.6], [0 0 0], 35, 45, struct();
    'tilt-azimuth-225', [0.9 0.6 0.6], [0 0 0], 35, 225, struct();
    'attitude-yaw', [0.6 -0.3 0.6], [60 0 0], 35, 20, struct();
    'attitude-pitch', [-0.6 0.3 0.6], [0 25 0], 0, 0, struct();
    'attitude-roll', [0.6 0.9 0.3], [0 0 -30], 0, 0, struct();
    'attitude-yaw-pitch-roll', [0.6 -0.3 1.2], [35 20 -15], 20, 120, struct();
    'attitude-negative-yaw-pitch-roll', [-0.6 0.9 0.3], [-110 -35 25], 15, 250, struct();
    'power-off', [0 0 0], [0 0 0], 0, 0, struct('P_t', 0);
    'power-0100', [0.6 0.3 0.6], [0 0 0], 0, 0, struct('P_t', 0.1);
    'power-0810', [0 0 0], [0 0 0], 0, 0, struct('P_t', 0.81);
    'power-1620', [0 0 0], [0 0 0], 0, 0, struct('P_t', 1.62);
    'half-angle-20', [0.6 0.3 0.6], [0 0 0], 0, 0, struct('Phi_half', 20);
    'half-angle-60', [0.6 0.3 0.6], [0 0 0], 0, 0, struct('Phi_half', 60);
    'half-angle-80', [0.6 0.3 0.6], [0 0 0], 0, 0, struct('Phi_half', 80);
    'area-minimum', [0 0 0], [0 0 0], 0, 0, struct('A_det', 1e-8);
    'area-10-square-mm', [0 0 0], [0 0 0], 0, 0, struct('A_det', 1e-5);
    'area-package-maximum', [0 0 0], [0 0 0], 0, 0, struct('A_det', 1e-4);
    'fov-30-inside', [0 0 0], [0 0 0], 29, 0, struct('FOV', 30);
    'fov-30-outside', [0 0 0], [0 0 0], 31, 0, struct('FOV', 30);
    'fov-60-inside', [0 0 0], [0 0 0], 59, 0, struct('FOV', 60);
    'fov-60-outside', [0 0 0], [0 0 0], 61, 0, struct('FOV', 60);
    'fov-90-inside', [0 0 0], [0 0 0], 89, 0, struct('FOV', 90);
    'emission-backface', [0 0 0], [0 0 0], 0, 0, struct('n_t', [0 0 1]);
    'emission-above-anchor', [0 0 3], [0 0 0], 0, 0, struct();
    'emission-tilted-anchor', [0.3 -0.4 0.6], [0 0 0], 0, 0, struct('n_t', [0.5 0 -sqrt(0.75)]);
    'emission-displaced-anchor', [-0.6 0.2 0.6], [0 0 0], 0, 0, struct('t', [0.4 -0.3 2.2]);
    'attitude-combined-optical-parameters', [0.3 -0.6 0.9], [70 -15 10], 25, 200, struct('P_t', 0.7, 'Phi_half', 35, 'A_det', 4e-5, 'FOV', 70);
};
rows = cell(size(specifications, 1), 1);
for index = 1:size(specifications, 1)
    P = baseline;
    overrides = specifications{index, 6};
    names = fieldnames(overrides);
    for fieldIndex = 1:numel(names)
        P.(names{fieldIndex}) = overrides.(names{fieldIndex});
    end
    P.m = -log(2) / log(cosd(P.Phi_half));
    P.C = P.P_t * (P.m + 1) * P.A_det / (2 * pi);
    r = specifications{index, 2};
    attitude = specifications{index, 3};
    tilt = specifications{index, 4};
    azimuth = specifications{index, 5};
    R = rotm_zyx(attitude(1), attitude(2), attitude(3));
    N_B = [sind(tilt) * cosd(azimuth), sind(tilt) * sind(azimuth), cosd(tilt)];
    mu = rx_powers(r, R, N_B, P);
    normal = (R * N_B')';
    displacement = r - P.t;
    distance = norm(displacement);
    direction = displacement / distance;
    cosPhi = max(-1, min(1, dot(P.n_t, direction)));
    cosPsi = max(-1, min(1, dot(normal, -direction)));
    status = 'los';
    if P.P_t == 0
        status = 'off';
    elseif cosPhi <= 0
        status = 'outside-emission';
    elseif cosPsi <= 0 || cosPsi < cosd(P.FOV)
        status = 'outside-fov';
    end
    assert(isfinite(mu) && mu >= 0);
    assert(abs(acosd(cosPsi) - P.FOV) > 0.01);
    rows{index} = struct( ...
        'id', specifications{index, 1}, ...
        'emitter', struct('id', 'anchor', 'position', P.t, 'normal', P.n_t, 'powerW', P.P_t, 'halfPowerAngleDeg', P.Phi_half), ...
        'detector', struct('position', r, 'normal', normal, 'areaM2', P.A_det, 'fovHalfAngleDeg', P.FOV), ...
        'bodyAttitudeYawPitchRollDeg', attitude, ...
        'bodyDetectorNormal', N_B, ...
        'expected', struct('powerW', mu, 'distanceM', distance, 'irradianceAngleDeg', acosd(cosPhi), 'incidenceAngleDeg', acosd(cosPsi), 'status', status));
end
metadata = struct( ...
    'modelId', 'lambertian-los-v1', ...
    'sourceFunctions', {{'poc_params', 'rx_powers', 'rotm_zyx'}}, ...
    'sourceRelativePath', sourceRelativePath, ...
    'generator', 'generate_reference.m', ...
    'matlabRelease', version('-release'), ...
    'matlabVersion', version, ...
    'powerReference', 'Original rx_powers output, without noise or optical gain', ...
    'angleReference', 'World geometry from original rotm_zyx attitude', ...
    'units', struct('position', 'm', 'normal', 'unit vector', 'power', 'W', 'area', 'm^2', 'angles', 'deg', 'variance', 'W^2'));
fixture = struct( ...
    'metadata', metadata, ...
    'baseline', struct('halfPowerAngleDeg', baseline.Phi_half, 'detectorAreaM2', baseline.A_det, 'fovHalfAngleDeg', baseline.FOV, 'powerW', baseline.P_t, 'varianceW2', baseline.sigma2, 'averagingSamples', baseline.N_samples), ...
    'cases', {rows});
outputPath = fullfile(here, 'los-reference.json');
[file, message] = fopen(outputPath, 'w', 'n', 'UTF-8');
assert(file ~= -1, message);
closeFile = onCleanup(@() fclose(file));
fprintf(file, '%s\n', jsonencode(fixture, 'PrettyPrint', true));
fprintf('Generated %d LOS references using MATLAB %s: %s\n', numel(rows), version('-release'), outputPath);
end
