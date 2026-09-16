function [perturbed, coordinates_rad] = rx_perturb_normals(normals, variance_deg2, structure, trials)
validateattributes(variance_deg2, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
sigma = sqrt(variance_deg2)*pi/180;
K = size(normals, 2);
perturbed = zeros(3, K, trials);
switch structure
    case 'independent'
        noise = sigma*randn(2, K, trials);
        coordinates_rad = reshape(noise, 2*K, trials);
        for i = 1:K
            E = rx_tangent_basis(normals(:, i));
            for j = 1:trials
                delta = noise(:, i, j);
                angle = norm(delta);
                factor = 1;
                if angle>0
                    factor = sin(angle)/angle;
                end
                perturbed(:, i, j) = cos(angle)*normals(:, i)+factor*E*delta;
            end
        end
    case 'common_rotation'
        noise = sigma*randn(3, trials);
        coordinates_rad = noise;
        for j = 1:trials
            w = noise(:, j);
            angle = norm(w);
            R = eye(3);
            if angle>0
                a = w/angle;
                S = [0 -a(3) a(2); a(3) 0 -a(1); -a(2) a(1) 0];
                R = eye(3)+sin(angle)*S+(1-cos(angle))*(S*S);
            end
            perturbed(:, :, j) = R*normals;
        end
    otherwise
        error('cambridge:PoseStructure', 'Choose independent or common_rotation.');
end
end
