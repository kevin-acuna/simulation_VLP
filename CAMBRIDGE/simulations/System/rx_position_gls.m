function [position_m, valid, optical_vector_W] = rx_position_gls(mean_W, normals, p, sample_counts)
K = size(normals, 2);
if nargin < 4
    sample_counts = p.acquisition.samples_per_orientation;
end
if isscalar(sample_counts)
    sample_counts = repmat(sample_counts, K, 1);
end
sample_counts = sample_counts(:);
validateattributes(mean_W, {'numeric'}, {'real', 'finite', '2d', 'nrows', K});
validateattributes(normals, {'numeric'}, {'real', 'finite', '2d', 'nrows', 3});
validateattributes(sample_counts, {'numeric'}, {'real', 'finite', 'integer', 'positive', 'numel', K});
H = normals';
Hwhite = sqrt(sample_counts).*H;
s = svd(Hwhite, 'econ');
assert(numel(s)==3 && s(3)>p.numerics.rank_relative_tolerance*s(1), ...
    'cambridge:Unidentifiable', 'The visible receiver normals must span R^3.');
optical_vector_W = Hwhite\(sqrt(sample_counts).*mean_W);
beta = sqrt(sum(optical_vector_W.^2, 1));
u = optical_vector_W./beta;
c = -p.transmitter.normal'*u;
valid = beta>0 & c>0 & all(normals'*u>cosd(p.receiver.fov_deg), 1);
position_m = nan(3, size(mean_W, 2));
m = -log(2)/log(cosd(p.transmitter.half_angle_power_deg));
C = p.transmitter.power_W*(m+1)*p.receiver.area_m2 ...
    *p.receiver.filter_transmission*p.receiver.optical_gain/(2*pi);
d = sqrt(C*c(valid).^m./beta(valid));
position_m(:, valid) = p.transmitter.position_m-u(:, valid).*d;
end
