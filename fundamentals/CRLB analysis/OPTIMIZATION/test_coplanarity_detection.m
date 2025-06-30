%% Test Coplanarity Detection
% Specific test to verify coplanarity detection is working correctly

clear; clc;

fprintf('Testing Coplanarity Detection\n');
fprintf('============================\n\n');

%% Test different orientation configurations

% Test Case 1: Truly coplanar orientations (all in XY plane, z=0)
fprintf('Test 1: All orientations in XY plane (z=0)\n');
nt_1 = [
    1, 0, -1;    % x components: pointing E, N, W
    0, 1,  0;    % y components
    0, 0,  0     % z components: all horizontal
];
fprintf('Orientations:\n');
for i = 1:3
    fprintf('  [%.1f, %.1f, %.1f]\n', nt_1(:,i));
end

% Check coplanarity manually
v1 = nt_1(:,1);
v2 = nt_1(:,2);
normal = cross(v1, v2);
if norm(normal) > 1e-6
    normal = normal / norm(normal);
    fprintf('Plane normal: [%.3f, %.3f, %.3f]\n', normal);
    
    % Check third vector
    distance = abs(dot(nt_1(:,3), normal));
    fprintf('Distance of 3rd vector to plane: %.6f\n', distance);
    
    if distance < 0.2
        fprintf('✓ Vectors are coplanar\n');
    else
        fprintf('✗ Vectors are NOT coplanar\n');
    end
else
    fprintf('✗ First two vectors are parallel\n');
end

% Test Case 2: Non-coplanar orientations
fprintf('\nTest 2: Non-coplanar orientations\n');
nt_2 = [
    1,  0,  0;    % x components: E, N, down
    0,  1,  0;    % y components
    0,  0, -1     % z components: horizontal, horizontal, vertical
];
fprintf('Orientations:\n');
for i = 1:3
    fprintf('  [%.1f, %.1f, %.1f]\n', nt_2(:,i));
end

v1 = nt_2(:,1);
v2 = nt_2(:,2);
normal = cross(v1, v2);
if norm(normal) > 1e-6
    normal = normal / norm(normal);
    fprintf('Plane normal: [%.3f, %.3f, %.3f]\n', normal);
    
    distance = abs(dot(nt_2(:,3), normal));
    fprintf('Distance of 3rd vector to plane: %.6f\n', distance);
    
    if distance < 0.2
        fprintf('✗ Vectors appear coplanar (unexpected)\n');
    else
        fprintf('✓ Vectors are NOT coplanar (expected)\n');
    end
else
    fprintf('✗ First two vectors are parallel\n');
end

% Test Case 3: The problematic case from the original test
fprintf('\nTest 3: Original test case (theta=45°, different azimuth)\n');
theta_rad = deg2rad(45);
orientations_deg = [45, 0, 45, 90, 45, 180];  % theta, rho pairs

nt_3 = zeros(3, 3);
for i = 1:3
    theta = deg2rad(orientations_deg(2*i-1));
    rho = deg2rad(orientations_deg(2*i));
    
    nt_3(:,i) = [
        sin(theta) * cos(rho);
        sin(theta) * sin(rho);
        -cos(theta)
    ];
end

fprintf('Orientations (theta=45°, rho=0°,90°,180°):\n');
for i = 1:3
    fprintf('  [%.3f, %.3f, %.3f]\n', nt_3(:,i));
end

v1 = nt_3(:,1);
v2 = nt_3(:,2);
normal = cross(v1, v2);
if norm(normal) > 1e-6
    normal = normal / norm(normal);
    fprintf('Plane normal: [%.3f, %.3f, %.3f]\n', normal);
    
    distance = abs(dot(nt_3(:,3), normal));
    fprintf('Distance of 3rd vector to plane: %.6f\n', distance);
    
    if distance < 0.2
        fprintf('⚠ Vectors appear coplanar (threshold dependent)\n');
    else
        fprintf('✓ Vectors are NOT coplanar\n');
    end
else
    fprintf('✗ First two vectors are parallel\n');
end

fprintf('\nConclusion: The original test case with theta=45° is NOT truly coplanar.\n');
fprintf('For better coplanarity testing, use theta=90° (all horizontal).\n');
